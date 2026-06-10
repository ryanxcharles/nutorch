//! nutorchd: the Nutorch v2 daemon (PoC, issue 0002).
//!
//! Owns the tensor registry and the LibTorch context; serves newline-delimited
//! JSON requests over a Unix socket. One connection at a time (PoC).
//!
//! Known PoC simplification: stale-socket removal on startup is unconditional;
//! a second daemon on the same path steals it from a live first daemon (see
//! issues/0002-nutorchd-poc/02-daemon-spine.md).

mod convert;
mod protocol;
mod registry;

use std::io::{BufRead, BufReader, Write};
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::PathBuf;

use protocol::{Request, Response};
use registry::Registry;
use tch::{Device, Kind, Tensor};

fn default_socket_path() -> PathBuf {
    match std::env::var_os("TMPDIR") {
        Some(tmp) => PathBuf::from(tmp).join("nutorchd.sock"),
        None => PathBuf::from("/tmp/nutorchd.sock"),
    }
}

fn socket_path_from_args() -> PathBuf {
    let mut args = std::env::args().skip(1);
    while let Some(arg) = args.next() {
        if arg == "--socket" {
            if let Some(path) = args.next() {
                return PathBuf::from(path);
            }
        }
    }
    default_socket_path()
}

/// Look up two operand handles and apply v1's Rust-side device-equality
/// check (ported from v1/cargo/src/command_add.rs:140-148): a clean error
/// naming both devices, before any tch call. No auto-transfer.
fn binary_operands<'r>(
    registry: &'r Registry,
    a: &str,
    b: &str,
) -> Result<(&'r Tensor, &'r Tensor), String> {
    let ta = registry
        .get(a)
        .ok_or_else(|| format!("unknown handle: {a}"))?;
    let tb = registry
        .get(b)
        .ok_or_else(|| format!("unknown handle: {b}"))?;
    if ta.device() != tb.device() {
        return Err(format!(
            "device mismatch: tensors must be on the same device, got {:?} and {:?}",
            ta.device(),
            tb.device()
        ));
    }
    Ok((ta, tb))
}

fn handle_request(registry: &mut Registry, request: Request) -> Response {
    match request {
        Request::Tensor {
            data,
            device,
            dtype,
        } => {
            let device = match convert::parse_device(device.as_deref()) {
                Ok(d) => d,
                Err(e) => return Response::error(e),
            };
            let kind = match convert::parse_kind(dtype.as_deref()) {
                Ok(k) => k,
                Err(e) => return Response::error(e),
            };
            match convert::json_to_tensor(&data, kind, device) {
                Ok(tensor) => Response::handle(registry.insert(tensor)),
                Err(e) => Response::error(e),
            }
        }
        Request::Full {
            shape,
            value,
            device,
            dtype,
        } => {
            // Rust-side shape validation, ported from v1 command_full.rs:
            // non-empty, every dimension >= 1.
            if shape.is_empty() {
                return Response::error("shape cannot be empty");
            }
            if let Some(bad) = shape.iter().find(|d| **d < 1) {
                return Response::error(format!(
                    "invalid shape: every dimension must be >= 1, got {bad}"
                ));
            }
            let device = match convert::parse_device(device.as_deref()) {
                Ok(d) => d,
                Err(e) => return Response::error(e),
            };
            let kind = match convert::parse_kind(dtype.as_deref()) {
                Ok(k) => k,
                Err(e) => return Response::error(e),
            };
            let result = if let Some(i) = value.as_i64() {
                Tensor::f_full(&shape, i, (kind, device))
            } else if let Some(f) = value.as_f64() {
                Tensor::f_full(&shape, f, (kind, device))
            } else {
                return Response::error(format!("fill value must be a number, got {value}"));
            };
            match result {
                Ok(tensor) => Response::handle(registry.insert(tensor)),
                Err(e) => Response::error(convert::tch_error(e)),
            }
        }
        Request::Add { a, b } => {
            let (ta, tb) = match binary_operands(registry, &a, &b) {
                Ok(pair) => pair,
                Err(e) => return Response::error(e),
            };
            match ta.f_add(tb) {
                Ok(tensor) => Response::handle(registry.insert(tensor)),
                Err(e) => Response::error(convert::tch_error(e)),
            }
        }
        Request::Mm { a, b } => {
            let (ta, tb) = match binary_operands(registry, &a, &b) {
                Ok(pair) => pair,
                Err(e) => return Response::error(e),
            };
            // Rust-side validation ported from v1 command_mm.rs:117-140:
            // both rank-2, inner dimensions equal.
            let (sa, sb) = (ta.size(), tb.size());
            if sa.len() != 2 || sb.len() != 2 {
                return Response::error(format!(
                    "mm requires two 2-D tensors, got shapes {sa:?} and {sb:?}"
                ));
            }
            if sa[1] != sb[0] {
                return Response::error(format!(
                    "mm shape mismatch: inner dimensions must match, got {sa:?} and {sb:?}"
                ));
            }
            match ta.f_mm(tb) {
                Ok(tensor) => Response::handle(registry.insert(tensor)),
                Err(e) => Response::error(convert::tch_error(e)),
            }
        }
        Request::Mean { handle } => match registry.get(&handle) {
            // v1 fidelity: mean dtype defaults to float32 regardless of the
            // input kind (v1 command_mean.rs:133,152, lib.rs:197); also keeps
            // MPS happy (no float64).
            Some(tensor) => match tensor.f_mean(Kind::Float) {
                Ok(tensor) => Response::handle(registry.insert(tensor)),
                Err(e) => Response::error(convert::tch_error(e)),
            },
            None => Response::error(format!("unknown handle: {handle}")),
        },
        Request::Value { handle } => match registry.get(&handle) {
            Some(tensor) => {
                let cpu = match tensor.f_to_device(Device::Cpu) {
                    Ok(t) => t,
                    Err(e) => return Response::error(convert::tch_error(e)),
                };
                match convert::tensor_to_json(&cpu) {
                    Ok(value) => Response::value(value),
                    Err(e) => Response::error(e),
                }
            }
            None => Response::error(format!("unknown handle: {handle}")),
        },
    }
}

fn serve_connection(registry: &mut Registry, stream: UnixStream) -> std::io::Result<()> {
    let mut writer = stream.try_clone()?;
    let reader = BufReader::new(stream);
    for line in reader.lines() {
        let line = line?;
        if line.trim().is_empty() {
            continue;
        }
        let response = match serde_json::from_str::<Request>(&line) {
            Ok(request) => handle_request(registry, request),
            Err(e) => Response::error(format!("bad request: {e}")),
        };
        let mut payload = serde_json::to_string(&response).expect("response serializes");
        payload.push('\n');
        writer.write_all(payload.as_bytes())?;
        writer.flush()?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn request(json: serde_json::Value) -> Request {
        serde_json::from_value(json).expect("valid request")
    }

    fn expect_handle(response: Response) -> String {
        match response {
            Response::Handle { handle, .. } => handle,
            other => panic!("expected handle, got {other:?}"),
        }
    }

    fn expect_value(response: Response) -> serde_json::Value {
        match response {
            Response::Value { value, .. } => value,
            other => panic!("expected value, got {other:?}"),
        }
    }

    fn expect_error(response: Response) -> String {
        match response {
            Response::Error { error, .. } => error,
            other => panic!("expected error, got {other:?}"),
        }
    }

    fn value_of(registry: &mut Registry, handle: &str) -> serde_json::Value {
        expect_value(handle_request(
            registry,
            request(json!({"op":"value","handle":handle})),
        ))
    }

    #[test]
    fn full_round_trips_exactly() {
        let mut registry = Registry::new();
        let h = expect_handle(handle_request(
            &mut registry,
            request(json!({"op":"full","shape":[2,2],"value":1})),
        ));
        assert_eq!(value_of(&mut registry, &h), json!([[1.0, 1.0], [1.0, 1.0]]));
    }

    #[test]
    fn add_is_exact() {
        let mut registry = Registry::new();
        let a = expect_handle(handle_request(
            &mut registry,
            request(json!({"op":"tensor","data":[1,2,3]})),
        ));
        let b = expect_handle(handle_request(
            &mut registry,
            request(json!({"op":"tensor","data":[4,5,6]})),
        ));
        let sum = expect_handle(handle_request(
            &mut registry,
            request(json!({"op":"add","a":a,"b":b})),
        ));
        assert_eq!(value_of(&mut registry, &sum), json!([5.0, 7.0, 9.0]));
    }

    #[test]
    fn mm_of_ones_is_exact_and_mean_folds_it() {
        let mut registry = Registry::new();
        let a = expect_handle(handle_request(
            &mut registry,
            request(json!({"op":"full","shape":[2,2],"value":1})),
        ));
        let b = expect_handle(handle_request(
            &mut registry,
            request(json!({"op":"full","shape":[2,2],"value":1})),
        ));
        let product = expect_handle(handle_request(
            &mut registry,
            request(json!({"op":"mm","a":a,"b":b})),
        ));
        assert_eq!(
            value_of(&mut registry, &product),
            json!([[2.0, 2.0], [2.0, 2.0]])
        );
        let mean = expect_handle(handle_request(
            &mut registry,
            request(json!({"op":"mean","handle":product})),
        ));
        assert_eq!(value_of(&mut registry, &mean), json!(2.0));
    }

    #[test]
    fn mm_rejects_mismatched_shapes_naming_them() {
        let mut registry = Registry::new();
        let a = expect_handle(handle_request(
            &mut registry,
            request(json!({"op":"full","shape":[2,3],"value":1})),
        ));
        let b = expect_handle(handle_request(
            &mut registry,
            request(json!({"op":"full","shape":[2,3],"value":1})),
        ));
        let error = expect_error(handle_request(
            &mut registry,
            request(json!({"op":"mm","a":a,"b":b})),
        ));
        assert!(
            error.contains("[2, 3]"),
            "error should name shapes: {error}"
        );
    }

    #[test]
    fn mm_rejects_non_2d() {
        let mut registry = Registry::new();
        let a = expect_handle(handle_request(
            &mut registry,
            request(json!({"op":"tensor","data":[1,2,3]})),
        ));
        let error = expect_error(handle_request(
            &mut registry,
            request(json!({"op":"mm","a":a.clone(),"b":a})),
        ));
        assert!(error.contains("2-D"), "error should mention rank: {error}");
    }

    #[test]
    fn add_rejects_unknown_handle() {
        let mut registry = Registry::new();
        let a = expect_handle(handle_request(
            &mut registry,
            request(json!({"op":"tensor","data":[1]})),
        ));
        let error = expect_error(handle_request(
            &mut registry,
            request(json!({"op":"add","a":a,"b":"nope"})),
        ));
        assert!(error.contains("unknown handle"), "{error}");
    }

    #[test]
    fn full_rejects_bad_shapes() {
        let mut registry = Registry::new();
        let empty = expect_error(handle_request(
            &mut registry,
            request(json!({"op":"full","shape":[],"value":1})),
        ));
        assert!(empty.contains("empty"), "{empty}");
        let zero = expect_error(handle_request(
            &mut registry,
            request(json!({"op":"full","shape":[2,0],"value":1})),
        ));
        assert!(zero.contains(">= 1"), "{zero}");
    }
}

fn main() -> std::io::Result<()> {
    let socket_path = socket_path_from_args();
    // PoC: unconditional stale-socket removal (see module doc).
    let _ = std::fs::remove_file(&socket_path);
    let listener = UnixListener::bind(&socket_path)?;

    println!("nutorchd (PoC, issue 0002)");
    println!("socket: {}", socket_path.display());
    println!("MPS available: {}", tch::utils::has_mps());

    let mut registry = Registry::new();
    for stream in listener.incoming() {
        match stream {
            Ok(stream) => {
                if let Err(e) = serve_connection(&mut registry, stream) {
                    eprintln!("connection error: {e}");
                }
            }
            Err(e) => eprintln!("accept error: {e}"),
        }
    }
    Ok(())
}

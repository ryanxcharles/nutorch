# Experiment 1: `shape` end to end — daemon, CLI, Nushell

## Description

Implement `torch shape <t>` / `$t | torch shape` as a single end-to-end change:
the daemon handler, the CLI arm, and the generated Nushell wrapper. `shape`
returns a tensor's dimensions as a JSON list of integers — PyTorch's
`tensor.shape` / `tensor.size()`, and a restoration of v1's `torch shape`.

The op is small enough that one experiment covers the whole vertical slice. It
is a **bespoke (data-returning) op**, not a table op: the `ops/src/lib.rs` table
produces new tensor handles, while `shape` returns data. It therefore joins the
existing bespoke set (`value`, `tensors`, `free`) at every layer, mirroring
`value` — the closest sibling (single handle in, JSON value out).

Design decisions (the open questions from the issue README, now settled):

- **Reply envelope**: reuse `Response::value` with the dims as a JSON integer
  array — the same envelope `value`/`tensors` use. The CLI's existing
  `print_response` (`torch-cli/src/main.rs:141`) already prints
  `response["value"]` as JSON, so `torch shape $t` prints `[2,3]` on stdout with
  no new print path.
- **Lease/touch semantics**: treat `shape` as tensor _use_, not analysis — touch
  the lease and the tensor (like `value` at `dispatch.rs:114-115`), not the
  no-touch path that `tensors`/`status` use. Reading a tensor's shape is a
  reason to keep it alive.
- **Scalar / 0-dim tensors**: `tensor.size()` returns `[]` for a 0-dim tensor;
  that flows through as the JSON empty list `[]`. No special-casing.
- **Validation** (carried-forward principle 5): reuse `registry.get_tensor`,
  which already returns the right typed error when the handle is missing or is a
  module/optimizer rather than a tensor — same as `value`.
- **Reference page / `torch ops`**: `shape` stays out of the generated op-table
  reference and `torch ops`, exactly as `value`/`free`/`tensors` do today
  (parity with the existing bespoke ops). It is added to the CLI's hand-written
  bespoke help instead (`print_ops`, `print_op_help`).

## Changes

### `nutorchd/src/protocol.rs`

Add a `Shape` variant to the `Bespoke` enum, carrying a single `handle: String`
(mirrors `Value` without `meta`). Tag is the default lowercase `shape`.

```rust
Shape {
    handle: String,
},
```

### `nutorchd/src/dispatch.rs`

1. Add `"shape"` to the bespoke route list at the top of request parsing (the
   `match name.as_str()` arm currently listing
   `"tensor" | "value" | "free" |
   "tensors" | …`), so the request
   deserializes as `Bespoke` instead of falling through to the unknown-op /
   table path.
2. Add a `Bespoke::Shape { handle }` arm to the dispatch match (next to
   `Bespoke::Value`), mirroring `value`'s lookup + touch:

```rust
Bespoke::Shape { handle } => {
    lifecycle.lock().unwrap().touch();
    registry.touch(&handle);
    match registry.get_tensor(&handle) {
        Ok(tensor) => (Response::value(serde_json::json!(tensor.size())), false),
        Err(lookup) => (Response::error(lookup.code(), lookup.message()), false),
    }
}
```

`tensor.size()` returns `Vec<i64>`; `serde_json::json!` serializes it as a JSON
integer array. No device move is needed (sizes are metadata, not data), so
unlike `value` there is no `f_to_device` step.

### `torch-cli/src/main.rs`

Add a `"shape"` arm to `build_bespoke_request` (the `match args.op.as_str()` at
~408), mirroring `"value"` but with no flags:

```rust
"shape" => {
    if let Some((name, _)) = args.flags.first() {
        return Err(format!("unknown flag: --{name}"));
    }
    let handle = positional_or_stdin(args, 0, "tensor handle")?;
    Ok(serde_json::json!({ "op": "shape", "handle": handle }))
}
```

Routing already works: `nutorch_ops::find("shape")` is `None`, so `run()` (line
1019-1022) dispatches it through `build_bespoke_request`, and `print_response`
prints the value. `shape` is not in the `free`/`step` quiet-on-success list, so
the dims print.

Also surface it in the hand-written bespoke help (parity with `value`):

- `print_ops` (~896): add a bespoke listing line for `shape`.
- `print_op_help` (~902): add a `"shape"` arm —
  `usage: torch shape [handle]   (or pipe the handle in)`.

### `torch-cli/src/main.rs` — `NU_PRELUDE` (the generator)

`nutorch.nu` is generated (`torch nu-module`), so the wrapper is added to the
`NU_PRELUDE` constant, mirroring `nutorch value` (line 1101) — single handle,
dual input — but returning `list<int>` and skipping `__nutorch-restore` (dims
are always finite ints, never the non-finite token dialect):

```nu
# A tensor's dimensions as a native list of ints — handle as the argument
# or from $in (dual input); the argument wins when both arrive.
export def "nutorch shape" [handle?: string]: any -> list<int> {
  let __in = $in
  let __out = if $handle != null { ^torch shape $handle } else { $__in | ^torch shape }
  $__out | from json
}
```

### `nutorch.nu` (regenerated, not hand-edited)

Regenerate after the Rust change: `torch nu-module | save -f nutorch.nu`.

### `scripts/test-dual-input.nu`

Add a parity entry mirroring the `value` block (after it), asserting both forms
agree and equal the known shape:

```nu
# shape (prelude verb): handle as argument or pipe.
let sh = ([[1 2 3] [4 5 6]] | nutorch tensor)
let sp = ($sh | nutorch shape)
let sa = (nutorch shape $sh)
if not (check "shape: both forms identical" ($sp == $sa and $sp == [2 3])) { $failed = true }
```

## Verification

All commands run from the repo root after `cargo build --release` (or
`scripts/bootstrap.sh`), with `target/release` on `PATH` for the Nushell tests.

1. **Build & format gates** (the standard hygiene gates):
   - `cargo build --release` — clean, no new warnings.
   - `cargo fmt -- --check` — clean (run `cargo fmt` first; accept its output).
   - `cargo test` — the existing `dispatch.rs` unit tests stay green; add a unit
     test for `shape` alongside them (e.g. a 2×3 `full` tensor returns
     `value == [2,3]`, and a scalar returns `[]`).
   - `dprint check` — clean for the touched markdown (this file, the issue
     README).

2. **CLI, bash form** (the canonical pair, both run live):
   ```bash
   t=$(torch full '[2,3]' 1)
   torch shape $t          # → [2,3]
   torch shape $t | cat    # pipeline composes
   echo "$t" | torch shape # → [2,3]   (stdin handle)
   s=$(torch tensor '3.0'); torch shape $s   # → []   (0-dim)
   torch shape tensor://nope  # → error: unknown handle (non-zero exit)
   torch shape nope           # → error: malformed handle (no kind:// prefix)
   m=$(torch nn relu); torch shape $m        # → error: not a tensor
   ```
   Pass: dims print as a JSON int list; scalar prints `[]`; all three error
   cases exit non-zero with a Rust-side message — and they exercise distinct
   paths: `tensor://nope` is the unknown-handle path, `nope` is the
   malformed-handle path, `nn://…` is the wrong-kind path.

3. **Nushell, mirrored form**:
   ```nu
   use nutorch.nu *
   let t = (nutorch full [2 3] 1)
   nutorch shape $t        # → [2, 3]   (native list<int>)
   $t | nutorch shape      # → [2, 3]
   ```

4. **Dual-input parity**: `nu scripts/test-dual-input.nu` ends with
   `PASS: dual input parity (nushell module)` and the new `shape` line reads
   `ok  shape: both forms identical`.

Pass criteria: all gates green; both shells return `[2,3]` for a 2×3 tensor and
`[]` for a scalar in both input forms; missing/wrong-kind handles error cleanly;
the parity script passes.

## Design review

**Reviewer:** in-session `adversarial-reviewer` subagent (fresh context,
read-only). **Verdict: APPROVED** — zero Required findings. Every load-bearing
claim was checked against the real source: bespoke routing
(`dispatch.rs:34-41`), the internally-tagged `Bespoke` enum needing no explicit
rename (`protocol.rs:13-14`), `tensor.size() -> Vec<i64>` serializing as a JSON
int array via `Response::value` (`protocol.rs:132`), the typed
`registry.get_tensor` errors (`registry.rs:51-97`), CLI routing/printing
(`main.rs:1019-1022, 141-142, 1032`), and the 0-dim `[]` case
(`convert.rs:200-204`).

Findings addressed:

- **[Optional] Negative test mislabeled.** `torch shape nope` hits the
  _malformed-handle_ path (`bad_argument`, no `kind://` prefix), not the
  unknown-handle path it claimed. **Fixed**: the Verification section now tests
  three distinct error paths — `tensor://nope` (unknown handle), `nope`
  (malformed), and an `nn://` handle (wrong kind) — each correctly labeled.
- **[Nit] `print_ops` bespoke list is already partial** (lists only `tensor` and
  `value`, not `free`/`tensors`/`step`/`forward`). Noted; not a blocker. Adding
  `shape` joins that partial list as planned.

## Result

_(to be recorded after implementation)_

## Conclusion

_(to be recorded after implementation)_

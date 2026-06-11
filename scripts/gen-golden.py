#!/usr/bin/env python
"""Golden-test generator (issue 0005).

Run with the repo venv (the EXACT torch the daemon links):

    .venv-torch/bin/python scripts/gen-golden.py

Emits nutorchd/tests/golden.json. Every input tensor is constructed with the
dtype the daemon would assign (float32 default — Python's int64 inference
must never leak in) on device=mps, so expected outputs are bitwise
comparable with the daemon's MPS results.

Known documented deviation: nutorch's `mean` reduces in float32 regardless of
input dtype (v1 fidelity); PyTorch's mean errors on int inputs. The int-mean
case below encodes nutorch's documented semantics (t.float().mean()).

randn: the daemon generates on the seeded CPU generator and transfers to MPS
(tch cannot reach the MPS generator); the golden mirrors exactly that.
"""

import json
import pathlib

import torch

assert torch.backends.mps.is_available(), "golden generation requires MPS"
DEV = "mps"
DTYPES = {
    "float32": torch.float32,
    "float64": torch.float64,
    "int32": torch.int32,
    "int64": torch.int64,
}

cases = []


def make(spec):
    dtype = DTYPES[spec.get("dtype", "float32")]
    return torch.tensor(spec["data"], dtype=dtype, device=DEV)


def ok(name, op, tensors, params, compute):
    """compute(real_tensors) -> list of output tensors."""
    outs = compute([make(t) for t in tensors])
    cases.append(
        {
            "name": name,
            "op": op,
            "tensors": tensors,
            "params": params,
            "expect": {"values": [o.cpu().tolist() for o in outs]},
        }
    )


def ok_value(name, op, tensors, params, value):
    cases.append(
        {
            "name": name,
            "op": op,
            "tensors": tensors,
            "params": params,
            "expect": {"value": value},
        }
    )


def err(name, op, tensors, params, code):
    cases.append(
        {
            "name": name,
            "op": op,
            "tensors": tensors,
            "params": params,
            "expect": {"error": code},
        }
    )


def t(data, dtype="float32"):
    return {"data": data, "dtype": dtype}


# --- pointwise ---
ok("add_broadcast", "add", [t([[1, 2, 3], [4, 5, 6]]), t([10, 20, 30])], {},
   lambda ts: [ts[0] + ts[1]])
err("add_not_broadcastable", "add", [t([[1, 2, 3], [4, 5, 6]]), t([1, 2, 3, 4])], {},
    "shape_mismatch")
ok("sub", "sub", [t([5, 7, 9]), t([1, 2, 3])], {}, lambda ts: [ts[0] - ts[1]])
ok("sin", "sin", [t([0.0, 0.5, 1.0, 1.5707963267948966])], {},
   lambda ts: [torch.sin(ts[0])])
ok("pow_int_exponent", "pow", [t([1, 2, 3])], {"exponent": 3},
   lambda ts: [torch.pow(ts[0], 3)])
ok("pow_float_exponent", "pow", [t([1, 4, 9])], {"exponent": 0.5},
   lambda ts: [torch.pow(ts[0], 0.5)])
ok("clamp_both_bounds", "clamp", [t([-5, 0, 5])], {"min": -1, "max": 1},
   lambda ts: [torch.clamp(ts[0], -1, 1)])
ok("clamp_min_only", "clamp", [t([-5, 0, 5])], {"min": 0},
   lambda ts: [torch.clamp(ts[0], min=0)])

# --- reductions ---
ok("sum_all", "sum", [t([[1, 2], [3, 4]])], {}, lambda ts: [ts[0].sum()])
ok("sum_dim0", "sum", [t([[1, 2], [3, 4]])], {"dim": 0},
   lambda ts: [ts[0].sum(dim=0)])
ok("sum_dim1_keepdim", "sum", [t([[1, 2], [3, 4]])], {"dim": 1, "keepdim": True},
   lambda ts: [ts[0].sum(dim=1, keepdim=True)])
ok("mean_float", "mean", [t([1, 2, 3, 4])], {}, lambda ts: [ts[0].mean()])
# Documented deviation: nutorch mean reduces ints in float32 (v1 fidelity).
ok("mean_int_input_is_float32", "mean", [t([1, 2, 3, 4], "int64")], {},
   lambda ts: [ts[0].float().mean()])

# --- comparison ---
ok("eq", "eq", [t([1, 2, 3]), t([1, 0, 3])], {}, lambda ts: [ts[0] == ts[1]])
ok_value("allclose_true", "allclose", [t([1.0, 2.0]), t([1.0, 2.0])], {}, True)
ok_value("allclose_false_default_tol", "allclose", [t([1.0, 2.0]), t([1.01, 2.0])], {}, False)
ok_value("allclose_true_loose_rtol", "allclose", [t([1.0, 2.0]), t([1.01, 2.0])],
         {"rtol": 0.1}, True)
ok("sort_default", "sort", [t([3, 1, 2])], {},
   lambda ts: list(torch.sort(ts[0])))
ok("sort_descending", "sort", [t([[3, 1, 2], [6, 5, 4]])], {"dim": 1, "descending": True},
   lambda ts: list(torch.sort(ts[0], dim=1, descending=True)))

# --- linalg ---
ok("mm", "mm", [t([[1, 2, 3], [4, 5, 6]]), t([[7, 8], [9, 10], [11, 12]])], {},
   lambda ts: [ts[0] @ ts[1]])
err("mm_rank1", "mm", [t([1, 2, 3]), t([1, 2, 3])], {}, "shape_mismatch")
err("mm_inner_mismatch", "mm", [t([[1, 2], [3, 4]]), t([[1, 2], [3, 4], [5, 6]])], {},
    "shape_mismatch")

# --- shape ---
ok("cat_dim0", "cat", [t([1]), t([2]), t([3])], {}, lambda ts: [torch.cat(ts)])
ok("cat_dim1", "cat", [t([[1, 2]]), t([[3, 4]])], {"dim": 1},
   lambda ts: [torch.cat(ts, dim=1)])

# --- creation ---
ok("full", "full", [], {"shape": [2, 3], "value": 7},
   lambda ts: [torch.full([2, 3], 7, dtype=torch.float32, device=DEV)])
ok("full_float_value", "full", [], {"shape": [2], "value": 0.5},
   lambda ts: [torch.full([2], 0.5, dtype=torch.float32, device=DEV)])
err("randn_int_dtype", "randn", [], {"shape": [2], "dtype": "int64"}, "bad_dtype")
err("randn_float64", "randn", [], {"shape": [2], "dtype": "float64"}, "bad_dtype")

# randn with a seed: mirror the daemon (CPU generator, then transfer).
torch.manual_seed(42)
seeded = torch.randn([2, 3], dtype=torch.float32, device="cpu").to(DEV)
cases.append(
    {
        "name": "randn_seeded",
        "op": "randn",
        "tensors": [],
        "params": {"shape": [2, 3]},
        "seed": 42,
        "expect": {"values": [seeded.cpu().tolist()]},
    }
)

out = pathlib.Path(__file__).resolve().parent.parent / "nutorchd" / "tests" / "golden.json"
out.write_text(json.dumps(cases, indent=2) + "\n")
print(f"wrote {len(cases)} cases to {out}")

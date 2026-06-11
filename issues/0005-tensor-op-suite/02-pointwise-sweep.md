+++
[implementer]
agent = "claude-code"
model = "claude-fable-5"
+++

# Experiment 2: The first pointwise sweep (~55 ops)

## Description

The first category sweep on the Experiment-1 loom: the pointwise math surface.
Each op is one table row, one apply mapping (typically one line), and golden
coverage. The sweep also discharges two small owed items: `--alpha` on
`add`/`sub` (PyTorch fidelity; v1 had `--alpha` on add) and the
`softmax`/`log_softmax` pair (PyTorch makes dim required; v1 defaulted it to the
last dim — we make `--dim` required for PyTorch fidelity; reduction in float32
matches both).

**MPS support is determined empirically by the golden generator**: it runs every
op on MPS in Python first; any op the linked PyTorch cannot run on MPS is
excluded from the table (this is an MPS-only product — shipping an op that
always errors is worse than honest absence) and recorded in the Result.

## Changes

1. **`ops/src/lib.rs`**: compact row constructors (`unary(...)`,
   `binary_broadcasting(...)`) so each new op is one readable line; then the
   rows. The planned list (subject to the MPS-support oracle):
   - **unary (~42)**:
     `abs acos acosh asin asinh atan atanh ceil cos cosh
     deg2rad erf erfc exp exp2 expm1 floor frac log log10 log1p log2 logit
     neg rad2deg reciprocal relu round rsqrt sgn sigmoid sign sinc sinh sqrt
     square tan tanh trunc`
     plus `softmax` / `log_softmax` (required `--dim`; float32 reduction) and
     `nan_to_num` (optional `--nan/--posinf/--neginf` Float flags).
   - **binary, broadcasting (~13)**:
     `mul div maximum minimum atan2 fmod remainder floor_divide hypot
     copysign xlogy logaddexp heaviside`.
     `pow` gains nothing (stays scalar-exponent; tensor-exponent pow is recorded
     as a later spec point alongside clamp's tensor bounds). `positive` is
     skipped (identity). `digamma lgamma i0` ride the oracle: included if MPS
     supports them, excluded-and-recorded otherwise — same as everything else.
   - **`add`/`sub` gain `--alpha`** (Scalar flag, default 1), with the two
     formulas stated separately because the signs differ: **`add`:
     `a + alpha·b`; `sub`: `a − alpha·b`** (PyTorch semantics). Golden cases for
     BOTH `add --alpha` and `sub --alpha` so the harness would catch a sign
     error.
2. **`nutorchd/src/dispatch.rs`**: apply mappings (one line per unary; `--alpha`
   routed via `f_add` / scaled forms; `softmax`/`log_softmax` via their tch
   calls with `Kind::Float`).
3. **`scripts/gen-golden.py`**: a data-driven sweep section — domain-aware
   sample inputs per op (e.g. `acos` on [-1,1], `log` on positives, `acosh` on
   [1,∞)); one golden case per unary, two per binary (broadcast + exact),
   `--alpha` cases, `softmax` cases; regenerated goldens stay dprint-clean and
   byte-stable (the Experiment-1 lesson).
4. **No grammar, protocol, client, or doc changes** — that is the point of the
   loom. (The README op count lives behind `torch ops`, which is generated.)
5. The ops-crate `table_has_fifteen_ops` count test becomes count-agnostic
   (uniqueness + invariants stay; a hardcoded census per sweep would be a stale
   literal every time).

## Verification

1. **Hygiene**: `cargo build` 0 warnings; `cargo test` green;
   `cargo fmt --all -- --check` clean; `dprint check` clean on touched files
   (including the regenerated golden.json); `git status --porcelain v1/` empty.
2. **Golden suite green** with one case minimum per new op (the count grows from
   29 to ~85+; the harness floor assertion is raised accordingly).
3. **Generator regeneration is byte-stable** (run twice, identical file).
4. **Live spot-checks** (a handful, not exhaustive — the goldens are the
   exhaustive layer): `mul`/`div` pipelines; `relu` of a mixed-sign tensor;
   `add --alpha 2`; `softmax --dim 0` sums to ~1; an excluded-op name (if any)
   returns `unknown_op`.
5. **`torch ops` count** equals the new table size + 2 bespoke (programmatic).
6. **MPS-support exclusions recorded**: every op from the planned list that the
   oracle rejected is named in the Result with the Python error line.

**Pass** = all six. **Partial** = sweep lands minus recorded exclusions plus any
op whose golden disagrees (recorded, excluded, follow-up). **Fail** = the loom
required structural surgery (that would mean Experiment 1's architecture claim
was wrong).

## Design Review

**Reviewer:** `adversarial-reviewer` subagent (fresh context, read-only).
**First pass: CHANGES REQUIRED** — 1 Required (the `--alpha` formula was stated
once for both ops; `sub` is `a − alpha·b`, the opposite sign — exactly the
fidelity class this experiment exists to prevent; fixed with separate formulas
plus mandatory golden cases for both), 2 Optional (softmax's required-`--dim`
was misattributed to v1, which defaults to the last dim — reworded as a
PyTorch-fidelity choice; thirteen unhomed pointwise ops folded in or explicitly
dispositioned: `positive` skipped as identity, `digamma/lgamma/i0` ride the MPS
oracle), 1 Nit (the hardcoded table-count test becomes count-agnostic). **Second
pass: CHANGES REQUIRED** — the README index link still carried the stale pre-fix
title/count; fixed. **Approved** with the index in sync (per-finding
confirmations and the 55-op arithmetic verified by the reviewer).

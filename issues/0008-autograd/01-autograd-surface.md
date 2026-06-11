+++
[implementer]
agent = "claude-code"
model = "claude-fable-5"

[review.design]
agent = "claude-code"
subagent = "adversarial-reviewer"
model = "claude-opus"

[review.result]
agent = "claude-code"
subagent = "adversarial-reviewer"
model = "claude-opus"
+++

# Experiment 1: The autograd surface — five verbs and a flag

## Description

Expose the workflow; libtorch already has the engine. This experiment settles
all five of the issue's design questions and ships the whole surface:

```bash
w=$(torch randn '[3]' --requires_grad)
loss=$(torch mul $w $w | torch sum)
torch backward $loss
torch grad $w | torch value
torch zero_grad $w
d=$(torch detach $w)
```

(Flag spelling: `--requires_grad`, underscore — consistent with every existing
multi-word flag: `--keepdim`, `--start_dim`, `--split_size`. The issue README's
`--requires-grad` example is corrected by this decision.)

**The five design questions, settled here:**

1. **Graph lifetime vs. `free`** — document, don't fight. Freeing a handle
   removes it from the registry; if a live graph references the tensor,
   libtorch's refcount keeps the storage until the graph dies (when the
   anchoring outputs are freed or overwritten). Consequences shipped as docs +
   one demonstrating test: freeing an INTERMEDIATE handle before `backward` is
   fine (the graph holds it); freeing a LEAF before reading its grad loses your
   access to that grad (the handle is your only key). `torch tensors` accounting
   remains registry-only — graph-held storage is invisible to it, stated in the
   README section.
2. **Tracking faithfulness** — automatic, because tch is. Any op whose input
   requires grad produces a tracked result (its handle reports so). `detach` is
   the documented exit. Nothing to build beyond docs.
3. **`backward` semantics** — scalar-only (Rust pre-check: `numel() == 1`, error
   names the shape — PyTorch's own rule, with a better message than its C++
   one); requires `t.requires_grad()` (pre-check, clean error); gradients
   ACCUMULATE across calls (PyTorch fidelity), and **`zero_grad` ships in the
   same experiment** so the accumulation contract is usable; `--retain-graph` is
   recorded as future (PyTorch's default frees the graph after backward; a
   second backward through the same graph errors — that tch/libtorch error
   passes through as `torch_error`, acceptable and documented).
4. **`grad` returns a SNAPSHOT** — a fresh registry tensor deep-copied from
   `.grad` at call time. Rationale: PyTorch's `.grad` is accumulated IN PLACE by
   later backward calls; a live view behind a string handle would change under
   the shell's feet — action at a distance the pipeline model cannot express.
   Before any backward (undefined `.grad`): the error
   `no gradient: run backward first` (code `bad_argument`).
5. **MPS backward coverage by oracle** — per-op gradient goldens: for each
   representative op `o`, Python computes
   `x = tensor(..., requires_grad=True, device=mps); o(x).sum().backward()` and
   records `x.grad`; the harness replays the same chain through the in-process
   dispatch (create → op → sum → backward → grad) and compares exactly. Any op
   whose backward kernel MPS lacks is recorded, excluded from the golden set,
   and noted in the Result (forward stays available; only the golden coverage
   notes the gap).

**Surface shape:** `backward`, `grad`, `detach`, `zero_grad` are TABLE ops
(category `autograd`) — they fit the model exactly (one tensor in;
None/Handles(1) out; `backward`'s and `zero_grad`'s `ResultKind::None` already
exists for `manual_seed`). `--requires_grad` is a Bool flag on bespoke `tensor`
plus the weight-init creation rows: `randn`, `rand`, `zeros`, `ones`, `full`
(the rest of the creation family is trivially extensible later, recorded).
Requires-grad on a non-float dtype is `bad_dtype` (PyTorch's own rule).

## Changes

1. **`ops/src/lib.rs`**: four `autograd` rows — `backward` (Exactly(1), None),
   `grad` (Exactly(1), Handles(1)), `detach` (Exactly(1), Handles(1)),
   `zero_grad` (Exactly(1), None); `flag("requires_grad",
   Bool)` added to the
   five creation rows.
2. **`nutorchd/src/protocol.rs`**: `Bespoke::Tensor` gains
   `requires_grad: Option<bool>`.
3. **`nutorchd/src/dispatch.rs`**:
   - `build_input_tensor` applies `set_requires_grad(true)` when asked (after
     the float-dtype check → `bad_dtype` otherwise);
   - apply arms: `backward` (pre-checks: `requires_grad()`, `numel()==1`; then
     `f_backward()`); `grad` (undefined → `bad_argument`; else detach + deep
     copy → snapshot handle); `detach` (`f_detach()`); `zero_grad` — NOTE: tch's
     `zero_grad(&mut self)` needs `&mut`, but apply holds `&Tensor`; the arm
     mirrors tch's own implementation on the grad tensor: `f_grad()` → if
     defined, `detach_()` then `f_zero_()` (the detach prevents tracking the
     in-place zero); undefined grad is a no-op success, matching PyTorch's
     `x.grad = None` tolerance. **Pinned consequence**: after `zero_grad`, the
     grad remains DEFINED (zeros), so `grad` returns a zeros tensor — never the
     "no gradient" error;
   - the five creation arms apply `set_requires_grad` from the flag (float-only
     check shared with the bespoke path). **Ordering is load-bearing
     (design-review finding — the `.to()` non-leaf trap)**: for the transferring
     arms (`randn`, `rand` build on CPU then move to MPS) and for
     `json_to_tensor` inputs (which also build-then-transfer),
     `set_requires_grad(true)` must be the LAST step, applied to the
     post-transfer MPS tensor. Set before the move, the MPS tensor is a NON-leaf
     whose `.grad` stays None forever while gradients accumulate on a hidden CPU
     leaf the registry never holds — verified live in Python. A unit test pins
     the failing case: `randn --requires_grad` → backward → `grad` is populated;
   - unit tests: accumulation across two backwards then zero_grad resets;
     grad-before-backward errors; backward on non-scalar names the shape;
     backward on a non-tracked tensor errors; detach produces an untracked
     handle; snapshot immutability (grad handle unchanged by a later backward);
     free-intermediate-then-backward works; requires_grad on int dtype is
     `bad_dtype`.
4. **`torch-cli/src/main.rs`**: `requires_grad` joins `BESPOKE_PRESENCE_FLAGS`
   (the bespoke `tensor` arm reads it); table rows need nothing (Bool flags are
   already spec-driven).
5. **`scripts/gen-golden.py`**: a `grad_*` section — a new case shape
   `{"grad_op": name, "input": {...}, "params": {...},
   "expect_grad": [...]}`;
   representative set:
   `sin exp sigmoid tanh
   sqrt relu log mul(x,x) mm(x,x) pow(x,2) mean softmax(dim) sum(dim)`;
   the generator runs each on MPS (the oracle — backward-unsupported ops
   recorded and skipped); goldens stay finite.
6. **`nutorchd/tests/golden.rs`**: the `grad_op` case path — create input with
   requires_grad, run op (params; `[h,h]` for the with-self binary cases),
   `sum`, `backward`, `grad`, compare exactly; the harness sets requires_grad on
   the POST-transfer tensor. Floor raised to a concrete `>= 218` (207 + the
   final grad-case count).
7. **`README.md`**: an "Autograd" section — the workflow, the accumulation
   contract, `detach`, the graph-lifetime note (free intermediates freely; keep
   your leaf handles), and the `tensors`-accounting caveat.

## Verification

1. **Hygiene**: build 0 warnings; fmt/dprint clean on touched files; full suite
   green; `v1/` untouched.
2. **Golden gradients green** (every representative op exact vs Python on MPS;
   oracle exclusions recorded).
3. **Unit tests**: the eight cases in Changes item 3.
4. **Live, the issue's goal verbatim**: the README workflow —
   `randn
   --requires_grad` → `mul`/`sum` pipeline → `backward` → `grad` →
   `value` shows `2x`; `zero_grad` then `grad` returns zeros (pinned: the
   in-place zero leaves a defined grad — stated in docs); double backward
   without retain errors with a passthrough `torch_error`; accumulation
   demonstrated (two backwards → 2× the gradient, on a freshly rebuilt graph).
5. **Graph-lifetime live**: free an intermediate, backward still succeeds;
   `tensors` shows the freed handle gone while backward still worked (the
   documented decoupling, observed).
6. **Docs**: README section present, dprint-clean, commands verbatim from
   check 4.

**Pass** = all six. **Fail** = the table model could not express the four verbs
(protocol surgery needed), or gradient goldens diverge from Python beyond
exclusions.

## Design Review

**Reviewer:** `adversarial-reviewer` subagent (fresh context, read-only).
**First pass: CHANGES REQUIRED** — 1 Required, and a deep one: the design didn't
specify that `set_requires_grad` must be applied AFTER the CPU→MPS transfer in
the transferring creation arms (`randn`, `rand`) and the golden harness. The
reviewer proved the trap live in Python: set before the move, the MPS tensor is
a non-leaf (`is_leaf == False`), its `.grad` stays None forever, and gradients
accumulate on a hidden CPU leaf the registry never holds — `torch grad` would
error "no gradient" on every such tensor. Fixed: ordering specified as
load-bearing at all three sites, with a unit test pinning the exact failing
case. 2 Optional folded in: the softmax gradient golden was degenerate
(softmax(x).sum() ≡ 1 → expected grad exactly zero; a broken backward passes
vacuously) — replaced with softmax·softmax summed; and `zero_grad`'s aftermath
is now pinned (defined zeros, never the no-gradient error) with tch's own
`detach_()`-then-zero recipe adopted. 1 Nit: the golden floor is now a concrete
`>= 218`. The reviewer also pre-verified the load-bearing facts: backward works
end-to-end on MPS in the linked torch; all 13 representative backward kernels
run on MPS (zero expected exclusions); `f_grad` never errors (so `defined()` is
the correct gate); `set_requires_grad` mutates in place; aliased-handle
`mm(x,x)` is sound; and the table model fits all four verbs with no protocol
surgery.

## Result

**Result:** Pass

The whole surface landed: four table ops (`backward`, `grad`, `detach`,
`zero_grad` — category `autograd`), `--requires_grad` on bespoke `tensor` plus
the five weight-init creation rows, gradient goldens, and the README section.
All five issue design questions are settled as designed.

- **Gradient goldens: 13/13 first run** (220 total, floor 218; byte-stable
  regeneration at sha256 `7c71ad50…`) — every representative op's backward
  bitwise-matches Python on MPS, including the non-degenerate softmax·softmax
  case. **MPS backward oracle exclusions: zero** (as the design reviewer
  pre-verified).
- **Unit tests** (57 daemon tests, up from 49): accumulation → zero_grad →
  zeros; snapshot immutability; grad-before-backward; non-scalar backward naming
  the shape; untracked backward; detach untracking; the free-intermediate
  demonstration; int-dtype rejection; and the `.to()` non-leaf regression case
  (`randn --requires_grad` is a tracked MPS LEAF whose grad populates — the
  design review's trap, pinned).
- **Live, the issue's goal verbatim**: seeded `randn --requires_grad` →
  `mul|sum` → `backward` → `grad` reads exactly 2x the values; `zero_grad` →
  grad reads zeros (pinned semantics); double backward through the same graph
  errors with libtorch's own informative retain_graph message as a passthrough
  `torch_error`; two fresh graphs accumulate 2.0→4.0 while the first snapshot
  stays [2.0, 4.0]; freeing an intermediate handle then backward succeeds with
  the right gradient; all three error paths exit 1 with named causes.
- **Hygiene**: build 0 warnings; fmt/dprint clean; full suite green; `v1/`
  untouched.
- **One implementation find, caught by the unit test before review**: tch's
  `f_clone(&self, out)` is the clone-INTO-out variant — the natural reading
  (`g.f_clone(&g)`) silently aliases instead of copying, and the
  snapshot-immutability test failed exactly as designed to. The snapshot now
  allocates explicitly (`f_zeros_like` + `f_copy_`) with the trap documented at
  the call site.

## Conclusion

Autograd is a workflow, not an engine — confirmed: the entire feature is four
one-tensor table ops, one flag, and the ordering discipline the design review
made load-bearing (requires_grad LAST, post-transfer). PyTorch fidelity held
everywhere it was pledged: accumulation, scalar-only backward, float-only
leaves, and libtorch's own retain_graph error passing through. The issue's five
design questions all closed on first implementation. nn/optim now has its
prerequisite. The issue can close.

## Result Review

**Reviewer:** `adversarial-reviewer` subagent (fresh context, read-only),
reviewing the pre-commit working tree. **Verdict: APPROVED — no Required,
Optional, or Nit findings.** The reviewer independently confirmed all four
design-review mandates in code AND behavior (the post-transfer ordering at all
three sites with the regression test that would panic on the undefined grad; the
non-degenerate softmax golden; zero_grad→zeros pinned in test, README, and live;
the >= 218 floor against 220 actual), verified the f_clone aliasing claim
against the tch source (clone-INTO-out variant) and the explicit-copy fix with
its immutability assertion, spot-checked two gradient goldens against fresh
Python (exact), reproduced byte-stable regeneration at the recorded sha, ran the
full live workflow verbatim including all error paths and the dual-input forms
of all four verbs, judged the README's detach wording honest (shares data,
untracked), and confirmed registry hygiene (no orphans; backward/zero_grad
create nothing). **Close readiness: READY** — all five design questions settled
and verified; the Scope's exclusions correctly absent; the flag-spelling
deviation deliberately recorded.

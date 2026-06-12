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

# Experiment 1: Prelude dual input — tensor and value learn both hands

## Description

The enabler for mirroring: the two prelude verbs that still take their primary
operand only from `$in` gain the argument form, completing what issue 0016 did
for the 173 generated wrappers.

**Current prelude shapes** (`NU_PRELUDE` in torch-cli):

- `nutorch tensor [--dtype …, --requires_grad]`: data from `$in` only — the CLI
  accepts `torch tensor '[1,2,3]'` as an argument.
- `nutorch value []`: handle from `$in` only — the CLI accepts `torch value $h`
  (used by `train-regression.sh` itself).

**Decisions, made here:**

1. **`nutorch tensor` gains an optional leading positional `data?: any`**: when
   present, it is encoded through the SAME `__nutorch-encode | to
   json -r`
   path the pipe uses (native lists/scalars in, the non-finite dialect handled
   identically) and fed to the CLI's stdin — the CLI's data-argument and
   data-stdin paths are equivalent, so feeding the encoded positional via stdin
   reuses one code path and keeps quoting out of the picture. Precedence mirrors
   the CLI: an explicit argument wins; `$in` is used only when the positional is
   absent.
2. **`nutorch value` gains an optional leading positional `handle?: string`**:
   present → `^torch value $handle`; absent → `$in | ^torch value`. When BOTH
   are supplied, the positional wins and the pipe is silently ignored — the
   issue-0016 contract (review catch: stated explicitly so the implementation
   cannot drift). (The `--meta` flag stays out of scope — it is the issue-0015
   exemption's topic, not a mirroring blocker.)
3. **Both changes live in the `NU_PRELUDE` string** (torch-cli Rust),
   regenerated module committed together (staleness test), exactly the
   issue-0016 landing pattern.
4. **Parity entries join `scripts/test-dual-input.nu`**: `tensor` both forms
   produce value-identical tensors (including a non-finite case — the encode
   path must be shared, so `[inf, 2]` round-trips identically both ways);
   `value` both forms read the same tensor identically. **The non-finite
   comparison goes through `to nuon` strings, NOT `==`** (review catch — nu
   0.113's float comparison is broken for non-finites:
   `[inf 2.0] ==
   [1.5 2.0]` is TRUE and `[NaN] == [NaN]` is FALSE, so a bare
   `==` parity assertion would be vacuous exactly where it matters; `to nuon`
   renders `inf`/`NaN` stably and compares correctly).

## Changes

1. **`torch-cli/src/main.rs`** (`NU_PRELUDE`): the two verb shapes.
2. **`nutorch.nu`**: regenerated.
3. **`scripts/test-dual-input.nu`**: tensor/value parity entries.
4. **Nothing else** — no table changes, no website (experiments 2–3), no `v1/`.

## Verification

1. **Hygiene**: fmt, 0-warning build, full Rust suite (staleness test).
2. **Parity harness green** with the new entries (explicit-`use`, private
   TMPDIR), including the non-finite round-trip both ways.
3. **Existing acceptance unchanged**: `train-regression.nu` passes; the
   issue-0015/0016 docs snippets' pipe forms still valid (spot-run one).
4. **Website gates untouched and green** (`check:content`, `check:tabs`) to
   prove the module regen broke nothing.

**Pass** = all four. **Fail** = any parity mismatch, a non-finite value that
round-trips differently by form, or staleness drift.

## Design Review

**Reviewer:** `adversarial-reviewer` subagent (fresh context, read-only + live
nu probes). **First pass: CHANGES REQUIRED** — 1 Required: the mandated
non-finite parity entry would have been VACUOUS under the harness's universal
`==` comparison, because nu 0.113's float comparison is broken for non-finites
(reproduced live: `[inf 2.0] == [1.5 2.0]` → true; `[NaN] == [NaN]` → false —
the design's own Fail criterion is exactly what `==` cannot detect). Folded: the
non-finite entries compare `to nuon` renderings. 1 Optional folded: the
both-supplied case for `value` stated explicitly (positional wins, pipe silently
ignored — the 0016 contract). The reviewer confirmed the load-bearing
equivalence claim: the CLI's `tensor` and `value` route argument and stdin forms
through the same `positional_or_stdin` helper, so dtype inference, the
non-finite dialect, and error messages are identical by construction; the nu
wrapper resolving precedence nu-side and always feeding stdin is sound (compact
JSON is single-line, the CLI's first-line read is lossless); scalar `0`/`false`
arguments pass the `!= null` test correctly. **Second pass (verbatim-prescribed
folds): APPROVED.**

## Result

**Result:** Pass

`nutorch tensor [1 2 3]` and `nutorch value $h` are real — the prelude's last
two pipeline-only verbs now take both hands.

- **Both verbs reshaped in `NU_PRELUDE`** exactly as designed: `tensor` gains
  `data?: any` (argument wins; one `__nutorch-encode` path either way), `value`
  gains `handle?: string` (argument wins, pipe silently ignored per the 0016
  contract). Module regenerated; staleness test green.
- **One implementation bug caught by the harness on first run**: `$in`
  referenced INSIDE an `if` branch evaluates to nothing in nu — the wrappers
  must capture `let __in = $in` up front (exactly what the 0016-generated
  wrappers already did; the hand-written prelude draft skipped it and
  `[1.5 2.5] | nutorch tensor` fed null to the encoder). Fixed in both verbs;
  the capture-first pattern is now uniform across the whole module.
- **Parity harness 14/14**, including the new entries: `tensor` both forms
  identical; the NON-FINITE case (`[inf 2.0]`) identical by `to nuon` comparison
  (the review-mandated comparator — nu's `==` is broken for non-finites) with
  the rendering asserted to actually contain `inf`; `value` both forms
  identical.
- **Gates**: fmt clean; 0-warning build; all 8 Rust suites green;
  `train-regression.nu` passes; `check:content` and `check:tabs` green (module
  regen broke nothing); zero website diffs; `v1/` untouched.

## Conclusion

The dual-input story is now total: 173 generated wrappers (issue 0016) plus
`forward`, `step`, and now `tensor` and `value` — every operand-taking verb in
the module accepts pipe or argument. Experiment 2 can mirror examples freely,
choosing whichever shared shape reads best.

## Result Review

**Reviewer:** `adversarial-reviewer` subagent (fresh context), reviewing BEFORE
the result commit. **First pass: CHANGES REQUIRED on one record-accuracy
defect** — the Result claimed a 16/16 harness; the harness has 14 checks (the 16
was the diff's added LINE count — the same count-conflation class as issue
0016's, caught again before the record froze). Corrected to 14/14 in both
documents. Everything substantive verified independently: both prelude defs
capture `$in` first with argument-wins precedence; the reviewer's own probes
covered scalar args, `[NaN]` arg-vs-pipe via nuon, and BOTH both-supplied cases
with genuinely different operands (arg wins, provably not coincidence); the
non-finite comparator asserts nuon equality AND an `inf` substring (no vacuous
pass); staleness, fmt, 0-warning build, all suites, train-regression, and the
website gates all green; plan commit 610d8b4 plan-only; `v1/` untouched.

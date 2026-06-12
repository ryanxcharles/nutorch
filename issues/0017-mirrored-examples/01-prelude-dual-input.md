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

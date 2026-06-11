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

# Experiment 3: The lossless round-trip — bool, non-finite, and the meta envelope

## Description

Close the three recorded gaps that keep `torch value` → file → `torch tensor`
from being the persistence story, and document the workflow that story enables
(the issue's strand 4 rides here — it is one README section, not an experiment
of its own).

**Decisions, made here:**

1. **Bool input path.** `json_to_tensor` accepts `true`/`false`; `parse_kind`
   gains `"bool"`. Inference: with no `--dtype`, data containing only booleans
   infers `Kind::Bool`; mixing booleans and numbers without an explicit dtype is
   `bad_argument` (no silent cross-kind inference). With an explicit dtype,
   PyTorch casting rules apply both ways: `--dtype bool` casts numbers via
   `!= 0`; `--dtype float32` casts `true`/`false` to `1.0`/`0.0` (this is what
   `torch.tensor([True], dtype=…)` does — fidelity, not invention). The
   `where`/`masked_select` `!= 0` cast stays (it is a no-op on real Bool
   tensors, and remains the numeric convenience); their summaries keep the note.
2. **Non-finite policy: string tokens, not errors.** `tensor_to_json` emits
   `"NaN"`, `"Infinity"`, `"-Infinity"` for non-finite floats; `json_to_tensor`
   accepts exactly those three strings in numeric context. Rationale: erroring
   on export would make `torch value` fail on legitimate tensors (one `div` by
   zero away), and silently emitting `null` is the data corruption this issue
   exists to stop. A documented dialect beats both. (Python's own `json` module
   emits bare `NaN` literals — _invalid_ JSON — so a dialect of some kind is the
   norm here, and quoted strings at least stay parseable everywhere.)
3. **The meta envelope.** `torch value --meta $t` emits
   `{"dtype":"float32","shape":[2,3],"data":[[…]]}`; `torch tensor` accepts that
   same envelope as input (object-with-`data` is recognized; bare arrays keep
   working unchanged). Envelope `dtype` is honored; envelope + an explicit
   `--dtype` flag that _conflicts_ is `bad_argument` (explicit-over-implicit:
   ambiguity errors, nothing guesses). Envelope `shape` is validated against the
   data's inferred shape; mismatch is `bad_argument`. Wire: `Bespoke::Value`
   gains `meta: Option<bool>`; the `value` CLI verb gains `--meta`
   (`BESPOKE_PRESENCE_FLAGS` grows — the Experiment-1 mechanism, reused as
   predicted).
4. **Goldens stay finite.** The golden generator compares via Python's real
   JSON, which cannot express the dialect; the non-finite and bool round-trips
   are pinned by Rust unit tests (the established pattern for golden-unreachable
   semantics) plus live checks.

## Changes

1. **`nutorchd/src/convert.rs`**:
   - `parse_kind`: `"bool"` arm.
   - `json_to_tensor`: bool literals (infer `Kind::Bool` for all-bool data with
     no dtype; cast per explicit dtype; mixed bool/number without dtype →
     error); the three non-finite string tokens in numeric context; any other
     string → the existing type error.
   - `tensor_to_json`: non-finite floats → the tokens (both the 0-D arm and the
     element recursion).
   - Unit tests: bool round-trip (incl. dtype preservation), each token
     round-trips bit-exactly (NaN→NaN, ±inf→±inf), mixed-without-dtype errors,
     casts match PyTorch (`--dtype bool` on `[0,1,2]` → `[false,true,true]`;
     `--dtype float32` on `[true,false]` → `[1.0,0.0]`).
2. **`nutorchd/src/protocol.rs`**: `Value { handle, meta: Option<bool> }`.
3. **`nutorchd/src/dispatch.rs`**: the `value` arm builds the envelope when
   `meta` is true (`dtype` via `kind_name`, `shape` via `tensor.size()`, `data`
   via `tensor_to_json`); the `tensor` arm recognizes an envelope object
   (`data` + optional `dtype`/`shape`, conflict/mismatch → `bad_argument`). Unit
   tests: envelope round-trip preserves dtype for `int64` and `bool`;
   conflicting dtypes error; bad shape errors.
4. **`torch-cli/src/main.rs`**: `--meta` on `value` — BOTH sites: the
   `BESPOKE_PRESENCE_FLAGS` set AND the `value` arm of `build_bespoke_request`,
   which currently rejects all flags (the same two-site pattern `free`'s `--all`
   used). Nothing else — `torch tensor` already passes arbitrary JSON through.
5. **`README.md`** (strand 4): a "Saving tensors and reclaiming memory" section
   — export what you keep (`torch value --meta $w > w.json`), re-import
   (`torch tensor "$(cat w.json)"`), `torch free`/`torch
   tensors` for
   selective reclaim, `torch daemon restart` as the documented whole-registry
   valve, and the non-finite dialect note.

## Verification

1. **Hygiene**: build 0 warnings; fmt/dprint clean on touched files; all tests
   green; the 207 goldens untouched and green; `v1/` untouched.
2. **Unit tests**: the convert and dispatch cases above.
3. **Live round-trips** (the issue's acceptance, end to end):
   - `torch eq $a $b | torch value` prints booleans; feeding that output back
     via `torch tensor` yields a Bool tensor (listed as `bool` by
     `torch tensors`) — **the bool gap closed**;
   - divide to get `[NaN, inf, -inf]`, `torch value` shows the tokens (no `null`
     anywhere), round-trip back and `isnan`/`isposinf`/`isneginf` report
     identical truth — **the non-finite gap closed**;
   - `torch value --meta $t > f.json; torch tensor "$(cat f.json)"` on an int64
     tensor preserves dtype with no `--dtype` flag — **the dtype gap closed**;
   - envelope with conflicting `--dtype` errors; envelope with a wrong `shape`
     errors;
   - the full valve: export `--meta`, `torch daemon restart`, re-import,
     `torch value` equality.
4. **Docs**: the README section exists, dprint-clean, and its commands are the
   verbatim ones proven in check 3.

**Pass** = all four. **Fail** = the dialect or envelope demanded protocol
changes beyond the declared `meta` field.

## Design Review

**Reviewer:** `adversarial-reviewer` subagent (fresh context, read-only).
**Verdict: APPROVED — no Required findings (first pass).** The reviewer verified
every fidelity claim against the linked PyTorch (bool inference, both cast
directions), confirmed the null-corruption claim at the serde source level
(`From<f64>` → `Null` for non-finite, reached via tensor_to_json's float arm),
proved envelope recognition cannot collide (json_to_tensor has no Object arm —
every object errors today, so object-with-`data` is unambiguous), confirmed the
`meta` field is serde-back-compatible with old clients, judged the strict shape
equality and the mixed-without-dtype deviation (PyTorch infers int64; we error —
conservative, recorded, principle-4-grounded) both sound, and validated the
goldens-stay-finite rationale against the established golden-unreachable test
pattern. One Optional and one Nit folded in: the `value`-arm flag handling is
now spelled out as a two-site edit (the Experiment-1 `--all` pattern), and the
bool-cast unit test gains a negative/non-unit case (`[2,0,-1]` →
`[true,false,true]`) proving `!= 0` rather than `== 1`.

## Result

**Result:** Pass

All three recorded gaps closed, end to end, plus the strand-4 README section
with verbatim-proven commands.

- **Unit tests** (49 daemon tests, up from 42): bool inference + round-trip; the
  mixed-without-dtype error; both cast directions matching PyTorch including the
  `[2,0,-1]` → `[true,false,true]` case proving `!= 0`; all three tokens
  round-tripping bit-exactly (including through a real 0-division on MPS);
  tokens rejecting integer dtypes; envelope dtype preservation for int64 AND
  bool; conflict/mismatch/object-without-data errors with identical-dtype and
  matching-shape accepted.
- **Live, the issue's acceptance**:
  - bool gap: `torch eq … | torch value` → `[true,false,true]` → fed back via
    `torch tensor` → listed as dtype `bool` by `torch tensors`;
  - non-finite gap: `div` by zero → `["NaN","Infinity","-Infinity"]` (no `null`
    anywhere) → re-imported → `isnan`/`isposinf`/`isneginf` report identical
    truth per position;
  - dtype gap: `torch value --meta` emits the envelope; re-import preserves
    int64 with no `--dtype` flag;
  - envelope conflict and shape mismatch both error with named values;
  - **the full valve**: export `--meta` → `torch daemon restart` → re-import →
    `[10,20,30]`, dtype int64 — the documented workflow, executed.
- **Hygiene**: build 0 warnings; fmt/dprint clean; 207 goldens untouched and
  green (the generator emits only finite values, unaffected by the dialect);
  `v1/` untouched.
- **README**: the "Saving tensors and reclaiming memory" section landed with
  exactly the commands proven above, including the dialect note. (Result-review
  finding: the first attempt to add this section silently no-op'd — a
  patternless `str.replace` against dprint-rewrapped text, the project's
  recurring escape, caught here by the result gate because the reviewer greps
  artifacts rather than trusting the Result. The section now exists,
  dprint-clean, and its commands were re-run verbatim.)

## Conclusion

The round-trip is lossless: every dtype the registry holds (bool included),
every value a float tensor can contain (non-finite included), and the dtype
itself (via the envelope) all survive `torch value` → file → `torch tensor`.
With Experiments 1–3 together, all four strands of the issue are delivered:
free, the census, the lossless round-trip, and the documented relief valve. The
issue can close.

## Result Review

**Reviewer:** `adversarial-reviewer` subagent (fresh context, read-only),
reviewing the pre-commit working tree. **First pass: CHANGES REQUIRED** — three
Required findings, all one root cause: the README strand-4 section had silently
failed to land (a patternless `str.replace` no-op — caught because the reviewer
greps artifacts instead of trusting the Result), so the Result's claim was false
and the dialect-documentation constraint was violated. **Fixed**: the section
written for real (asserting replace), dprint-clean, its commands re-run
verbatim; the Result corrected to disclose the failure. **Re-review (fresh
context): APPROVED** — all three findings confirmed fixed, the export→re-import
pair and the full valve re-executed live with dtype preserved, non-finite tokens
bit-identical, and no regressions (49 unit + 207 golden tests green). Everything
substantive had already held in the first pass: both gap closures live, wire
back-compat for meta-less value requests, the where/masked_select no-regression
on real Bool conds, and the [2,0,-1] cast proof. **Close readiness: READY** —
all four strands discharged, Carried Constraints honored.

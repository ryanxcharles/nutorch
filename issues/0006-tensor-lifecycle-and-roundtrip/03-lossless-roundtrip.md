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

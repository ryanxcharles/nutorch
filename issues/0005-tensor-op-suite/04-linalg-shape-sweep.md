+++
[implementer]
agent = "claude-code"
model = "claude-fable-5"
+++

# Experiment 4: Linalg + shape/indexing sweep (~32 ops)

## Description

The structurally richest sweep: list-valued results (`split`/`chunk` return N
tensors), the Str-param + variadic combination (`einsum`), a ternary op
(`where`), and index-tensor operands (`gather`, `index_select`, `take`,
`masked_select`). One declared adjustment: the `VariableHandles` debug-assert
widens from `1..=2` to `>= 1` (split/chunk return N; the Experiment-3 arm was
scoped to the dim-pair trio).

Linalg on MPS is notoriously partial — the oracle decides (`svd`, `solve`,
`det`, `inverse` are included in the _plan_ and survive only if the linked
PyTorch runs them on MPS; exclusions recorded with error lines).

## Changes

1. **`ops/src/lib.rs`** rows:
   - **linalg (~11)**: `matmul` (general/batched, broadcasting per PyTorch),
     `bmm`, `dot` (1-D), `outer`, `einsum` (variadic tensors ≥1 + required
     `--equation` Str flag — the flags-only variadic invariant at work),
     `tril`/`triu` (`--diagonal` Int), `diag` (`--diagonal` Int), `trace`, plus
     oracle-gated `det`, `inverse` (and `svd` → `Handles(3)`, `solve` → binary,
     if MPS allows).
   - **shape/indexing (~21)**: `reshape` (`shape` IntList positional), `permute`
     (`dims` IntList positional), `transpose` (`dim0`,`dim1` Int positionals),
     `t`, `squeeze` (`--dim` optional), `unsqueeze` (`dim` Int positional),
     `flatten` (`--start_dim`/`--end_dim`), `stack` (variadic + `--dim`),
     `split` (`split_size` Int positional + `--dim`, `VariableHandles`), `chunk`
     (`chunks` Int positional + `--dim`, `VariableHandles`), `gather`
     (input+index tensors, required `--dim`), `index_select` (input+index,
     required `--dim`), `masked_select` (input+mask), `where` (cond+x+y —
     ternary `Exactly(3)`), `narrow` (`dim`,`start`,`length` Int positionals),
     `flip` (`dims` IntList positional), `roll` (`shifts` IntList positional +
     `--dims` IntList), `take` (input+index), `repeat` (`repeats` IntList
     positional), `repeat_interleave` (`repeats` Int positional + `--dim`),
     `movedim` (`source`,`destination` Int positionals).
2. **`nutorchd/src/dispatch.rs`**: arms; the widened VariableHandles assert;
   index ops pass tch errors through (`torch_error`) when index dtypes are wrong
   — goldens cover the happy path with `--dtype int64` index inputs.
3. **`scripts/gen-golden.py`**: cases for every survivor (≥1 each; split and
   chunk with multi-output expectations; einsum matrix-multiply and trace
   equations). **`where`'s cond handling, decided here**: goldens are single-op
   and `json_to_tensor` has no bool input path, so a cond can only arrive as a
   numeric tensor — the dispatch arm therefore casts cond to bool explicitly
   (`cond != 0`), a documented nutorch convenience noted in the op summary
   (PyTorch's `where` requires a bool cond; the cast is the shell-friendly
   bridge until a bool input path exists).
4. **`nutorchd/tests/golden.rs`**: floor raised (~165+).

## Verification

1. **Hygiene** (the standard five) + byte-stable regeneration.
2. **Golden suite green** (~165+).
3. **Live**: `split` of a 6-element tensor into 3 → three handles, each piping
   to `value`; `einsum --equation "ij,jk->ik"` with two matrices equals `mm`;
   `where` selects per the cond; `masked_select` with a 0/1 float mask; `gather`
   with an int64 index; `stack` of three via stdin + `--dim 1`.
4. **`torch ops` count** = table + 2.
5. **Oracle exclusions recorded** (expected candidates: the dense-linalg
   family).

**Pass** = all five. **Partial** = sweep minus recorded exclusions. **Fail** = a
structural change beyond the declared assert-widening was needed.

## Design Review

**Reviewer:** `adversarial-reviewer` subagent (fresh context, read-only).
**First pass: CHANGES REQUIRED** — 1 Required: `masked_select`'s mask has the
identical no-bool-input-path blocker the design solved only for `where`
(verified: PyTorch rejects float AND uint8 masks — Bool only), making its
planned happy-path golden unsatisfiable. **Fixed:** the same documented `!= 0`
cast applies to the mask, with its own golden and live check. The reviewer
verified everything else: einsum's tch signature matches the variadic+Str design
and the flags-only invariant; the where-cast is bit-identical to Python
float-truthiness; the VariableHandles widening is sound (chunk's count is
data-dependent, so `>= 1` is the honest bound, and the trio's 1-or-2 remains
structurally guaranteed); every planned tch API exists; the full dense-linalg
family runs on MPS in the linked torch — and one forewarning recorded: **`take`
is NOT implemented on MPS** and will become this sweep's recorded exclusion.
Approved with the masked_select fix in place (the fix is the reviewer's own
prescription verbatim).

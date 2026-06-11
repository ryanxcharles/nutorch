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

# Experiment 2: `torch tensors` — the listing that makes `free` targetable

## Description

You can't manage what you can't see. `torch tensors` lists every tensor the
registry holds, one per line, handle first, awk-composable:

```
$ torch tensors
3f2a…  [4096,4096]  float32  67108864  312s  45s
9c1b…  [3]          int64    24        10s   10s
$ torch tensors | awk '$5 > 300 {print $1}' | torch free   # free the old
```

Columns: **handle, shape, dtype, bytes, age (seconds since creation), idle
(seconds since last use)**. Whitespace-aligned for eyes, single-space parseable
for awk (shape prints without internal spaces: `[4096,4096]`). Rows sort
oldest-created first (the natural order for "what's been sitting here"). Empty
registry prints nothing, exit 0.

**Decisions, made here:**

- **Wire**: bespoke `{"op":"tensors"}` →
  `{"ok":true,"value":[{"handle":…,"shape":[…],"dtype":…,"bytes":…,
  "age_secs":…,"idle_secs":…},…]}`.
  The CLI renders columns; the JSON stays on the wire for tooling.
- **Per-tensor timestamps**: the registry entry grows `created` and `touched`
  `Instant`s. `insert` sets both; **tensor use touches** — table ops touch each
  operand handle (and each HandleOrScalar param handle) before resolving refs,
  and bespoke `value` touches its handle. `free` does not touch what it removes;
  `tensors` itself touches nothing.
- **`tensors` does not touch the daemon idle lease** (it is analysis, like
  `status` — issue-0004 convention) and **does not auto-spawn** the daemon.
- **No daemon → print nothing, exit 0.** A dead daemon truthfully holds no
  tensors, and `torch tensors | torch free` composing to a no-op is the right
  behavior. (`torch daemon status` remains the "is it up" probe that errors when
  down.)
- **Borrow order in `execute_table`**: touches are `&mut` operations, so the
  touch pass runs BEFORE the `&Tensor` resolution pass (the existing
  immutable-borrow phase is unchanged).

## Changes

1. **`nutorchd/src/registry.rs`**: `Entry { tensor, created, touched }` replaces
   the bare `Tensor` value; `insert` stamps both; `get` is unchanged (`&self`,
   no touch — touching is explicit); `touch(&mut self, handle)` (a no-op on an
   absent handle, so the table's touch pass stays harmless when resolution is
   about to error with `unknown_handle`); `list(&self) -> Vec<…>` sorted
   oldest-first with per-entry shape/dtype/bytes/ages; `approx_bytes`/
   `len`/`remove`/`clear`/`contains` adapt to the entry type. Unit tests: list
   order, idle resets on touch but not on `get`, entry fields.
2. **`nutorchd/src/protocol.rs`**: `Bespoke::Tensors` (unit variant).
3. **`nutorchd/src/dispatch.rs`**: `"tensors"` joins the bespoke-name list; the
   arm builds the JSON rows (no lease touch); `execute_table` gains the
   operand/param-handle touch pass; bespoke `value` touches. Unit tests: rows
   match registry contents; ops reset a tensor's idle; `tensors` resets neither
   tensor idle nor the daemon lease.
4. **`torch-cli/src/main.rs`**: `tensors` verb — a dedicated early branch in
   `run()` BEFORE the auto-spawn block (mirroring the `daemon` verb's placement;
   without it, `tensors` would fall through to the bespoke builder's unknown-op
   error and the spawn path). No spawn; daemon-down → exit 0 silent; render
   aligned columns from the wire JSON (handle, compact shape, dtype, bytes,
   `{age}s`, `{idle}s`).
5. **`convert.rs`**: a `kind_name(Kind) -> &str` helper for the dtype column,
   covering EVERY kind the registry can hold — not just `parse_kind`'s four
   input dtypes. Comparison ops mint `Kind::Bool` tensors and
   `randn --dtype float16` mints `Kind::Half`, so the map is:
   `float32 float64 float16 int32 int64 int16 int8 uint8 bool`, with a defined
   fallback (the Kind's debug name, lowercased) rather than a partial mirror
   that panics. Where a name overlaps `parse_kind`'s inputs it matches them; the
   rest are display-only (documented).

## Verification

1. **Hygiene**: build 0 warnings; fmt/dprint clean on touched files; all tests
   green (207 goldens untouched); `v1/` untouched.
2. **Unit tests**: the registry and dispatch cases in Changes items 1 and 3.
3. **Live**:
   - empty daemon → `torch tensors` prints nothing, exit 0; daemon NOT spawned
     by the call (no socket appears);
   - create an int64 and a float32 tensor → two rows, correct dtype and bytes
     columns; shapes print compact (`[2,3]`);
   - a Bool row lists correctly: `torch eq $a $b`, then `torch tensors` shows
     the result with dtype `bool` and 1-byte-per-element accounting;
   - age/idle behave: sleep, then `torch sin $t` — `$t`'s idle resets, age keeps
     growing; the OTHER tensor's idle does not reset;
   - the composition the issue promises:
     `torch tensors | awk '{print $1}' | torch free` empties the registry
     (verified via `torch daemon status`);
   - `torch tensors` does not reset the daemon idle clock.
4. **Wire**: `{"op":"tensors"}` via `nc` returns the JSON rows.

**Pass** = all four. **Fail** = the touch pass forced changes outside the
declared sites or broke a golden.

## Design Review

**Reviewer:** `adversarial-reviewer` subagent (fresh context, read-only).
**First pass: CHANGES REQUIRED** — 1 Required: the dtype column was scoped to
`parse_kind`'s four input dtypes, but the registry demonstrably holds
`Kind::Bool` (every comparison op) and `Kind::Half` (`randn --dtype
float16`) —
a partial `kind_name` either fails to compile or mislabels/panics on the
listing's expected case. Fixed: full kind coverage with a defined fallback, plus
a Bool-row verification step. 1 Optional folded in: the `tensors` verb's `run()`
branch placement is now explicit (before the auto-spawn block, mirroring
`daemon`). 1 Nit folded in: `touch` is a no-op on absent handles. The reviewer
verified the awk example honestly works (`"312s"` coerces to 312), the no-daemon
silent exit-0 trade is defensible as documented, the touch/borrow ordering is
sound, `free`'s remove-discard is Entry-compatible, no table op named `tensors`
exists, and Response::Value carries the array shape. Approved with the fixes in
place (the reviewer's prescriptions verbatim).

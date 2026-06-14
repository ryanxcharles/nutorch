+++
status = "open"
opened = "2026-06-14"
+++

# Issue 18: `shape` — a tensor's dimensions, on demand

## Goal

Restore `torch shape <t>` (and `$t | torch shape`) to v2: a dedicated operation
that returns a tensor's dimensions as a list of integers, matching PyTorch's
`tensor.shape` / `tensor.size()` and v1's `torch shape`. It is the one piece of
v1's implemented command surface that has no direct v2 equivalent.

## Background

The v1→v2 audit (this session) confirmed v2 re-implements all of v1's 40
commands and adds ~140 more ops plus the nn/optim subsystem — with two
exceptions:

- `torch devices` was **intentionally removed** (issue 0003: GPU-only, no device
  option anywhere). Not a gap.
- `torch shape` has **no v2 op**. `torch shape <h>` currently returns
  `unknown op: shape`.

The dimensions are not unavailable today — the `torch tensors` registry listing
shows a `shape` column per tensor (`torch-cli/src/main.rs` formats it from the
`tensors` reply, and the daemon computes `tensor.size()` to produce it). But
there is no per-handle op that returns just the dims for one tensor, which is
what scripting needs (`for d in (torch shape $t) { … }`, capturing a single
dimension, asserting a shape in a test). PyTorch users reach for `.shape`
constantly; v1 had it; it should exist in v2.

v1's implementation (`v1/cargo/src/command_shape.rs`) was exactly this: look up
the tensor, call `tensor.size()`, return a `list<int>` — the value is **not**
stored in the registry. It supported the dual input pattern (pipeline or
positional arg) and returned the empty list for a 0-dim (scalar) tensor.

## Analysis

`shape` is a **data-returning (bespoke) op**, not a table op. The
`ops/src/lib.rs` table is for operations that consume tensor handles and produce
a new tensor handle; `shape` returns a JSON int list instead. The established v2
pattern for this is the bespoke set — `value`, `tensors`, `free` — routed ahead
of the op table in `nutorchd/src/dispatch.rs` (the match arm at the top of
request parsing lists `"tensor" | "value" | "free" | "tensors" | …`). `shape`
joins that list rather than the table.

The three touch points, each mirroring an existing sibling:

- **Daemon** (`nutorchd/src/dispatch.rs`): add `"shape"` to the bespoke route
  and implement a handler that resolves one handle and returns its
  `tensor.size()` as a JSON integer array in the reply envelope. The size
  computation already exists for the `tensors` listing, so this is a small,
  well-precedented addition. It must validate the handle (good Rust-side error
  if missing / if the handle is a module, not a tensor — per carried-forward
  principle 5).
- **CLI** (`torch-cli/src/main.rs`): a `"shape"` arm that takes one tensor
  handle (positional or, via the stdin-prefix grammar, the leftmost missing
  slot) and sends the request. The generic data-reply printer
  (`response["value"]` at `main.rs:141`) already prints a JSON value, so the
  dims would print as `[2,3]` on stdout — composable in bash like `value` is.
- **Nushell** (`nutorch.nu`): an
  `export def "nutorch shape" [handle?: string]: any -> list<int>` wrapper
  mirroring `nutorch value` (`nutorch.nu:59`) — dual input (positional arg or
  `$in`), returning a native `list<int>`. If `nutorch.nu` is generated, the
  generator/prelude is the edit site, not the file directly.

Open design questions to resolve when **Experiment 1** is designed (not
prejudged here):

- **Reply envelope**: reuse the `{"value": …}` shape that `value`/`tensors`
  already use (so the CLI's existing printer works unchanged), vs. a dedicated
  key. Reusing `value` is the lighter path and likely correct.
- **Reference page / `torch ops`**: bespoke ops are not in the op table, so
  `shape` won't auto-appear in the generated reference (issue 0017) or in
  `torch ops`. Decide whether that is acceptable (it matches how `value`/`free`/
  `tensors` are handled today) or whether `shape` should be surfaced in docs
  some other way. Keep parity with the existing bespoke ops unless there's a
  reason to diverge.
- **Scalar / 0-dim tensors**: return `[]` (v1's behavior, and what
  `tensor.size()` yields), and make sure the CLI/nu round-trip the empty list
  cleanly.
- **Mirrored examples**: per issue 0017, any new examples on the site are
  line-for-line bash/nu pairs and are gate-checked (`check:mirror`); the verb
  scan covers new fences. Adding `shape` to docs inherits those gates.

## Scope

In (intended): the `shape` op end-to-end — daemon handler, CLI arm, Nushell
wrapper — with dual input, handle validation, the 0-dim case, parity tests
(`scripts/test-dual-input.nu`), and whatever docs/examples follow the issue-0017
mirroring gates. Out: any other v1 command (none remain), changing the
intentionally-removed `devices` decision, and broadening `shape` into a
size/stride/ndim metadata command (this op returns dims only, matching v1 and
PyTorch `.shape`).

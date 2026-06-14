+++
status = "open"
opened = "2026-06-14"
+++

# Issue 19: `shape` joins the website docs

## Goal

Document the `shape` op (issue 0018) on the nutorch.com docs site, with a
mirrored bash/nu example that passes the existing site gates — the piece of
issue 0018's intended scope that landed in the CLI's built-in help but never on
the website.

## Background

Issue 0018 added `shape` end to end (daemon, CLI, Nushell) and surfaced it in
the CLI's self-documenting help (`torch shape --help`, the `torch ops` bespoke
listing). But the user-facing website under `website/src/content/docs/` was not
touched, so `shape` is absent from the rendered docs that document its sibling
bespoke ops (`tensor`, `value`, `free`, `tensors`) on `tensors.md`. Issue 0018
is closed and immutable, so this is tracked as its own issue.

The site is gated (issues 0012–0017). Two gates bear directly on adding a
`shape` example:

- **`check:content`** (`website/scripts/check-content.ts`) — the honesty scan:
  every `torch <verb>` / `nutorch <verb>` in a docs fence must be a real table
  op (from live `torch ops --json`) or a member of the hand-maintained
  `NON_OP_VERBS` allowlist. That set currently lists `tensor`, `value`, `free`,
  `tensors`, `forward`, `step`, `daemon`, `nn`, `ops`, `nu-module`, `--version`
  — **but not `shape`**. So a `torch shape` fence fails the scan until `shape`
  is added to `NON_OP_VERBS`.
- **`check:mirror`** (`website/scripts/check-mirror.ts`) — every adjacent
  bash→nu fence pair must have equal non-blank/non-comment command-line counts
  (issue 0017). A new `shape` example must be a line-for-line bash/nu twin.

A third gate also reacts: **`check:tabs`** asserts a hardcoded per-page
tab-group count (`EXPECTED["docs/tensors/"]`), so the new bash/nu pair (which
the issue-0015 rehype plugin wraps into a tab group automatically) requires
bumping that count from `3` to `4`, or the gate FAILs. The remaining gates
(`check:links`, `check:theme`, `check:ops-ref`) stay green untouched —
`check:ops-ref` because `shape` is bespoke and not in the generated op-table
reference (parity with `value`/`free`/`tensors`, the issue-0018 decision).

## Analysis

`tensors.md` (section "Core", `order: 3`) is the natural home — it already
documents `tensor`/`value`/`free`/`tensors` with mirrored bash/nu pairs. `shape`
reads a tensor's dimensions, so it fits as a short addition (e.g. near the
creation examples or census section): given a handle, `torch shape $t` →
`[2,3]`, mirrored by `nutorch shape $t` → a native `list<int>`.

The change is therefore three edits plus verification:

1. **`website/scripts/check-content.ts`** — add `"shape"` to `NON_OP_VERBS`, so
   the honesty scan accepts the new fences. (`shape` is a real client verb,
   verified live in issue 0018 and again here.)
2. **`website/scripts/check-shell-tabs.ts`** — bump `EXPECTED["docs/tensors/"]`
   from `3` to `4` for the new tab group (the design-review finding).
3. **`website/src/content/docs/tensors.md`** — add a mirrored bash/nu example
   pair documenting `shape`, structurally equal line-for-line so `check:mirror`
   passes, with the example chosen so the bash and nu forms mirror cleanly
   (capture-then-shape, the same shared-shape editorial style issue 0017 used).

Verification runs the real gates (`bun install` first — `node_modules` is absent
on a fresh checkout), and the example is run live in both shells against the
built `torch`/`nutorch shape` so the doc shows real output. The toolchain is
present (bun 1.3.14).

Open questions for **Experiment 1** to settle (not prejudged): the exact
placement and wording of the example within `tensors.md`, and whether to show
the 0-dim `[]` case in the doc or keep the example to the common 2-D case.

## Experiments

- [Experiment 1: document `shape` on the Tensors page](01-document-shape-on-tensors-page.md)
  — **Designed**

## Scope

In (intended): adding `shape` to the website docs (`tensors.md`) with a mirrored
bash/nu example, and the `NON_OP_VERBS` allowlist update needed for the honesty
gate; verifying all site gates pass. Out: changing the `shape` op itself (issue
0018, done and closed); the generated op-table reference (bespoke ops stay out,
per issue 0018); regenerating golden vectors (separate future work); any other
doc page beyond what documenting `shape` naturally requires.

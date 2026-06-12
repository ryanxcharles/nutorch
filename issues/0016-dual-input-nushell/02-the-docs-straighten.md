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

# Experiment 2: The docs straighten — both forms, both shells

## Description

With the module now honoring the Dual Input Pattern, the documentation that
issue 0015 had to bend for honesty straightens back out. The dual-input nu
panels get their argument form, and every "pipeline-first by design" hedge
retires. After this the issue closes.

**The inventory** (every place the old limitation leaks into prose or panels):

1. **getting-started, dual-input section**: the nu panel currently shows one
   form with a "pipeline-first" comment; it becomes the two-form twin of its
   bash panel (`$a | nutorch add $b` pipeline / `nutorch add $a $b` argument),
   and the section prose returns to the strong claim — both forms work, in both
   shells.
2. **tensors, dual-input section**: same treatment; the section prose ("the
   Nushell module is pipeline-first by design") rewritten to state the rule once
   for both shells: the leftmost tensor comes from the pipe/stdin or as an
   argument — same grammar, owned by the CLI.
3. **nushell page**: "Wrappers are pipeline-first — the first tensor slot is
   `$in`" updated to describe dual input (pipe `$in` or pass handles as
   arguments; the CLI's stdin-prefix grammar fills the leftmost missing slots in
   both shells).
4. **Nothing else changes**: tab-group counts stay identical on every page
   (panels change content, not pairing), so the `check:tabs` count map is
   untouched; all other twins already use pipeline form, which remains valid.
   (Reviewed and already correct: ops.md's dual-input sentence is shell-neutral
   and honest — no change needed; the five `pipeline-first` hedges enumerated by
   the reviewer are the complete set.)

**Decisions:**

1. **Every displayed nu form runs live first** (explicit-`use`, private TMPDIR)
   — the argument forms verbatim as displayed, even though the parity harness
   already covers the ops, because the harness tests ops and the docs display
   SNIPPETS.
2. **The prose states the rule once, shell-neutrally**, instead of per-shell
   carve-outs — that is the whole point of the issue.

## Changes

1. **`website/src/content/docs/getting-started.md`**: dual-input nu panel +
   section prose.
2. **`website/src/content/docs/tensors.md`**: same.
3. **`website/src/content/docs/nushell.md`**: the wrapper-description sentence.
4. **Nothing else** — no Rust, no module, no plugin/gates, no `v1/`.

## Verification

1. **Displayed snippets reproduce live** (both new nu panels, verbatim).
2. **Build + gates**: `bun run build`, `check:content`, `check:tabs` (count map
   unchanged — asserts the panels changed content, not structure),
   `check:links`, `check:theme` green; dprint clean; zero `.rs` diffs.
3. **The hedge is gone**: grep over `website/src` finds no "pipeline-first"
   remnant (the phrase only ever existed as the limitation's hedge).
4. **By eye**: the getting-started dual-input group screenshotted on its nu tab,
   both modes.

**Pass** = all four. **Fail** = any displayed snippet the module rejects, any
count-map drift, or a surviving hedge.

## Design Review

**Reviewer:** `adversarial-reviewer` subagent (fresh context, read-only).
**Verdict: APPROVED (first pass).** The reviewer grepped every `pipeline-first`
occurrence in `website/src` — exactly five, all issue-0015 hedges, all covered
by the inventory (two prose + two fence comments + the nushell page sentence);
confirmed no legitimate use survives that the grep gate would wrongly delete;
confirmed the count map counts groups (not lines) so the panels' new content
cannot drift it; confirmed the new argument-form snippets pass the honesty
checker's verb scan; and confirmed ops.md's existing dual-input sentence is
already shell-neutral. One Nit folded: that ops.md fact is now recorded in the
inventory for completeness.

## Result

**Result:** Pass

The hedges are gone and both panels tell the same strong truth.

- **Both displayed snippets ran live first** (explicit-`use`, private TMPDIR):
  `$a | nutorch add $b` and `nutorch add $a $b` both → `[5.0, 7.0, 9.0]`.
- **All five `pipeline-first` hedge sites straightened** (the reviewer's
  enumerated set): getting-started's prose returns to "both of these work, in
  both shells" with the two-form nu panel; tensors' prose becomes "one grammar,
  both shells" with its two-form panel; the nushell page now describes the
  wrappers as honoring the dual input pattern. Grep over `website/src`: zero
  `pipeline-first` remnants.
- **Gates**: build clean (20 pages); `check:content`, `check:links`,
  `check:tabs` (count map unchanged — the panels changed content, not
  structure), `check:theme` all green; dprint clean; zero `.rs` diffs; `v1/`
  untouched. Screenshots: `logs/issue-0016/dual-input-nu-{light,dark}.png` (the
  getting-started page pinned to nu).

## Conclusion

Documentation and implementation agree again: the Dual Input Pattern is one
rule, stated once, true in both shells. With Experiment 1's delegation and this
straightening, issue 0016 is complete — close it.

## Result Review

**Reviewer:** `adversarial-reviewer` subagent (fresh context), reviewing BEFORE
the result commit and gating the issue close. **Verdict: APPROVED — no Required
findings.** The reviewer ran both displayed dual-input forms verbatim
(`[5.0, 7.0, 9.0]` each), confirmed zero `pipeline-first` hits in `website/src`,
read all three straightened sections, reproduced every gate (build,
check:content, check:tabs with the unchanged count map, check:links,
check:theme, dprint), and verified the process state (plan commit 8e86888
plan-only; zero `.rs` diffs at review time; `v1/` untouched). One Optional
folded as a review-prompted ADDENDUM beyond the experiment's declared no-module
scope (recorded as the deviation it is): the generated module's banner comment
still said "Wrappers are pipeline-first" — the generator string updated, module
regenerated, the staleness test and the 11/11 parity harness re-run green, zero
`pipeline-first` remnants anywhere in the project's live tree.

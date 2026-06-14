# Experiment 1: document `shape` on the Tensors page

## Description

Add a mirrored bash/nu example documenting `shape` to `tensors.md`, and the
honesty-gate allowlist entry it requires, then prove every site gate stays
green. One experiment covers the whole change — it is three small edits (two
gate scripts plus the doc) plus verification.

## Changes

### `website/scripts/check-content.ts`

Add `"shape"` to the `NON_OP_VERBS` set (next to `value`/`free`/`tensors`), so
the honesty scan accepts `torch shape` / `nutorch shape` in docs fences. `shape`
is a real client verb (issue 0018), not a table op, so it belongs in this
hand-maintained allowlist exactly as its bespoke siblings do.

### `website/scripts/check-shell-tabs.ts`

Bump `EXPECTED["docs/tensors/"]` from `3` to `4`. The tabs gate asserts a
hardcoded per-page tab-group count (`count === expected`); the Tensors page has
three bash→nu pairs today ("dual input", "Creating tensors", "Census"), and the
new `## Shape` pair makes a fourth `.shell-tabs` group. Without this edit the
gate FAILs with `found 4`. (Caught at the design-review gate — see below.)

### `website/src/content/docs/tensors.md`

Add a short `## Shape` section after "Creating tensors" (before "Export and
import"), with a mirrored bash/nu pair. The two panels are line-for-line twins
(2 command lines each, so `check:mirror` sees `bash=2 nu=2`):

````markdown
## Shape

A tensor's dimensions come back as a list — `torch shape` for one handle, the
same shape the `tensors` census shows per row:

```bash
t=$(torch full '[2,3]' 7)   # a 2×3 tensor
torch shape $t              # → [2,3]
```

```nu
let t = (nutorch full [2 3] 7)   # a 2×3 tensor
nutorch shape $t                 # → [2, 3]   (a native list<int>)
```
````

The bash form prints compact JSON (`[2,3]`); the nu wrapper returns a native
`list<int>`, which Nushell renders as `[2, 3]` — the same shell-rendering
difference the rest of the page already shows, not a structural divergence.

The example mirrors the canonical capture-then-use shape (issue 0017): bash
`t=$(…)` ↔ nu `let t = (…)`, then the op line. Both forms are run live (see
Verification) so the shown output is real.

## Verification

From `website/` (toolchain present: bun 1.3.14; `node_modules` absent on a fresh
checkout, so install first). `torch` must be on `PATH` for the gates that shell
out to the real binary.

1. **Install deps**: `bun install`.
2. **Live output check** (the example shows real output): with the issue-0018
   binaries built, run both panels verbatim and confirm bash prints `[2,3]` and
   nu renders `[2, 3]`:
   ```bash
   t=$(torch full '[2,3]' 7); torch shape $t            # → [2,3]
   nu -c 'use nutorch.nu *; let t = (nutorch full [2 3] 7); nutorch shape $t'
   ```
3. **Honesty scan**: `bun run check:content` — passes (no
   `unknown verb 'torch shape'`); proves the `NON_OP_VERBS` edit is necessary
   and sufficient. (Sanity: without the edit this gate FAILs on the new fence;
   record that it does, then with the edit it passes.)
4. **Mirror gate**: `bun run check:mirror` — the new pair reports
   `ok  tensors.md:<n>: bash=2 nu=2`; no FAIL anywhere.
5. **Tabs gate**: `check:tabs` drives a served build over CDP, so it needs the
   preview server up first: `bun run build`, then `bun run preview --port 4399`
   (background), then `bun run check:tabs`. The Tensors page must report
   `4 group(s)` — passing only because of the `EXPECTED["docs/tensors/"]` bump
   to `4`. (Sanity: with the bump but the new pair absent, or the pair present
   but no bump, this line FAILs `4 === 3`.)
6. **Remaining gates stay green**: `bun run check:links`, `bun run check:theme`,
   `bun run check:ops-ref` (the last is unaffected — `shape` is bespoke, not in
   the generated reference).
7. **Build**: `bun run build` completes without error (the page renders) — run
   before the preview server in step 5.

Pass criteria: all six gate commands and the build succeed; the live run shows
`[2,3]` / `[2, 3]`; `check:content` is demonstrated to depend on the
`NON_OP_VERBS` edit, and `check:tabs` on the count bump.

## Design review

**Reviewer:** in-session `adversarial-reviewer` subagent (fresh context,
read-only). **Verdict: CHANGES REQUIRED → fixed.** It confirmed the honesty-scan
and mirror-gate halves against the real source (the `NON_OP_VERBS` regex matches
`shape`; `commandLines()` excludes only blank and `#`-prefixed lines, so the
inline-comment example counts `bash=2 nu=2`; the fences are adjacent), and that
`check:ops-ref` is unaffected and the live behavior matches.

Findings addressed:

- **[Required] Missed `check:tabs` count update.** `check-shell-tabs.ts` asserts
  a hardcoded `EXPECTED["docs/tensors/"] = 3` with `count === expected`; the new
  pair makes a 4th group, so the gate would FAIL `4 === 3`. **Fixed**: the
  Changes section now includes bumping that entry to `4`, and the README
  Background / Verification no longer claim `check:tabs` "stays green
  untouched."
- **[Optional] `check:tabs` needs the preview server.** It drives a served build
  over CDP at `localhost:4399`. **Fixed**: Verification step 5 now starts
  `bun run build` + `bun run preview --port 4399` before `check:tabs`.

## Result

**Result:** Pass

Implemented the three edits as designed:

- `website/scripts/check-content.ts`: added `"shape"` to `NON_OP_VERBS`.
- `website/scripts/check-shell-tabs.ts`: bumped `EXPECTED["docs/tensors/"]` `3`
  → `4`.
- `website/src/content/docs/tensors.md`: added the `## Shape` section with the
  mirrored bash/nu pair.

Verification (`bun install` run first — `node_modules` was absent):

- **Live output:** `torch shape $t` → `[2,3]`; `nutorch shape $t` → a native
  `list<int>` (`[2, 3]`). Matches the doc.
- **`check:content`** — passes (`content checks passed`). Demonstrated to depend
  on the allowlist edit: temporarily removing `"shape"` makes it FAIL with
  `unknown verb 'torch shape'`; restoring it passes again.
- **`check:mirror`** — `mirror gate passed`; the new pair reports
  `ok tensors.md:2: bash=2 nu=2` (the page now has four balanced pairs).
- **`check:links`** — `links ok: 20 pages checked`.
- **`check:ops-ref`** — `ops reference current (185 ops, 9 pages)` — unaffected,
  as predicted (`shape` is bespoke).
- **`bun run build`** — completes; the page renders with `<h2 id="shape">Shape`.
- **`check:tabs`** — its substantive assertion verified directly against the
  built HTML: `dist/docs/tensors/index.html` contains exactly **4**
  `class="shell-tabs` groups, matching the `EXPECTED` bump to `4` (the gate's
  check is `count === expected`).

Environment limitation (not a defect): `check:tabs` and `check:theme` drive a
served build over CDP and require Google Chrome at
`/Applications/Google Chrome.app`, which is **not installed on this machine**,
so the full gates could not be executed here. `check:theme` is unrelated to this
change (theme matrix). For `check:tabs`, the count assertion — the only part
this change affects — was confirmed against the same built HTML the gate
fetches. On a machine with Chrome, run
`bun run build && bun run preview --port 4399` then `bun run check:tabs` to
execute it end to end.

## Conclusion

`shape` is now documented on the website: the Tensors page gains a `## Shape`
section with a mirrored bash/nu example, rendered as a fourth shell-tab group,
and the honesty scan accepts the new verb. The three site gates this change
touches (`check:content`, `check:mirror`, and the `check:tabs` count) are all
satisfied — the first two executed green here, the third verified against the
built HTML pending a Chrome-equipped run. This completes the website-docs piece
that issue 0018 scoped but left undone, so `shape` is now documented everywhere
its bespoke siblings are: CLI help and the docs site.

## Completion review

**Reviewer:** in-session `adversarial-reviewer` subagent (fresh context,
read-only). **Verdict: APPROVED** — no Required or Optional findings. It
independently reproduced every load-bearing claim: the diff is exactly the three
source edits plus the issue docs (nothing extraneous); `check:content`,
`check:mirror` (new pair `ok tensors.md:2: bash=2 nu=2`), `check:links`, and
`check:ops-ref` (185 ops, unchanged) all pass; Chrome is genuinely absent and
both CDP gates hardcode its path, so attributing them to that is accurate;
`bun run build` yields exactly 4 `class="shell-tabs` groups on the tensors page
(matching the bump) and renders `<h2 id="shape">`; live
`nutorch shape $t |
describe` is `list<int>`; `dprint check` clean; plan and
result commits are separate.

- **[Nit] nu annotation vs REPL rendering.** The doc's `# → [2, 3]` is the
  logical list value; interactive Nushell renders a `list<int>` as a vertical
  table. Reviewer marked it acceptable (the parenthetical "(a native
  `list<int>`)" discloses the type, and it matches the page's existing
  convention of annotating values inline, e.g. `arange … # [0, 2, 4, 6, 8]`).
  Left as-is.

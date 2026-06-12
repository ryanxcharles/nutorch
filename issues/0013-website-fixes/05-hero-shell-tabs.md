+++
[implementer]
agent = "claude-code"
model = "claude-fable-5"

[review]
waived = "user decision 2026-06-12: no adversarial review for issue 0013"
+++

# Experiment 5: Hero shell tabs — bash/zsh and Nushell

## Description

Punch-list addition: the hero example gets a shell toggle. The shell-support
question was put to the user first; the decision: **two tabs — "bash / zsh" and
"Nushell"** (bash and zsh share syntax byte-for-byte; fish differs only
trivially and stays in the caption; Nushell is the differentiated story and
earns its tab). Per the user's direction this experiment was implemented first
and written up after, with one standing order: if the Nushell example failed to
reproduce, STOP immediately.

**Decisions:**

1. **The Nushell tab shows the module form, no `use` line** — honest for what a
   hero depicts (a brew user at their interactive REPL, where the issue-0014
   autoload stub seats the module). Scripts use `use`; the docs page says so.
2. **Reproduction is the gate, with a DISCRIMINATING form** (the issue-0014
   lesson applied): the exact displayed snippet ran via
   `nu -c 'use /opt/homebrew/share/nutorch/nutorch.nu *; …'` — explicit `use`
   because `-c` skips autoload, and the pipeline form
   (`[1 2 3] | nutorch tensor`) is module-only, so passing it cannot be a
   CLI-symlink false positive. Output: `[5.0, 7.0, 9.0]` — byte-matching the
   displayed comment.
3. **Mechanism**: both blocks Shiki-rendered at build (existing `CodeBlock`,
   dual themes); two-button `role="tablist"` control with `aria-selected` and
   panel `hidden` swapping in a few lines of vanilla inline JS; choice persisted
   to localStorage (`hero-shell`); default bash/zsh. Active-tab styling is one
   CSS rule keyed on `aria-selected`.

## Changes

1. **`website/src/pages/index.astro`**: `heroDemoNu`, the tab control + two
   panels, the tab script.
2. **`website/src/styles/global.css`**: the `.hero-shell-tab` active rule.
3. **Nothing else** — no Rust, no docs content, no `v1/`.

## Verification

1. Both examples reproduce live (bash via the CLI; nu via the explicit-use
   discriminating form).
2. Built HTML: two tabs, two panels, nu panel `hidden` by default, dual-theme
   spans in both blocks; `check:content` covers the new literal (the index.astro
   scan from experiment 3).
3. CDP tab matrix against a served build: default bash/zsh with empty storage;
   click swaps panels and `aria-selected` and stores `nu`; the choice persists
   across reloads in BOTH theme modes (screenshots captured); clicking back
   stores `posix`.
4. Standard gates: build, `check:content`, `check:links`, `check:theme`
   unaffected, dprint, zero `.rs` diffs.

## Result

**Result:** Pass

- **The Nushell example reproduced exactly** before anything was built:
  `[5.0, 7.0, 9.0]` from the discriminating explicit-use form — the
  stop-immediately condition never fired.
- **Built output asserted**: 2 tabs, 2 panels, nu panel hidden by default (the
  first grep hit was the button's `aria-controls` — the element itself carries
  `hidden`), both blocks dual-theme highlighted (bash + nu grammars).
- **CDP tab matrix all green** (5 assertions): default bash/zsh with null
  storage; click → Nushell panel shown, `aria-selected` flipped, `nu` stored;
  persisted across reloads in both light and dark (screenshots:
  `logs/issue-0013/hero-tabs-nu-{light,dark}.png` — active tab carries the
  primary-green border, nu code legible in both modes); click back → `posix`
  stored.
- **Gates**: build clean (20 pages); `check:content` green (the index.astro
  literal scan sees `nutorch tensor/add/value` — all known verbs); `check:links`
  green; dprint clean; zero `.rs` diffs; `v1/` untouched.

## Conclusion

The hero now speaks both languages: POSIX pipelines for the bash/zsh majority,
native structured data for the Nushell visitor — each in its own tab, each
example reproduced against the real binaries before display, and the visitor's
choice remembered. The issue-0014 lesson (discriminating forms or it didn't
happen) is now standard practice in this issue's verifications.

+++
[implementer]
agent = "codex"
model = "gpt-5"
+++

# Experiment 1: Rename the Nushell namespace

## Description

Make `torch <op>` the primary Nushell wrapper namespace while keeping existing
`nutorch <op>` scripts working through exported compatibility aliases.

This is one cohesive experiment because the generated module, committed
`nutorch.nu`, Nu verification scripts, README, website docs, and generated
reference pages all describe the same user-facing command name. Splitting the
rename from the docs would knowingly leave a published half-state.

The intended contract after this experiment:

- In Nushell, `torch tensor`, `torch add`, `torch value`, `torch tensors`,
  `torch daemon status`, `torch nn ...`, and the rest of the wrapped surface use
  the structured Nushell wrappers.
- In Nushell, `^torch ...` explicitly invokes the external CLI when raw CLI
  output is wanted.
- In Nushell, `nutorch <op>` remains available as a compatibility alias for
  existing scripts.
- In POSIX shells, the external CLI remains `torch`; the installed `nutorch`
  symlink remains out of scope.

Nu 0.113.1 accepts multiword aliases such as
`export alias "nutorch add" = torch add`, and a probe confirmed they preserve
ordinary positionals, flags, and piped input into the target custom command.
That makes aliases the smallest honest compatibility layer: no duplicate wrapper
bodies and no second conversion path.

## Changes

1. **`torch-cli/src/main.rs`**:
   - Change the `NU_PRELUDE` wrappers from `export def "nutorch ..."` to
     `export def "torch ..."`.
   - Change generated table-op wrappers from `export def "nutorch {op}"` to
     `export def "torch {op}"`.
   - Generate `export alias "nutorch ..."` compatibility aliases for every
     prelude wrapper and generated table op.
   - Update comments and staleness-test wording so `torch` is documented as the
     primary Nushell namespace and `nutorch` as compatibility.
2. **`nutorch.nu`**:
   - Regenerate from `torch nu-module`.
   - Confirm it exports primary `torch` wrappers and `nutorch` aliases.
3. **Nushell scripts**:
   - Update `scripts/test-dual-input.nu` and `scripts/train-regression.nu` to
     use `torch`.
   - Keep at least one compatibility assertion proving `nutorch` aliases still
     work and route through the structured wrapper.
4. **README and website docs**:
   - Update Nushell examples to use `torch`.
   - Document `^torch` as the explicit external-CLI escape hatch where raw
     output or CLI rendering matters.
   - Keep package/project names (`NuTorch`, `nutorch` formula/tap, paths,
     `nutorch.nu`) unchanged where they are names rather than Nushell commands.
5. **Website generator and generated reference docs**:
   - Update `website/scripts/gen-ops-reference.ts` so Nu reference fences use
     `torch`, then regenerate the reference pages.
   - Update website content checks only if their command-name assumptions need
     tightening after the docs move.
6. **No daemon, protocol, ops-table, formula, installer, package-share, or POSIX
   CLI behavior changes.**

## Verification

Pass requires all of:

1. **Design/process**: the experiment is linked from the issue README as
   `Designed`; design review approves before implementation; a separate plan
   commit exists before implementation begins.
2. **Rust hygiene**:
   - `cargo fmt`
   - `cargo fmt -- --check`
   - `cargo check` with no warnings
   - `cargo test`
3. **Generated module correctness**:
   - `cargo test` includes the `nutorch.nu` staleness test.
   - `nu -c 'use ./nutorch.nu *; [(which "torch tensor" | get 0.type) (which "nutorch tensor" | get 0.type)] | to nuon'`
     reports both commands as module commands (`custom` for `torch`, `alias` for
     `nutorch`, or whatever exact type names Nu 0.113.1 reports for that pair).
   - A live Nu smoke proves structured wrapper behavior:
     `[[1 2] [3 4]] | torch tensor | torch value` returns native Nu data.
   - A live Nu smoke proves the escape hatch: `^torch value <handle>` returns
     the raw external JSON/text form.
   - A live Nu smoke proves compatibility:
     `nutorch tensor [1 2] | nutorch value` still works.
4. **Nushell acceptance scripts**:
   - `PATH="$PWD/target/debug:$PATH" nu scripts/test-dual-input.nu`
   - `PATH="$PWD/target/debug:$PATH" nu scripts/train-regression.nu`
5. **Documentation and website gates**:
   - `dprint fmt` on touched Markdown/TOML/JSON.
   - `dprint check`
   - From `website/`: `bun run check:ops-ref`, `bun run check:content`,
     `bun run check:tabs`, and `bun run check:mirror`.
   - `rg -n '\bnutorch [a-z][a-z0-9_-]*' README.md website/src/content scripts`
     returns no primary Nushell examples, with only explicit compatibility
     discussion/assertions allowed.
6. **Workflow**: after implementation, record `## Result`, update this
   experiment's README status, run result review, fix real findings, record the
   review, then make the result commit.

**Pass** = all gates pass and current docs teach `torch` as the Nushell command.
**Partial** = implementation works but compatibility or docs migration remains
incomplete. **Fail** = aliases cannot preserve the wrapper behavior or the
rename creates unavoidable ambiguity in Nushell command resolution.

## Design Review

**Reviewer:** Codex fresh-context subagent (`multi_agent_v1`, nickname
`Popper`). **First pass: CHANGES REQUIRED** — 3 Required, all folded into the
Verification section. (1) Rust hygiene lacked a build/no-warning gate, so
`cargo check` with no warnings is now required. (2) The docs-search gate listed
only a handful of verbs and could miss examples such as `nutorch randn`,
`nutorch daemon status`, or generated reference lines; it is now a broad
`\bnutorch [a-z][a-z0-9_-]*` scan with explicit compatibility exceptions only.
(3) The `which` smoke used two bare expressions in `nu -c`, which would only
emit the last result; it now constructs one output value containing both command
types. **Second pass: APPROVED** — the reviewer confirmed all three prior
Required findings are resolved and no new Required finding was introduced.

## Result

**Result:** Partial

The Nushell command rename itself is implemented and verified:

- `torch-cli/src/main.rs` now generates `torch <op>` wrappers as the primary
  Nushell namespace.
- `nutorch.nu` is regenerated from `torch nu-module`; it contains primary
  `torch` wrappers plus `nutorch` compatibility aliases for the prelude verbs
  and all 185 table ops.
- `scripts/test-dual-input.nu`, `scripts/train-regression.nu`, README examples,
  website docs, the landing page snippets, and generated reference pages now
  teach `torch` for Nushell commands.
- The docs explain `^torch` as the explicit escape hatch for raw external CLI
  output.
- The installed package names, formula/tap, `nutorch.nu` filename, daemon,
  protocol, and POSIX CLI behavior are unchanged.

Direct verification passed:

- `cargo fmt`
- `cargo fmt -- --check`
- `cargo check` with no new warnings
- `cargo build`
- `cargo test -p torch-cli` (includes the `nutorch.nu` staleness test)
- `PATH="$PWD/target/debug:$PATH" nu -c 'use ./nutorch.nu *; [(which "torch tensor" | get 0.type) (which "nutorch tensor" | get 0.type)] | to nuon'`
  → `[custom, alias]`
- Live structured wrapper smoke: `[[1 2] [3 4]] | torch tensor | torch value`
  returned native Nu data `[[1.0, 2.0], [3.0, 4.0]]`
- Live escape-hatch smoke: `^torch value <handle>` returned raw CLI JSON
  `[[1.0,2.0],[3.0,4.0]]`
- Live compatibility smoke: `nutorch tensor [1 2] | nutorch value` returned
  `[1.0, 2.0]`
- `PATH="$PWD/target/debug:$PATH" nu scripts/test-dual-input.nu` passed,
  including the new `nutorch` alias compatibility assertion.
- `dprint check`
- `git diff --check`
- From `website/`:
  - `PATH="/Users/astrohacker/dev/nutorch/target/debug:$PATH" bun run check:ops-ref`
  - `PATH="/Users/astrohacker/dev/nutorch/target/debug:$PATH" bun run check:content`
  - `bun run check:mirror`
- `rg -n '\bnutorch [a-z][a-z0-9_-]*' README.md website/src/content scripts`
  reports only the explicit compatibility assertion in
  `scripts/test-dual-input.nu`.

Required verification did not fully pass:

- `cargo test` fails in the unchanged `nutorchd/tests/golden.rs` suite, in four
  `nn_linear_*` golden cases (`nn_linear_bias`, `nn_linear_relu`,
  `nn_linear_gelu`, `nn_linear_sigmoid`). The implementation diff for this
  experiment does not touch `nutorchd/`, `ops/`, `Cargo.toml`, or `Cargo.lock`;
  the zsh training twin fails with the same convergence numbers as the Nu
  script, so this is not caused by the namespace rename.
- `PATH="$PWD/target/debug:$PATH" nu scripts/train-regression.nu` fails with the
  same training convergence problem as `scripts/train-regression.sh`
  (`final loss 0.3571428656578064 >= 1e-3`).
- `bun run check:tabs` cannot start Chrome in this environment:
  `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome` is missing, and
  no Chrome/Chromium binary was found in `/Applications` or PATH.

## Conclusion

The issue-20 behavior is in place: Nushell users can use `torch` as the command
namespace, `nutorch` remains a compatibility alias, and docs now teach the new
surface. The experiment cannot honestly close as Pass until the required
verification gates are either made green or explicitly re-scoped around the
pre-existing/current NN golden failure and the missing browser dependency for
`check:tabs`.

## Result Review

**Reviewer:** Codex fresh-context subagent (`multi_agent_v1`, nickname
`Lorentz`). **Verdict: APPROVED — no findings.** The reviewer confirmed the
result commit had not been made, no daemon/protocol/ops/formula/install files
were changed, `torch <op>` wrappers are primary, `nutorch <op>` aliases exist,
`target/debug/torch nu-module | diff -u - nutorch.nu` is clean, and live Nu
smokes prove structured wrapper output, raw `^torch` output, and compatibility
alias behavior. The reviewer re-ran and passed `cargo fmt -- --check`,
`cargo check`, `cargo test -p torch-cli`, `dprint check`,
`scripts/test-dual-input.nu`, `check:ops-ref`, `check:content`, and
`check:mirror`; they also reproduced the recorded failures: full `cargo test`
fails only on the four unchanged `nn_linear_*` golden cases, both Nu and zsh
regression training fail with final loss `0.3571428656578064`, and `check:tabs`
fails because Chrome is missing. **Scoped re-review: APPROVED** — after a
post-review comment cleanup in `scripts/gen-golden.py`, a second fresh-context
reviewer confirmed the broad command scan still reports only the expected
compatibility assertion and the cleanup introduces no new Required finding.

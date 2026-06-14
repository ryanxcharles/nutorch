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

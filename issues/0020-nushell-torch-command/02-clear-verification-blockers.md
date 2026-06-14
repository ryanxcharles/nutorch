+++
[implementer]
agent = "codex"
model = "gpt-5"
+++

# Experiment 2: Clear the remaining verification blockers

## Description

Experiment 1 implemented the issue-20 command rename, but finished Partial
because required verification was blocked by two current-state failures:

1. Full `cargo test` fails in four `nn_linear_*` golden cases because linear
   forward ignores explicit bias while storing it as a parameter.
2. `bun run check:tabs` assumes Google Chrome at one fixed macOS path and fails
   before testing anything when that binary is absent.

This experiment clears those blockers so issue 20 can be verified and closed.
The NN change is not part of the command rename itself, but it is now the
current blocker for the required gate; the experiment keeps it minimal and
driven by the existing golden/training tests.

Observed evidence for the NN failure:

- Explicit `torch nn linear 2 3 --weight W --bias-tensor B` reports two
  parameters and stores the bias correctly.
- `torch forward` returns the exact no-bias result.
- `cargo test` fails only the biased linear golden outputs, while
  `nn_linear_no_bias` passes.
- `scripts/train-regression.sh` and `scripts/train-regression.nu` fail with the
  same final loss, so the failure is shell-independent.

The likely fix is to avoid `Tensor::f_linear` for `NnModule::Linear` and express
linear forward directly as matrix multiply plus optional bias:
`input.matmul(weight.t())` and then `+ bias` when present. That keeps gradients
through both parameters and matches PyTorch's definition.

For shell-tabs, the verifier should find a browser from `CHROME`, common macOS
Chrome/Chromium/Edge/Brave paths, or PATH (`google-chrome`, `chromium`,
`chromium-browser`, `msedge`, `brave-browser`). If none is available, the script
should fail with a clear dependency message. It should not silently pass without
testing shell tabs.

## Changes

1. **`nutorchd/src/nn.rs`**:
   - Replace `NnModule::Linear` forward's `f_linear` call with explicit fallible
     `f_matmul(weight.f_t())` plus optional fallible bias addition.
   - Preserve the current error context (`linear forward: ...`) and autograd
     behavior.
2. **`website/scripts/check-shell-tabs.ts`**:
   - Resolve the browser path from `CHROME`, common macOS app paths, or PATH.
   - Keep the existing CDP-based assertions unchanged once a browser is found.
   - If no browser is found, fail before spawning with a clear message naming
     the supported discovery paths.
3. **Issue docs**:
   - Record the result and review.
   - Keep Experiment 1's README status as `Partial`, because that is its
     historical result; if all gates pass, mark Experiment 2 as `Pass` and close
     issue 20 with a README conclusion.

## Verification

Pass requires all of:

1. **Design/process**: design review approves before implementation; a separate
   plan commit exists before implementation begins.
2. **Rust gates**:
   - `cargo fmt`
   - `cargo fmt -- --check`
   - `cargo check` with no warnings
   - `cargo test`
3. **Training gates**:
   - `PATH="$PWD/target/debug:$PATH" scripts/train-regression.sh`
   - `PATH="$PWD/target/debug:$PATH" nu scripts/train-regression.nu`
4. **Issue-20 command gates from Experiment 1 still pass**:
   - `PATH="$PWD/target/debug:$PATH" cargo test -p torch-cli`
   - `PATH="$PWD/target/debug:$PATH" nu scripts/test-dual-input.nu`
   - Live Nu smokes for `torch`, `^torch`, and `nutorch` compatibility.
5. **Website/documentation gates**:
   - `dprint fmt` on touched Markdown/TOML/JSON.
   - `dprint check`
   - From `website/`:
     `PATH="/Users/astrohacker/dev/nutorch/target/debug:$PATH" bun run check:ops-ref`
   - From `website/`:
     `PATH="/Users/astrohacker/dev/nutorch/target/debug:$PATH" bun run check:content`
   - From `website/`: `bun run check:mirror`
   - From `website/`: `bun run build`, then
     `bun run preview -- --host 127.0.0.1 --port 4399` while
     `bun run check:tabs` runs.
6. **Command-name audit**:
   - `rg -n '\bnutorch [a-z][a-z0-9_-]*' README.md website/src/content scripts`
     reports only the explicit compatibility assertion in
     `scripts/test-dual-input.nu`.
7. **Workflow**: record `## Result`, update issue README statuses, run result
   review, fix real findings, record approval, make the result commit, and only
   then close the issue if all required gates pass.

**Pass** = all blockers are cleared, the issue-20 rename remains intact, and the
issue can close. **Partial** = one blocker remains but the work narrows it with
accurate evidence. **Fail** = the proposed NN or browser-discovery fix is wrong
or weakens verification.

## Design Review

**Reviewer:** Codex fresh-context subagent (`multi_agent_v1`, nickname
`Archimedes`). **Verdict: APPROVED — no Required findings.** One Optional was
folded: Experiment 1's README status remains `Partial` as its historical result;
Experiment 2 becomes `Pass` if this experiment clears the remaining gates. One
Nit was folded: the NN forward rewrite now explicitly names fallible tch calls
and preserving `linear forward: ...` error context.

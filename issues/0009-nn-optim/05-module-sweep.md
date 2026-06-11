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

# Experiment 5: The module sweep — conv, norms, dropout, embedding, pools

## Description

The remaining module family on the proven loom (variant + build arm + forward
match + explicit-weight goldens), plus the train/eval mode verbs that dropout
and batch_norm make necessary.

**New module kinds** (constructor args in parens; defaults are PyTorch's):

- `conv1d` / `conv2d` (in_channels, out_channels, kernel_size — **all Ints;
  kernels/strides/paddings are SQUARE/uniform in this sweep**, IntList variants
  recorded as follow-up;
  `--stride 1 --padding 0 --dilation 1 --groups 1 --no-bias`;
  `--weight/--bias-tensor` explicit loading, shapes checked)
- `conv_transpose2d` (same surface; `--output-padding 0`; NOTE: tch's arg order
  is `(…, output_padding, groups, dilation)` — groups BEFORE dilation, the
  reverse of conv2d; flagged so the implementer doesn't mirror)
- `embedding` (num_embeddings, embedding_dim; `--weight`; forward takes int64
  index tensors; `padding_idx` deliberately omitted — tch's sentinel `-1` (=
  None) is passed; recorded)
- `layer_norm` (normalized_shape as IntList; `--eps 1e-5`; learnable
  weight=1s/bias=0s — `--weight/--bias-tensor` loadable)
- `batch_norm` (num_features; `--eps 1e-5 --momentum 0.1`; learnable
  weight/bias + running_mean/var buffers — ONE kind serving 1d AND 2d inputs, as
  the underlying kernel does; running stats update in train mode, used in eval
  mode)
- `group_norm` (num_groups, num_channels; `--eps 1e-5`)
- `dropout` (`--p 0.5`)
- `leaky_relu` (`--negative-slope 0.01` — underscore on the wire).
  **Implementation note (design-review finding)**: tch's `f_leaky_relu` takes NO
  slope argument (0.01 baked in) — a non-default slope would be silently
  ignored. The forward is therefore computed manually as
  `max(0, x) + slope · min(0, x)` and goldened against `F.leaky_relu(x, slope)`
  with a non-default slope so the wiring is proven, not assumed.
- `softmax` (dim, required — PyTorch nn.Softmax's constructor arg)
- `max_pool2d` / `avg_pool2d` (kernel_size; `--stride` defaults to kernel_size,
  `--padding 0`)
- `flatten` (`--start-dim 1 --end-dim -1` — nn.Flatten's defaults, NOT the table
  op's 0; PyTorch fidelity)

**Excluded, recorded**: `lstm`/`gru` — their forward returns
`(output, hidden, cell)`, a multi-output contract our single-tensor `forward`
deliberately does not have; recorded as future work gated on a multi-output
forward design, NOT on MPS support.

**Decisions, made here:**

1. **Train/eval mode**: `torch nn train <nn://m>` / `torch nn eval
   <nn://m>`
   set a mode bit that propagates through Sequential to every child. Modules
   constructed in TRAIN mode (PyTorch's default). `nn info` reports the mode.
   Dropout is identity in eval; batch_norm uses running stats in eval. Wire:
   `Bespoke::NnMode { module, train }`.
2. **Dropout determinism — the OWN-MASK convention**: tch's `manual_seed` cannot
   reach the MPS generator (issue 0005), so MPS dropout would be unseedable.
   Dropout therefore generates its mask on the seeded CPU generator
   (`rand(shape) >= p`, scaled by `1/(1-p)`) and transfers — deterministic,
   PyTorch-equivalent in distribution and semantics (inverted dropout), NOT
   bitwise-vs-Python (different draw stream; impossible either way since
   Python-on-MPS is itself unseedable through any common stream). Goldens cover
   EVAL-mode identity exactly; train mode gets Rust tests: determinism under
   manual_seed, zero-fraction ≈ p, scaling (mean of kept elements = 1/(1-p) ×
   original), and gradient flow through the mask. **p is validated to [0, 1]**
   (`bad_argument` outside); **p = 1 is special-cased to all zeros** (the naive
   `1/(1-p)` scaling is inf × 0 = NaN there — PyTorch yields zeros;
   design-review finding) and p = 0 to identity, with unit tests for both edges.
3. **batch_norm state mutation**: the running-stats buffers are updated in place
   by the kernel during train-mode forward (libtorch mutates the passed tensors)
   — our `forward(&self)` signature survives because the mutation is interior.
   Goldens: train-mode forward (explicit weights, batch stats) AND eval-mode
   forward (explicit running stats) — both exact vs Python.
4. **Goldens for every parameterized kind** use explicit weights (the exp-2
   strategy): conv1d/conv2d/conv_transpose2d (stride/padding variants),
   embedding (int64 indices), layer_norm, batch_norm (train + eval), group_norm;
   shape-only kinds (pools, flatten, leaky_relu, softmax) golden on fixed
   inputs. The MPS oracle decides survivors; exclusions recorded.

## Changes

1. **`nutorchd/src/nn.rs`**: the new variants (+`training: bool` where behavior
   differs by mode — Dropout, BatchNorm; a `set_training(&mut
   self, bool)`
   walking Sequential), forward arms via tch fallible calls (`f_conv1d/2d`,
   `f_conv_transpose2d`, `f_embedding`, `f_layer_norm`, `f_batch_norm`,
   `f_group_norm`, the own-mask dropout, `f_leaky_relu`, `f_softmax`,
   `f_max_pool2d`, `f_avg_pool2d`, `f_flatten`), `parameters()` extended (conv
   weight/bias, embedding weight, norm weight/bias — NOT running stats, which
   are buffers, as in PyTorch).
2. **`nutorchd/src/registry.rs`**: none expected (the loom holds).
3. **`nutorchd/src/dispatch.rs`**: `build_module` arms (arg validation +
   explicit-weight shape checks per kind); `Bespoke::NnMode` arm; unit tests:
   dropout train-mode quartet (determinism/fraction/scale/grad), eval-identity,
   batch_norm running-stat evolution + eval behavior, mode propagation through
   sequential, conv shape validation errors.
4. **`torch-cli/src/main.rs`**: the new kinds in `build_nn_request` (a
   data-driven kind table now — the client-side match has outgrown itself; flags
   parse by the same hyphen/underscore-tolerant rule the optimizer kinds use);
   `nn train`/`nn eval`.
5. **Goldens**: ~14 new cases; floor `>= 254`.
6. **`README.md`**: the nn section's module list updated.

## Verification

1. **Hygiene**: standard + byte-stable regeneration.
2. **Goldens green**; oracle exclusions recorded with error lines.
3. **Unit tests**: the set in Changes item 3.
4. **Live**: an MNIST-shaped pipeline composes and runs —
   `conv2d(1,4,3) → relu → max_pool2d(2) → flatten → linear(…, 10)` on a
   `[1,1,8,8]` input yields `[1,10]`; dropout train vs eval observably differ
   and eval equals identity; `nn train`/`nn eval` round-trip via `nn info`;
   embedding looks up int64 indices; batch_norm's running stats move after a
   train-mode forward (visible via eval-mode output change).
5. **Training still works**: `train-classify.sh` (committed, unchanged) still
   passes — the sweep must not disturb the optimizer path.

**Pass** = all five. **Fail** = a kind required forward-signature or protocol
surgery (lstm-class problems leaking in).

## Design Review

**Reviewer:** `adversarial-reviewer` subagent (fresh context, read-only).
**First pass: CHANGES REQUIRED** — 2 Required: (1) tch's `f_leaky_relu` takes NO
slope argument (verified at the source line — only the backward form carries
one), so the designed `--negative-slope` flag would be silently ignored; the
forward is now computed manually (`max(0,x) + slope·min(0,x)`) and goldened with
a non-default slope. (2) The dropout own-mask formula NaNs at p = 1 (`1/(1-p)` =
inf, times an all-zero mask) where PyTorch yields zeros — p is now validated to
[0,1] with both edges special-cased and unit-tested. Optionals folded:
kernel/stride/padding pinned to Ints (square/uniform; IntList recorded);
embedding's `padding_idx` recorded as deliberately omitted (sentinel −1);
conv_transpose2d's groups-before-dilation arg order flagged. The reviewer
verified every other tch signature, MPS support for the whole sweep including
embedding BACKWARD, the real in-place running-stats mutation batch_norm relies
on, the PyTorch defaults (Flatten 1/−1, train-by-default, softmax dim), the
MNIST-pipeline arithmetic, and the floor.

## Result

**Result:** Pass

Thirteen new module kinds landed on the loom; the table of modules now covers
the issue's scope minus the recorded lstm/gru exclusion.

- **Goldens: 13/13 module cases first-run** (255 total, floor 253; byte-stable
  at sha256 `7a49f4cb…`): conv1d/conv2d (stride/padding
  variants)/conv_transpose2d, embedding (int64), layer_norm, batch_norm TRAIN
  and EVAL, leaky_relu with a NON-default slope (proving the manual
  `max(0,x)+slope·min(0,x)` wiring the design review forced), softmax, both
  pools, flatten, dropout-eval identity.
- **One golden exclusion, recorded with evidence**: `group_norm` — the C-API
  entry (tch's `atg_group_norm`) and Python's `torch.group_norm` produce results
  **1 ULP apart on MPS in this libtorch build** (probed exhaustively:
  plain/grad/no-affine identical within each side, the two sides differing
  consistently — same composite, different dispatch path). Internal consistency
  is pinned by a Rust test (module forward ≡ tch's direct call); the exclusion
  note lives in the generator.
- **Unit tests** (76 daemon tests): the dropout train-mode quartet (seeded
  determinism, zero-fraction ≈ p, 1/(1−p) scaling, gradient flow) plus the
  p=1-all-zeros-no-NaN and p=0-identity edges and range rejection; batch_norm
  running stats observably evolving (eval-before ≠ eval-after a train forward);
  mode propagation through sequential (info reports it; eval dropout inside is
  identity); conv weight shape mismatch errors; group_norm internal consistency.
- **Live**: the MNIST-shaped pipeline
  conv2d(1,4,3)→relu→max_pool2d(2)→flatten→linear(36,10) on [1,1,8,8] → [1,10]
  with exactly 410 parameters; dropout train (zeros + 2.0 scaling) vs eval
  (identity) with `nn info` reporting the mode; embedding int64 lookup;
  batch_norm stats moving; **and the committed `train-classify.sh` still passes
  unchanged** — the sweep disturbed nothing.
- **Hygiene**: build 0 warnings; fmt/dprint clean; `v1/` untouched. (One
  result-review finding fixed before commit: the conv arms computed
  `channels / groups` unvalidated — `--groups 0` panicked the connection thread
  with a divide-by-zero, and non-divisible groups silently truncated the weight
  shape. Both now `bad_argument` with named values, mirroring group_norm's
  existing validation; three new unit-test cases pin it, including
  conv_transpose validating OUT channels.)

## Conclusion

The module surface is complete per the issue's scope: 19 kinds, all golden- or
consistency-verified, with train/eval mode, the own-mask dropout convention (the
issue's design question 5, answered), and one honestly-recorded ULP exclusion.
What remains: save/load (the last strand) and the close.

## Result Review

**Reviewer:** `adversarial-reviewer` subagent (fresh context, read-only),
reviewing the pre-commit working tree. **First pass: CHANGES REQUIRED** — 1
Required, and a daemon-crasher: the conv arms divided by `groups` unvalidated,
so `--groups 0` panicked the connection thread (reproduced live in the daemon
log) and non-divisible groups silently built a truncated weight. Fixed with
group_norm-style validation (`groups >= 1`, divisibility on in_channels —
out_channels for conv_transpose), three new unit-test cases, and the Result
corrected to disclose. Everything else held under attack: all five design-review
mandates verified in code (manual leaky_relu at slope 0.2; the dropout p-edges;
groups-before- dilation; padding_idx −1); the group_norm exclusion independently
reproduced and judged correct ("not an error in our arm"); goldens byte-stable
with two spot-checks against fresh Python; the MNIST pipeline,
dropout/batch_norm mode behavior, and train-classify.sh all re-run successfully.

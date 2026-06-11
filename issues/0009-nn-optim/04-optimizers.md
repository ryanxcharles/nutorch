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

# Experiment 4: Optimizers and the training loop

## Description

`Object::Optimizer` becomes real, and with it the issue's reason to exist — the
canonical loop:

```bash
opt=$(torch nn sgd $model --lr 0.01 --momentum 0.9)
for i in $(seq 200); do
  pred=$(torch forward $model $x)
  loss=$(torch mse_loss $pred $y)
  torch backward $loss
  torch step $opt
  torch nn zero_grad $opt
done
```

**Four optimizers** (the exp-2 decision: our own structs over shallow-cloned
parameter references — in-place steps propagate to the module because tch
tensors share their TensorImpl):

| kind      | flags (PyTorch defaults)                                                             |
| --------- | ------------------------------------------------------------------------------------ |
| `sgd`     | `--lr` (required), `--momentum` 0, `--weight_decay` 0, `--dampening` 0, `--nesterov` |
| `adam`    | `--lr` 0.001, `--beta1` 0.9, `--beta2` 0.999, `--eps` 1e-8, `--weight_decay` 0       |
| `adamw`   | adam's flags; `--weight_decay` 0.01 (decoupled)                                      |
| `rmsprop` | `--lr` 0.01, `--alpha` 0.99, `--eps` 1e-8, `--weight_decay` 0, `--momentum` 0        |

**Decisions, made here:**

1. **Construction**: `torch nn sgd <nn://module> --lr …` → `optim://…`. The
   optimizer captures shallow clones of the module's parameters AT CONSTRUCTION
   (PyTorch's `optim.SGD(model.parameters())` moment). The module handle is NOT
   consumed (you keep using it). Constructing over a module with zero parameters
   is `bad_argument`. `--nesterov` requires `momentum > 0` and `dampening == 0`
   (PyTorch's own ValueError, reproduced at construction with the constraint
   named).
2. **Update math is PyTorch's, exactly** (golden-verified, multi-step, so state
   buffers are exercised): SGD with
   weight-decay→momentum-buffer→(nesterov|dampening) in PyTorch's documented
   order; Adam/AdamW with bias correction and step count; AdamW's weight decay
   decoupled; RMSprop with square-average (+optional momentum). State buffers
   live in the Optimizer entry as plain tensors.
3. **`torch step <optim://…>`** runs in place under `tch::no_grad` (in-place
   mutation of leaves that require grad is illegal outside it). Params with no
   gradient yet are SKIPPED (PyTorch behavior — a param not in the graph simply
   doesn't move). Steps touch the lease and the optimizer entry.
4. **`torch nn zero_grad <optim://…>`** zeroes every captured param's grad (the
   per-tensor `zero_grad` recipe, looped). Also accepts an `nn://` module handle
   (zeroing ITS params) — both are natural asks; the kind dispatch makes it
   unambiguous.
5. **`torch nn set_lr <optim://…> <lr>`** mutates the stored lr (the scheduler
   primitive; schedulers themselves stay out of scope, per the issue).
6. **The acceptance scripts** (Verification — the issue's Goal): plain zsh,
   regression AND classification, loss verifiably decreasing and final quality
   asserted numerically. **Reproducibility required**: each script uses a
   PRIVATE `--socket` (never the user's daemon) and seeds via `manual_seed`
   before any init, so the numeric thresholds are a sound, repeatable gate.
7. **`step` keeps the dual input pattern**: `torch step $opt` or
   `$opt | torch step` (principle 2; the `forward` precedent).

**Wire**: `Bespoke::Nn` already carries `{kind, args}` — optimizer kinds ride
the SAME construction op (kind `sgd|adam|adamw|rmsprop`, args carry `module` +
hyperparams). `Bespoke::Step { optimizer }`, `Bespoke::NnZeroGrad { handle }`,
`Bespoke::NnSetLr { optimizer, lr }`. `step` is a new top-level CLI verb;
`zero_grad`/`set_lr` are `nn` subcommand forms. (The table op `zero_grad` from
issue 0008 keeps its tensor-level role; `nn zero_grad` is the bulk form.)

**Golden strategy**: `optim_step` cases — explicit-weight linear, fixed
input/target, mse loss, N=3 steps of each optimizer with non-default hyperparams
where meaningful (momentum 0.9, nesterov, adamw decay, **and
coupled-weight-decay Adam** — the one case that distinguishes the op sequences
below; without it the suite passes vacuously); expected weights after each step
computed by Python `torch.optim.*` on MPS.

**Bitwise equality is contingent on mirroring PyTorch's ACTUAL op sequence, not
the textbook algebra** (design-review finding, established empirically): the
textbook first-moment update `m.mul_(β1).add_(g, 1−β1)` diverges from
`torch.optim.Adam` by 1 ULP at step 3 under coupled weight decay; only PyTorch's
real op — **`m.lerp_(g, 1−β1)`** — reproduces it. The prescribed sequence (all
exposed by tch): first moment via `f_lerp_`; second moment via `f_addcmul_`;
denom as `(v.sqrt() / √bc2).add_(eps)`; param update via `f_addcdiv_`. SGD's
momentum buffer initializes to a CLONE of the (weight-decayed) grad on the FIRST
step — not zeros (the other classic divergence). The foreach-vs-sequential
kernel question is empirically moot on MPS (foreach on/off/default are bitwise
identical).

## Changes

1. **`nutorchd/src/nn.rs`**: `Optimizer` struct (kind enum + params:
   `Vec<Tensor>` + per-param state buffers + hyperparams) with `step()` and
   `zero_grad()` implementing the four algorithms.
2. **`nutorchd/src/registry.rs`**: `Object::Optimizer`,
   `insert_optimizer`/`get_optimizer_mut`; `approx_bytes` counts state buffers.
3. **`nutorchd/src/protocol.rs`**: the three new Bespoke variants.
4. **`nutorchd/src/dispatch.rs`**: optimizer kinds in `build_module`'s sibling
   `build_optimizer`; the `step`/`nn_zero_grad`/`nn_set_lr` arms. Unit tests:
   hand-checked single SGD step (lr 0.1, known grad); momentum buffer evolution
   over two steps; skip-params-without-grad; zero-param module rejected; set_lr
   changes subsequent step size; zero_grad over module AND optimizer handles.
5. **`torch-cli/src/main.rs`**: `step` verb; `nn sgd|adam|adamw|rmsprop`
   construction; `nn zero_grad`/`nn set_lr`.
6. **Goldens**: `optim_step` case type (per optimizer, 3 steps, weights after
   each); floor `>= 240`.
7. **`scripts/train-regression.sh` + `scripts/train-classify.sh`**: the
   acceptance scripts (committed — they are the issue's demo artifacts);
   README's nn section gains the real loop.

## Verification

1. **Hygiene**: standard + byte-stable regeneration.
2. **Goldens**: all four optimizers' 3-step trajectories bitwise vs Python
   `torch.optim` on MPS.
3. **Unit tests**: the six in Changes item 4.
4. **Live**: the canonical loop verbatim; `set_lr` observably changes step size;
   `nn zero_grad` on both handle kinds; step on an optimizer whose params never
   saw backward (no-op, no error).
5. **The acceptance** (the issue's Goal, executed): `train-regression.sh` fits
   `y = 2x + 1` (linear 1→1, SGD, 200 steps) — final loss `< 1e-3` and learned
   weight/bias within 5% of (2, 1); `train-classify.sh` trains
   linear(2→8)→relu→linear(8→2) with `cross_entropy` on a linearly separable toy
   set — loss decreases monotonically-ish (first vs last), final accuracy 100%
   on the training points.

**Pass** = all five. **Fail** = optimizer trajectories diverge from PyTorch
beyond exclusions, or the loop cannot be expressed.

## Design Review

**Reviewer:** `adversarial-reviewer` subagent (fresh context, read-only).
**First pass: CHANGES REQUIRED** — 2 Required, found EMPIRICALLY: the reviewer
reproduced `torch.optim` on MPS op-by-op and proved (1) the bitwise pledge was a
trap as written — the textbook Adam first-moment update diverges from PyTorch by
1 ULP at step 3 under coupled weight decay; only PyTorch's actual `lerp_` op
reproduces it (the design now prescribes the exact sequence: `f_lerp_`,
`f_addcmul_`, the sqrt/bias-correction denom, `f_addcdiv_`); and (2) the golden
set lacked the ONE case that distinguishes the sequences (coupled-weight-decay
Adam — added; plain Adam and AdamW pass under both forms). The reviewer also
established that foreach-vs-sequential is bitwise moot on MPS, and that
SGD/AdamW/RMSprop reproduce bitwise with the textbook sequence. Four Optional
folded: the nesterov constraint validated at construction (PyTorch's own
ValueError); SGD's first-step buffer = clone of the weight-decayed grad (not
zeros); the acceptance scripts now require private sockets + seeding; `step`
keeps the dual input pattern. Confirmed sound: the shallow-clone aliasing (steps
propagate through sequential consumption; freed-module weights stay alive —
PyTorch-faithful), registry hygiene, kind-string routing, floor arithmetic.

## Result

**Result:** Pass

The issue's reason to exist, demonstrated: plain shell scripts train neural
networks on the GPU, and the optimizer math is bitwise PyTorch's.

- **Goldens: 5/5 optimizer trajectories first-run bitwise** (242 total, floor
  240; byte-stable at sha256 `89cb0fa6…`, verified twice): SGD+momentum,
  SGD+nesterov+weight-decay, **coupled-weight-decay Adam** (the case that pins
  `lerp_` — the design review's empirical find, vindicated: the prescribed op
  sequence reproduced torch.optim exactly), AdamW, RMSprop+momentum — three
  steps each, weights compared after every step.
- **The acceptance, executed**:
  - `train-regression.sh`: loss 6.0012 → 2.46e-7 over 200 SGD steps; learned
    weight 1.9996 (target 2), bias 1.0008 (target 1) — within 0.1%, far inside
    the 5% gate. **PASS.**
  - `train-classify.sh`: linear(2,8)→relu→linear(8,2) + Adam + cross_entropy;
    loss 0.7069 → 0.000145; predictions exactly `[0,0,1,1,0,1]` — 100%.
    **PASS.**
  - Both scripts use private sockets and seeded init (reproducible gates), and
    both are committed as the issue's demo artifacts.
- **Unit tests** (72 daemon tests): the hand-checked SGD step (w: 1 → 0.8 at lr
  0.1, grad 2 — with an f32-tolerance lesson: 1 − 0.1·2 is 0.800000012 in
  float32, asserted approximately); momentum buffer evolution matching hand
  arithmetic (0.8 → 0.54) including the FIRST-step buffer=grad-clone gotcha;
  `set_lr` observably changing step size; step-without-grad as a silent no-op;
  zero-parameter modules and the nesterov constraint rejected at construction;
  `nn zero_grad` on BOTH handle kinds.
- **Hygiene**: build 0 warnings; fmt clean; full suite green; `v1/` untouched.
  One harness iteration: the optim case's bespoke helper initially lacked a
  `Handles` arm (nn_parameters returns one) — caught by the first golden run,
  fixed.

## Conclusion

The object model completes its arc: modules hold parameters, optimizers hold
state over shallow-clone views, and the canonical PyTorch loop runs verbatim in
zsh against the MPS GPU with bitwise-faithful updates. The design review's
empirical `lerp_` finding was the experiment's hinge — without it, a textbook
Adam would have shipped 1 ULP wrong under coupled weight decay and the goldens
would have caught it only AFTER implementation. What remains for the issue: the
module sweep (conv, norms, dropout, embedding, pooling) and save/load, then
close.

## Result Review

**Reviewer:** `adversarial-reviewer` subagent (fresh context, read-only),
reviewing the pre-commit working tree. **Verdict: APPROVED — one Optional
finding, folded in** (`set_lr` rejected `lr = 0`, which PyTorch permits —
verified against the live torch; now `lr >= 0`). The reviewer verified every
design-review mandate in code (the `f_lerp_` first moment; the coupled-wd Adam
golden present and passing; the nesterov constraint; the first-step buffer
clone; private sockets + seeding in both scripts; step's stdin form live),
reproduced byte-stable goldens at the recorded sha, spot-checked
`opt_sgd_momentum` step-1 weights against fresh `torch.optim.SGD` on MPS
(exact), **ran both acceptance scripts to PASS with values matching the
Result**, ran all 72 unit tests, confirmed the quiet loop verbs don't swallow
errors, and judged the Result honest including the f32-tolerance note and the
harness-iteration disclosure.

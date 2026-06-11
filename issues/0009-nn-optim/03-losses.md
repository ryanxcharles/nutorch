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

# Experiment 3: Losses as table ops

## Description

The issue's loss list lands as ordinary tensor→tensor rows on the issue-0005
loom — no module machinery involved (losses are functions, not objects;
PyTorch's class wrappers add nothing the shell needs):

```bash
loss=$(torch mse_loss $pred $target)
torch backward $loss
```

**The nine ops** (category `loss`, all `Exactly(2)` input+target, `Handles(1)`,
**all `broadcasts: false`** — the elementwise pre-check would falsely reject the
class-index losses, whose `[N,C]` input vs `[N]` target is legitimate but not
broadcastable; tch reproduces PyTorch's native shape behavior,
broadcast-or-error, without our pre-check):

| op                                 | flags                                 | notes                                                     |
| ---------------------------------- | ------------------------------------- | --------------------------------------------------------- |
| `mse_loss`                         | `--reduction`                         |                                                           |
| `l1_loss`                          | `--reduction`                         |                                                           |
| `smooth_l1_loss`                   | `--reduction`, `--beta` (Float, 1.0)  |                                                           |
| `huber_loss`                       | `--reduction`, `--delta` (Float, 1.0) |                                                           |
| `cross_entropy`                    | `--reduction`                         | int64 class-index targets                                 |
| `nll_loss`                         | `--reduction`                         | int64 targets, log-prob inputs                            |
| `binary_cross_entropy`             | `--reduction`                         | probabilities in [0,1]                                    |
| `binary_cross_entropy_with_logits` | `--reduction`                         | logits (the stable form; full PyTorch name — principle 3) |
| `kl_div`                           | `--reduction`, `--log_target` (Bool)  | underscore per flag convention                            |

`--reduction` is a Str flag accepting `mean`/`sum`/`none` (PyTorch's values;
default `mean`), mapped to tch's `Reduction` enum; an unknown value is
`bad_argument` naming the three. Class-weight tensors, `ignore_index`, and
`label_smoothing` are recorded as future flags (the loom makes them one-line
additions when wanted).

**Out-of-scope guard**: no client, protocol, registry, or nn.rs changes — pure
table rows + apply arms + goldens, the 0005 sweep recipe.

## Changes

1. **`ops/src/lib.rs`**: nine rows, category `loss`, with a
   `loss(name, summary)` const helper for the reduction-only ops.
2. **`nutorchd/src/dispatch.rs`**: a
   `parse_reduction(p) ->
   Result<Reduction, …>` helper; nine apply arms via
   the tch fallible calls (`f_mse_loss`, `f_l1_loss`, `f_smooth_l1_loss`,
   `f_huber_loss`, `f_cross_entropy_loss` (no weight, ignore_index −100,
   label_smoothing 0.0 — PyTorch defaults), `f_nll_loss`,
   `f_binary_cross_entropy` (no weight), `f_binary_cross_entropy_with_logits`
   (no weight/pos_weight), `f_kl_div`). Unit test: bad `--reduction` value
   errors naming the choices.
3. **`scripts/gen-golden.py` + harness**: one golden per op vs Python `F.*` on
   MPS (the oracle — exclusions recorded), plus `--reduction
   sum` and `none`
   variants for `mse_loss`, and ONE gradient golden (`mse_loss` through
   `backward` → input grad) since loss-backward is the entire point. **The
   harness extension, specified** (design-review finding — `with_self`'s `[h,h]`
   reuse does NOT cover this): the grad case gains an optional `target` field,
   built as a DISTINCT non-grad leaf; the operand vector becomes `[x, target]`;
   only `x.grad` is compared (the target has no gradient). Floor `>= 236`.
4. **`README.md`**: the training-loop sketch in the nn section gains its real
   loss line (replacing nothing — one sentence).

## Verification

1. **Hygiene**: standard five + byte-stable regeneration.
2. **Goldens green**: every loss exact vs Python on MPS; the mse gradient case
   exact; oracle exclusions recorded.
3. **Live**: `mse_loss` of a forward result against a target, `backward`, `grad`
   on the module's weight via `nn parameters` — the full loss-driven gradient
   path that Experiment 4's optimizer will consume; `--reduction sum|none`
   change the value/shape as expected; `cross_entropy` with int64 targets; bad
   reduction errors.
4. **`torch ops`** lists the `loss` category.

**Pass** = all four. **Fail** = a loss required non-table machinery.

## Design Review

**Reviewer:** `adversarial-reviewer` subagent (fresh context, read-only).
**First pass: CHANGES REQUIRED** — 2 Required: (1) the `broadcasts` flag was
unstated, and `true` would have made the elementwise pre-check falsely reject
every class-index loss call (`[N,C]` vs `[N]` is legitimate but not
broadcastable — the reviewer traced the pre-check and proved
`broadcastable([N,C],[N])` is false); now explicitly `false` on all nine rows,
with tch reproducing PyTorch's native shape behavior. (2) The gradient-golden
harness extension was underspecified — `with_self`'s `[h,h]` reuse does not
cover a distinct non-grad target; the case shape now specifies the `target`
field, the `[x, target]` operand vector, and the x-grad-only comparison.
Optional folded: `bce_with_logits` renamed to the full
`binary_cross_entropy_with_logits` (principle 3 — every other op name matches
PyTorch exactly). Nits folded: `--log_target` underscore per convention (the
exp-2 hyphen lesson), the eight/nine wording fixed. The reviewer verified all
nine tch signatures with argument orders (no transpositions), the Reduction enum
mapping, MPS support for all nine in the linked torch, and the PyTorch defaults
(ignore_index −100, label_smoothing 0, beta/delta 1.0, reduction mean).

---
title: Loss ops
description: The 9 loss operations, generated from the op table.
order: 26
section: "Reference"
---

Generated from the binaries by `scripts/gen-ops-reference.ts` — do not edit by
hand. Every op also documents itself: `torch <op> --help`.

### mse_loss

mean squared error (--reduction mean|sum|none)

```
usage: torch mse_loss <t1> <t2> [--reduction <Str>]
```

### l1_loss

mean absolute error (--reduction)

```
usage: torch l1_loss <t1> <t2> [--reduction <Str>]
```

### smooth_l1_loss

smooth L1 loss (--beta, default 1.0)

```
usage: torch smooth_l1_loss <t1> <t2> [--reduction <Str>] [--beta <Float>]
```

### huber_loss

Huber loss (--delta, default 1.0)

```
usage: torch huber_loss <t1> <t2> [--reduction <Str>] [--delta <Float>]
```

### cross_entropy

cross entropy over logits vs int64 class indices

```
usage: torch cross_entropy <t1> <t2> [--reduction <Str>]
```

### nll_loss

negative log likelihood (log-prob inputs, int64 targets)

```
usage: torch nll_loss <t1> <t2> [--reduction <Str>]
```

### binary_cross_entropy

BCE over probabilities in [0,1]

```
usage: torch binary_cross_entropy <t1> <t2> [--reduction <Str>]
```

### binary_cross_entropy_with_logits

BCE over logits (the stable form)

```
usage: torch binary_cross_entropy_with_logits <t1> <t2> [--reduction <Str>]
```

### kl_div

KL divergence (--log_target if target is log-space)

```
usage: torch kl_div <t1> <t2> [--reduction <Str>] [--log_target]
```

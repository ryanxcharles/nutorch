---
title: Autograd ops
description: The 4 autograd operations, generated from the op table.
order: 27
section: "Reference"
---

Generated from the binaries by `scripts/gen-ops-reference.ts` — do not edit by
hand. Every op also documents itself: `torch <op> --help`.

### backward

backpropagate from a scalar loss (gradients accumulate)

```
usage: torch backward <t1>
```

### grad

snapshot of a tensor's accumulated gradient

```
usage: torch grad <t1>
```

### detach

a graph-free reference to the same data

```
usage: torch detach <t1>
```

### zero_grad

zero a tensor's accumulated gradient in place

```
usage: torch zero_grad <t1>
```

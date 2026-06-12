---
title: Creation ops
description: The 14 creation operations, generated from the op table.
order: 20
section: "Reference"
---

Generated from the binaries by `scripts/gen-ops-reference.ts` — do not edit by
hand. Every op also documents itself: `torch <op> --help`.

### full

a tensor of the given shape filled with a value

```
usage: torch full <shape> <value> [--dtype <Str>] [--requires_grad]
```

### randn

standard-normal random tensor (float kinds only)

```
usage: torch randn <shape> [--dtype <Str>] [--requires_grad]
```

### zeros

a tensor of zeros

```
usage: torch zeros <shape> [--dtype <Str>] [--requires_grad]
```

### ones

a tensor of ones

```
usage: torch ones <shape> [--dtype <Str>] [--requires_grad]
```

### eye

identity matrix (n x n, or n x --m)

```
usage: torch eye <n> [--m <Int>]
```

### arange

range [--start, end) by --step (CLI reshape of PyTorch overloads)

```
usage: torch arange <end> [--start <Scalar>] [--step <Scalar>]
```

### linspace

steps evenly spaced points in [start, end]

```
usage: torch linspace <start> <end> <steps>
```

### rand

uniform [0,1) random tensor (seeded CPU generator)

```
usage: torch rand <shape> [--requires_grad]
```

### randint

random int64s in [--low, high) (seeded CPU generator)

```
usage: torch randint <high> <shape> [--low <Int>]
```

### zeros_like

zeros with the input's shape and dtype

```
usage: torch zeros_like <t1>
```

### ones_like

ones with the input's shape and dtype

```
usage: torch ones_like <t1>
```

### full_like

a value-filled tensor with the input's shape and dtype

```
usage: torch full_like <t1> <value>
```

### rand_like

uniform random with the input's shape (seeded CPU generator)

```
usage: torch rand_like <t1>
```

### randn_like

normal random with the input's shape (seeded CPU generator)

```
usage: torch randn_like <t1>
```

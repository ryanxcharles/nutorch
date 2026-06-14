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

```bash
torch full <shape> <value> [--dtype <Str>] [--requires_grad]
```

```nu
torch full <shape> <value> [--dtype <Str>] [--requires_grad]
```

### randn

standard-normal random tensor (float kinds only)

```bash
torch randn <shape> [--dtype <Str>] [--requires_grad]
```

```nu
torch randn <shape> [--dtype <Str>] [--requires_grad]
```

### zeros

a tensor of zeros

```bash
torch zeros <shape> [--dtype <Str>] [--requires_grad]
```

```nu
torch zeros <shape> [--dtype <Str>] [--requires_grad]
```

### ones

a tensor of ones

```bash
torch ones <shape> [--dtype <Str>] [--requires_grad]
```

```nu
torch ones <shape> [--dtype <Str>] [--requires_grad]
```

### eye

identity matrix (n x n, or n x --m)

```bash
torch eye <n> [--m <Int>]
```

```nu
torch eye <n> [--m <Int>]
```

### arange

range [--start, end) by --step (CLI reshape of PyTorch overloads)

```bash
torch arange <end> [--start <Scalar>] [--step <Scalar>]
```

```nu
torch arange <end> [--start <Scalar>] [--step <Scalar>]
```

### linspace

steps evenly spaced points in [start, end]

```bash
torch linspace <start> <end> <steps>
```

```nu
torch linspace <start> <end> <steps>
```

### rand

uniform [0,1) random tensor (seeded CPU generator)

```bash
torch rand <shape> [--requires_grad]
```

```nu
torch rand <shape> [--requires_grad]
```

### randint

random int64s in [--low, high) (seeded CPU generator)

```bash
torch randint <high> <shape> [--low <Int>]
```

```nu
torch randint <high> <shape> [--low <Int>]
```

### zeros_like

zeros with the input's shape and dtype

```bash
torch zeros_like <t1>
```

```nu
torch zeros_like <t1>
```

### ones_like

ones with the input's shape and dtype

```bash
torch ones_like <t1>
```

```nu
torch ones_like <t1>
```

### full_like

a value-filled tensor with the input's shape and dtype

```bash
torch full_like <t1> <value>
```

```nu
torch full_like <t1> <value>
```

### rand_like

uniform random with the input's shape (seeded CPU generator)

```bash
torch rand_like <t1>
```

```nu
torch rand_like <t1>
```

### randn_like

normal random with the input's shape (seeded CPU generator)

```bash
torch randn_like <t1>
```

```nu
torch randn_like <t1>
```

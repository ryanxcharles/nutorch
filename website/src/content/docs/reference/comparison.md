---
title: Comparison ops
description: The 25 comparison operations, generated from the op table.
order: 22
section: "Reference"
---

Generated from the binaries by `scripts/gen-ops-reference.ts` — do not edit by
hand. Every op also documents itself: `torch <op> --help`.

### eq

elementwise equality (returns a Bool tensor)

```bash
torch eq <t1> <t2>
```

```nu
torch eq <t1> <t2>
```

### allclose

true if all elements are close (returns a JSON bool)

```bash
torch allclose <t1> <t2> [--rtol <Float>] [--atol <Float>]
```

```nu
torch allclose <t1> <t2> [--rtol <Float>] [--atol <Float>]
```

### sort

sort along --dim (default last); returns values and indices

```bash
torch sort <t1> [--dim <Int>] [--descending]
```

```nu
torch sort <t1> [--dim <Int>] [--descending]
```

### gt

elementwise a > b (Bool, broadcasting)

```bash
torch gt <t1> <t2>
```

```nu
torch gt <t1> <t2>
```

### lt

elementwise a < b (Bool, broadcasting)

```bash
torch lt <t1> <t2>
```

```nu
torch lt <t1> <t2>
```

### ge

elementwise a >= b (Bool, broadcasting)

```bash
torch ge <t1> <t2>
```

```nu
torch ge <t1> <t2>
```

### le

elementwise a <= b (Bool, broadcasting)

```bash
torch le <t1> <t2>
```

```nu
torch le <t1> <t2>
```

### ne

elementwise a != b (Bool, broadcasting)

```bash
torch ne <t1> <t2>
```

```nu
torch ne <t1> <t2>
```

### logical_and

elementwise logical AND (Bool, broadcasting)

```bash
torch logical_and <t1> <t2>
```

```nu
torch logical_and <t1> <t2>
```

### logical_or

elementwise logical OR (Bool, broadcasting)

```bash
torch logical_or <t1> <t2>
```

```nu
torch logical_or <t1> <t2>
```

### logical_xor

elementwise logical XOR (Bool, broadcasting)

```bash
torch logical_xor <t1> <t2>
```

```nu
torch logical_xor <t1> <t2>
```

### isclose

elementwise closeness (Bool; --rtol/--atol)

```bash
torch isclose <t1> <t2> [--rtol <Float>] [--atol <Float>]
```

```nu
torch isclose <t1> <t2> [--rtol <Float>] [--atol <Float>]
```

### isnan

elementwise NaN test (Bool)

```bash
torch isnan <t1>
```

```nu
torch isnan <t1>
```

### isinf

elementwise infinity test (Bool)

```bash
torch isinf <t1>
```

```nu
torch isinf <t1>
```

### isfinite

elementwise finiteness test (Bool)

```bash
torch isfinite <t1>
```

```nu
torch isfinite <t1>
```

### isposinf

elementwise +inf test (Bool)

```bash
torch isposinf <t1>
```

```nu
torch isposinf <t1>
```

### isneginf

elementwise -inf test (Bool)

```bash
torch isneginf <t1>
```

```nu
torch isneginf <t1>
```

### logical_not

elementwise logical NOT (Bool)

```bash
torch logical_not <t1>
```

```nu
torch logical_not <t1>
```

### equal

whole-tensor equality (returns a JSON bool)

```bash
torch equal <t1> <t2>
```

```nu
torch equal <t1> <t2>
```

### topk

top-k values+indices (--smallest = PyTorch largest=False, a NuTorch-ism)

```bash
torch topk <t1> <k> [--dim <Int>] [--smallest]
```

```nu
torch topk <t1> <k> [--dim <Int>] [--smallest]
```

### argsort

indices that would sort along --dim (default last)

```bash
torch argsort <t1> [--dim <Int>] [--descending]
```

```nu
torch argsort <t1> [--dim <Int>] [--descending]
```

### searchsorted

insertion indices: searchsorted(sorted_seq, values)

```bash
torch searchsorted <t1> <t2>
```

```nu
torch searchsorted <t1> <t2>
```

### bucketize

bucket indices: bucketize(values, boundaries)

```bash
torch bucketize <t1> <t2>
```

```nu
torch bucketize <t1> <t2>
```

### msort

sort along the first dimension (values only)

```bash
torch msort <t1>
```

```nu
torch msort <t1>
```

### unique

sorted unique values

```bash
torch unique <t1>
```

```nu
torch unique <t1>
```

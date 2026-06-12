---
title: Reduction ops
description: The 21 reduction operations, generated from the op table.
order: 23
section: "Reference"
---

Generated from the binaries by `scripts/gen-ops-reference.ts` — do not edit by
hand. Every op also documents itself: `torch <op> --help`.

### sum

sum over all elements, or along --dim

```
usage: torch sum <t1> [--dim <Int>] [--keepdim]
```

### mean

mean over all elements, or along --dim (float32, v1 fidelity)

```
usage: torch mean <t1> [--dim <Int>] [--keepdim]
```

### prod

product over all elements, or along --dim

```
usage: torch prod <t1> [--dim <Int>] [--keepdim]
```

### amax

max values over all elements, or along --dim

```
usage: torch amax <t1> [--dim <Int>] [--keepdim]
```

### amin

min values over all elements, or along --dim

```
usage: torch amin <t1> [--dim <Int>] [--keepdim]
```

### max

max of all elements; with --dim also returns indices

```
usage: torch max <t1> [--dim <Int>] [--keepdim]
```

### min

min of all elements; with --dim also returns indices

```
usage: torch min <t1> [--dim <Int>] [--keepdim]
```

### median

median of all elements; with --dim also returns indices

```
usage: torch median <t1> [--dim <Int>] [--keepdim]
```

### argmax

index of the max, overall or along --dim

```
usage: torch argmax <t1> [--dim <Int>] [--keepdim]
```

### argmin

index of the min, overall or along --dim

```
usage: torch argmin <t1> [--dim <Int>] [--keepdim]
```

### all

true if all elements are true (Bool tensor)

```
usage: torch all <t1> [--dim <Int>] [--keepdim]
```

### any

true if any element is true (Bool tensor)

```
usage: torch any <t1> [--dim <Int>] [--keepdim]
```

### std

standard deviation (--correction, default 1)

```
usage: torch std <t1> [--dim <Int>] [--keepdim] [--correction <Int>]
```

### var

variance (--correction, default 1)

```
usage: torch var <t1> [--dim <Int>] [--keepdim] [--correction <Int>]
```

### nansum

sum treating NaN as zero

```
usage: torch nansum <t1> [--dim <Int>] [--keepdim]
```

### logsumexp

log(sum(exp(x))) along --dim

```
usage: torch logsumexp <t1> [--dim <Int>] [--keepdim]
```

### count_nonzero

count of nonzero elements, overall or along --dim

```
usage: torch count_nonzero <t1> [--dim <Int>]
```

### cumsum

cumulative sum along --dim

```
usage: torch cumsum <t1> [--dim <Int>]
```

### cumprod

cumulative product along --dim

```
usage: torch cumprod <t1> [--dim <Int>]
```

### norm

p-norm (--p default 2), overall or along --dim

```
usage: torch norm <t1> [--p <Float>] [--dim <Int>] [--keepdim]
```

### diff

forward differences along --dim (default last)

```
usage: torch diff <t1> [--dim <Int>]
```

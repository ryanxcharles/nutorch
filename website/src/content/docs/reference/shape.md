---
title: Shape ops
description: The 23 shape operations, generated from the op table.
order: 25
section: "Reference"
---

Generated from the binaries by `scripts/gen-ops-reference.ts` — do not edit by
hand. Every op also documents itself: `torch <op> --help`.

### cat

concatenate tensors along --dim (default 0)

```bash
torch cat <t1>... (at least 2) [--dim <Int>]
```

```nu
torch cat <t1>... (at least 2) [--dim <Int>]
```

### reshape

reshape to the given shape (-1 infers one dim)

```bash
torch reshape <t1> <shape>
```

```nu
torch reshape <t1> <shape>
```

### permute

permute dimensions

```bash
torch permute <t1> <dims>
```

```nu
torch permute <t1> <dims>
```

### transpose

swap two dimensions

```bash
torch transpose <t1> <dim0> <dim1>
```

```nu
torch transpose <t1> <dim0> <dim1>
```

### t

transpose a 2-D tensor

```bash
torch t <t1>
```

```nu
torch t <t1>
```

### squeeze

drop size-1 dims (all, or --dim)

```bash
torch squeeze <t1> [--dim <Int>]
```

```nu
torch squeeze <t1> [--dim <Int>]
```

### unsqueeze

insert a size-1 dim

```bash
torch unsqueeze <t1> <dim>
```

```nu
torch unsqueeze <t1> <dim>
```

### flatten

flatten dims (--start_dim/--end_dim)

```bash
torch flatten <t1> [--start_dim <Int>] [--end_dim <Int>]
```

```nu
torch flatten <t1> [--start_dim <Int>] [--end_dim <Int>]
```

### stack

stack tensors along a NEW --dim (default 0)

```bash
torch stack <t1>... (at least 2) [--dim <Int>]
```

```nu
torch stack <t1>... (at least 2) [--dim <Int>]
```

### split

split into chunks of split_size along --dim

```bash
torch split <t1> <split_size> [--dim <Int>]
```

```nu
torch split <t1> <split_size> [--dim <Int>]
```

### chunk

split into N chunks along --dim

```bash
torch chunk <t1> <chunks> [--dim <Int>]
```

```nu
torch chunk <t1> <chunks> [--dim <Int>]
```

### gather

gather values along --dim using an int64 index tensor

```bash
torch gather <t1> <t2> [--dim <Int>]
```

```nu
torch gather <t1> <t2> [--dim <Int>]
```

### index_select

select rows/cols along --dim by an int64 index tensor

```bash
torch index_select <t1> <t2> [--dim <Int>]
```

```nu
torch index_select <t1> <t2> [--dim <Int>]
```

### masked_select

select by mask (numeric mask cast via != 0, a NuTorch-ism)

```bash
torch masked_select <t1> <t2>
```

```nu
torch masked_select <t1> <t2>
```

### where

cond ? x : y (numeric cond cast via != 0, a NuTorch-ism)

```bash
torch where <t1> <t2> <t3>
```

```nu
torch where <t1> <t2> <t3>
```

### narrow

slice: length elements from start along dim

```bash
torch narrow <t1> <dim> <start> <length>
```

```nu
torch narrow <t1> <dim> <start> <length>
```

### flip

reverse along the given dims

```bash
torch flip <t1> <dims>
```

```nu
torch flip <t1> <dims>
```

### roll

roll elements by shifts (optionally along --dims)

```bash
torch roll <t1> <shifts> [--dims <IntList>]
```

```nu
torch roll <t1> <shifts> [--dims <IntList>]
```

### repeat

tile the tensor by repeats per dim

```bash
torch repeat <t1> <repeats>
```

```nu
torch repeat <t1> <repeats>
```

### repeat_interleave

repeat each element N times (optionally along --dim)

```bash
torch repeat_interleave <t1> <repeats> [--dim <Int>]
```

```nu
torch repeat_interleave <t1> <repeats> [--dim <Int>]
```

### movedim

move a dim to a new position

```bash
torch movedim <t1> <source> <destination>
```

```nu
torch movedim <t1> <source> <destination>
```

### take_along_dim

gather along --dim with a broadcastable int64 index

```bash
torch take_along_dim <t1> <t2> [--dim <Int>]
```

```nu
torch take_along_dim <t1> <t2> [--dim <Int>]
```

### scatter

non-inplace scatter: input, int64 index, src along --dim

```bash
torch scatter <t1> <t2> <t3> [--dim <Int>]
```

```nu
torch scatter <t1> <t2> <t3> [--dim <Int>]
```

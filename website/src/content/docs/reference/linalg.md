---
title: Linear algebra ops
description: The 17 linalg operations, generated from the op table.
order: 24
section: "Reference"
---

Generated from the binaries by `scripts/gen-ops-reference.ts` — do not edit by
hand. Every op also documents itself: `torch <op> --help`.

### mm

matrix multiply of two 2-D tensors

```
usage: torch mm <t1> <t2>
```

### matmul

general matrix product (batched, PyTorch broadcasting)

```
usage: torch matmul <t1> <t2>
```

### bmm

batched matrix multiply of two 3-D tensors

```
usage: torch bmm <t1> <t2>
```

### dot

dot product of two 1-D tensors

```
usage: torch dot <t1> <t2>
```

### outer

outer product of two 1-D tensors

```
usage: torch outer <t1> <t2>
```

### einsum

Einstein summation over --equation

```
usage: torch einsum <t1>... (at least 1) [--equation <Str>]
```

### tril

lower triangle (--diagonal offset)

```
usage: torch tril <t1> [--diagonal <Int>]
```

### triu

upper triangle (--diagonal offset)

```
usage: torch triu <t1> [--diagonal <Int>]
```

### diag

diagonal of a matrix, or diagonal matrix from a vector

```
usage: torch diag <t1> [--diagonal <Int>]
```

### trace

sum of the main diagonal of a 2-D tensor

```
usage: torch trace <t1>
```

### det

determinant of a square matrix

```
usage: torch det <t1>
```

### inverse

inverse of a square matrix

```
usage: torch inverse <t1>
```

### svd

singular value decomposition (U, S, V)

```
usage: torch svd <t1>
```

### solve

solve AX = B for X

```
usage: torch solve <t1> <t2>
```

### cross

vector cross product along --dim

```
usage: torch cross <t1> <t2> [--dim <Int>]
```

### kron

Kronecker product

```
usage: torch kron <t1> <t2>
```

### tensordot

tensor contraction over the last/first --dims dims (default 2)

```
usage: torch tensordot <t1> <t2> [--dims <Int>]
```

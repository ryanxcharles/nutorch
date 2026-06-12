---
title: Pointwise ops
description: The 71 pointwise operations, generated from the op table.
order: 21
section: "Reference"
---

Generated from the binaries by `scripts/gen-ops-reference.ts` — do not edit by
hand. Every op also documents itself: `torch <op> --help`.

### add

a + alpha*b (broadcasting; --alpha default 1)

```
usage: torch add <t1> <t2> [--alpha <Scalar>]
```

### sub

a - alpha*b (broadcasting; --alpha default 1)

```
usage: torch sub <t1> <t2> [--alpha <Scalar>]
```

### sin

elementwise sine

```
usage: torch sin <t1>
```

### pow

elementwise power (scalar or tensor exponent)

```
usage: torch pow <t1> <exponent>
```

### clamp

clamp into [min, max] (scalar or tensor bounds; one required)

```
usage: torch clamp <t1> [--min <HandleOrScalar>] [--max <HandleOrScalar>]
```

### abs

elementwise absolute value

```
usage: torch abs <t1>
```

### acos

elementwise arccosine

```
usage: torch acos <t1>
```

### acosh

elementwise inverse hyperbolic cosine

```
usage: torch acosh <t1>
```

### asin

elementwise arcsine

```
usage: torch asin <t1>
```

### asinh

elementwise inverse hyperbolic sine

```
usage: torch asinh <t1>
```

### atan

elementwise arctangent

```
usage: torch atan <t1>
```

### atanh

elementwise inverse hyperbolic tangent

```
usage: torch atanh <t1>
```

### ceil

elementwise ceiling

```
usage: torch ceil <t1>
```

### cos

elementwise cosine

```
usage: torch cos <t1>
```

### cosh

elementwise hyperbolic cosine

```
usage: torch cosh <t1>
```

### deg2rad

degrees to radians

```
usage: torch deg2rad <t1>
```

### digamma

elementwise digamma

```
usage: torch digamma <t1>
```

### erf

elementwise error function

```
usage: torch erf <t1>
```

### erfc

elementwise complementary error function

```
usage: torch erfc <t1>
```

### exp

elementwise e^x

```
usage: torch exp <t1>
```

### exp2

elementwise 2^x

```
usage: torch exp2 <t1>
```

### expm1

elementwise e^x - 1

```
usage: torch expm1 <t1>
```

### floor

elementwise floor

```
usage: torch floor <t1>
```

### frac

elementwise fractional part

```
usage: torch frac <t1>
```

### i0

elementwise modified Bessel function I0

```
usage: torch i0 <t1>
```

### lgamma

elementwise log-gamma

```
usage: torch lgamma <t1>
```

### log

elementwise natural log

```
usage: torch log <t1>
```

### log10

elementwise log base 10

```
usage: torch log10 <t1>
```

### log1p

elementwise log(1+x)

```
usage: torch log1p <t1>
```

### log2

elementwise log base 2

```
usage: torch log2 <t1>
```

### logit

elementwise logit (inverse sigmoid)

```
usage: torch logit <t1>
```

### neg

elementwise negation

```
usage: torch neg <t1>
```

### rad2deg

radians to degrees

```
usage: torch rad2deg <t1>
```

### reciprocal

elementwise 1/x

```
usage: torch reciprocal <t1>
```

### relu

elementwise max(x, 0)

```
usage: torch relu <t1>
```

### round

elementwise round to nearest

```
usage: torch round <t1>
```

### rsqrt

elementwise 1/sqrt(x)

```
usage: torch rsqrt <t1>
```

### sgn

elementwise sign (complex-aware)

```
usage: torch sgn <t1>
```

### sigmoid

elementwise sigmoid

```
usage: torch sigmoid <t1>
```

### sign

elementwise sign

```
usage: torch sign <t1>
```

### sinc

elementwise normalized sinc

```
usage: torch sinc <t1>
```

### sinh

elementwise hyperbolic sine

```
usage: torch sinh <t1>
```

### sqrt

elementwise square root

```
usage: torch sqrt <t1>
```

### square

elementwise x^2

```
usage: torch square <t1>
```

### tan

elementwise tangent

```
usage: torch tan <t1>
```

### tanh

elementwise hyperbolic tangent

```
usage: torch tanh <t1>
```

### trunc

elementwise truncation toward zero

```
usage: torch trunc <t1>
```

### softmax

softmax along --dim (float32)

```
usage: torch softmax <t1> [--dim <Int>]
```

### log_softmax

log-softmax along --dim (float32)

```
usage: torch log_softmax <t1> [--dim <Int>]
```

### nan_to_num

replace NaN/inf (--nan/--posinf/--neginf)

```
usage: torch nan_to_num <t1> [--nan <Float>] [--posinf <Float>] [--neginf <Float>]
```

### mul

elementwise product (broadcasting)

```
usage: torch mul <t1> <t2>
```

### div

elementwise true division (broadcasting)

```
usage: torch div <t1> <t2>
```

### maximum

elementwise maximum (broadcasting)

```
usage: torch maximum <t1> <t2>
```

### minimum

elementwise minimum (broadcasting)

```
usage: torch minimum <t1> <t2>
```

### atan2

elementwise atan2(a, b) (broadcasting)

```
usage: torch atan2 <t1> <t2>
```

### fmod

elementwise C-style remainder (broadcasting)

```
usage: torch fmod <t1> <t2>
```

### remainder

elementwise Python-style remainder (broadcasting)

```
usage: torch remainder <t1> <t2>
```

### floor_divide

elementwise floor division (broadcasting)

```
usage: torch floor_divide <t1> <t2>
```

### hypot

elementwise hypotenuse (broadcasting)

```
usage: torch hypot <t1> <t2>
```

### copysign

magnitude of a, sign of b (broadcasting)

```
usage: torch copysign <t1> <t2>
```

### xlogy

elementwise x*log(y) (broadcasting)

```
usage: torch xlogy <t1> <t2>
```

### logaddexp

elementwise log(e^a + e^b) (broadcasting)

```
usage: torch logaddexp <t1> <t2>
```

### lerp

a + weight*(b - a) (scalar or tensor weight)

```
usage: torch lerp <t1> <t2> <weight>
```

### addcmul

a + value * b * c

```
usage: torch addcmul <t1> <t2> <t3> [--value <Scalar>]
```

### addcdiv

a + value * b / c

```
usage: torch addcdiv <t1> <t2> <t3> [--value <Scalar>]
```

### bitwise_and

bitwise AND of int tensors (broadcasting)

```
usage: torch bitwise_and <t1> <t2>
```

### bitwise_or

bitwise OR of int tensors (broadcasting)

```
usage: torch bitwise_or <t1> <t2>
```

### bitwise_xor

bitwise XOR of int tensors (broadcasting)

```
usage: torch bitwise_xor <t1> <t2>
```

### bitwise_not

bitwise NOT of an int tensor

```
usage: torch bitwise_not <t1>
```

### bitwise_left_shift

left shift of int tensors (broadcasting)

```
usage: torch bitwise_left_shift <t1> <t2>
```

### bitwise_right_shift

right shift of int tensors (broadcasting)

```
usage: torch bitwise_right_shift <t1> <t2>
```

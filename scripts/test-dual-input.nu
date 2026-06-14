#!/usr/bin/env nu
# Issue 0016 acceptance: the Dual Input Pattern in the Nushell module —
# pipeline form and argument form produce identical values across the
# wrapper shapes, and the CLI's arity errors surface through the module.
# Usage: PATH must contain `torch`; run: nu scripts/test-dual-input.nu

use ../nutorch.nu *

$env.TMPDIR = (mktemp -d)
mut failed = false

def check [name: string, ok: bool] {
  print $"(if $ok { 'ok  ' } else { 'FAIL' }) ($name)"
  $ok
}

torch manual_seed 42 | ignore
let a = ([1 2 3] | torch tensor)
let b = ([4 5 6] | torch tensor)

# add (two tensors + flag)
let p1 = ($a | torch add $b | torch value)
let p2 = (torch add $a $b | torch value)
if not (check "add: both forms identical" ($p1 == $p2)) { $failed = true }
let f1 = ($a | torch add $b --alpha 2 | torch value)
let f2 = (torch add $a $b --alpha 2 | torch value)
if not (check "add --alpha: both forms identical" ($f1 == $f2)) { $failed = true }

# mm (two 2-D tensors)
let m = ([[1.0 2.0] [3.0 4.0]] | torch tensor)
let mm1 = ($m | torch mm $m | torch value)
let mm2 = (torch mm $m $m | torch value)
if not (check "mm: both forms identical" ($mm1 == $mm2)) { $failed = true }

# mse_loss (two tensors)
let t = ([1.5 2.5 3.5] | torch tensor)
let l1 = ([1.0 2.0 3.0] | torch tensor | torch mse_loss $t | torch value)
let l2 = (torch mse_loss ([1.0 2.0 3.0] | torch tensor) $t | torch value)
if not (check "mse_loss: both forms identical" ($l1 == $l2)) { $failed = true }

# zero_grad (single tensor, result nothing — parity via the grad read)
let w1 = (torch randn [3] --requires_grad)
let w2 = (torch randn [3] --requires_grad)
($w1 | torch mul $w1 | torch sum) | torch backward
($w2 | torch mul $w2 | torch sum) | torch backward
$w1 | torch zero_grad
torch zero_grad $w2
let g1 = ($w1 | torch grad | torch value)
let g2 = ($w2 | torch grad | torch value)
if not (check "zero_grad: both forms zero the grad" ($g1 == $g2 and ($g1 | math sum) == 0.0)) { $failed = true }

# gather (two tensors, --dim flag)
let src = ([[1.0 2.0] [3.0 4.0]] | torch tensor)
let idx = ([[0 0] [1 0]] | torch tensor --dtype int64)
let ga1 = ($src | torch gather $idx --dim 1 | torch value)
let ga2 = (torch gather $src $idx --dim 1 | torch value)
if not (check "gather --dim: both forms identical" ($ga1 == $ga2)) { $failed = true }

# reshape (tensor + IntList positional — the list-conversion path)
let r1 = ($a | torch reshape [3 1] | torch value)
let r2 = (torch reshape $a [3 1] | torch value)
if not (check "reshape [3 1]: both forms identical" ($r1 == $r2)) { $failed = true }

# cat (variadic — the untouched AtLeast arm, both forms)
let c1 = ([$a $b] | torch cat | torch value)
let c2 = (torch cat $a $b | torch value)
if not (check "cat: both forms identical" ($c1 == $c2)) { $failed = true }

# forward (prelude verb)
let model = (torch nn linear 3 2)
let fw1 = ($a | torch forward $model | torch value)
let fw2 = (torch forward $model $a | torch value)
if not (check "forward: both forms identical" ($fw1 == $fw2)) { $failed = true }

# tensor (prelude verb): data as argument or pipe — one encode path.
# Non-finite parity compares `to nuon` strings: nu 0.113's `==` is broken
# for inf/NaN ([inf 2.0] == [1.5 2.0] is true; [NaN] == [NaN] is false).
let tp = ([1.5 2.5] | torch tensor | torch value | to nuon)
let ta = (torch tensor [1.5 2.5] | torch value | to nuon)
if not (check "tensor: both forms identical" ($tp == $ta)) { $failed = true }
let nfp = ([inf 2.0] | torch tensor | torch value | to nuon)
let nfa = (torch tensor [inf 2.0] | torch value | to nuon)
if not (check "tensor non-finite: both forms identical (nuon)" ($nfp == $nfa and ($nfp | str contains "inf"))) { $failed = true }

# value (prelude verb): handle as argument or pipe.
let vh = ([7 8 9] | torch tensor)
let vp = ($vh | torch value | to nuon)
let va = (torch value $vh | to nuon)
if not (check "value: both forms identical" ($vp == $va)) { $failed = true }

# shape (prelude verb): handle as argument or pipe.
let sh = ([[1 2 3] [4 5 6]] | torch tensor)
let sp = ($sh | torch shape)
let sa = (torch shape $sh)
if not (check "shape: both forms identical" ($sp == $sa and $sp == [2 3])) { $failed = true }

# Compatibility aliases from the pre-issue-0020 namespace still route
# through the structured wrappers.
let compat = (nutorch tensor [10 20] | nutorch value)
if not (check "nutorch aliases still work" ($compat == [10 20])) { $failed = true }

# arity errors surface from the CLI (captured via a sub-shell: a def-internal
# external failure raises past `do | complete` in-process). Under-supply with
# non-TTY stdin reads EOF, so the CLI says "expected N piped handle(s), got 0";
# at a terminal it says "missing tensor operand(s)" — both are the grammar's.
let modpath = ($env.FILE_PWD | path join ".." | path join "nutorch.nu" | path expand)
let under = (do { ^nu -c $"use ($modpath) *; torch add" } | complete)
if not (check "under-supply names the CLI error" ($under.exit_code != 0 and (($under.stderr | str contains "piped handle") or ($under.stderr | str contains "missing tensor operand")))) { $failed = true }
let over = (do { ^nu -c $"use ($modpath) *; let t = \([1] | torch tensor\); torch add $t $t $t" } | complete)
if not (check "too many positionals names the CLI error" ($over.exit_code != 0 and ($over.stderr | str contains "too many arguments"))) { $failed = true }

torch daemon stop | ignore

if $failed { error make { msg: "dual-input parity failed" } }
print "PASS: dual input parity (nushell module)"

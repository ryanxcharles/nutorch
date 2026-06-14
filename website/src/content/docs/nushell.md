---
title: Nushell
description: A generated module gives Nushell native structured data over the same daemon — tables in, tables out.
order: 7
section: Clients
---

Bash gets pipelines; [Nushell](https://www.nushell.sh/) gets pipelines _and_
structure. A generated module wraps every operation so tensors come from and
return to native Nushell values — no JSON wrangling.

## Setup

**If you installed NuTorch with Homebrew, there is nothing to set up.** The
formula ships a vendor-autoload stub, Nushell sources it at startup, and `torch`
commands are simply there in every new session — no `use` line, no `config.nu`
edit. (Mechanism: Nushell autoloads every `.nu` file in
`$nu.vendor-autoload-dirs`, and brew-built Nushell scans
`$(brew --prefix)/share/nushell/vendor/autoload`.)

The manual fallback — for from-source installs, or a Nushell that was not
installed by Homebrew (cargo, MacPorts, nightly builds) and so may not scan the
brew prefix:

```nu
# one-time: autoload in every session
mkdir ~/.config/nushell/autoload
'use "/opt/homebrew/share/nutorch/nutorch.nu" *'
  | save ~/.config/nushell/autoload/nutorch.nu

# or just this session
use /opt/homebrew/share/nutorch/nutorch.nu *
```

A current copy of `nutorch.nu` also ships in the repo root; regenerate it any
time with:

```nu
torch nu-module | save -f nutorch.nu
```

## Structured data in and out

```nu
let t = ([[1 2] [3 4]] | torch tensor)
$t | torch mm $t | torch value            # a native table
torch tensors | where bytes > 1_000_000 | get handle | each {|h| torch free $h }
```

Wrappers honor the dual input pattern — pipe the leftmost tensor in as `$in`, or
pass handles as arguments and the CLI's grammar fills the missing slots — and
every one of the 185 ops is wrapped, plus the registry and daemon verbs.
Non-finite values cross the boundary as REAL Nushell NaN/infinity floats; the
JSON dialect (`"NaN"`, `"Infinity"`, `"-Infinity"`) is handled for you in both
directions.

Use `^torch` when you explicitly want the external CLI's raw text or JSON output
instead of the structured Nushell wrapper result. The old `nutorch <op>`
namespace remains as a compatibility alias for existing scripts.

## Training, natively

The regression from [neural networks](/docs/neural-networks/), as Nushell:

```nu
use nutorch.nu *

torch manual_seed 42 | ignore
let x = ([[0.0] [1.0] [2.0] [3.0]] | torch tensor)
let y = ([[1.0] [3.0] [5.0] [7.0]] | torch tensor)
let model = (torch nn linear 1 1)
let opt = (torch nn sgd $model --lr 0.05)

for i in 1..200 {
  let loss = ($x | torch forward $model | torch mse_loss $y)
  $loss | torch backward
  $opt | torch step
  torch nn zero_grad $opt | ignore
}
```

The full script (with assertions) is `scripts/train-regression.nu` in the repo —
it converges to the same losses as its zsh twin.

## Plain JSON everywhere else

The structured verbs also serve any other tool via `--json`:

```bash
torch tensors --json
torch ops --json
torch daemon status --json
torch nn info $m --json
```

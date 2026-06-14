# NuTorch

**PyTorch-style GPU tensor operations from any shell.**

NuTorch is a shell interface to GPU tensors. A background daemon, `nutorchd`,
owns the tensor registry, LibTorch context, GPU memory, and autograd graphs. The
`torch` CLI sends one operation per invocation over a Unix socket and prints
plain string handles, so tensor programs compose in bash, zsh, fish, Nushell,
and scripts.

Nushell gets a generated structured module with native lists, tables, and
records. POSIX shells get ordinary stdin/stdout composition.

NuTorch is GPU-only on Apple silicon. Every tensor lives on Metal through MPS;
there is no CPU mode and no per-tensor device option. The daemon refuses to
start without MPS.

```bash
a=$(torch tensor '[1,2,3]')
b=$(torch tensor '[4,5,6]')
torch add $a $b | torch value
# [5.0,7.0,9.0]   computed on the GPU
```

## Installing

With [Homebrew](https://brew.sh) on Apple silicon:

```bash
brew tap nutorch/nutorch
brew trust nutorch/nutorch   # brew 6.0+ requires trusting third-party taps
brew install nutorch
```

Homebrew pours a prebuilt bottle when one matches your macOS. Otherwise it
builds from the pinned release tarball.

The installed CLI is available as both `torch` and `nutorch`. In the Homebrew
formula and source installer, `nutorch` is a symlink to `torch`.

The formula source lives at `dist/nutorch.rb`; the published tap is
[nutorch/homebrew-nutorch](https://github.com/nutorch/homebrew-nutorch).

### From Source

```bash
git clone https://github.com/nutorch/nutorch
cd nutorch
scripts/bootstrap.sh     # venv + torch 2.11.0 + release build
scripts/install.sh       # installs to ~/.nutorch by default
torch --version
```

Add `~/.nutorch/bin` to `PATH`, or pass a prefix to `scripts/install.sh`.

The installed binaries are relocatable. The required LibTorch dylibs are copied
into the install prefix and resolved by a baked relative rpath, so the install
does not need environment variables or the source checkout at runtime.

## The Daemon

Normal `torch` commands start `nutorchd` automatically when it is not already
running. The daemon shuts itself down after 1 hour of inactivity by default;
tensor operations renew that idle lease. Tensors live exactly as long as the
daemon.

```bash
torch daemon status      # pid, version, device, ttl, tensor count, socket, log
torch daemon ttl 4h      # change the live daemon's idle TTL
torch daemon stop        # shut down now
torch daemon restart     # fresh daemon, empty registry
torch daemon start       # start without running an operation
```

Set `NUTORCHD_TTL` to change the default TTL, for example `30m`, `2h`, or
`none`.

Run `torch ops` to list the operation table. For table operations, run
`torch <op> --help`, for example `torch add --help`.

## Handles and Pipelines

Tensor data stays in the daemon. The shell only sees typed handles such as
`tensor://...`, `nn://...`, and `optim://...`.

Every table operation accepts tensors either as arguments or from stdin:

```bash
torch add $a $b           # argument form
echo $a | torch add $b    # pipeline form: stdin fills the leftmost tensor slot
```

Nushell wrappers follow the same pattern:

```nu
nutorch add $a $b
$a | nutorch add $b
```

## Neural Networks

Modules are daemon-resident objects with `nn://` handles. Optimizers are
daemon-resident objects with `optim://` handles.

```bash
l=$(torch nn linear 2 3)                         # PyTorch-default init
m=$(torch nn sequential $l "$(torch nn relu)")   # consumes the child handles
y=$(torch forward $m $x)                         # or: echo $x | torch forward $m
torch nn parameters $m                           # live tensor:// parameter views
torch nn info $m
```

Module kinds:

```text
linear conv1d conv2d conv_transpose2d embedding layer_norm
batch_norm group_norm dropout relu sigmoid tanh gelu leaky_relu softmax
max_pool2d avg_pool2d flatten sequential
```

Optimizer kinds:

```text
sgd adam adamw rmsprop
```

Training uses ordinary tensor operations plus optimizer handles:

```bash
opt=$(torch nn sgd $m --lr 0.05)
loss=$(torch mse_loss $pred $target)
torch backward $loss
torch step $opt
torch nn zero_grad $opt
```

`torch nn train $m` and `torch nn eval $m` switch training/eval behavior for
modules such as dropout and batch norm.

Save and load model state with safetensors:

```bash
torch nn save $m model.safetensors
torch nn load $fresh model.safetensors
```

The saved state is PyTorch-interchangeable and includes buffers. Loading expects
a same-architecture module.

## Autograd

LibTorch records the computation graph automatically once a tensor requires
gradients:

```bash
w=$(torch randn '[3]' --requires_grad)
loss=$(torch mul $w $w | torch sum)
torch backward $loss
torch grad $w | torch value
torch zero_grad $w
d=$(torch detach $w)
```

Rules match PyTorch where possible:

- `backward` needs a scalar loss on a tensor that requires gradients.
- `grad` before any backward is an error.
- Gradients accumulate until you zero them.
- Re-run the forward computation before each backward pass; a second backward
  through the same graph errors, as in PyTorch.

Freeing an intermediate handle does not break backward, because the graph keeps
the tensors it needs internally. Keep leaf handles, because they are how you
read gradients.

## Nushell

Homebrew installs a Nushell autoload file, so new brew-built Nushell sessions
get `nutorch` commands without a manual `use` line.

```nu
let t = ([[1 2] [3 4]] | nutorch tensor)
$t | nutorch mm $t | nutorch value
nutorch tensors | where bytes > 1_000_000 | get handle | each {|h| nutorch free $h }
```

A current generated module is also committed at `nutorch.nu`. Regenerate it
with:

```bash
torch nu-module | save -f nutorch.nu
```

The wrappers preserve Nushell-native values, including NaN and infinity values.
The same structured data is available to any shell through JSON flags such as
`torch tensors --json`, `torch ops --json`, `torch nn info $m --json`, and
`torch daemon status --json`.

See `scripts/train-regression.nu` for a complete Nushell training loop.

## Saving Tensors and Reclaiming Memory

Export tensors you want to keep, then re-import them later:

```bash
torch value --meta $w > w.json
w=$(torch tensor "$(cat w.json)")
```

`--meta` includes dtype metadata so round-trips preserve dtype.

List and free registry handles:

```bash
torch tensors
torch free $t1 $t2
torch free --all
torch daemon restart
```

JSON has no native NaN or infinity values, so `torch value` writes the tokens
`"NaN"`, `"Infinity"`, and `"-Infinity"` for non-finite values. `torch tensor`
reads those tokens back.

## Copyright

Copyright (c) 2026 [Astrohacker](https://astrohacker.com) — MIT License (see
[LICENSE](LICENSE)).

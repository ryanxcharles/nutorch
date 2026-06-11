+++
status = "open"
opened = "2026-06-11"
+++

# Issue 8: Autograd — gradients from the shell

## Goal

Differentiate through tensor pipelines: create tensors that require gradients,
run any chain of existing ops, call `backward` on a scalar loss, and read the
gradients back — all from the shell, with PyTorch semantics.

```bash
w=$(torch tensor '[1.0,2.0]' --requires-grad)
loss=$(torch mul $w $w | torch sum)
torch backward $loss
torch grad $w | torch value     # [2.0, 4.0]
```

## Background

LibTorch builds the computation graph automatically: every op the daemon already
dispatches through tch participates in autograd whenever an input requires grad.
Nothing about differentiation is reimplemented — this issue exposes a workflow,
not an engine. The visible surface is small:

- `--requires-grad` on tensor creation;
- `torch backward <loss>` — run backpropagation from a scalar;
- `torch grad <t>` — a handle to a tensor's accumulated gradient;
- `torch detach <t>` — a graph-free copy (the escape hatch);
- whatever gradient-reset verb the design settles on (see question 3).

Tracking is off unless asked: tensors default to `requires_grad = false` exactly
as in PyTorch, so pure data work pays no graph cost. This is the prerequisite
issue for nn/optim (issue TBD): optimizer steps are pointless until gradients
exist.

## Design Questions

To be settled by experiments (not here), recorded so the issue's shape is honest
up front:

1. **Graph lifetime vs. `free` (the deep one).** A computation graph holds
   references to its upstream tensors inside libtorch. Freeing a registry handle
   whose tensor a live graph still references removes the HANDLE, but the
   underlying storage survives until the graph itself dies. That is semantically
   sound (nothing dangles) but it decouples `torch tensors`' byte accounting
   from the true resident footprint. The issue must decide what to document,
   whether `tensors`/`status` should surface graph-held memory at all, and what
   the memory-horizon contract says about graphs (likely: graphs die with the
   tensors that anchor them — `free` of the loss/outputs releases the graph;
   document, don't fight, libtorch's refcounting).
2. **Faithfulness of tracking.** PyTorch tracks any op whose input requires
   grad; so do we, automatically, because tch does. Intermediates in a tracked
   pipeline carry graph baggage by design. Nothing to build — but the docs must
   say it, and `detach` is the documented exit.
3. **`backward` semantics.** Scalar-only to start (PyTorch's own default for
   `.backward()` without arguments); whether `--retain-graph` ships in v1 of the
   surface or is recorded as future; and gradient accumulation — PyTorch
   ACCUMULATES across backward calls, so either a `zero_grad`-like verb ships
   alongside or accumulate-by-default is documented loudly (fidelity says:
   accumulate, and ship the reset verb).
4. **What `grad` returns.** Before any backward: PyTorch's `.grad` is `None` —
   the CLI analogue is a clean error (`no gradient: run backward
   first`), not
   an empty tensor. After backward: a handle — decided as a SNAPSHOT (a fresh
   registry tensor copied from `.grad` at call time) or a live view; snapshot is
   the safer contract for string handles (a view that silently changes under
   later backward calls is action at a distance the shell cannot see).
5. **MPS coverage.** Backward kernels on MPS are a distinct support surface from
   forward. The golden-generator oracle pattern (issue 0005) applies: gradients
   are golden-verified against Python `torch` on MPS, and any op whose BACKWARD
   is unimplemented on MPS gets recorded, not worked around.

## Scope

In: the five verbs/flags above, golden-verified gradients for a representative
op set, docs (README + the op-table summaries where relevant). Out (recorded):
optimizers and nn modules (the follow-up issue), `--retain-graph`/higher-order
gradients unless trivially cheap, per-op `grad_fn` introspection.

## Experiments

- [Experiment 1: The autograd surface — five verbs and a flag](01-autograd-surface.md)
  — **Designed**

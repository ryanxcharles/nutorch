+++
status = "open"
opened = "2026-06-14"
+++

# Issue 20: Nushell uses `torch`

## Goal

Make the Nushell command name `torch`, matching the cross-shell CLI name, while
preserving a deliberate compatibility path for existing `nutorch` Nushell
scripts.

Update all documentation, including the website, so Nushell examples teach
`torch` as the primary command and reserve `^torch` for explicitly invoking the
external binary from Nushell.

## Background

NuTorch 1.0 already presents `torch` as the canonical external CLI in POSIX
shells. The installed `nutorch` binary is only a symlink to `torch`, kept as a
compatibility alias.

Nushell is the exception: the generated module currently exports wrappers named
`nutorch tensor`, `nutorch add`, `nutorch tensors`, and so on. Those wrappers
delegate to the external CLI with `^torch`, converting native Nushell values at
the boundary. Because Nushell custom commands win for their exact command name,
the module shadows the external command only where a wrapper exists; the
external remains available explicitly through `^torch`.

Issue 0010 rejected same-name `torch` wrappers because of the risk of partial
shadowing: wrapped subcommands would return native Nushell values while
unwrapped subcommands would silently fall through to the external binary. That
tradeoff has changed. The module now wraps the public tensor surface, registry
verbs, daemon status, and the nn/optim family, and the external escape hatch is
clear and idiomatic in Nushell.

## Analysis

The product shape should be one command name everywhere:

```nu
let t = ([[1 2] [3 4]] | torch tensor)
$t | torch mm $t | torch value
torch tensors | where bytes > 1_000_000
```

In Nushell, `torch value` should mean the structured wrapper and return native
Nu data. When a user wants the raw external CLI behavior, they should write
`^torch value`.

The compatibility question is the main design point. Existing published docs and
scripts use `nutorch`, and the Homebrew autoload stub makes those commands
available today. A clean migration likely exports both names for at least one
release:

- `torch <op>` as the primary Nushell API.
- `nutorch <op>` as compatibility aliases or thin wrappers.
- `^torch <op>` as the documented way to bypass the module and call the external
  binary from Nushell.

The generator should continue to be the source of truth. The committed
`nutorch.nu` file may keep its filename for package compatibility, or the
experiment may rename it if the install/autoload/docs changes justify that. The
command namespace inside the file is the important behavior.

## Scope

In:

- Update the Nushell module generator and committed generated module so `torch`
  is the primary exported command namespace.
- Preserve `nutorch` Nushell commands as an explicit compatibility path unless
  an experiment proves that removing them is acceptable.
- Update verification scripts and Nushell examples to use `torch`.
- Update README documentation.
- Update website documentation and generated/reference examples so Nushell tabs
  use `torch`, and explain `^torch` where raw external output matters.
- Keep the external CLI binary named `torch`; do not change daemon or wire
  protocol behavior.

Out:

- Renaming the project, Homebrew formula, daemon, socket names, package share
  directory, or installed `nutorch` symlink.
- Changing POSIX-shell command behavior.
- Removing `nutorch` compatibility without a specific experiment and migration
  decision.

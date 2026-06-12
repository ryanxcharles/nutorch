+++
status = "open"
opened = "2026-06-12"
+++

# Issue 14: `nutorch` in Nushell, with nothing to type

## Goal

`nutorch` commands work in Nushell out of the box — no `use nutorch.nu *` at the
start of every session. Open a new Nushell, type `nutorch tensor '[1,2]'`, and
it works.

No adversarial review for this issue (user decision, 2026-06-12) — experiments
run design → plan commit → implement → result commit, with verification carrying
the weight.

## Background

The v2 Nushell story is the generated module `nutorch.nu`: rich wrappers
(`nutorch tensor`, `nutorch mm`, …) that take and return native Nushell values
and call `^torch` underneath. But a module only exists in scope after
`use nutorch.nu *` — which today must be typed (or put in `config.nu`) by hand.
The user's actual request was zero-setup availability in Nushell.

(A first version of this issue misread the request as "make `nutorch` a CLI name
in every shell" and shipped a `nutorch → torch` symlink through `install.sh` and
the formula before being corrected. That experiment record was removed at user
direction; the symlink changes themselves remain in the tree and in history —
harmless, and unrelated to this goal.)

## Analysis

Two mechanisms, not mutually exclusive:

1. **User-level**: one line in `config.nu` —
   `use /opt/homebrew/share/nutorch/nutorch.nu *`. Works today, but it is
   per-user setup: exactly the thing the goal wants to eliminate.
2. **Package-level (the real fix): Nushell vendor autoload.** Nushell sources
   every `.nu` file in `$nu.vendor-autoload-dirs` at startup —
   `$(brew --prefix)/share/nushell/vendor/autoload` is on that list for
   brew-installed Nushell. This is how starship, zoxide, and carapace ship
   zero-config Nushell integration. The nutorch formula installs a one-line stub
   there (`use ".../share/nutorch/nutorch.nu" *`), and `brew install nutorch`
   makes `nutorch` work in every new Nushell session with no config edit.

Open questions for the experiment design:

- The exact autoload-dir contract on this machine's Nushell version (verify
  `$nu.vendor-autoload-dirs` includes the brew prefix path; verify a sourced
  `use … *` at autoload time exports into the session scope).
- `install.sh` parity: from-source installs should get the same behavior where
  reasonable (the prefix's autoload dir is only consulted if it is on the user's
  autoload path — may reduce to a documented `config.nu` line for non-brew
  installs).
- The published tap and bottle pick the stub up with the next release (same
  precedent as the MIT metadata and the CLI symlink).

## Scope

In: the vendor-autoload stub in `dist/nutorch.rb`; whatever `install.sh` parity
is reasonable; docs (Nushell page: replace the manual `use` framing with "it's
just there" + the manual line as fallback); local hand-applied stub so the
user's machine gets the behavior now.

Out (recorded): republishing the tap / re-bottling before the next release;
reverting the issue's earlier CLI-symlink side effect (separate concern, the
user has not asked); any plugin mechanism (v1's dead end).

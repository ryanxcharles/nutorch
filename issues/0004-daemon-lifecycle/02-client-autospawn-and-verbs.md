+++
[implementer]
agent = "claude-code"
model = "claude-fable-5"

[review.design]
agent = "claude-code"
subagent = "adversarial-reviewer"
model = "claude-opus"

[review.result]
agent = "claude-code"
subagent = "adversarial-reviewer"
model = "claude-opus"
+++

# Experiment 2: Client auto-spawn and the `torch daemon` command family

## Description

The user-facing half: any tensor command **auto-starts** the daemon when the
socket is dead, and `torch daemon status|ttl|stop|restart|start` exposes the
Experiment-1 machinery. After this experiment the issue's goal statement holds
end to end: you never think about the daemon, and you can always ask it how long
your memory has left.

Experiment 1 deliberately made this layer thin: every verb is one wire op plus
formatting; auto-spawn is "spawn what `probe_and_bind` already knows how to
welcome".

## Changes

1. **Auto-spawn** (`torch-cli/src/main.rs`):
   - On connect failure for a **tensor op**, the client: locates `nutorchd`
     (same directory as the `torch` binary via `current_exe()`; overridable with
     `NUTORCHD_BIN`), spawns it detached with `--socket <resolved path>` and
     stdout/stderr appended to the conventional log file (socket path with
     `.log`), then polls the socket (~50 ms interval, ~5 s bound) until it
     answers, and retries the request once. Startup failure → a clear error
     naming the log file. The spawned daemon gets `Stdio::null()` for stdin and
     is fully detached, so it survives the client's exit. (The daemon's
     probe-bind makes spawn races harmless — losers exit 0 — except for the
     simultaneous-start TOCTOU window already recorded and deferred in
     Experiment 1.)
   - **Which commands auto-spawn**: tensor ops, `daemon start`, and
     `daemon restart` do. `daemon status`, `daemon ttl`, and `daemon stop` do
     **not** — observing, configuring, or stopping a daemon must not create one.
2. **`torch daemon <verb>`** (new op family in the client; no protocol changes —
   Experiment 1 shipped the ops):
   - `status` → `status` op, printed as human-readable lines (pid, uptime, ttl,
     idle, remaining, tensors, memory, socket, log). Not running → "not running
     (socket: …)" on stderr, **exit 1** (scriptable liveness check), and no
     spawn.
   - `ttl <duration>` → `set_ttl` op; prints the new ttl. Not running → error,
     exit 1.
   - `stop` → `shutdown` op; prints confirmation. Not running → "not running",
     **exit 0** (stopping nothing is success — idempotent).
   - `restart` → `stop` semantics (ignore not-running), **then poll until the
     old socket is gone (or refuses) before spawning** — the old daemon flushes
     its shutdown response before unlinking, so a new daemon spawned too eagerly
     could probe the dying one, yield, and leave zero daemons. Then the
     auto-spawn path; prints the new pid via a follow-up `status`.
   - `start` → the auto-spawn path; prints "started (pid N)" or "already running
     (pid N)".
   - **The `daemon` verb family parses its subcommand and arguments from
     positionals only and never falls back to stdin** (unlike `value`/`mean`,
     these verbs have no pipeline form; a missing `ttl <duration>` is a plain
     usage error, not a blocking stdin read).
3. **Docs**:
   - root `README.md`: a short "The daemon" paragraph — starts automatically,
     idles out after 1 hour (configurable), `torch daemon status` to inspect,
     tensors live only as long as the daemon (the memory-horizon contract);
   - root `AGENTS.md`: the Vision bullet on tensor lifetime is updated — the
     daemon lifecycle (auto-start, sliding idle TTL) is now real, while
     tensor-level lifecycle (named handles, `free`, per-tensor TTLs) remains
     future work; Directory Structure gains `src/lifecycle.rs`.
4. **Tests**: the client remains I/O-bound glue, so this experiment's
   correctness lives in the behavioral checks below (the daemon-side logic they
   exercise is already unit-tested). No new unit tests beyond what refactoring
   requires; the no-warnings gate still applies.

## Verification

From the repo root; dedicated `--socket` paths under `/tmp`; everything cleaned
up by the checks. `T=./target/debug/torch`.

1. **Hygiene**: `cargo build` 0 warnings; `cargo test` green (32 from Exp 1);
   `cargo fmt --all -- --check` clean; `dprint check` clean on touched files;
   `git status --porcelain v1/` empty.
2. **Cold start (the headline)**: with no daemon and no socket file,
   `$T tensor '[1,2,3]' --socket S | $T value --socket S` → `[1.0,2.0,3.0]` —
   the daemon was spawned transparently; `$T daemon status --socket S` shows it
   running; the log file `S.log` exists and contains the banner.
3. **status semantics**: after `daemon stop`, `daemon status` prints "not
   running", exits 1, and does NOT spawn a daemon (no socket file appears).
4. **Expiry → transparent respawn (the full invisible loop)**: `daemon ttl 2s`,
   wait ~4s (daemon expires), then a plain `$T tensor '[9]' … | $T value …`
   succeeds → `[9.0]` with a NEW daemon (different pid in `status` than before
   expiry).
5. **stop**: `daemon stop` → confirmation, socket gone; `daemon stop` again →
   "not running", exit 0.
6. **restart**: with a live daemon holding a tensor, `daemon restart` → new pid,
   and the old handle is now `unknown handle` (fresh registry — explicit and
   expected).
7. **start**: `daemon start` on a dead socket → "started (pid N)"; again →
   "already running" with the same pid.
8. **ttl verb**: `daemon ttl 30m` → reports 1800s; `status` agrees (`remaining`
   ≤ 1800).
9. **Default socket end-to-end, safely isolated**: one run with NO `--socket`
   anywhere, but under a **private `TMPDIR`** (`env TMPDIR=$(mktemp -d)`), so
   the default-path code (`$TMPDIR/nutorchd.sock`) is exercised for real while a
   genuine user daemon on the actual default socket can never be touched:
   `$T tensor '[1]' | $T value` → `[1.0]`, then `$T daemon stop`, then the
   private dir is removed. (Stopping a real in-use daemon would destroy live GPU
   tensors — the check must be structurally incapable of that.)
10. **Docs**: README contains the auto-start + 1-hour story; AGENTS.md Vision
    reflects the implemented daemon lifecycle.

**Pass** = all ten. **Partial** = auto-spawn works but a verb misbehaves in a
recorded, non-destructive way. **Fail** = cold start does not work, expiry does
not respawn transparently, or a non-spawning verb spawns a daemon.

## Design Review

**Reviewer:** `adversarial-reviewer` subagent (fresh context, read-only).
**First pass: CHANGES REQUIRED** — 1 Required, 3 Optional, 1 Nit:

- [Required] Verification check 9 ran tensor ops and `daemon stop` against the
  REAL default socket with no guard — on a machine with a genuine daemon in use
  (the expected steady state once this issue ships), the check would have
  stopped it and destroyed live GPU tensors. **Fixed:** check 9 now exercises
  the default-path code under a private `TMPDIR` (`env TMPDIR=$(mktemp -d)`),
  making the hazard structurally impossible.
- [Optional] `restart`'s stop-then-spawn had a latent race (the old daemon
  flushes its shutdown response before unlinking, so an eager respawn could
  probe the dying daemon, yield, and leave zero daemons). **Fixed:** restart
  polls until the old socket is gone before spawning.
- [Optional] The daemon verbs' stdin behavior was unspecified against the
  client's blocking stdin-fallback helper. **Fixed:** positionals only, never
  stdin.
- [Optional] Spawned daemon's stdin unspecified. **Fixed:** `Stdio::null()`
  - detached note.
- [Nit] "spawn races harmless" overstated. **Fixed:** now qualified by the
  deferred Exp-1 TOCTOU window.

**Re-review (fresh context): APPROVED** — all five confirmed resolved; the
reviewer verified the check-9 fix against both binaries' `default_socket_path()`
implementations (private TMPDIR genuinely isolates both the spawned daemon and
the stopping client). No new findings.

## Result

**Result:** Pass

All ten checks pass in a single clean run:

```
cold start:        [1.0,2.0,3.0] from a dead socket; status shows the spawned
                   daemon; the .log file exists with the banner
status after stop: "daemon not running" on stderr, exit 1, no socket appears
expiry → respawn:  daemon ttl 2s → 4s later a plain tensor op succeeds ([9.0])
                   against a NEW pid — the full invisible loop
ttl verb:          ttl 30m → 1800s; status remaining: 1799s
restart:           new pid; the old handle is "unknown handle" (fresh registry)
stop idempotent:   second stop → "nothing to stop", exit 0
start idempotent:  "started (pid N)" then "already running (pid N)"
default socket:    end-to-end under a private TMPDIR; nothing left behind
docs:              README "The daemon" section; AGENTS.md Vision updated
```

**Hygiene:** `cargo build` 0 warnings; `cargo test` green (32);
`cargo fmt --all -- --check` clean; `dprint check` clean;
`git status --porcelain v1/` empty; no stray daemons after the run.

**Bug found and fixed during verification (the find of the experiment):** the
first verification run **deadlocked**. The daemon-verb code probed liveness with
`match try_connect(socket) { Some(_) => exchange(...) }` — and a Rust `match`
scrutinee's temporary lives for the entire match arm, so the probe connection
stayed open while `exchange` opened a second connection. Against the serial
one-connection-at-a-time daemon (still blocked reading the open probe), the
reply never came: a textbook self-deadlock. The fix replaces every probe site
with `daemon_alive()`, which drops the probe stream before returning, with a doc
comment explaining exactly this hazard (`torch-cli/src/main.rs`). The tensor-op
path had silently dodged the bug only because a plain `if` condition drops its
temporary earlier. This is the serial daemon's first real bite; the concurrency
issue inherits the case study.

**Verification-run note:** after the deadlock was fixed, the first (stuck) test
script was found still limping in the background racing the re-run on the same
socket; everything was killed and the entire suite re-run clean, uncontended —
the transcript above is from that clean run. A momentary `pgrep` hit after the
final stop was confirmed to be shutdown exit-latency (the daemon flushes its
reply before exiting), not a leak.

## Conclusion

The issue's goal holds end to end. From a dead machine state:
`torch tensor '[1,2,3]' | torch value` just works — daemon spawned invisibly,
logged beside its socket; an hour of inactivity later it is gone, and the next
command conjures a fresh one. `torch daemon status` shows the lease in real
time; `ttl`/`stop`/`restart`/`start` control it. Auto-start makes expiry
harmless, expiry makes auto-start safe to forget — the two halves the issue
called load-bearing are both real now.

Carried forward: the match-scrutinee deadlock is the strongest argument yet for
the concurrency issue (a daemon that served connections concurrently would never
have deadlocked); the simultaneous-start TOCTOU window remains deferred there
too.

## Result Review

**Reviewer:** `adversarial-reviewer` subagent (fresh context, read-only),
reviewing the pre-commit working tree. **Verdict: APPROVED — no Required or
Optional findings; one Nit, folded in** (the "log path with `.log`" wording now
says the extension is _replaced_, matching `with_extension`'s behavior). The
reviewer independently reproduced every gate and behavioral check on its own
throwaway sockets — including the deadlock regression check (`daemon
status`
must reply, not hang) and the private-TMPDIR default-socket run — and audited
the review-mandated items in code: null stdin + log redirect on the spawned
daemon, restart's poll-until-dead, daemon verbs structurally unable to reach the
stdin fallback, and auto-spawn reachable only from tensor ops / start / restart.
It verified no held-probe patterns remain and judged the deadlock account
"technically accurate — correct Rust semantics" (match scrutinee temporaries vs
if-condition temporaries) against the daemon's serial accept loop.

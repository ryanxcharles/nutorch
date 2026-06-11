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

# Experiment 1: Thread-per-connection, one lock as the execution queue

## Description

Implement the issue's contract in one pass: the accept loop spawns a thread per
connection; the registry moves behind `Arc<Mutex<…>>`; every request dispatches
under that lock. All four design corners from the issue are decided here:

1. **Lock scope = dispatch only.** A connection thread reads a line, locks the
   registry, runs `handle_request`, unlocks, THEN writes the response. Writes
   happen outside the lock (streams are per-connection, so there is nothing to
   interleave with); requests on one connection stay serial by the read loop
   itself. `handle_request` keeps its `&mut Registry` signature — callers lock,
   dispatch.rs does not change, and every existing unit test runs unmodified.
2. **Idle-TTL coherence by lock discipline.** The lease touch already happens
   inside `handle_request` — which now runs under the registry lock. The expiry
   watcher changes from "check every second" to "LOCK the registry, then check":
   if it wins the lock and `expired()` holds, no request can be mid-execution
   (it would hold the lock) and none can have touched-but-not-started (touch
   happens under the lock), so it exits holding the lock. The mid-op-expiry race
   — which exists in TODAY's serial daemon for any op longer than the TTL — is
   closed by construction, not by sleeping.
3. **Shutdown semantics: graceful to the requester, clean-but-abrupt to peers.**
   The shutdown path (and TTL expiry, and signals) unlinks the socket and exits
   as today. The requester gets its flushed response first. Concurrent peers see
   EOF mid-connection — exactly what daemon death looks like today, a condition
   every client already handles ("empty response from daemon"). **The shutdown
   thread holds the registry lock from dispatch straight through `exit()`** —
   never dropping it — which is both simpler and strictly stronger than
   drop-and-reacquire (no other op can run between the shutdown response and the
   exit; the response write happens under the lock, acceptable for this one
   arm). What is NOT promised is draining other connections' queued requests.
   Recorded plainly.
4. **Error isolation and accounting are free.** Parse errors answer on their own
   stream; an IO error kills only its own thread (logged to the daemon log);
   `status`/`tensors` snapshots read under the same lock as everything else.

The signal-handler thread and client are untouched. The wire protocol, op table,
and grammar are untouched (the issue's mandate boundary).

## Changes

1. **`nutorchd/src/main.rs`** (the whole change lives here):
   - `let registry = Arc::new(Mutex::new(Registry::new()));`
   - accept loop: `thread::spawn` per connection with `Arc` clones (registry,
     lifecycle) and owned copies of the socket path;
   - `serve_connection(registry: &Mutex<Registry>, …)`: per line — lock,
     `handle_request(&mut guard, …)`, then: normal responses drop the guard and
     write outside the lock; the shutdown response writes, flushes, unlinks, and
     exits while STILL HOLDING the guard (design corner 3);
   - the expiry watcher: lock registry → `expired()` → unlink + exit while
     holding the lock; otherwise drop and sleep 1s;
   - connection-thread errors logged with a connection-scoped prefix.
2. **No `nutorchd/src/dispatch.rs` changes** (signature stays `&mut Registry`).
   No protocol, ops, or client changes. (If implementation discovers otherwise,
   that is the issue's declared exceeded-mandate signal — Fail.)

## Verification

1. **Hygiene**: build 0 warnings; fmt/dprint clean on touched files; the FULL
   existing suite green unmodified (49 unit + 207 golden + 3 smoke + lifecycle
   tests — zero test-file edits).
2. **The headline: a stuck client costs nothing.**
   - The stuck client is NOT `nc` (macOS `nc -w` silently closes idle
     connections and `< /dev/null` half-closes at once — a vacuous-pass hazard
     the design review caught). The reliable recipe:
     `python3 -c 'import socket,time; s=socket.socket(socket.AF_UNIX);
     s.connect(SOCK); time.sleep(600)' &`
     — connects, sends nothing, stays parked.
   - Baseline first, cheaply: BEFORE editing, the current binary + the parked
     client + a concurrent op demonstrably hangs (no old-build juggling — the
     pre-change binary is just the binary before the edit; issue 0004's probe
     deadlock already documents the class).
   - New behavior: with the parked client in the background, tensor ops from
     other shells complete normally.
3. **Parallel-client stress**: 8 background shells, each looping 25 iterations
   of tensor→add→value against one daemon; all 200 results exact; final
   `torch daemon status` tensor count **exactly 600** (8 shells × 25 iters × (2
   inputs + 1 add result), nothing freed in the loop); no errors in any shell;
   daemon log clean of panics.
4. **Serialized execution observed**: two clients submit big `mm`s (4096²)
   simultaneously; each result is verified `equal` (whole-tensor) to the same
   `mm` computed alone beforehand — correctness with teeth, not just liveness.
5. **Shutdown under load**: while the stress loop runs, `torch daemon
   stop`;
   the stopper gets its confirmation; the loop clients get clean errors
   (connection refused / empty response), NOT hangs; socket file gone; no zombie
   daemon.
6. **TTL coherence with idle connections**: daemon with `--ttl 2s`; an idle `nc`
   connection held open the whole time; ops every 0.5s for ~4s keep the daemon
   alive (touches renew under the lock); stop the ops; daemon exits ~2s later
   DESPITE the still-open idle connection (an open socket is not work and does
   not pin the lease); socket unlinked.
7. **Error isolation**: one connection sends garbage (gets its error), while a
   concurrent valid op on another connection succeeds untouched.

**Pass** = all seven. **Fail** = the change could not stay inside main.rs
(dispatch/protocol/client edits needed), or any existing test had to change.

## Design Review

**Reviewer:** `adversarial-reviewer` subagent (fresh context, read-only).
**First pass: CHANGES REQUIRED** — 2 Required, both verification-precision: the
stress criterion said "exactly 8×25×2 (+ results)" which is not a checkable
number (fixed: exactly 600, formula stated), and the `nc` stuck-client recipe is
unreliable on macOS (`-w` silently closes idle connections; `< /dev/null`
half-closes immediately) — a vacuous-pass hazard on the issue's headline check
(fixed: a parked Python socket that connects and sleeps). 2 Optional folded in:
the old-binary baseline juggling is replaced by demonstrating the hang against
the pre-change binary before editing; shutdown now holds the lock from dispatch
straight through `exit()` (simpler and strictly stronger than
drop-and-reacquire, whose benign-but-confusing intervening-op window the
reviewer named). 1 Nit folded in: the dual-`mm` check now compares each result
`equal` to a solo run. **The reviewer independently verified the load-bearing
concurrency claims**: every lifecycle-lock site traced (`rg .lock()`) — both the
watcher and all request-path arms acquire registry → lifecycle in the same
order, so the deadlock the design must avoid cannot occur; the preserved
`&mut Registry` signature keeps every existing test compiling unmodified;
`exit()` while holding a Mutex is harmless; both exit paths unlink first.

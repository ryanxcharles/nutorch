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

# Experiment 1: Daemon-side lifecycle — idle TTL, clean exits, probe-bind, and the three protocol ops

## Description

Build the daemon half of the issue: the sliding idle TTL with self-shutdown, the
three clean exits (expiry, `shutdown` op, signals), the
liveness-probe-before-bind that fixes the socket-steal debt, and the `status` /
`set_ttl` / `shutdown` protocol ops. **No client changes** — the client layer
(`torch daemon` verbs, auto-spawn) is the next experiment, and this one is
verified with raw wire requests (`nc -U`) plus daemon flags, so the two layers
stay independently testable.

Splitting here keeps each experiment one coherent surface: this one is "the
daemon can manage its own life"; the next is "the user never has to".

## Changes

1. **Lifecycle state** (`nutorchd/src/main.rs`): a `Lifecycle` struct shared
   between threads (`Arc<Mutex<…>>`) holding: process start `Instant` (uptime),
   last-activity `Instant`, and `ttl: Option<Duration>` (`None` = run forever).
   - **Activity = tensor ops only**: `tensor`, `full`, `add`, `mm`, `mean`,
     `value` reset last-activity. `status`, `set_ttl`, `shutdown` do not
     (observing or configuring the daemon must not immortalize it; `set_ttl`
     moves the deadline anyway, by definition: deadline = last-activity + ttl).
   - **Expiry watcher**: a background thread wakes ~1×/second; when
     `now > last_activity + ttl`, it logs the expiry, unlinks the socket, and
     exits 0. (This is the design's "timer thread" answer to the blocking-accept
     problem — chosen over a polling accept because it keeps the serve loop
     untouched.)
2. **TTL configuration** (daemon side):
   - `--ttl <duration>` flag, `NUTORCHD_TTL` env var (flag wins), default `1h`;
   - a duration parser (daemon-owned; the client will pass raw strings): accepts
     `<n>s|m|h` (e.g. `90s`, `30m`, `2h`), bare integer seconds, and `none`;
     rejects everything else with a clear error. Unit-tested.
3. **Probe-before-bind** (replaces unconditional stale-socket removal): try
   `UnixStream::connect` on the socket path first —
   - connection succeeds → another daemon is alive → log "already running" and
     **exit 0 quietly** (the design's race resolution: the newcomer yields; an
     auto-spawning client just needs _a_ daemon);
   - connection refused / not found → remove any stale file and bind.
   - **Known residual (recorded, deferred)**: two daemons starting
     _simultaneously_ can both probe before either binds (a TOCTOU window) — the
     second's remove-then-bind could unlink the first's fresh socket. This
     closes the recorded steal-from-a-LIVE-daemon debt but not the
     simultaneous-start race; the auto-spawn experiment mitigates it (one spawn
     per connect failure, then re-probe), and a fully exclusive bind (lock file)
     belongs to the concurrency issue if it ever bites.
4. **Signal handling**: take the `signal-hook` dependency; a thread waits on
   SIGTERM/SIGINT, then unlinks the socket and exits 0. Fixes the
   stranded-socket debt.
5. **Protocol ops** (`protocol.rs` + dispatch):
   - `{"op":"status"}` → `{"ok":true,"value":{…}}` with: `pid`, `uptime_secs`,
     `device` ("mps"), `ttl_secs` (number or null for `none`), `idle_secs`,
     `remaining_secs` (number or null), `tensors` (count), `approx_bytes` (Σ
     numel × element size over the registry), `socket`, `log` (the conventional
     log path: socket path with a `.log` extension — the spawner wires actual
     redirection next experiment, so for a manually-started daemon this path may
     not exist; it is a convention report, not a file guarantee).
   - `{"op":"set_ttl","ttl":"<duration>"}` → ok + the new `ttl_secs` (parsed by
     the same duration parser; errors are one-line).
   - `{"op":"shutdown"}` → responds `{"ok":true,…}` first, then unlinks the
     socket and exits 0 (graceful: the response is flushed before exit).
   - `Registry` gains `len()` and an iterator (legitimately needed now — they
     were removed in issue 0002 as dead code; the no-warnings gate forced
     honesty then and gets satisfied properly now).
6. **Startup banner** gains the lifecycle facts: pid, ttl. Tests: duration
   parser (all forms + rejects); `status` response shape and field sanity (pid
   matches, tensors counts inserts, approx_bytes positive after an insert);
   `set_ttl` changes `remaining_secs`; activity-reset semantics (a tensor op
   moves `idle_secs` back to ~0, a `status` call does not). Expiry, probe-bind,
   signal, and shutdown exits are behavioral (below) — they end the process, so
   they are not unit tests.

## Verification

From the repo root; all wire probes via
`printf '<json>\n' | nc -U -w 1 <socket>`. Each behavioral daemon uses a
dedicated socket under `/tmp` and is cleaned up by the check itself.

1. **Hygiene**: `cargo build` 0 warnings; `cargo test` green (new unit tests
   included); `cargo fmt --all -- --check` clean; `dprint check` clean on
   touched files; `git status --porcelain v1/` empty.
2. **Idle expiry (the headline)**: start `nutorchd --socket S --ttl 3s`; create
   a tensor; confirm `status` shows `ttl_secs: 3` and small `idle_secs`; wait
   ~5s; **the process has exited on its own and the socket file is gone**.
3. **Sliding renewal**: start with `--ttl 4s`; at t≈2s do a tensor op; at
   t≈4.5–5s (past the original 4s deadline, comfortably inside the renewed ~6s
   one) the daemon is still alive and serving; then let it expire. _Timing note
   for all second-scale checks: the watcher wakes ~1×/second, so expiry fires
   within ~1s after the deadline; hand-run timings tolerate ±1s and the checks
   are margined accordingly._
4. **Activity semantics**: with `--ttl 1h`, `status` twice a few seconds apart
   shows `idle_secs` growing (status does not reset); one tensor op resets
   `idle_secs` to ~0.
5. **`set_ttl` live**: `set_ttl 2s` on an idle daemon → `remaining_secs` drops
   accordingly and the daemon expires without restart; `set_ttl none` on another
   → `remaining_secs` null, still alive well past any deadline; `set_ttl bogus`
   → one-line error.
6. **Graceful `shutdown` op**: response `ok:true` is received, process exits,
   socket file gone.
7. **Probe-bind**: with a live daemon on S, start a second
   `nutorchd
   --socket S` → it exits 0 quietly; the FIRST daemon still owns
   the socket (a tensor created before is still readable after). With a stale
   socket file (daemon killed -9), a new daemon starts and binds normally.
8. **Signals**: SIGTERM to a live daemon → exits, socket file gone (the
   stranded-socket debt is fixed); same for SIGINT.
9. **Default TTL**: a daemon started with no flag and no env reports
   `ttl_secs: 3600` in `status`.

**Pass** = all nine. **Partial** = lifecycle works but one exit path misbehaves
in a recorded, non-data-losing way. **Fail** = expiry doesn't fire, expiry fires
despite activity (data loss in active use), or the probe-bind still steals a
live socket.

## Design Review

**Reviewer:** `adversarial-reviewer` subagent (fresh context, read-only).
**Verdict: APPROVED** — no Required findings. The reviewer confirmed the
load-bearing claims: the `Arc<Mutex<Lifecycle>>` + 1 Hz watcher cannot deadlock
against the blocking serve loop (neither side holds the mutex across a blocking
read); the probe-bind outcome mapping (live → success, stale → ECONNREFUSED,
missing → ENOENT) is correct Unix behavior; `signal-hook`'s dedicated-thread
pattern keeps unlink+exit out of async-signal context (and beats `ctrlc`, which
lacks SIGTERM); the `status` shape reuses the existing untagged
`Response::Value` variant; and `approx_bytes` is implementable (`numel`, `kind`,
`elt_size_in_bytes` all exist in tch 0.24). It judged the daemon/client split
sensible, activity semantics internally consistent (`value` rightly counts as
activity), and the Fail criterion correctly focused on expiry-despite-activity
as the data-loss case. Two Optional findings and one Nit, all folded in: (1) the
simultaneous-start TOCTOU window is now recorded as a known, deferred residual
distinct from the fixed live-steal debt; (2) check 3's renewal timing got wider
margins plus a ±1s watcher-granularity note; (3) the `status.log` field is now
documented as a convention report that may not exist for manually-started
daemons.

## Result

**Result:** Pass

All nine checks pass. The behavioral transcript, abridged:

```
check 2 (idle expiry, --ttl 3s):  ttl: 3 idle: 0 → process exited on its own;
                                  socket file gone; log: "idle ttl expired; exiting"
check 3 (sliding renewal, 4s):    alive past original deadline (renewed);
                                  still serving; expired after renewal lapsed
check 4 (activity semantics):     idle 1 → 2 across two status calls (status
                                  does not reset); 0 after a tensor op
check 5 (set_ttl live):           set_ttl 2s → remaining 1 → expired without
                                  restart; set_ttl none → alive past any
                                  deadline; "bogus" → one-line error
check 6 (shutdown op):            {"ok":true,"value":"shutting down"} received,
                                  process exited, socket gone
check 7 (probe-bind):             second daemon exits 0 ("already running");
                                  FIRST daemon survives and its tensor is still
                                  readable ([42.0]); kill -9 leaves a stale
                                  socket; a new daemon binds over it normally
check 8 (signals):                SIGTERM and SIGINT both → socket cleaned up
check 9 (default):                ttl_secs: 3600 with no flag and no env
```

**Hygiene:** `cargo build` 0 warnings; `cargo test` green — 32 tests (29 unit: 7
conversion + 1 registry + 6 lifecycle-module + 15 dispatch including the four
new lifecycle-dispatch tests; plus 3 MPS smoke tests);
`cargo fmt --all -- --check` clean; `dprint check` clean;
`git status --porcelain v1/` empty.

**One implementation find:** serde's `rename_all = "lowercase"` maps `SetTtl` to
`setttl`, not the design's wire name `set_ttl` — caught immediately by the new
dispatch unit test, fixed with an explicit `#[serde(rename = "set_ttl")]`. The
test suite earned its keep before the wire ever did.

Also updated: the daemon's module doc, which still described the issue-0002
"unconditional stale-socket removal" simplification this experiment removed.

## Conclusion

The daemon now manages its own life: it yields to a living sibling instead of
stealing its socket, renews its lease on every tensor op, reports its own vital
signs (`status`), takes runtime TTL changes (`set_ttl`), dies politely on
request (`shutdown`), on signal (SIGTERM/SIGINT), and of old age (idle expiry) —
and in every one of those exits it sweeps its own socket. Both recorded socket
debts from issues 0002/0003 are closed; the remaining simultaneous-start TOCTOU
window is documented and deferred as designed.

The next experiment is the client half: auto-spawn on connect failure (spawn
detached → redirect output to the conventional `.log` path → poll the socket →
retry), the `torch daemon status|ttl|stop|restart|start` verbs over the three
new ops, and the doc updates (README/AGENTS.md gain the "you never start the
daemon" story). The daemon side was built to make that layer thin: every verb is
one wire op plus formatting.

## Result Review

**Reviewer:** `adversarial-reviewer` subagent (fresh context, read-only),
reviewing the pre-commit working tree. **Verdict: APPROVED — no Required,
Optional, or Nit findings.** The reviewer independently reproduced every gate
and every behavioral check on its own daemons (expiry, renewal, activity
semantics, set_ttl none/bogus, graceful shutdown ordering, probe-bind survival
with the tensor still readable, both signals, the 3600s default) — and went
beyond the recorded checks to verify the TTL precedence chain directly
(`--ttl 7s` beats `NUTORCHD_TTL=99s`; env-only is honored). It cleared the
scrutinized subtleties: no mutex deadlock/poisoning risk (no lock held across
blocking work), the new unknown-argument rejection breaks nothing recorded (all
prior invocations use only `--socket`), the ms-granularity unit tests
legitimately bypass the second-granularity wire parser, and both deviations (the
serde `set_ttl` rename, the module-doc rewrite) are honestly recorded.

# Container capacity scheduling — keeping the pipe full without killing the runs

`trading-1-dev` is a **fixed, shared 7.75 GB / ~8-core resource**. Every kind of
work in this repo draws on it differently, and the failure mode is silent: an
OOM-killed backtest child writes no exception, no `Killed` line, no stack — the
scenario just reports `FAIL (scenario crashed or did not write actual.sexp)` and
an empty log. Observed 2026-08-12: six concurrent agents linking OCaml binaries
pushed the container to 5.6/7.75 GB and killed a 26y run **1h53m in**, with the
only evidence being a `<no result>` in the chain log.

This file is the scheduling discipline. It is the throughput counterpart to
`sweep-hygiene.md` (which says what not to do during a sweep) — this one says
what to *run* when, so the session neither idles nor thrashes.

## The three work classes

| class | container cost | can run concurrently? |
|---|---|---|
| **Backtest / sweep** — `scenario_runner`, `panel_runner`, tuner | **~2.2-2.4 GB** by `docker stats` for a 26y top-3000 run; 1 core per `--parallel` unit; hours | **One at a time.** Two 26y workers do not fit. |
| **Agent (QC / feat / harness)** — dune build + runtest in its own worktree | ~1-2 GB while linking, bursty, all cores; 5-8 GB disk per worktree | **Cap 3.** Each is a full OCaml link. |
| **Dispatcher-side work** — `gh`, `jj`, `git`, reading logs, writing docs/memory | ~0 | **Unlimited.** Always safe. |

The rule that follows from the table: **a long backtest and an agent wave are
mutually exclusive; dispatcher-side work is free and should fill every gap.**

## QC outranks backtests (user directive, 2026-08-18)

**An open PR waiting on QC is scheduled BEFORE any backtest.** When the two
compete for the container, QC wins — including killing or deferring a run
already in flight if that is what frees the machine.

Why this ordering, even though a backtest looks like the more productive use:

- A queued QC gate blocks a **merge**, which blocks every branch that would
  build on it. A deferred backtest blocks only itself.
- QC is **bounded** (minutes); a backtest is **unbounded** (hours). The
  backtest waiting on QC costs far less total latency than QC waiting on the
  backtest.
- Backtests are **relaunch-resumable** — the spec is committed and the run is
  reproducible. A PR sitting unreviewed is pure dead time, and it accumulates:
  `pr-gate-loop.md` opens with a session that found **eight** unreviewed PRs.

**Pre-flight, before launching anything long:**

```sh
sh dev/scripts/pr_gate_status.sh
```

If any PR reads `dispatch qc-structural` or `dispatch qc-behavioral`, run that
wave first. Do not start a multi-hour run "while QC is pending" on the grounds
that the container looks free — it is not free, it is committed.

Observed 2026-08-18: four CI-green PRs sat idle behind a tiebreak backtest that
was itself testing a baseline about to be retired. The backtest was killed, the
QC wave ran, all four merged, and nothing was lost — which is the general shape
of this trade. The wave also produced four corrections to the durable record
that CI could not have caught, including a README that would have sent the next
session on a 1.5-hour confounded run.

## Scheduling rules

0. **QC first.** See above — an open PR awaiting QC preempts any backtest, in
   flight or planned.
1. **Never dispatch agents while a multi-hour backtest is running.** Not "few
   agents" — none. A 26y run holds ~2.2-2.4 GB for hours; three linking agents
   spike past what remains. If a backtest is live and PR work is queued, either
   (a) let the backtest finish, or (b) decide the backtest is lower value, stop
   it *cleanly*, and record what was lost. Do not run both and hope.
2. **Cap concurrent agents at 3** when no backtest is running. Beyond that they
   contend on cores and on the dune lock, and per-agent wall time grows faster
   than throughput does — a 26y run slowed from 2h17m to 4h07m purely from
   agent contention on 2026-08-12.
3. **Batch by phase, not by PR.** Dispatch all the structural reviews together,
   collect, then all the behavioral ones. Mixed waves leave the container busy
   with a long tail while the dispatcher waits on one straggler.
4. **Fill agent-wait time with dispatcher-side work** — merges, memory updates,
   status/handoff docs, reading ledger entries, planning the next wave, writing
   specs for runs that will launch later. There is no reason to idle while
   agents run; there is every reason not to start a fourth agent.
5. **Check before launching anything long:**
   ```sh
   docker stats --no-stream --format 'mem={{.MemUsage}} cpu={{.CPUPerc}}' trading-1-dev
   ```
   A 26y run needs ≥4 GB headroom. If mem is above ~3.5 GB used, something else
   is live — find it before launching.
6. **Long runs go in a pinned worktree, detached, with a file log**
   (`sweep-hygiene.md`), so a dispatcher-side mistake cannot kill them and a
   session boundary cannot orphan them.

### ⚠ Measure with `docker stats`, not per-process RSS

Measured on the 2026-08-13 cell-09 run: `docker stats` sat at **2.2-2.4 GB** for
the whole leg, while a per-process peak-RSS sampler logged **10,460 MB** — which
is impossible as anonymous memory against a 7.75 GB container.

The gap is the **columnar mmap'd snapshot warehouse**
(`project_snapshot_format_v2`): mapped file pages count toward RSS but are
evictable, so RSS overstates the true footprint several-fold for anything that
opens the warehouse. Two operational consequences:

- An **RSS-based capacity guard would refuse to launch** on a container with
  plenty of room. Guard on `docker stats MemUsage`.
- An **RSS-based post-mortem would misattribute an OOM** — a 10 GB peak-RSS line
  in a log is not evidence the process was near the limit.

## Diagnosing an OOM kill (it does not announce itself)

Symptoms: scenario reports `FAIL (scenario crashed or did not write
actual.sexp)`; the runner's own log ends mid-stream with no exception; the chain
records `<no result>`. `dmesg` inside the container is typically empty (the kill
happens in the host VM's cgroup).

Confirm by reconstructing the load at the time — how many agents were building,
what `docker stats` showed. Absence of an error message is *evidence for* OOM,
not against it: a real crash leaves a stack trace, and a data error leaves a
`Sys_error`.

## Throughput self-check (run this at every natural pause)

> *Is the container idle right now? If yes — what long thing should be running?
> Is anything blocked only on a dispatcher-side action I could do in 30 seconds
> (a merge, a push, a bookmark move)? Am I about to start a 4th agent, or start
> agents on top of a backtest?*

Idle container plus a queue of long work is the throughput failure; agents-on-
backtest is the correctness failure. Both are caught by that one check.

# Next-session priorities — 2026-08-19 PM

**Supersedes** `next-session-priorities-2026-08-19-overnight.md`, which was
written before the cron merged #2384 and is historical from its "held in draft"
line onward.

## Start here

```sh
date '+%m-%d %H:%M'; git log --date=format:'%m-%d %H:%M' --pretty='%ad %h %s' -8 origin/main
sh dev/scripts/pr_gate_status.sh
```

`main` is clean: clock back to `0`, W1's RS gate landed, `do-not-merge` label
live. No open PRs except `test/entry-cap-axis` (spec only, no PR opened yet).

## The active queue — 4 items, one chain plus one independent

The **fill-model correctness chain**. Each unblocks the next; do not reorder.

| | task | state |
|---|---|---|
| **E1** #2404 | what should `entry_extension_max_pct` be | axis RAN, **result is biased — see below** |
| **E2** #2403 | re-pin 27 goldens to live config | unblocked on cost (2.0h), waiting on E1 |
| **E3** | flip `enable_sim_entry_stoplimit` default-on | user-directed; needs E1+E2 |
| **E4** #2407 | how much record return comes from broken-base fills | **independent, high value, ready** |

Plus **P2** (#13 in the task list): live picks skip the 15% stop-width gate —
**a user decision**, questions already in the published report.

### E1 — read this before trusting the number

The axis ran (16 folds × {1,2,5,10,15}). `1.0` dominates every metric and wins
Calmar 13/16, MaxDD 15/16. Live's `15.0` is the **worst** tested value.

**But the folds are ONE YEAR and that biases the result toward tight caps.** A
tighter cap causes more **no-fills**; when a stock gaps past the limit you forgo
its *entire* run — and a 1-year fold truncates that run, so the miss is
understated while the avoided-chase benefit is fully counted. The strongest
signal in the table being **MaxDD** is consistent with "takes fewer positions",
not with "picks better".

Next step is **longer folds (3y/5y)** plus per-arm **trade counts** and **max
single-trade P&L**, then the confirmation grid. **Do not move a default or
re-pin to 1.0 on this.** Current honest state: 15.0 looks poorly supported, 2.0
is defensible, 1.0 is promising on a measurement whose horizon flatters it.

⚠ The committed spec header
(`trading/test_data/walk_forward/entry-extension-cap-tight-2010-2026.sexp`)
predicts the **opposite** of what happened ("expect lower return"). Fix it so a
wrong expectation does not sit beside a right measurement.

## Backlog (issues filed, deliberately out of the active list)

- **#2408** S1 — stop-anchor surface. Cheap, zero new code, but a *return* lever
  behind a *correctness* chain.
- **#2409** D2 — archetype taxonomy. Blocked on D1b→#2380; premise weakened by
  selection-is-closed + `rs_value` R²=0.00000 + the fat-tail law.
- **#2410** F2 — cancel decomposition. **Moot at defaults** (both cancel
  mechanisms off) and largely answered by the rest-time table. Close unless a
  run arms them.
- **D1b** — recorded on **#2380**, which is the blocker.
- **KILLED: D3 tiebreak.** Already settled — the 2026-06-29/30 breadth grids
  REJECT a backtest default-flip; Quality is armed for live picks only.

## What this session settled

| | |
|---|---|
| **Stale-order fills are NOT an edge** | rest >26wk = 7.8% of fills, **−15.1% of P&L** (−3,923/trade vs +2,518). Net-losing but tail-heavy — which is why one 5y cell showed −40.91pp for cutting them. `project_stale_order_fills_are_not_an_edge`. |
| **The clock (26w) is probably RIGHT** | My overnight "do not promote" verdict is **superseded**. #2397's revert was procedurally correct (don't ship a measured golden regression silently) but the mechanism has the larger sample behind it. Re-flip framed in **#2405**. |
| **Age is the wrong discriminator** | A base can legitimately take months. Clock cuts on age, re-screen on stage-flicker (−137pp), neither on **whether the base held** — the untested third option, **#2407**. |
| **H1 resolved** | `--parallel 3` = **2.58×** (86% eff). Golden re-pin **5.3h → 2.0h**. Five hypotheses died, two mine. Caveat: memory binds the heavy specs — `goldens-broad` OOM'd even at `--parallel 1` (`SNAPSHOT_CACHE_MB` unset ⇒ 4096 MB/child vs 7.75 GB). |
| **`do-not-merge` label** | #2402. Draft status does **not** hold a PR — the cron merged #2384 30 min after I drafted it under an explicit hold. |
| **entry cap divergence** | 82 specs at `2.0`, live at `15.0`, neither derived. **Not** a conflation — same rule (StopLimit limit price) both sides; my "delete the market re-anchor" proposal was withdrawn after reading `entry_reconciliation.mli` (it would reintroduce #2103's 14×-understated risk). |

## Process notes that cost real time

- **`jj new <rev>` discards uncommitted working-copy files.** Lost the axis spec
  this way; recreate-and-commit *before* launching anything that reads it.
- **Append-only logs make `grep` match history.** A monitor matched a stale
  `rc=2` from a prior run and reported a live job as finished. Watermark with
  `tail -n +N`.
- **`dune runtest` serves cache** — `--force` or a mutation silently "passes".
- **`pkill -f` can match nothing and look successful.** Kill by PID; remove
  **both** `_build/.lock` and `_build/.db`.
- **QC agents still build the parent tree** (#2386, second instance) and can
  leave a wedged build that outlives them and blocks the container.
- **`universe.txt` is traded symbols, not `universe_size`.** Same spec names
  exist in `goldens-small` (302) and `goldens-broad` (1000) — always name the
  directory in a cross-run comparison.

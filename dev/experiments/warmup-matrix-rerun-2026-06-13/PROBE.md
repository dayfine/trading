# Warmup-flip probe + matrix re-run (2026-06-13 PM)

**Context:** `suppress_warmup_trading` default was flipped `false → true` (#1566,
correctness invariant — "a 210-day backtest has 210 days of trades, not 420").
PM priorities P1 asks to re-measure the WF-CV / rolling-start matrices under the
new default, because the prior matrices (`project_rolling_start_matrix_first_run`)
were measured under the old (warmup-trades-ON) semantics.

## Why a probe first (don't launch 10h blind)

Open question before committing to a ~10h matrix re-run: **does the flip actually
change the rolling-start matrix?**

- The warmup-comparison experiment (2026-06-12) found scenario-level off/on
  **bit-identical** for *standalone* cells and concluded "scenario-level off/on is
  MOOT" — because a standalone scenario's `warmup_start` is the simulator's first
  day (cold; warmup = indicator formation, nothing survives into the window).
- **But the rolling-start matrix is different.** `Backtest.Runner.run_backtest`
  runs the simulator from `warmup_start = start_date − 210d`, and the matrix feeds
  it the `snap_top3000_2011` warehouse whose floor is **2010-06-07**. So for any
  **interior** start (2013, 2015, 2017…) the 210-day warmup sits in the *middle*
  of available data with **fully-formed indicators** → the strategy actively trades
  during warmup → the flip bites. (Only the earliest 2011 start is cold-equivalent,
  warmup_start 2010-06 ≈ warehouse floor.)

The "moot" memory therefore applies only to the earliest cold start; interior
starts are warm, exactly like WF folds.

## Probe (decisive)

One interior start, top-1000-2011 (speed), warm warmup, off vs on, 2.5y window:

| arm | Return | Trades | WinRate | MaxDD | Sharpe | AvgHold |
|---|---|---|---|---|---|---|
| **OFF** (warmup-trades, old default) | **24.90%** | 109 | 25.69% | 14.87% | 0.473 | 40.1d |
| **ON** (suppress, new default) | **12.61%** | 109 | 29.36% | 11.45% | 0.411 | 46.2d |

Spec: `period 2015-07-01..2017-12-31`, warmup_start 2014-12-03 (interior, warm),
Cell-E config (0.14/0.70/0.30, force-exit h=1, laggard h=2), 5bps spread,
snapshot `snap_top3000_2011`.

**Verdict: off ≠ on, materially (~2× return).** The flip DOES change interior
rolling-start numbers → the matrix re-run is justified, and the prior matrix
(`project_rolling_start_matrix_first_run`) numbers are **stale-semantics**
(measured warmup-trades-ON; the new default is OFF/suppress).

Signature is the **running start** (`project_warmup_trading_running_start`):
warmup-trades-ON inherits a bull portfolio built across 2014-12→2015-07, lifting
return + DD; suppress-ON starts from cash → lower return, lower DD, slightly
higher win-rate. Consistent with "warmup trading is a net-beneficial running
start in bull windows" — which is exactly the contamination the correctness flip
removes from the measured window.

## Matrix re-run (in flight at writeup time)

Launched `rolling_start_eval` on `cell-e-top3000-2011-15y` (the faithful match to
the stale matrix) under the new default (suppress=ON):

```
--scenario /tmp/cell-e-top3000-2011-15y.sexp --stride-days 170 --jitter-seed 42
--benchmark GSPC.INDX --snapshot-dir /tmp/snap_top3000_2011 --min-window-days 330
--parallel 1 --out /tmp/warmup-rerun/matrix-t3k-2011-ON.md
```

Output (container): `/tmp/warmup-rerun/matrix-t3k-2011-ON.md` + run.log. ~10h
serial (parallel=1 for top-3000 memory safety). Compare the new ON distribution
against the stale OFF headline (median edge ≈ +3.2pp/yr, 57% beat, worst −28pp)
when complete.

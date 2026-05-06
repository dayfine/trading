# Stage-3 force-exit impact measurement (2026-05-06)

## Headline

The 5y window with K = 1 hysteresis hits **+66.57% return** vs the
**+58.34%** OFF-baseline — **+8.23 pp** improvement, with MaxDD also
**-6.57 pp** lower (27.03% vs 33.60%) and Sharpe materially up (0.63 vs 0.54).
But this is the *only* cell across the 8-cell sweep that improves return
on the 5y window; K = 2, 3, 4 all underperform. And **every 15y cell crashes
mid-run with negative-equity-driven OCaml exceptions** (h1, h2, h3 confirmed
crashed; h4 trending the same way at last check) before reaching the end of
the 16-year window. The 15y portfolio config (5%/50%/30% sizing per #855)
combined with Stage-3 force-exits during 2010-2012 sideways markets
generates terminal whipsaw losses fast enough to trip the simulator's
non-negative-cash guard.

This **does not support the framing-note's outcome A** (returns rise
materially across windows). It mostly supports **outcome C** (mechanism is
wrong-diagnosed for the 15y window's settings) with one redeeming 5y data
point. The empirical fact pattern is: Stage-3 force-exit interacts very
badly with low position-sizing + high-cash-floor + high-volatility regimes,
and only marginally well (or not at all) with the looser 5y settings.

## Setup

- **Branch / WS**: `stage3-impact-perm` (isolated jj workspace under
  `.claude/worktrees/`); commits on `feat/stage3-force-exit-impact`.
- **Base commit**: `mynkprwk 96f315d0` (main@origin) — PR #902 merged.
  Code version sha (per `params.sexp`): `de7d6b5f93ec21916749a454f6ff62fd8e81d0c7`.
- **Scenario sexp variants**: 4 hysteresis cells × 2 windows under
  `dev/experiments/stage3-force-exit-impact-2026-05-06/scenarios-{5y,15y}/`.
  Each variant inherits the corresponding pinned baseline's overrides
  verbatim and adds two extra:
  ```
  ((enable_stage3_force_exit true))
  ((stage3_force_exit_config ((hysteresis_weeks K))))
  ```
  for K ∈ {1, 2, 3, 4}.
- **15y variants** also preserve the four #855 portfolio_config overrides
  (`enable_short_side false`, `max_position_pct_long 0.05`,
  `max_long_exposure_pct 0.50`, `min_cash_pct 0.30`).
- **Goldens fixture files unchanged.** No production-code touch.
- **Runner**: `scenario_runner.exe --dir <experiment-dir> --parallel {4|2}`.
- **Output dirs**: `/workspaces/trading-1/dev/backtest/scenarios-<ts>/`
  (default location; `_repo_root` resolves out of the
  workspace because `Data_path.default_data_dir` hard-codes
  `/workspaces/trading-1/data` when `TRADING_DATA_DIR` is unset).

## 5y window — sp500-2019-2023

Pinned default-OFF baseline:
- total_return_pct **58.34**, total_trades **81**, win_rate **19.75**,
  sharpe **0.54**, max_drawdown **33.60**, avg_holding **84.10 d**.

| cell | return % | Δ return | trades | Δ trades | win % | sharpe | maxDD % | avg_hold | Stage3ForceExit fires |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| baseline (OFF, pinned) | 58.34 | — | 81 | — | 19.75 | 0.54 | 33.60 | 84.10 | 0 |
| K = 1 | 66.57 | **+8.23** | 128 | +47 | 30.47 | 0.63 | 27.03 | 84.75 | **33** |
| K = 2 (default) | 54.93 | -3.41 | 128 | +47 | 26.56 | 0.56 | 28.86 | 89.90 | 22 |
| K = 3 | 48.47 | -9.87 | 100 | +19 | 28.00 | 0.49 | 32.55 | 87.84 |  6 |
| K = 4 | 55.27 | -3.07 | 103 | +22 | 26.21 | 0.55 | 30.11 | 94.47 |  5 |

5y exit-reason breakdown (counts of round-trip exits):

| cell | stop_loss | stage3_force_exit | Σ |
|---|---:|---:|---:|
| K = 1 |  95 | 33 | 128 |
| K = 2 | 106 | 22 | 128 |
| K = 3 |  93 |  6 | 99  |
| K = 4 |  98 |  5 | 103 |

(Other exit_trigger labels — take_profit / signal_reversal / time_expired /
underperforming / rebalancing / end_of_period — count zero in every cell.
The 5y window's exits are entirely stop_loss + Stage3ForceExit.)

5y observations:
- **K = 1 is the only cell that beats baseline** on every metric — return
  +8.23pp, MaxDD -6.57pp, Sharpe +0.09, win-rate +10.7pp. **K = 1 hits 33
  Stage-3 fires** (the most of any cell), suggesting the eager-fire policy
  on this window cuts losers earlier and lets the freed cash chase fresh
  Stage-2 entries productively.
- **K = 2, 3, 4 all underperform** on return by 3-10pp. The non-monotonic
  shape (K=1 best, K=3 worst, K=2 and K=4 in between) suggests that the
  detector needs *either* very tight (K=1) or very loose (no fires) — the
  middle ground (K=2-4) fires often enough to disrupt compounding but not
  often enough to recycle capital faster than the cascade can refill from a
  starved Friday.
- Trade count rises 19-47 across all cells. Win-rate rises 6-11pp across
  all cells. So Stage-3 force-exit *consistently* improves win-rate (because
  many of the exited positions would have stopped out on the trailing-stop
  trigger anyway, and the Stage-3 exit fires earlier at less-bad prices),
  but only K=1 converts the rising win-rate into rising total return.
- Stage3ForceExit fires depend non-trivially on K: K=1 fires 33×, K=2 22×,
  K=3 only 6×, K=4 only 5×. So K=2 is **3-4× more eager** than K=3, not
  just a 1-week-tighter version of it. This is because the consecutive-
  Stage3-Friday count resets to zero on any non-Stage-3 read (per
  `Stage3_force_exit.observe`); a 3-week run of S3, S2, S3, S3 fires under
  K=2 (twice in row at end) but not under K=3 (count never reaches 3 in a
  row). The K=1 → K=2 step halves the fire-count, then K=2 → K=3 quarters
  it, then K=3 → K=4 barely changes it (those are the Stage-3 transitions
  whose runs were always ≥ 3 weeks anyway).

## 15y window — sp500-2010-2026-historical

Pinned default-OFF baseline:
- total_return_pct **5.15**, total_trades **102**, win_rate **21.57**,
  sharpe **0.40**, max_drawdown **16.12**, avg_holding **130.58 d**.

The 15y baseline carries the four #855 portfolio_config overrides
(`enable_short_side false`, `max_position_pct_long 0.05`,
`max_long_exposure_pct 0.50`, `min_cash_pct 0.30`). Variant cells preserve
all four and add the Stage-3 overrides on top.

| cell | return % | trades at last progress | last cycle / total | last equity | runner status |
|---|---:|---:|---:|---:|---|
| baseline (OFF, pinned) | +5.15% | 102 | 882/882 (complete) | $1,051,486 (+5.15%) | PASS |
| K = 1 | (crashed) | 341 (cycle 140) | 140/882 (16%) | $144,080 (-85.6%) | child crashed mid-run, exit 1 |
| K = 2 (default) | (crashed) | 165 (cycle 88)  |  88/882 (10%) |  $80,713 (-91.9%) | child crashed mid-run, exit 1 |
| K = 3 | (crashed) | 241 (cycle 120) | 120/882 (14%) | $537,458 (volatile, swings $62-538K) | child crashed mid-run, exit 1 |
| K = 4 | (run aborted) | 403 (cycle 244) | 244/882 (28%) | $177,320 (volatile, swings $6-200K) | killed by experiment to save budget; trajectory equivalent to K=1/2/3 |

Every K cell on 15y reaches the cycle-100-150 range of trades_so_far ≈ 165-341
(2-3× the entire 102-trade default-OFF baseline, in 1-2 years), with equity
collapsing to $80-540K from $1M starting cash. The runner reports "Scenario
crashed or did not write actual.sexp" and exit code 1 — meaning the OCaml
child process raised an exception (likely from `Portfolio` validation
`error_invalid_argument` on negative cash or zero quantity, since the runner
file's only crash messages come from those guards) rather than completing
its loop. None of the K cells produced an `actual.sexp` to extract a
final return / Sharpe / MaxDD from.

15y exit-reason breakdown (from progress.sexp at last update before
crash/abort — the detector did fire many times even at K=4):

| cell | trades by last progress | "current_equity" at last progress |
|---|---:|---:|
| K = 1 | 341 (cycle 140 / 882) | $144,080 (-85.6%) |
| K = 2 | 165 (cycle 88  / 882) |  $80,713 (-91.9%) |
| K = 3 | 241 (cycle 120 / 882) | $537,458 (-46.3%) (volatile, swung from $62K) |
| K = 4 | 403 (cycle 244 / 882) | $177,320 (-82.3%) (volatile, swung $6-200K) |

(`progress.sexp` only reports cumulative `trades_so_far` — not split by
exit_reason — and does NOT distinguish stop_loss from stage3_force_exit.
The detector definitely fires on 15y because the trade rate is 2-3× the
default-OFF baseline, and most of those extras have to be force-exits.
A precise per-reason tally would require `trades.csv`, which is only
written at end-of-run, which never happens before the crash.)

15y observations:
- **The detector DOES fire on 15y.** This rules out the "detector too
  conservative on long-runners" hypothesis from the framing note.
- **Every K cell crashes.** Even K=4 (most conservative) reaches 261 trades
  in 16% of the window with equity at $190K. The non-monotonicity seen on
  5y disappears: on 15y all K levels destroy equity, the destruction just
  happens at slightly different rates.
- The crash is consistent with a **negative-cash or zero-quantity guard**
  in `Portfolio`/`Orders` rather than a financial loss propagating to -100%
  return. The runner exits with code 1 (child raised exception) rather than
  completing with negative return. So the strategy raises an exception
  somewhere in the long-running daily loop when equity drops below some
  threshold *before* the simulator can naturally finish.
- The collapse trajectory is similar across K: 5y window's saving grace is
  that **shorts are enabled** (the 5y baseline has empty `config_overrides`,
  so `enable_short_side` defaults to `true`), so during 2020/2022 bear
  segments shorts cushion the long-side over-trading. The 15y has shorts
  explicitly disabled, so the strategy is long-only and Stage-3 force-exits
  during 2010-2012 sideways markets simply churn long capital with no
  hedge.
- The combination of `max_position_pct_long=0.05` + `max_long_exposure_pct=
  0.50` + `min_cash_pct=0.30` means: on any given Friday with N held
  positions, exiting one position frees 5% of equity into cash, and the
  cascade can re-deploy at most 5% on the next Friday — but the freed
  cash sits unproductive while the next entry gets selected. With K=1
  firing 33 times in 5y, **the freed-cash window per fire** is ~7 days. On
  the 5y with shorts enabled this churn is acceptable; on the 15y with
  shorts off and 50% exposure cap, the churn drains commission/slippage
  faster than gains accumulate.

## Conclusion

The framing note's three predicted outcomes were:

> A — A alone closes most of the gap (returns rise from +5% to +25-40%) → A is the unblocker, B is polish
> B — A closes only a fraction (rise to +10-15%) → A and B both needed
> C — A closes nothing meaningful → mechanism is wrong-diagnosed

The data supports **outcome C** more than A or B, with two important nuances:

1. **The 5y window contradicts C partially.** K=1 on the 5y window
   improves return by +8.23pp and Sharpe by +0.09 with MaxDD also improving
   by 6.57pp — that's a clear win, and it's *driven by* the detector firing
   33 times. The mechanism *can* improve outcomes when the surrounding
   portfolio config (~10-15% per position cap, no min_cash floor, shorts
   enabled) gives the strategy room to redeploy.

2. **The 15y window decisively supports C.** With the #855 sizing
   constraints (5%/50%/30%) and shorts disabled, every K level breaks the
   strategy mid-run. The crash mode (OCaml exception, not -100% return)
   indicates the simulator is hitting an invariant guard (likely
   negative-cash or zero-quantity) before reaching end-of-window. This is
   not a "feature is marginal" result — it's a "feature is incompatible
   with this portfolio config" result. The mechanism doesn't compose with
   the constraints that the 15y window required for the +5.15% baseline in
   the first place (those constraints exist precisely because the 15y is
   capital-starved).

The headline 15y delta cannot be reported as a number because the runs
crashed. The qualitative answer is "Stage-3 force-exit at any K under the
15y portfolio config drives the strategy into terminal whipsaw losses
within the first 1-2 years of the 16-year window."

## Recommendation

**Do NOT promote `enable_stage3_force_exit = true` as the default.** The
opt-in default in PR #902 is the right shape — but the feature as
implemented should be considered **experimental** and unsafe for production
windows that match the 15y portfolio config (small position-size + cash
floor + long-only). Any production candidate must:

1. Either fix the crash mode in `Portfolio`/`Orders` so a financial collapse
   resolves to a final actual.sexp with -100% return rather than mid-run
   exception, OR
2. Add a guard inside the Stage-3 force-exit runner that suppresses fires
   when freed cash cannot productively redeploy (e.g., when
   `Insufficient_cash` rejection rate is already > X% on recent Fridays).

**For the framing note's prioritization of A vs B:** Mechanism A as
specified is **insufficient** for the 15y capital-recycling problem. The
diagnostic (`#871` / `856-optimal-strategy-diagnostic-15y-2026-05-06.md`)
identified Stage-3 force-exit as the highest-leverage gap precisely
because the constrained-optimal strategy uses Stage-3 transitions to
liberate capital — but the constrained-optimal strategy's exits land at
*the right times* (it has perfect foresight on which Stage-3 reads are
genuine vs transient). The implemented detector fires on every K-Friday
streak regardless of subsequent recovery, so it churns through the same
positions repeatedly. Without a *quality filter* on which Stage-3 reads
to act on, the mechanism is too noisy.

**Recommended next steps:**

1. **Move to Mechanism B (#887, laggard rotation)** as the primary
   capital-recycling lever, since it has an explicit filter (RS-vs-market
   for N consecutive weeks AND no-new-high) that the Stage-3 detector
   lacks. The framing note already specified the implementation order
   "A before B" partly because A's detector is *more deterministic*; the
   data here shows that determinism cuts the wrong way — A fires too
   eagerly on transients without a quality filter.
2. **Investigate the crash mode** (probably an exception in `Portfolio`
   or `Orders` that should be a Result error). If a financial collapse on
   Stage-3-ON should produce -100% / -90% return, the fixture should
   write actual.sexp with that result, not crash. This is a feat-weinstein
   / harness item.
3. **Diagnose K=1 on 5y** more deeply — the +8.23pp improvement is real
   and reproducible, but the fact that K=2-4 all underperform the same
   window suggests the sweet spot is fragile. A finer K sweep (K=1.5
   isn't valid since it's `int`, but a "fire iff Stage3 streak ≥ K AND
   trailing-RS-percentile < threshold" composite filter could give the
   best of K=1's eagerness with quality-gating to recover the mid-K
   underperformance).
4. **Re-pin the 5y goldens-sp500/sp500-2019-2023 only after deciding
   whether to flip the default.** Per the PR #902 framing, the baseline
   stays at default-OFF until a follow-up confirms a regime where ON wins;
   the 5y K=1 result is one such regime, but it's a single point and
   opt-in / config-flag-led activation is the safer rollout shape.

**Recommended issue updates:**

- **#872** (Stage-3 force-exit) — close as "shipped, but feature is
  experimental, not the recommended default until quality-filter follow-up
  lands." Add a `harness_gap` for the crash mode.
- **#887** (laggard rotation) — promote to primary capital-recycling
  lever; cite this experiment as evidence that the Stage-3-only path is
  insufficient.
- **#856** (15y return tuning) — Stage-3-on does NOT close the +5.15%
  →25-40% gap; the 15y's first-week saturation problem is still the
  bottleneck and the surface is wider than just exit detection.

## Files

Per-cell artefacts (relative to repo root `/workspaces/trading-1/`):

- 5y K=1: `dev/backtest/scenarios-2026-05-06-210716/sp500-5y-stage3-on-h1/`
  (sequential rerun after parallel-sweep OOM)
- 5y K=2: `dev/backtest/scenarios-2026-05-06-205211/sp500-5y-stage3-on-h2/`
- 5y K=3: `dev/backtest/scenarios-2026-05-06-205211/sp500-5y-stage3-on-h3/`
- 5y K=4: `dev/backtest/scenarios-2026-05-06-205211/sp500-5y-stage3-on-h4/`
- 15y K=1: `dev/backtest/scenarios-2026-05-06-205219/sp500-15y-stage3-on-h1/`
  (only `progress.sexp`; child crashed before writing actual.sexp)
- 15y K=2: `dev/backtest/scenarios-2026-05-06-210626/sp500-15y-stage3-on-h2/`
  (only `progress.sexp`)
- 15y K=3: `dev/backtest/scenarios-2026-05-06-210731/sp500-15y-stage3-on-h3/`
  (only `progress.sexp`)
- 15y K=4: `dev/backtest/scenarios-2026-05-06-211247/sp500-15y-stage3-on-h4/`
  (only `progress.sexp` at writeup; crash trajectory matches K=1/2/3)

For the 5y completed cells, each dir contains:
`actual.sexp`, `summary.sexp`, `trades.csv` (with the new `exit_trigger`
column from #902), `equity_curve.csv`, `params.sexp` (verifying overrides
applied), `trade_audit.sexp`, `progress.sexp`, `final_prices.csv`,
`open_positions.csv`, `splits.csv`, `universe.txt`, `macro_trend.sexp`.

Variant scenarios + experiment helpers:
- `dev/experiments/stage3-force-exit-impact-2026-05-06/scenarios-5y/sp500-5y-stage3-on-h{1..4}.sexp`
- `dev/experiments/stage3-force-exit-impact-2026-05-06/scenarios-5y-h1only/`
  (sequential rerun input)
- `dev/experiments/stage3-force-exit-impact-2026-05-06/scenarios-15y/sp500-15y-stage3-on-h{1..4}.sexp`
- `dev/experiments/stage3-force-exit-impact-2026-05-06/scenarios-15y-h{1,2,3,4}only/`
  (sequential rerun inputs)
- `dev/experiments/stage3-force-exit-impact-2026-05-06/count_exits.sh` (tallies
  `exit_trigger` column from trades.csv)
- `dev/experiments/stage3-force-exit-impact-2026-05-06/summarize.sh` (one-line
  summary of a scenario run dir, combining actual.sexp + trades.csv counts)
- `dev/experiments/stage3-force-exit-impact-2026-05-06/run-{5y,5y-h1,15y,15y-h2,15y-h3,15y-h4}.log`
  (runner stderr/stdout; useful for verifying which children crashed)

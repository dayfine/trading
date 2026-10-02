# 26y investor preset — salts 0 / 1 / 2 (QUEUE item 4 completed)

Chain L3, 2026-10-01 11:39 → 21:27 PT, one build: pinned worktree `sweep-investor26` at main
6d84ff1c3. Spec `specs/inv26sc-investor.sexp` (unchanged), window 2000-01-01 → 2026-06-26, PIT
top-3000 schedule, `_v11pit` warehouse, cap 12,000. Artifacts:
`results/inv26sc-investor-s{1,2}-v11-*`, `results/s0-rerun-6d84ff1c3/` (s0 on this build),
`results/chain-L3.log`, `results/launch-L3.sh`. s0's committed artifacts (`results/inv26sc-investor-s0-v11-*`)
are from the 09-30 build 650b18e2a (#3048).

Descriptive record, single arm (no paired lever). V6 on every cell: `V6 INVARIANT PASS` with the
share-class map loaded (`chain-L3.log`).

## 0. Same-build check

s0 re-run on 6d84ff1c3: `actual.sexp` byte-identical to #3048's, `equity_curve.csv`
byte-identical, `trades.csv` byte-identical (`position_id` included). So s1/s2 (this
build) and the committed s0 (650b18e2a) are directly comparable.

## 1. Headline

From `results/inv26sc-investor-s<N>-v11-actual.sexp` and the equity curves:

| | return | CAGR | max DD | Calmar | Sharpe | trades | win rate |
|---|---:|---:|---:|---:|---:|---:|---:|
| s0 | +623.6 % | 7.76 % | 31.1 % | 0.250 | 0.60 | 506 | 42 % |
| s1 | +401.3 % | 6.27 % | 31.0 % | 0.202 | 0.51 | 520 | 43 % |
| s2 | +621.3 % | 7.74 % | 31.0 % | 0.250 | 0.60 | 510 | 43 % |
| SPY (adjusted close, same dates) | | 8.13 % | 55.2 % | 0.147 | | | |

- **Drawdown is salt-stable** (31.0–31.1 %) and **Calmar beats SPY at every salt** (0.20–0.25 vs 0.15).
- **Return trails SPY at every salt**: CAGR 0.4–1.9 pp below.

## 2. Why s1 differs — one trade

Join on (symbol, entry_date) against s0 (`results/inv26sc-investor-s0-v11-trades.csv`):

| | shared | shared P&L (s0 / other) | s0-only | other-only |
|---|---|---|---|---|
| s1 vs s0 | 483 | $3.10M / $3.18M | 23, +$1.90M | 37, ~$0 |
| s2 vs s0 | 498 | $5.31M / $5.31M | 8, −$0.30M | 12, −$0.17M |

s1 never takes **ADMA** (s0/s2: entry 2023-12-19, exit 2024-12-23, +300 %, +$1.60–1.61M) and
AVGO 2013 (+$0.48M). Annual returns of the three salts agree within 0.7 pp in every year through 2012; s1 diverges from 2013 on: 2013 (+22.5 vs +32.0 %), 2014 (+12.6 vs +19.2 %), 2015 (−3.2 vs +0.7 %) and 2024 (+26.4 vs +51.7 %). Same shape as the 5y
read (#3036): the **level is a path lottery on one or two fat-tail trades; the structure is not**.

## 3. Why it trails SPY — cash, not selection

**Average exposure is 42 %** at every salt (open-position entry notional ÷ equity, daily, from
`trades.csv` + `equity_curve.csv`: 41.9 / 42.3 / 41.9 %).

Year by year vs SPY (adjusted close), s0:

| year | SPY | s0 | Δ | exposure |
|---|---:|---:|---:|---:|
| 2000 | −9.7 | +15.3 | +25.0 | 44 % |
| 2002 | −21.6 | −0.9 | +20.7 | 1 % |
| 2008 | −36.8 | +0.8 | +37.6 | 4 % |
| 2009 | +26.4 | +2.4 | −24.0 | 12 % |
| 2016 | +12.0 | +1.3 | −10.7 | 17 % |
| 2019 | +31.2 | +5.7 | −25.5 | 41 % |
| 2021 | +28.7 | +14.1 | −14.6 | 51 % |
| 2023 | +26.2 | +4.9 | −21.3 | 43 % |
| 2024 | +24.9 | +51.7 | +26.8 | 59 % |
| 2025 | +17.7 | −15.4 | −33.1 | 40 % |

s0 beats SPY in 11 of 27 calendar years (s1 9, s2 11). The Calmar edge is **sitting out the
bears** (2000–02, 2008: exposure 1–44 %); the return gap is **missing the first leg of every
recovery** (2009, 2019, 2023: 12–43 % exposure while SPY made 26–31 %) — the macro gate and Stage-2
confirmation keep the book out until the V is mostly done (`project_melt_up_lag_anatomy`).

**2025 (−15.4 % vs SPY +17.7 %).** Equity peaked for 2025 at $8.51M on 2025-01-06 (all-time peak $8.93M on 2024-11-26) and ended at $6.94M.
Closed 2025 trades net +$0.16M only because MMYT's +$1.11M (entry 2023-10-26, exit 2025-02-24 on
laggard rotation) is realized there; its gain was marked mostly in 2024. Without it the year's
closed trades lose ~$0.94M, mainly stop-outs (AD −29.4 %, TNXP −25.1 %, MNSO −17.0 %, SKYT −14.8 %).

## 4. Exits and stops — identical structure at every salt

| salt | laggard_rotation | stop_loss | stop_loss gap_down / intraday | win rate by initial stop width (<8 / 8–12 / 12–16 %) |
|---|---|---|---|---|
| s0 | 254, +$12.2M | 246, −$7.5M | 203 (−$6.03M) / 43 (−$1.47M) | 29 / 40 / 50 % |
| s1 | 265, +$9.6M | 249, −$6.7M | 207 (−$5.57M) / 42 (−$1.15M) | 29 / 41 / 51 % |
| s2 | 261, +$12.1M | 243, −$7.3M | 200 (−$5.94M) / 43 (−$1.38M) | 30 / 41 / 50 % |

**Correction (10-01, after #3068 merged):** an earlier version of this paragraph read the
`gap_down` label as "stops fill at the next open (#2961)". That is wrong for these runs: every
salt's `params.sexp` sets `sim_stop_exit_fill_on_trigger_bar true` (#2967, the #2961 fix), so stops
fill on the trigger bar at the resting level, or at the open when the bar opens below it. Measured
fill vs the stop level (`(exit_stop − exit_price) / exit_stop`, `stop_loss` rows of each
`trades.csv`):

| salt | within 1 % of stop | 1–5 % below | > 5 % below (real overnight gaps) |
|---|---|---|---|
| s0 | 202 (−$5.48M) | 32 (−$0.96M) | 12 (−$1.07M) |
| s1 | 204 (−$4.76M) | 32 (−$1.08M) | 13 (−$0.87M) |
| s2 | 199 (−$4.97M) | 32 (−$1.29M) | 12 (−$1.06M) |

So ~82 % of stop exits fill within 1 % of the stop; the `gap_down` label mostly marks fills a few
cents below it, not true gaps. Gap slippage is bounded at ~12–13 exits / ~$1M per salt. Resting
fills are already on; #2961 is not a lever for this preset. 19 s0 stop exits filled > 3 pp worse
than their initial stop distance (−$1.65M).

## 5. What this says

- The investor preset is **a drawdown-control strategy that roughly matches SPY's return only
  when it catches a fat-tail winner**. Its robust properties (DD ~31 %, Calmar > SPY, 42–43 % win
  rate, exit mix) hold at all three salts; its level does not.
- The gap to SPY is **idle capital + late re-entry**, not trade selection: CAGR ≈ SPY's on ~42 %
  average deployment.
- Not supported by this record: bigger tickets / deployment ramps (rejected 09-14,
  `project_concentration_deploy_probe_reject`: fewer names miss the recovery monsters).
- Already answered on the broad universe (corrected 10-01 — an earlier version proposed re-testing
  the 06-20 sp500 barbell): the 06-27 floor sweep (`_ledger/2026-06-27-barbell-floor-sweep.sexp`,
  broad top-3000, hybrid engine) found the **SPY 30-week timing floor** is no free lunch (Sharpe and
  Calmar flat across weights; its cash-in-bear duplicates the engine's own bear defense). The
  **buy-hold SPY sleeve** was the positive variant, and the user declined it 06-27 on
  Weinstein-faithfulness grounds (a passive index allocation is portfolio construction, not stock
  selection). An idle-cash sleeve is that same passive allocation, so it needs a new user decision,
  not a test. #2961 resting-stop fills, also listed here before the correction above, is already
  on in these runs.

No ledger entry: descriptive, no lever, no promotion.

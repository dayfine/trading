# Goldens performance baselines — small + sp500 (2026-04-28)

Level-set on what each non-broad golden actually produces today, ahead of
the trade-audit work (`dev/plans/trade-audit-2026-04-28.md`). The
sp500-2019-2023 baseline note (`sp500-golden-baseline-2026-04-26.md`)
covered one cell with tight ranges; the other 4 cells (3 small + sp500
re-run) had wide expected ranges but no documented "what actually
happens" snapshot. This note fills that gap and adds buy-and-hold
context for each window.

## Setup

- Build: post-#636 main (`565365fb`).
- Initial cash: $1M, no `config_overrides` on any cell.
- `OCAMLRUNPARAM=o=60,s=512k`; `trading-1-dev` container.
- `scenario_runner.exe --fixtures-root .../trading/test_data/backtest_scenarios`.
- Buy-and-hold: GSPC.INDX (S&P 500 cash index) `adjusted_close` from
  `data/G/X/GSPC.INDX/data.csv`, first/last trading day in window.
- Run dirs:
  `dev/backtest/scenarios-2026-04-28-034425/{bull-crash-2015-2020,covid-recovery-2020-2024,six-year-2018-2023}/`,
  `dev/backtest/scenarios-2026-04-28-034706/sp500-2019-2023/`.

## Strategy vs buy-and-hold

| Scenario | Window | Years | Strategy return | Strategy CAGR | B&H return | B&H CAGR | Strategy MaxDD | B&H MaxDD |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| bull-crash-2015-2020 | 2015-01..2020-12 | 6.0 | +80.3% | 9.4% | +82.5% | 10.6% | 36.2% | 33.9% |
| covid-recovery-2020-2024 | 2020-01..2024-12 | 5.0 | +30.9% | 5.0% | +80.5% | 12.5% | 34.7% | 33.9% |
| six-year-2018-2023 | 2018-01..2023-12 | 6.0 | +69.2% | 8.3% | +76.9% | 10.0% | 25.3% | 33.9% |
| sp500-2019-2023 | 2019-01..2023-12 | 5.0 | +70.8% | 10.1% | +90.0% | 13.7% | **97.7%** | 33.9% |

**Strategy underperforms buy-and-hold on 4/4 windows.** Closest: bull-crash
(−2.2 pp). Worst: covid-recovery (−49.6 pp). Strategy's only "win" is
six-year MaxDD (25.3% vs B&H 33.9%) — went partially-cash through
COVID; otherwise drawdowns are equal-or-worse.

## Trading metrics (current run)

| Scenario | Trips | Wins | Losses | Win % | Sharpe | Profit factor | Avg hold | Frequency | Realized PnL | Unrealized PnL | Open at end |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| bull-crash-2015-2020 | 83 | 27 | 56 | 32.5% | 0.63 | 0.41 | 101.2 d | 2.23/mo | −$159K | $1,663K | 6 |
| covid-recovery-2020-2024 | 118 | 44 | 74 | 37.3% | 0.33 | 1.20 | 67.0 d | 4.47/mo | +$136K | $1,141K | 9 |
| six-year-2018-2023 | 122 | 40 | 82 | 32.8% | 0.57 | 0.96 | 71.9 d | 3.23/mo | −$22K | $1,562K | 6 |
| sp500-2019-2023 | 134 | 51 | 83 | 38.1% | 0.39 | 1.29 | 72.6 d | 5.03/mo | +$198K | $1,675K | 10 |

All trades long-only; zero short-side activity (short strategy
unimplemented). All exits via `stop_loss` trigger.

## Trade-count drift since last pinning

Existing scenario-file ranges were pinned 2026-04-18 post-PR #409. Three
of the four cells now exceed `total_trades` upper bounds — these
goldens are red:

| Scenario | Pinned range | Observed | Out-of-band |
|---|---|---:|---|
| bull-crash | (10, 25) | 83 | high (3.3×) |
| covid-recovery | (12, 30) | 118 | high (3.9×) |
| six-year | (12, 30) | 122 | high (4.1×) |
| sp500-2019-2023 | (125, 145) | 134 | in band |

Bull-crash also drops total_return (80% < 250% lower bound) — the
unrealized P&L on hold-throughs that drove the 339% baseline has
unwound, replaced by frequent stops with realized losses. SP500 goes
out of band on max_drawdown (97.7% > 55% upper bound) — see anomaly
below.

This is **not** drift to absorb — it's a real strategy-behaviour shift
since the 2026-04-18 baselines that the trade-audit work needs to
explain. Re-pinning is premature until the audit reveals whether the
shift is a correctness regression or an intentional consequence of
post-#409 work.

## Per-scenario commentary

### bull-crash-2015-2020

Strong bull market into a sharp crash. Strategy realised −$159K across
83 round trips; nearly all the headline +80.3% comes from $1.66M
unrealized gain on 6 still-open positions. Win rate 32.5% with
profit-factor 0.41 means losers are roughly 2× larger than winners on
average — stops are pulling the trigger before runners can pay for the
losers. Equity peak $1.81M on 2020-12-28 (last day); trough $912K on
2016-01-21 — so the 36% drawdown is a 2015-→-early-2016 dip, not the
COVID crash itself. Strategy nearly matched B&H on return (−2.2 pp)
and was within 2 pp on drawdown — best relative performance of the
four cells.

### covid-recovery-2020-2024

Worst relative performance of the four. Strategy +30.9% vs B&H +80.5%
(−49.6 pp gap). Realised +$136K with profit-factor 1.20 — winners
*are* slightly larger than losers — but the 2022 bear chopped the
strategy out repeatedly: 118 trades over 5 years, avg-hold 67 days
means the strategy churned through stop-outs while B&H rode it out.
Trough $807K on 2020-05-04 (mid-COVID); peak $1.36M on 2024-12-04
gives a 34.7% MaxDD. Sharpe 0.33 reflects both the high churn and the
small final return.

### six-year-2018-2023

Mixed. Strategy +69.2% vs B&H +76.9% (only −7.7 pp gap), and
strategy's MaxDD 25.3% **beat** B&H 33.9% — the 2018 run-up to start
of period gave the strategy room to be partially-cash through the
COVID crash. Realised −$22K essentially flat; the +69% is unrealized
on 6 open positions. 122 trips, win-rate 32.8%, profit-factor 0.96
(losers slightly bigger than winners). Trough $941K on 2020-03-18
(COVID low); peak $1.72M on 2023-12-13. This is the cell where the
strategy looks most like a competent vol-managed long-only system.

### sp500-2019-2023

The headline. The 2026-04-26 baseline note pinned this at +18.5% return
/ 47.6% MaxDD / 0.26 Sharpe / 28.6% win rate — every single one of
those numbers has moved:

| | 2026-04-26 baseline | 2026-04-28 re-run | Δ |
|---|---:|---:|---:|
| Total return | +18.5% | +70.8% | +52.3 pp |
| Win rate | 28.6% | 38.1% | +9.5 pp |
| Sharpe | 0.26 | 0.39 | +0.13 |
| MaxDD | 47.6% | **97.7%** | +50.1 pp |
| Trips | 133 | 134 | ≈ |
| Avg hold | 82.4 d | 72.6 d | −10 d |

Return up, win-rate up, Sharpe up, drawdown vastly worse. The 97.7%
drawdown is **not real** in the trading-quality sense — equity hits
$25K on 2020-08-27 in a 1-day spike. Surrounding context: portfolio
$520K on 2020-07-31 → $25K on 2020-08-27 → $1.06M on 2020-08-31. The
late-Aug-2020 window straddles the AAPL 4:1 and Tesla 5:1 splits
(both effective 2020-08-31). No round-trip closes during this window
to absorb the loss — the dip is in mark-to-market on open positions
only, suggesting an off-by-one between the price-panel split-adjusted
close and the open-position reference price during the day-of-split
boundary. **This is a bug, not a strategy outcome**, and is the
single largest contributor to the headline MaxDD regression vs the
2026-04-26 baseline. Filed for trade-audit follow-up.

Setting the Aug 27 anomaly aside, the strategy's 2nd-worst trough on
sp500 was $891K (Stage-4 drawdown) → 49% MaxDD, consistent with the
old baseline.

## Aggregate observations

1. **Strategy is long-only, all-stop-out.** 0/477 trades are short;
   100% of exits are `stop_loss`. The "Weinstein system" today is
   really "Stage-2 entries → trail-and-stop on the long side." Short
   side is unimplemented (per `dev/status/short-side-strategy.md`
   status MERGED — that's wishful; the strategy's screener cascade
   doesn't generate short candidates in any of these runs).

2. **Edge is in early bull windows where unrealized gains pile up.**
   Strategy's two strongest cells (bull-crash, six-year) end with
   $1.5–1.7M unrealized P&L on 6 open positions — those are the
   trade-quality wins. Covid-recovery (which starts mid-cycle) and
   sp500-2019-2023 (similar) realise more but unrealized is smaller
   relative to position count.

3. **Win rates are 32–38%.** Stable across cells. Below Weinstein's
   book target of 40–50%; consistent with stop-buffer being too tight
   per the buffer-tuning experiment (`dev/experiments/stop-buffer/`).

4. **Profit factors 0.41 / 0.96 / 1.20 / 1.29.** Bull-crash is the
   outlier (PF 0.41) — losers are 2.4× larger than winners there. The
   other three cluster around 1.0, meaning realised P&L is nearly
   flat; strategy "earns" almost entirely via unrealised
   end-of-period mark-to-market on the longest-running positions.

5. **Trade frequency 2.2–5.0 trades/month.** sp500 is the busiest
   (5.0/mo on 491 universe); small (302 universe) goldens are 2–4/mo.
   This is the post-#409 regime where symbols re-enter after stop-out.

6. **Drawdown patterns:** every window contains the COVID-2020 crash,
   and B&H drawdown is 33.9% in all of them. Strategy MaxDD is 25–37%
   on the small-302 cells (within striking distance of B&H, sometimes
   beating it on six-year). Strategy MaxDD on sp500 is contaminated
   by the Aug-2020 split anomaly and not directly comparable.

## Where the strategy's edge lives

Tentative — the trade-audit will sharpen this:

- **Drawdown management on six-year-2018-2023.** Strategy 25.3% vs
  B&H 33.9%. The pre-COVID 2018 advance let the strategy bank gains
  and ride out the crash partially-cash. This is the one cell where
  the strategy unambiguously adds value over B&H.
- **Capital preservation on flat-cyclic markets.** None demonstrated —
  on covid-recovery (also a high-vol cyclic market), strategy
  catastrophically underperforms (−49.6 pp).
- **Stage-2 entries on individual leadership names.** 38% win rate on
  sp500 is the best of the four — the larger universe gives the
  cascade more candidates to choose from. Need trade-audit to confirm
  these are textbook Stage-2 breakouts vs noise.

## Where the strategy underperforms

- **Mid-cycle entry environments** (covid-recovery): the strategy
  doesn't catch the V-recovery that B&H captures wholesale.
- **Mark-to-market correctness around corporate actions.** The sp500
  Aug-2020 anomaly is a bug surface that the trade-audit will need to
  isolate. Possible split-adjustment timing in the columnar price
  panels.
- **All-stop-out exits.** 100% of trades exit via stop_loss — the
  strategy never takes profit on a target or rotates on
  Stage-2-to-Stage-3. This caps upside on the runners and is
  consistent with the low profit-factor.

## Next step

Trade-audit per `dev/plans/trade-audit-2026-04-28.md` — ranks
individual trades by P&L and surfaces the decision trail (entry
reason, stop-trail history, exit trigger). Without that, "why is win
rate 32% on bull-crash" is a blind metric. With it, we can identify
e.g. "60% of losses are within-1-week stop-outs on Stage-2 entries
that re-tested the breakout level" → maps to a stop-buffer tuning
recommendation.

## References

- Existing baseline: `dev/notes/sp500-golden-baseline-2026-04-26.md`
- Trade-audit plan: `dev/plans/trade-audit-2026-04-28.md`
- Status: `dev/status/backtest-perf.md`
- B&H source: `data/G/X/GSPC.INDX/data.csv`
- Run artefacts:
  `dev/backtest/scenarios-2026-04-28-034425/` (small),
  `dev/backtest/scenarios-2026-04-28-034706/sp500-2019-2023/`

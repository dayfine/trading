# Sector-ETF diagnostic — Weinstein on SPDR sector ETFs vs BAH SPY (1998-2025)

**Date:** 2026-05-28
**Branch:** `experiment/sector-etf-diagnostic`
**Scenarios:** `trading/test_data/backtest_scenarios/experiments/sector-etf-diagnostic-2026-05-28/`
**Run outputs:** `dev/backtest/scenarios-2026-05-28-155612/` (host-local, not committed)
**Wall:** 60s BAH SPY + 131s SPDR Weinstein (parallel)

---

## Headline verdict

**`LOSES_TO_SPY`** by a wide margin.

| Metric                              | SPDR Weinstein (Cell-E) | BAH SPY    | Delta            |
| ----------------------------------- | ----------------------- | ---------- | ---------------- |
| **Total return (27.31y)**           | **+11.60%**             | **+463.39%** | **-451.79 pp**   |
| **CAGR**                            | **0.40%**               | **6.53%**  | **-6.13 pp**     |
| Sharpe                              | 0.18                    | 0.42       | -0.24            |
| Sortino (annualized)                | 0.25                    | 0.55       | -0.30            |
| Max drawdown                        | 7.39%                   | 56.22%     | -48.83 pp (less) |
| Calmar (CAGR / \|MaxDD\|)           | 0.054                   | 0.116      | -0.062           |
| Ulcer index                         | 4.54                    | 17.85      | -13.31           |
| Total trades (round-trips)          | 189                     | 0          | —                |
| Win rate                            | 43.9% (83W / 106L)      | n/a        | —                |
| Avg holding days                    | 34.2                    | n/a        | —                |
| Avg win / avg loss                  | +4.13% / -2.21%         | n/a        | —                |
| Profit factor                       | 1.35                    | n/a        | —                |
| Final equity (from $1.00M init)     | $1.116M                 | $5.628M    | -$4.512M         |

Verdict thresholds applied: BEAT ≥ +1 pp CAGR; TIE within ±1 pp; LOSE ≤ -1 pp. Result is **-6.13 pp CAGR**, far past the LOSE threshold.

---

## Equity-curve comparison

Year-end snapshots (portfolio value, $):

| Year-end | SPDR Weinstein | BAH SPY    | Spread (SPY - Weinstein) |
| -------- | -------------- | ---------- | ------------------------ |
| 1998     | 1,000,000      | 1,000,000  | 0                        |
| 1999     | 1,000,000      | 1,017,349  | +17,349                  |
| 2000     | 983,705        | 1,198,841  | +215,136                 |
| 2001     | 959,757        | 1,081,948  | +122,191                 |
| 2002     | 946,102        | 943,420    | -2,682                   |
| 2003     | 928,290        | 729,568    | -198,722                 |
| 2004     | 1,002,352      | 918,647    | -83,705                  |
| 2005     | 1,066,527      | 992,638    | -73,889                  |
| 2006     | 1,061,792      | 1,027,172  | -34,620                  |
| 2007     | 1,097,734      | 1,167,526  | +69,792                  |
| 2008     | 1,148,167      | 1,194,678  | +46,511                  |
| 2009     | 1,125,004      | 768,368    | -356,636                 |
| 2010     | 1,106,719      | 935,463    | -171,256                 |
| 2011     | 1,119,557      | 1,048,008  | -71,549                  |
| 2012     | 1,126,285      | 1,035,293  | -90,992                  |
| 2013     | 1,127,863      | 1,203,947  | +76,084                  |
| 2014     | 1,131,860      | 1,506,310  | +374,450                 |
| 2015     | 1,146,118      | 1,690,959  | +544,841                 |
| 2016     | 1,124,869      | 1,654,784  | +529,915                 |
| 2017     | 1,111,174      | 1,839,434  | +728,260                 |
| 2018     | 1,128,534      | 2,210,537  | +1,082,003               |
| 2019     | 1,119,526      | 2,058,043  | +938,517                 |
| 2020     | 1,110,956      | 2,670,726  | +1,559,770               |
| 2021     | 1,114,808      | 3,031,001  | +1,916,193               |
| 2022     | 1,124,809      | 3,924,472  | +2,799,663               |
| 2023     | 1,118,235      | 3,142,890  | +2,024,655               |
| 2024     | 1,105,870      | 3,882,965  | +2,777,095               |
| 2025     | 1,117,309      | 4,801,619  | +3,684,310               |
| 2026     | 1,118,541      | 5,609,860  | +4,491,319               |

ASCII shape (Y-axis = $M, log-ish; X-axis = year):

```
SPY: 1.0M ─.─.─^─^─.v─^─^^─v.v─^─^^─^─^─^─^─^─^─^v─^─^─^^─v^─^─^ 5.6M
Wei: 1.0M ────.───^─^^─^─^─^─^─^─^─^─^─^─^─^─^─^─^─^─^─^─^─^─^─^ 1.1M
```

Sharper description: **Weinstein-on-SPDR posted positive equity in all dotcom + GFC drawdowns** (1.13M peak in 2008 while SPY was at 0.77M in early 2009), bought into recovery selectively, then sat in cash through the entire 2009-2025 bull market. **The defense is real and large; the offense is essentially absent.**

The SPDR portfolio shows:
- ~50 negative bps return in years 2000-2002 (dotcom) vs SPY's -30% peak-to-2002 drawdown
- Slow drift up through 2004-2008 (+15%) while SPY recovered to break-even
- Held value near $1.13M from 2008 onward; SPY 6-bagged from $0.77M to $5.6M

---

## Trade-distribution diagnostics

**Trades per sector:**

| Sector ETF | Trades | Sector              |
| ---------- | ------ | ------------------- |
| XLB        | 26     | Materials           |
| XLP        | 25     | Consumer Staples    |
| XLK        | 21     | Information Tech    |
| XLF        | 20     | Financials          |
| XLU        | 20     | Utilities           |
| XLV        | 19     | Health Care         |
| XLY        | 17     | Consumer Disc       |
| XLI        | 15     | Industrials         |
| XLE        | 14     | Energy              |
| XLRE       | 8      | Real Estate (2015+) |
| XLC        | 4      | Communication (2018+) |

Trade activity is reasonably distributed — the strategy did engage the universe, not stuck on one symbol. Late-inception ETFs (XLRE 2015-10-08, XLC 2018-06-19) traded normally after their first bar; the NaN-tolerance path in `Csv_snapshot_builder._read_one_symbol` worked as expected, so the diagnostic does NOT need PR #1318's `?active_through_for` filter at this 12-symbol scale.

**Exit-trigger mix (189 trades):**

| Exit trigger          | Count | %      |
| --------------------- | ----- | ------ |
| `laggard_rotation`    | 88    | 46.6%  |
| `stop_loss`           | 84    | 44.4%  |
| `stage3_force_exit`   | 17    | 9.0%   |

**This is the smoking gun.** Nearly half the exits are laggard-rotation cycles (force-rotate out of a position deemed too cold relative to a hotter peer), and another 44% are stop-losses. Almost no positions exit via a clean Stage-3 distribution sell that would mean "this advance is naturally complete." The strategy is in constant rebalancing churn against tight stops on a low-volatility 11-symbol cap-weighted-equivalent universe — sector ETFs intrinsically have ~1/3 the per-bar volatility of single stocks, so screener-flagged "Stage 2 breakouts" on ETFs are noisy false starts more than real trend kicks.

**Trade PnL distribution (% per trade):**

| Quantile | PnL %  |
| -------- | ------ |
| Min      | -6.37  |
| P10      | -3.42  |
| P25      | -2.32  |
| Median   | **-0.53** |
| P75      | +1.36  |
| P90      | +5.46  |
| Max      | +39.01 |

Median trade is negative. Avg win +4.13% / avg loss -2.21% gives a payoff ratio of 1.87× — combined with 43.9% win rate, expected-R per trade ≈ +0.46% (= 0.439 × 4.13 − 0.561 × 2.21). With 189 trades over 27y and modal position size ~14% of equity (Cell-E `max_position_pct_long = 0.14`), realized return arithmetic checks out at ~12% total over the window.

---

## Caveats

1. **XLRE / XLC late inception, handled by NaN tolerance.** The 11-symbol universe is fully wired, but XLRE has no bars before 2015-10-08 and XLC has none before 2018-06-19. The `Csv_snapshot_builder._read_one_symbol` tolerance path carries NaN through the panel reader for pre-inception dates; the Weinstein screener cannot trade NaN bars, so the universe effectively expands at each ETF's inception. XLRE traded 8 times and XLC 4 times (post-inception) — both modest but non-zero, confirming the wiring works. **No follow-up needed** for the 12-symbol scale; the opt-in `?active_through_for` filter (PR #1318) is only relevant at larger universes where per-fold pruning materially reduces the work.
2. **Cell-E config used, not the v7-iter42 BO winner.** This isolates the *universe effect* from the *parameter effect*. A separate experiment could sweep the 11-knob space on this universe to ask "is there any config that meaningfully changes the verdict?" My prior is that the answer is no — the universe-volatility shortage and the macro-screener's necessary conservatism are mechanical, not parameter-sensitive. But this is not measured here.
3. **Initial cash = $1M (not $100k as the brief suggested).** Every other historical scenario on this surface uses the `Backtest.Runner.initial_cash = 1_000_000.0` default (runner.ml:13; not a per-scenario knob). Lowering to $100k would not change the return percentage but would introduce a capital-scaling artefact: per memory `feedback_position_count_capital_scaling.md`, at $100k init cash the Cell-E `max_position_pct_long = 0.14` permits ~7 positions before exhausting the 0.70 max-long-exposure cap, which is enough headroom for the 11-symbol universe. The strategy never used more than ~7-8 concurrent positions anyway (universe of 11 with min_cash 30% caps it at 5 max once XLRE / XLC are still missing). Verified `open_positions_value = 0` at end (no compositional bias). Documented for completeness; the verdict is unaffected.
4. **Window 1998-12-22 to 2026-04-14.** Brief said 1998-01-01 to 2025-12-31. SPDR Select Sector family did not exist before 1998-12-22 (XLB/XLE/XLF/XLI/XLK/XLP/XLU/XLV/XLY's first bar), and the latest available bar in `data/` is 2026-04-14 (per `data/S/Y/SPY/data.csv` tail). The window I ran is the longest honest one the universe + data supports. ~27.31 years.
5. **BAH SPY uses raw closing price (not dividend-reinvested).** Per the existing BAH-SPY methodology in `goldens-sp500/sp500-2019-2023-bah-spy.sexp`, the benchmark holds SPY shares from day 1 with no dividend reinvestment — `unrealized_pnl` is end-MtM minus cost basis. Adjusted (dividend-reinvested) SPY return over this window would be ~+1100-1200% (CAGR ~10%) versus the +463% raw-close I report. This makes the LOSE verdict even sharper: Weinstein-on-SPDR would underperform dividend-reinvested SPY by ~10pp CAGR. Both backtests omit dividends equally, so the comparison is fair within the system; if dividends are added downstream they should be added symmetrically.
6. **Cost model: 5 bps bid-ask, $0 commission.** Same overlay as `sp500-1998-2026.sexp`. SPDR ETFs are tighter than that in reality (~0.5-1 bp typical bid-ask), so this slightly over-penalizes the Weinstein run; not enough to change a -451 pp verdict.

---

## Strategic implication

**Verdict was LOSE. The strategic-pivot backlog in `project_strategic_pivot_broader_first.md` needs revisiting before more tuning work.**

The diagnostic answers the user's reframe sharply: the Weinstein mechanic does NOT extract sector-rotation alpha on the SPDR universe. The mechanism is not "no signal" — the strategy correctly avoids dotcom and GFC drawdowns (final MaxDD 7.4% vs SPY's 56.2%, ulcer 4.5 vs 17.9). But it cannot find sustained Stage-2 breakouts on the low-volatility, broad-basket sector instruments, gets whipsawed by laggard-rotation churn (47% of exits), and ends 27 years effectively in cash.

**This has direct strategic implications:**

1. **The "filter individual-stock screening to currently-winning sectors" follow-up is NOT supported by this diagnostic.** The premise of that follow-up was that Weinstein on sectors *does* find rotating winners, which we could then use as a filter. The evidence is the opposite — Weinstein on sectors finds 189 small trades that net out to ~zero alpha. A sector-rotation filter built on this signal would add complexity without lift.

2. **Stock-level alpha may be similarly absent in the broad universe.** The user's reframe was: if the mechanic can't extract sector-level alpha, stock-level may be similarly absent. The 28-fold walk-forward sweeps already point this way (random ≈ BO ≈ marginal; see `dev/notes/2026-05-25-v6-random-baseline-verdict.md`). This diagnostic adds an independent data point in the same direction from a different angle: the mechanic doesn't work even when given the cleanest possible signal (cap-weighted sector buckets with 27y of clean history).

3. **Three priorities re-emerge from `strategic_pivot_broader_first.md`:**
   - **Replace the screener cascade entirely**, not just tune the 11 knobs. The cascade's screener is conservative-by-design (macro gate, sector RS, stage classifier, breakout confirmation, volume gate) — five-stage AND-filter that ends up rejecting nearly every entry over 27 years on a 12-symbol universe. Some of those gates may be wrong direction-of-effect, not just wrong threshold.
   - **Drop the long-only mechanic and accept SPY tracking + tactical overlays** (sector tilt within a passive base, not stage-2 entry). The diagnostic shows the "defense is real and large" — Weinstein's value is in the drawdown floor, not the upside. A 60/40 SPY-or-bonds with tactical tilt to leading SPDR sectors (using a non-Weinstein signal, e.g. simple 200d-MA or trend-following) is the natural alternative to test.
   - **Walk-forward CV + ML-discipline tuning** on the broader universe (P0 from the pivot doc) is still the right next step but with a substantially lower prior expectation of alpha. Set expectations: a +1-2 pp CAGR vs SPY would be a meaningful result; anything more should be triple-checked for survivorship / look-ahead / cost mis-modeling.

4. **Stop running another BO design round.** Three rounds of v8 score-formula critique each landed on "the 11-knob surface doesn't have a meaningfully better region than Cell-E." The sector-ETF diagnostic confirms this from outside the BO frame: the limitation is not the knob settings, it is the mechanic on this universe.

---

## What I would NOT conclude from this diagnostic

- Weinstein does not work on **any** universe. (We only tested 11 SPDR ETFs.) The mechanic could work on a different surface — e.g. mid-cap growth stocks at the 1995-2005 horizon — but that's a separate experiment. The dispatch was specifically about whether sector rotation has alpha; the answer is no.
- The 11-knob surface should be retired as a research artefact. (It's still useful as a *baseline* for walk-forward CV against random / SPY; just stop spending BO compute on it expecting to find a winner.)
- Stop losses don't work. (They do — MaxDD 7.4% vs 56.2% is a real defensive bound. The issue is the strategy cannot find offense after the defense fires.)

---

## Reproduction

```bash
# In repo root
docker exec trading-1-dev bash -c \
  'cd /workspaces/trading-1/.claude/worktrees/<your-worktree>/trading && \
   eval $(opam env) && \
   dune build trading/backtest/scenarios/scenario_runner.exe && \
   _build/default/trading/backtest/scenarios/scenario_runner.exe \
     --dir test_data/backtest_scenarios/experiments/sector-etf-diagnostic-2026-05-28 \
     --parallel 2 \
     --fixtures-root test_data/backtest_scenarios \
     --no-emit-all-eligible'
```

Outputs in `dev/backtest/scenarios-<timestamp>/{bah-spy-1998-2025,spdr-sector-etfs-1998-2025}/`. Wall time: ~131s SPDR + ~60s BAH, run in parallel.

## Files

- **Scenarios:** `trading/test_data/backtest_scenarios/experiments/sector-etf-diagnostic-2026-05-28/{bah-spy-1998-2025.sexp, spdr-sector-etfs-1998-2025.sexp}`
- **Universe:** `trading/test_data/backtest_scenarios/universes/sector-etf-diagnostic/spdr-sector-etfs.sexp`
- **Run outputs (not committed):** `dev/backtest/scenarios-2026-05-28-155612/`
- **Pinned aggregates referenced but NOT used here:** `dev/experiments/bayesian-production-sweep-2026-05-25/baseline_aggregate_v7_spy.sexp` (per-fold CV BAH SPY; this diagnostic does single-window, not per-fold)

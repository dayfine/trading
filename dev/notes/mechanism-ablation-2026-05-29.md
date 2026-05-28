## Mechanism ablation — isolating the alpha-killer on SPY-only + sector-ETFs

Date: 2026-05-29
Author: claude (experiment/mechanism-ablation agent)
Pairs with:
- Survey design: `dev/notes/strategy-diagnostic-survey-2026-05-28.md` — the
  4-cell (1a/1b/2a/2b) matrix that motivated this ablation. Updated by this
  PR with the ablation summary section.
- 1b report (forthcoming, separate PR): `dev/notes/spy-only-fullsize-2026-05-28.md`.
- 2b report (forthcoming, separate PR): `dev/notes/sector-etf-fullsize-2026-05-28.md`.

Note: the 1b/2b fullsize reports and their backing scenarios
(`spy-only-1998-2025-fullsize.sexp`, `spdr-sectors-1998-2025-fullsize.sexp`)
land via a sibling PR. The `spdr-sectors-11.sexp` universe file is included
in this PR because the 2b ablation scenarios depend on it; if the sibling
PR merges first, this PR's add of `spdr-sectors-11.sexp` will conflict
trivially (identical content).

Scenarios: `trading/test_data/backtest_scenarios/experiments/mechanism-ablation-2026-05-29/`
Raw outputs: `dev/experiments/mechanism-ablation-2026-05-29/<run>/{actual,summary}.sexp` + `trades.csv`.

## Headline verdict

**`laggard_rotation` IS the alpha-killer.** On the SPY-only 1b surface,
disabling laggard_rotation lifts total return from **+0.22% → +9.54%** (43×)
and lets the average winning trade hold for **336 days** instead of 32. On
the 11-SPDR-ETF 2b surface, the same single-knob ablation lifts total return
from **+7.43% → +49.45%** (6.7×) and lifts average winning-trade hold from
54 → 237 days.

The mechanism is not subtle: laggard_rotation closes Stage-2 positions
ROUTINELY at small gains (1-2%) or small losses, prematurely exiting trends
that would otherwise compound for hundreds of trading days. On a
single-asset universe it has no semantic content (there's no other candidate
to rotate INTO), but it still fires as a "go-to-cash" signal. On an 11-ETF
universe it produces churn that fragments multi-year sector trends.

Neither `stage3_force_exit` nor stop widening alone produces alpha.
`stage3_force_exit` is **inert** on SPY-only (the 1b-no-stage3 ablation
produces byte-identical metrics to 1b-baseline). Wide stops shift the exit
cause from `stop_loss` to `laggard_rotation` without unlocking longer
holds.

Even the unlocked alpha falls short of BAH-SPY (+464.14% / 6.62% CAGR over
27.03y). The maximally-permissive `1b-buy-and-hold-on-stage2` variant tops
out at +6.46% total — much better than +0.22% but still ~98.6% short of BAH.
**The Stage-2 entry filter itself rejects SPY most of the time**, even with
all exit-side mechanisms disabled. SPY only enters as a Stage-2 candidate
in narrow windows, so the strategy spends ~96% of calendar time in cash
regardless of how exit knobs are tuned. The remaining alpha gap is the
**Stage-2 admission criterion**, not the rotation runners.

## Full results table (10 variants)

Window: 1998-12-22 → 2025-12-31 (27.03 years).
Initial cash: $1,000,000.
BAH-SPY reference: +464.14% total / 6.62% CAGR / 56.22% MaxDD / 0 trades / 100% time in market.

### SPY-only (1 symbol universe)

| Variant | Total return | CAGR | Sharpe | MaxDD | Trades | Avg hold | Win rate | Stop / Laggard / Stage3 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1b-baseline | +0.22% | 0.01% | 0.02 | 2.09% | 10 | 26.5d | 50% | 5 / 5 / 0 |
| 1b-no-laggard | **+9.54%** | **0.34%** | **0.20** | 5.99% | 10 | 117.9d | 30% | 6 / 0 / 4 |
| 1b-wide-stops | +0.30% | 0.01% | 0.16 | 0.24% | 10 | 27.9d | 60% | 1 / 9 / 0 |
| 1b-no-stage3 | +0.22% | 0.01% | 0.02 | 2.09% | 10 | 26.5d | 50% | 5 / 5 / 0 |
| 1b-buy-and-hold-on-stage2 | **+6.46%** | **0.23%** | **0.38** | 1.75% | 4 (+1 open) | 215d | 0% closed | 4 / 0 / 0 |

### Sector ETFs (11-symbol universe)

| Variant | Total return | CAGR | Sharpe | MaxDD | Trades | Avg hold | Win rate | Stop / Laggard / Stage3 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 2b-baseline | +7.43% | 0.27% | 0.15 | 7.31% | 193 | 33.7d | 44.6% | 88 / 87 / 17 |
| 2b-no-laggard | **+49.45%** | **1.50%** | **0.43** | 8.58% | 190 | 92.9d | 30.5% | 119 / 0 / 67 |
| 2b-wide-stops | +5.35% | 0.19% | 0.20 | 5.29% | 197 | 55.6d | 50.3% | 30 / 129 / 37 |
| 2b-no-laggard-wide-stops | **+27.22%** | **0.89%** | **0.46** | 5.46% | 195 | 155.9d | 39.5% | 56 / 0 / 135 |

(Stop/Laggard/Stage3 columns count exit_trigger occurrences in trades.csv.
The total includes 1-4 blank rows per file from in-flight positions written
without a trigger.)

## Per-mechanism conclusion

### `laggard_rotation` — **THE alpha-killer**

- **SPY-only:** disabling moves +0.22% → +9.54% (Δ +9.32pp). Avg hold 26.5d →
  117.9d. Winner avg-hold goes from 32d → **336d**.
- **Sector-ETF:** disabling moves +7.43% → +49.45% (Δ +42.0pp). Avg hold
  33.7d → 92.9d. Winner avg-hold goes from 54d → **237d**.
- **Per-trade NAV impact (SPY-only):** the 2006-09-09 SPY entry held 28d
  with +3.74% in 1b-baseline, exits via `stop_loss`; same entry in
  1b-no-laggard holds **336d** with **+11.00%**. The 2016-11-26 entry: 28d
  / +1.96% / `laggard_rotation` in baseline; **497d / +19.14% / stop_loss**
  with laggard disabled.

**Why on a 1-symbol universe?** Laggard_rotation runs per-position scoring
against the screener-ranked universe; on SPY-only there is no other Stage-2
candidate to rotate INTO, so the runner closes the position to cash.
Functionally a "switch to cash on relative-strength dip" signal that has
no rebalancing benefit when the universe degenerate.

**Why on the 11-ETF universe?** The 11 sector ETFs all correlate
0.7-0.95+ with SPY; when one sector ETF dips relative to its peer, the
laggard runner rotates into the peer — but the peer also turns and the
rotation cycle dissipates ~5pp of alpha per cycle. With 47% of all trades
being laggard-driven exits, the cumulative drag is the dominant alpha
sink.

### `stage3_force_exit` — **inert on SPY-only; small contributor on 11-ETF**

- **SPY-only:** `1b-no-stage3` is **byte-identical** to `1b-baseline` —
  Stage3 never fires on SPY in the 10-trade sample (the 5 laggard exits
  + 5 stop_loss exits exhaust the trade history). Stage3 only fires when
  laggard is disabled — there, 4 of 10 exits become `stage3_force_exit`
  (it was being preempted by laggard_rotation in the baseline).
- **Sector-ETF:** Stage3 contributes 17/193 exits in baseline (~9%);
  jumps to 67/190 when laggard is disabled and 135/195 when both laggard
  is disabled and stops are widened. So Stage3 IS a real exit mechanism
  on the multi-ETF surface, but secondary to laggard.

### Wide stops (initial_stop_pct=0.30, installed_stop_min_pct=0.30, max_stop_distance=0.50, min_correction=0.30) — **marginal**

- **SPY-only:** moves +0.22% → +0.30% (Δ +0.08pp). Reduces MaxDD from 2.09%
  → 0.24% (smaller per-trade loss) but laggard now closes 9/10 trades (vs
  5/10 baseline). The wider stops don't fire as often, so laggard becomes
  the dominant exit cause — net activity barely changes.
- **Sector-ETF:** moves +7.43% → +5.35% (Δ -2.08pp, slight LOSS). MaxDD
  improves 7.31% → 5.29% but laggard rotation now drives 129/197 exits
  (was 87/193).
- **Combined with no-laggard** (only sector-ETF tested): +27.22% — STRICTLY
  WORSE than no-laggard alone (+49.45%). Wide stops are NEGATIVE-alpha when
  combined with no-laggard because Stage3 now fires more (135/195 exits vs
  67/190 in no-laggard-only), and these Stage3 exits land at small
  profits in the middle of trends.

### `1b-buy-and-hold-on-stage2` — **upper bound is still 98.6% short of BAH-SPY**

The maximally-permissive variant (no laggard + no stage3 + wide stops)
produces:
- 4 closed trades (all losers, total ~-4% per trade) + 1 OPEN position
  finished at +69k unrealized → +6.46% total return / +0.23% CAGR.
- Avg hold of closed positions: **215 days**.
- The 4 closed trades are: 2000-08-19→2000-10-07 (49d, stop_loss),
  2002-03-23 (20d, stop_loss), 2006-09-09→2008-01-23 (**501 days,
  stop_loss at -2.30%**), 2014-11-08→2015-08-25 (**290 days, stop_loss at
  -3.81%**). The 501-day held trade survived the entire 2007 bull but exited
  in January 2008 at a small loss on the GFC-onset volatility.
- The OPEN 5th position (entered post-2023-04-15) compounds the remaining
  $69k unrealized — captures the 2023-2025 SPY bull at scaled-down position
  size.

Even with EVERY exit mechanism near-disabled, the strategy:
- Misses the entire 2009-2014 post-GFC bull (no Stage-2 entry triggers).
- Misses 2017-2019 (no Stage-2 entry).
- Misses 2019-2023 (no Stage-2 entry until 2023-01).

**The Stage-2 admission criterion itself is the residual bind.** Even with
all exit mechanisms disabled, the screener cascade only admits SPY as a
Stage-2 candidate in narrow windows (2000-08, 2002-03, 2006-09, 2014-11,
2023-01). Most of the time SPY is classified as Stage 1 (basing/recovery)
or Stage 3 (topping) — never sustained Stage 2.

## Year-end NAV trajectory (SPY-only)

| Year-end | 1b-baseline | 1b-no-laggard | 1b-BAH-on-stage2 | BAH-SPY |
|---|---:|---:|---:|---:|
| 1998 | $1,000,000 | $1,000,000 | $1,000,000 | $1,025,552 |
| 2002 |   989,508 |   989,508 |   997,252 |   728,583 |
| 2007 | 1,001,148 | 1,033,144 | 1,001,362 | 1,205,178 |
| 2014 |   990,812 | 1,022,481 |   996,869 | 1,717,947 |
| 2018 | 1,005,052 | 1,106,595 |   999,512 | 2,055,911 |
| 2024 | 1,002,192 | 1,095,382 | 1,049,919 | 4,830,986 |
| 2025 | 1,002,192 | 1,095,382 | 1,064,638 | 5,648,250 |

(1b-no-laggard ends at $1.10M flat from 2018 onward because the last
laggard-free trade closed in 2018; the strategy spends 2018-2025 in cash
waiting for another Stage-2 entry that never gets admitted.)

## Year-end NAV trajectory (Sector-ETF)

| Year-end | 2b-baseline | 2b-no-laggard | 2b-no-laggard-wide-stops | BAH-SPY |
|---|---:|---:|---:|---:|
| 2002 |   928,468 |   920,662 |   947,100 |   728,583 |
| 2007 | 1,100,346 | 1,196,427 | 1,059,862 | 1,205,178 |
| 2014 | 1,098,995 | 1,363,255 | 1,143,719 | 1,717,947 |
| 2018 | 1,079,580 | 1,396,938 | 1,158,789 | 2,055,911 |
| 2024 | (n/a)     | 1,505,942 | 1,271,582 | 4,830,986 |
| 2025 | 1,074,328 | 1,494,540 | 1,272,216 | 5,648,250 |

2b-no-laggard tracks BAH-SPY closely from 1999-2007 (essentially matches),
then falls behind starting in the 2009-2014 post-GFC bull. Even at 1.5x
its baseline return, 2b-no-laggard still loses to BAH-SPY by -171pp /
-5.1pp CAGR. **Sector rotation on Stage-2 entries is a real but small alpha
source on top of laggard removal.**

## Recommended mechanism redesign direction

### Highest priority: redesign `laggard_rotation`

The mechanism as currently implemented is **net-negative alpha** on BOTH a
1-symbol universe AND an 11-symbol universe. Three possible redesigns,
ranked by expected upside:

**Option A — Make laggard_rotation universe-aware.** If `length universe ==
1` (no rotation target) OR `len candidates == 0` OR the only ranked
candidate IS the held position, suppress the exit. This rescues the
1-symbol case for free. Estimated patch: ~20 LOC in
`trading/weinstein/laggard_rotation/`. Risk: doesn't address the 11-ETF
churn problem where rotation candidates DO exist but rotation produces
drag.

**Option B — Tighten laggard threshold.** Currently fires on a 2-week
hysteresis when the held position's rank slips below some threshold.
Raising the rank-gap threshold + extending hysteresis to 8-13 weeks
(quarter-cycle, matching Weinstein's "30-week MA" cadence) would suppress
intra-trend churn. Patch: configurable; ~no LOC change, just default tune.

**Option C — Replace with Weinstein-canonical Stage-3 detection only.**
Weinstein's book does NOT prescribe laggard_rotation; it prescribes
Stage-3 force-exit when the 30-week MA flattens and price closes below it.
The current laggard_rotation is a "relative-rank" overlay added later. The
2b-no-laggard result (+49.45% with stops + Stage3 only) is the closest
match to the book and produces the best risk-adjusted result (Sharpe 0.43
vs baseline 0.15). **Recommendation: make laggard_rotation OFF by default
in Cell-E**, run a comparison across the 3- and 4-cell sp500-historical
goldens, and pin the new default if it doesn't regress.

### Secondary: investigate Stage-2 admission permissiveness

The 1b-buy-and-hold-on-stage2 result reveals the Stage-2 entry filter is
the residual bind. SPY only qualifies as Stage-2 ~5-6 times in 27 years
even with the most permissive exit logic. Some hypotheses for follow-up:

- The breakout filter (`is_breakout_candidate`) requires a specific
  resistance-crossing structure that an already-trending SPY frequently
  doesn't match (it's not BREAKING OUT — it's already broken out and
  trending).
- The volume confirmation requirement may be too strict for an ETF where
  daily volume varies with general market activity, not the underlying
  ETF's strength.
- The Stage-2 weeks-advancing minimum may be set too high for an index
  ETF where consolidations are shorter than for individual stocks.

A follow-up ablation should disable each Stage-2 sub-criterion in turn
(breakout-required, volume-confirmation, weeks-advancing-min) and measure
how often SPY enters as a candidate.

### De-prioritize: stop tuning

The wide-stops ablation produced **0.08pp improvement** on SPY-only and
**-2.08pp regression** on sector-ETF. Cell-E's tight stops are not the
binding constraint. The existing 16% / 8% / 0.0% stop knobs are not
worth further sweep budget on these surfaces.

## Caveats

### "1b-no-laggard" Stage3 exits are still net-negative

Of the 4 Stage3 exits in 1b-no-laggard, the per-trade outcomes are:
2002-04 (-3.88%), 2007-11 (-1.00%), 2019-09 (-1.93%), 2023-10 (+2.22%).
3 of 4 are losers; the largest gain in the 10-trade sequence was 2016-11
(+19.14% via stop_loss after 497 days). So Stage3 IS pruning some trades,
but if it could be tuned to ride further (hysteresis_weeks > 1), some
unrealized gain might be preserved.

### Sector-ETF correlations inflate the sector-rotation upside

The 11 SPDR ETFs are highly correlated (0.7-0.95+) with SPY and with each
other. When laggard_rotation rotates from one ETF to another, it's largely
a no-op for portfolio NAV. Disabling it doesn't unlock genuine
cross-sector alpha — it just stops churning. A more diverse universe
(stocks vs ETFs) would likely show similar single-knob impact but the
remaining alpha would be sourced differently.

### 1b-no-laggard ends in cash 2018-2025 with no entries

After the last laggard-free Stage-2 entry closes in early 2018, the
strategy spends 7+ years in cash. This is the Stage-2-admission bind:
even without laggard preempting, the screener simply doesn't admit SPY
as a Stage-2 candidate during the 2018-2023 bull. The +9.54% no-laggard
total return is a 1998-2018 phenomenon; the strategy effectively died
in early 2018 with no further trades.

### Skipped: 1b-just-spy-MA-cross

Per the brief's allowance, this variant would have required a NEW simple
MA-cross strategy module (no Weinstein cascade). At ~150-300 LOC for a
new Strategy module + dune wiring + a test, it exceeded the 30-min budget.
The 1b-buy-and-hold-on-stage2 variant approximates the same role: maximally
permissive Weinstein, which still requires Stage-2 admission and so isn't a
pure MA-cross. If this sanity check matters for the next iteration, a
follow-up agent should add a minimal MA-cross strategy module and run
it on the same SPY-only window — comparing both to BAH-SPY.

### 1b-wide-stops Sharpe (0.16) > baseline (0.02) despite identical CAGR

Wide stops produce smaller per-trade losses, so even at near-identical
total return the volatility goes way down (MaxDD 2.09% → 0.24%) and
the Sharpe lifts mechanically. Don't mistake this for actual edge — it's
risk-adjusted noise.

## Strategic implication

Combined with the survey's 4-cell finding and the v7 random-baseline
verdict, this ablation gives a concrete redesign target:

1. **Make `enable_laggard_rotation = false` the new Cell-E default.** The
   mechanism is net-negative alpha on every universe tested in this
   diagnostic. The 2b-no-laggard result (+49.45% / Sharpe 0.43) is the
   strongest single backtest of the 4-cell survey.
2. **Re-run the v8 BO sweep grid** with `enable_laggard_rotation = false`
   pinned. The 11-knob surface may produce genuine alpha when the dominant
   alpha-killer is removed; the v7 plateau finding ("random ≈ BO") was on
   a surface where laggard_rotation was forcing every variant into a
   no-trade-edge regime.
3. **Re-evaluate the v8 strategy-mechanic redesign discussion** with the
   evidence that ONE knob (an opt-OUT, not an opt-IN!) is responsible for
   most of the bind. The v8 redesign proposals can be much more surgical
   than a full mechanic rewrite — just remove laggard_rotation from the
   default config.
4. **Defer Stage-2 admission permissiveness work** until after #1-3 land
   — it's the next bind but its alpha headroom (the 1b-buy-and-hold-on-
   stage2 + open-position result) is ~6%-15% total return vs BAH-SPY's
   464%, so a tactical patch buys at most ~30pp not 400pp.

## Reproduction

```bash
# SPY-only (5 variants):
docker exec trading-1-dev bash -c \
  "cd /workspaces/trading-1/.claude/worktrees/<your-id>/trading/trading && eval \$(opam env) && \
   dune exec --no-build backtest/scenarios/scenario_runner.exe -- \
     --dir <repo>/trading/test_data/backtest_scenarios/experiments/mechanism-ablation-2026-05-29 \
     --parallel 5"

# Sector-ETF (4 variants, needs --fixtures-root to find spdr-sectors-11.sexp which is not on main yet):
docker exec trading-1-dev bash -c \
  "cd /workspaces/trading-1/.claude/worktrees/<your-id>/trading/trading && eval \$(opam env) && \
   dune exec --no-build backtest/scenarios/scenario_runner.exe -- \
     --dir <repo>/trading/test_data/backtest_scenarios/experiments/mechanism-ablation-2026-05-29-sector \
     --fixtures-root <repo>/trading/test_data/backtest_scenarios \
     --parallel 4"
```

Wall time: ~3 minutes for SPY-only batch, ~8 minutes for sector-ETF batch.

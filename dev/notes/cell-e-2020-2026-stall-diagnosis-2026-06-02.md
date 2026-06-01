# Cell E 2020-2026 stall — diagnosis (06-02 P0)

**Question (from `next-session-priorities-2026-06-02.md` P0):** Cell E (the
production multi-symbol config) hit ~$25M by the 2020 COVID period on the deep
2000-2026 run and is **flat-to-down since**. Why? Is the stall (a) whipsaw churn,
(b) laggard-rotation / force-exit churn, or (c) SP500 dispersion compression?

**Answer: (a) whipsaw — false-breakout stop-out churn in choppy/narrow tape —
with a breadth-quality twist.** Laggard rotation (hypothesis b) is the one part
*working*; it is not the problem. Dispersion (c) shows up as a 2023-specific
narrow-breadth mask, not as idle capital.

## Method

Two single backtests, canonical Cell E config (sizing 0.14/0.70/0.30 + stage3
force-exit h=1 + laggard rotation h=2), via `scenario_runner --dir`:

- **Fresh 2020-2026** — `$1M` start on 2020-01-01, 2020 PIT universe (506 sym).
  Controlled regime test: does Cell E work in 2020-2026 *independent* of legacy
  positions / large-capital scaling? (`cell-e-2020-2026-fresh-diag`)
- **2010-2026 full trajectory** — same config, $1M start 2010, for the
  within-run regime split (2010-2019 vs 2020-2026). (`cell-e-2010-2026-diag`)

Scenarios: `dev/backtest/cell-e-stall-diag/*.sexp`.

## Fresh 2020-2026 — headline

| metric | value | read |
|---|--:|---|
| Total return | +44.3% (6.3y) | CAGR 5.97% — badly trails BAH-SPY (~13%/yr) |
| **Profit factor** | **0.96** | **realized trading is net-LOSING**; the +44% NAV is unrealized gains in 7 survivors |
| Win rate | 35.3% | |
| **MaxDD** | **32.3%** | vs 18.4% on the 2010-2026 run — far worse |
| **DD duration** | **1414 days (3.9y)** | ~62% of the window underwater |
| Sharpe / Calmar | 0.49 / 0.18 | vs 0.78 / 0.52 full-period — risk-adjusted collapse |
| Round trips | 300 (43.5/yr) | capital is deployed, NOT idle → rules out pure (c) |

The strategy is *up* only because 7 open positions floated higher with the
2024-2025 mega-cap advance. The **realized** trading added nothing (PF 0.96).

## Where the money goes — exit-trigger decomposition (the key table)

| exit_trigger | n | share | win% | avg pnl% | net $ |
|---|--:|--:|--:|--:|--:|
| **stop_loss** | 196 | 65% | **18%** | −2.04% | **−$526,736** |
| laggard_rotation | 101 | 34% | **69%** | +4.38% | **+$503,144** |
| stage3_force_exit | 2 | 1% | 0% | −5.66% | −$16,106 |

- **Stop-outs are the wound.** Two-thirds of all exits are stop-losses, 82% of
  them losers, bleeding **−$527k**. Classic whipsaw: enter on a Stage-2 breakout,
  get stopped out (~22 days later) as the breakout fails in choppy tape.
- **Rotation is healthy.** 69% win, +4.38% avg, +$503k. The capital-recycler is
  doing its job — it harvests winners and redeploys. Hypothesis (b) is **wrong**;
  rotation nearly single-handedly offsets the stop-out bleed.
- Net realized ≈ −$24k → PF 0.96. The whole game is stop-out bleed vs rotation
  harvest, and in 2020-2026 they cancel.

## When it bleeds — by entry year

| entry yr | n | win% | net $ | macro gate that year |
|---|--:|--:|--:|---|
| 2020 | 50 | 48% | **+$209,809** | Bull 38 / Neu 11 — COVID-V breakouts worked |
| 2021 | 69 | 45% | −$42,012 | Bull 50 |
| **2022** | 46 | **17%** | **−$181,602** | **Bear 26 / Neu 15 / Bull 10** |
| **2023** | 52 | **25%** | −$24,396 | **Bull 45 / Neu 6** (stops alone −$153k) |
| 2024 | 50 | 44% | +$4,572 | Bull 51 |
| 2025 | 31 | 26% | +$16,740 | Bull 38 / Neu 9 / Bear 3 |

Damage concentrates in **2022 (bear) and 2023 (narrow chop)** — two *different*
failure modes:

1. **2022 — bear-rally whipsaw.** The macro gate was correctly Bearish 51% of the
   year, yet **46 entries still fired** (17% win). They cluster in the Neutral/
   Bullish blips — the bear-market rallies that paint Stage-2 breakouts which then
   fail. The gate's Neutral state still permits buys, and Neutral in a bear is a
   trap.
2. **2023 — narrow-breadth whipsaw.** The macro gate called 2023 **88% Bullish**
   (the index rose), but the rally was mega-cap-only; the median stock chopped.
   Broad-universe Stage-2 breakouts failed at 25% win (−$153k stops). The
   index-level macro gate **does not measure breadth quality**, so it said "go"
   while most stocks were untradeable.

## Diagnosis

The stall is **entry-quality failure in choppy / narrow tape**, surfacing as
false-breakout stop-out churn. It is:

- **NOT a faster-MA problem** — proven dead on SPY this program
  (`project_trader_investor_modes`); a faster MA *amplifies* whipsaw.
- **NOT rotation churn** — rotation is the healthiest part of the engine (+$503k,
  69% win).
- **NOT idle capital** — 300 trades / 43.5 per yr; capital is deployed.

It is the **same disease as the SPY 30wk investor** (`spy-stage-timing-trades-2026-05-31.md`):
in fast-chop regimes, breakouts confirm late and fail, and the strategy bleeds the
gap. On SPY (timing-only) it shows as "re-enter higher 8 of 9 times"; on Cell E
(multi-symbol) it shows as "65% of exits are losing stop-outs." Two views of one
mechanism.

## Implications — the lever (ranked by evidence)

The payoff-geometry cut changes the lever ranking. Because the two degraded
quantities (deeper losers, shorter winners) pull stop placement in **opposite**
directions, **any lever that touches the stop is two-sided and self-defeating** —
which is the whole prior-rejection history. The levers that can win are the ones
that **change whether/where you deploy capital, not the stop on what you hold**:

1. **Broader universe — test SP500-specificity FIRST (knob-free, data-gated,
   highest-info).** Post-2020 SP500 leadership was narrow (mega-cap); the surviving
   *trends* may have been in mid/small-caps the SP500 universe simply doesn't contain.
   A top-3000 / Russell-3000 universe might restore the +11%/106d winners without
   touching a single parameter. Re-run this exact 2020-2026 diagnostic on a broad
   universe; if PF recovers, the "stall" is a universe-breadth artifact, not a
   strategy defect. **Blocker:** committed `test_data` covers SP500 only (broad-3000
   coverage ~1%); needs a deep-bar fetch first (`fetch-historical-data` skill,
   `build_deep_universe.sh`) — a prerequisite task, not a same-session run.
   (`project_strategic_pivot_broader_first`.)

2. **Regime / trend-quality ENTRY throttle — the one mechanism class that escapes the
   two-sided tension.** Gating *entry count* (not the stop) is asymmetric in our
   favour: fewer entries when trend-quality is poor → fewer −2.52% deep losers,
   while the stop on surviving winners is untouched. Candidate triggers, all
   Weinstein-faithful (spine intact — still Stage-2-only, still breakout+volume, we
   *tighten the macro/breadth gate*, never remove it):
   - **Breadth gate** — A/D or %-above-30wk-MA threshold; 2023 (88% index-"Bullish",
     25% win) shows the index-level gate blind to narrow breadth. The run already
     loads "AD breadth bars" (under-weighted today).
   - **Macro-Neutral as no-buy** — 2022's bleed entered through Neutral/Bullish
     bear-rally blips; make Neutral block new entries.
   - **Trend-quality regime filter** — a rolling measure (e.g. recent realized
     winner-hold, or % of universe in sustained Stage 2) that throttles new deployment
     when the regime is low-trend-quality, parking capital in cash. Closest to
     Weinstein's macro-gate spirit, generalised from "is the index up" to "are trends
     actually extending."

3. **Stop / sizing redesign — deprioritised (inherent two-sided tension + explorative
   flag).** Vol-scaled stops would cap the −2.52% losers but shave the +4.32% trailed
   winners; the data shows this trade-off is real, and stop/sizing is the flagged
   over-explorative area (`feedback_strategy_mechanic_changes_too_explorative`). Not
   a first move.

Each new mechanism lands as a **default-off config axis**
(`experiment-flag-discipline.md`) and must clear the **deep cell + confirmation grid**
(`promotion-confirmation.md`) before any default flips. The mandatory regime cell here
is a window with **sustained trends** (2010-2019 or the deep pre-2009): a throttle
tuned to dodge 2021-2025 chop must not strangle the 2010-2019 / 2020-COVID-V regimes
where the fast breakouts *made* the money (+$396k in 2020 alone). That cross-regime
test is the gate — and it is why the broad-universe path ranks first: it can restore
the edge *without* a throttle that risks the good regimes.

## 2010-2026 within-run regime split — the clean controlled comparison

Same config, same $1M start in 2010; split the realized trades at 2020 (exit-year
basis). 16y run: 237.6% / $3.38M / PF 1.31 / 38% win / Sharpe 0.65 / MaxDD 17.5%.

| era | trades | win% | realized net | stop share | **profit factor** |
|---|--:|--:|--:|--:|--:|
| **2010-2019** | 438 | 39% | **+$1,616,634** | 59% | **1.78** |
| **2020-2026** | 232 | 37% | **−$264,348** | 61% | **0.88** |

**The edge didn't shrink — it inverted.** Realized profit factor fell from 1.78 to
0.88; the 2020-2026 era is realized-net *negative*. The final $3.38M was essentially
all earned by end-2019 (~$1M→$2.6M) plus unrealized float; "flat-to-down since 2020"
is literally that realized trading stopped making money in 2020.

### It is regime-WIDE post-2020, not one bad year

| yr | net | PF | stop_net | rot_net | note |
|---|--:|--:|--:|--:|---|
| 2020 | +$396k | 2.17 | +$31k | +$365k | COVID-V — breakouts worked |
| **2021** | **−$447k** | **0.35** | **−$369k** | −$208k | melt-up + violent sector rotation |
| 2022 | −$111k | 0.64 | −$171k | +$97k | rate-shock bear |
| 2023 | +$39k | 1.15 | −$160k | +$200k | narrow mega-cap bull |
| 2024 | +$70k | 1.24 | −$230k | +$305k | rotation carries it |
| **2025** | **−$281k** | **0.18** | **−$326k** | +$45k | AI/tariff chop |

The worst years (2021 melt-up, 2025 chop, 2022 bear) span *opposite* macro regimes —
so the cause is not "bears" specifically. The through-line: post-2020 the **stop-loss
net cost balloons** (−$369k / −$326k / −$230k in 2021/2025/2024) while **laggard
rotation stays healthy in every year** (positive 2022-2024). The stop *share* barely
moves (59%→61%) — what changed is that failed breakouts now fall *further* before the
stop catches, and the surviving winners shrank relative to them. Higher post-2020
index volatility + narrower breadth degrade breakout quality across the board.

## The mechanism — payoff-geometry inversion (the definitive cut)

Decomposing the 16y run's realized trades by win/loss magnitude (not just count)
pins the mechanism exactly. **The hit rate barely moved — the payoff geometry
inverted:**

| | 2010-2019 | 2020-2026 | change |
|---|--:|--:|---|
| Win rate | 38.6% | 37.1% | ≈flat |
| **Avg stop-out loss** | −0.96% | **−2.52%** | **2.6× deeper** |
| **Avg winner** | +11.26% | **+7.64%** | −32% |
| **Avg winner hold** | 106d | **63d** | −40% |

The edge was never about *how often* it won (~38% both eras) — it was the
asymmetry: **tiny losses, big winners**. Post-2020 that asymmetry collapsed from
both ends:

- **Losers fall 2.6× deeper** (−0.96% → −2.52%). Failed breakouts run much further
  against the position before the stop catches — a higher-volatility / gappier-tape
  effect.
- **Winners shrink and shorten** across *both* exit channels (not a rotation
  artifact — every channel degraded uniformly):

  | winner exit channel | 2010-2019 | 2020-2026 |
  |---|--:|--:|
  | via laggard_rotation | +13.04% / 122d | +9.34% / 75d |
  | via trailing stop | +7.74% / 76d | +4.32% / 40d |

  **Post-2020 trends are simply shorter and shallower.** A Stage-2 winner that ran
  122 days to +13% pre-2020 now runs ~75 days to +9% before rotation, or 40 days to
  +4% before the trailing stop. Nothing in the machinery changed — the market stopped
  handing out sustained multi-month trends.

PF = (win rate × avg win) / (loss rate × avg loss). Plug it in: pre-2020
≈ (0.386 × 11.26)/(0.614 × 0.96) ≈ **1.78**; post-2020 ≈ (0.371 × 7.64)/(0.629 ×
2.52) ≈ **0.71** realized — the whole inversion is magnitude, not frequency.

### Why this explains the three prior knob-rejections

The two degraded quantities pull stops in **opposite** directions, so no single
timing knob can fix both:

- To cap the −2.52% deep losers you'd **tighten / speed up** the stop — but the
  surviving winners ride that *same* stop (+4.32% trailed winners), so a tighter
  stop shaves the winners too. (This is exactly why faster-MA / tighter-timing lost:
  it cut winners as much as losers.)
- To let the +7.64% winners run you'd **loosen** the stop / lengthen rotation
  patience — but post-2020 trends don't extend (75-day rotation winners mostly give
  back if held), so patience just converts small winners into round-trips.

Continuation-buys (#1366), hysteresis (#136x), early-admission, and the MA dial all
died because they each tuned **one side of a two-sided regime change**. The regime,
not the parameters, moved.

## Diagnosis (revised with the regime split)

The 2020-2026 stall is a **genuine, regime-wide collapse of the entry edge** —
realized PF 1.78 → 0.88. It is:

- **NOT one bad year** — 2021, 2022, 2025 all bleed across opposite regimes.
- **NOT rotation churn** (b) — laggard rotation is net-positive in nearly every
  post-2020 year; it is the one mechanism still working.
- **NOT idle capital** (c) — capital stays deployed (43.5 trades/yr fresh).
- **NOT a faster-MA fix** — proven dead on SPY (`project_trader_investor_modes`).

It is **false-breakout stop-out churn (a)** whose *cost per failure* rose in the
modern high-volatility / narrow-breadth regime. Same disease as the SPY 30wk
investor (`spy-stage-timing-trades-2026-05-31.md`): breakouts confirm late and
fail; SPY shows it as "re-enter higher 8/9 times," Cell E as "post-2020 stop-net
craters."

## Reproduce

```
scenario_runner --dir dev/backtest/cell-e-stall-diag --parallel 2 --no-emit-all-eligible
# outputs → dev/backtest/scenarios-<ts>/{cell-e-2020-2026-fresh-diag,cell-e-2010-2026-diag}/
```

The two diagnostic scenarios (canonical Cell E config = the
`goldens-sp500-historical/sp500-2010-2026.sexp` golden with expected bands
stripped; reproduce by dropping these under `dev/backtest/cell-e-stall-diag/`):

**`cell-e-2020-2026-fresh.sexp`** — fresh $1M start 2020, 2020 PIT universe:
```scheme
((name "cell-e-2020-2026-fresh-diag")
 (period ((start_date 2020-01-01) (end_date 2026-04-30)))
 (universe_path "universes/sp500-historical/sp500-2020-01-01.sexp")
 (universe_size 506)
 (config_overrides
  (((enable_short_side false))
   ((portfolio_config ((max_position_pct_long 0.14))))
   ((portfolio_config ((max_long_exposure_pct 0.70))))
   ((portfolio_config ((min_cash_pct 0.30))))
   ((enable_stage3_force_exit true))
   ((stage3_force_exit_config ((hysteresis_weeks 1))))
   ((enable_laggard_rotation true))
   ((laggard_rotation_config ((hysteresis_weeks 2))))))
 (cost_model ((per_trade_commission 0.0) (per_share_commission 0.0)
   (bid_ask_spread_bps 5.0) (market_impact_bps_per_pct_adv 0.0)))
 (expected ((total_return_pct ((min -100.0) (max 100000.0)))
   (total_trades ((min 0) (max 100000))) (win_rate ((min 0.0) (max 100.0)))
   (sharpe_ratio ((min -10.0) (max 10.0)))
   (max_drawdown_pct ((min 0.0) (max 100.0)))
   (avg_holding_days ((min 0.0) (max 100000.0))))))
```
The 2010-2026 variant is identical with `(period ((start_date 2010-01-01) ...))`
and `universe_path "universes/sp500-historical/sp500-2010-01-01.sexp"`.

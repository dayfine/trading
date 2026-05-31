# SPY stage-timing on the deep 2000-2026 window — the thesis confirmed

The 2009-2026 bull window had stage-timing *trailing* buy-and-hold (whipsaws on
fast V-dips, `spy-stage-timing-trades-2026-05-31.md`). The deep 2000-2026 window
(dot-com −49% + GFC −57%) **reverses it**: the 30-week investor strategy beats
BAH-SPY on *every* metric. This is the regime where capital preservation
compounds — exactly the user's thesis.

## Result — deep 2000-2026 (SPY, investor 30wk)

| Metric | BAH-SPY | Investor (SPY 30wk) | **Cell E (SP500)** |
|---|--:|--:|--:|
| Total return | 369.9% | 420.3% | **2379.3%** |
| Final NAV ($1M) | $4.70M | $5.20M | **$24.8M** |
| CAGR | 6.13% | 6.55% | **12.97%** |
| Sharpe | 0.41 | 0.61 | **0.62** |
| Sortino | 0.51 | 0.84 | **1.55** |
| Calmar | 0.11 | 0.35 | **0.56** |
| MaxDD | 55.3% | **18.8%** | 23.0% |
| Trades | 0 | 19 (47% win) | 820 (36% win) |

Note the investor MaxDD is **18.8% on BOTH the bull and the deep window** — the
drawdown control is regime-invariant; what changes is whether the avoided
drawdowns were fast-V (recover, so dodging costs upside) or sustained (don't
recover for years, so dodging compounds).

## The NAV trajectory — where the edge is made

| Date | Regime point | Investor NAV | BAH NAV | Investor / BAH |
|---|---|--:|--:|--:|
| 2000-01-03 | start | $1.00M | $1.00M | 1.00× |
| 2002-10-09 | dot-com bottom | $0.83M | $0.55M | **1.49×** |
| 2007-10-09 | pre-GFC peak | $1.22M | $1.09M | 1.12× |
| **2009-03-09** | **GFC bottom** | **$1.16M** | **$0.49M** | **2.39×** |
| 2020-03-23 | COVID bottom | $2.78M | $1.54M | 1.80× |
| 2025-12-30 | final | $5.20M | $4.70M | 1.11× |

The entire edge is made in the two bears. At the **GFC bottom the investor held
2.4× BAH's capital** — it sat in cash through the −55% crash and re-entered near
the bottom. That preserved base compounds for 16 years. The 2009-2025 bull lets
BAH claw back (it never sells), narrowing the final gap to 1.11× — but it never
fully closes, because the investor started the recovery from a far higher base.

## The two dodges (the favorable exit-high / re-enter-low round-trips)

- **Dot-com:** last meaningful long exit ~144 (Oct 2000), sat out the 144→~80
  collapse, re-entered the recovery at **91.56** (May 2003). Re-entered ~36% below
  the exit.
- **GFC:** exited the 2005-07 leg at **149.04** (Dec 2007, +24.5%), sat out the
  entire 149→68 crash, re-entered at **92.03** (May 2009). Re-entered ~38% below
  the exit.

These are the user's 100→50→100 → exit-80/re-enter-60 → compound-higher, twice
over. (Contrast: the 2009-2026 window's 8-of-9 re-entries were *higher* — fast-V
whipsaws.)

## Synthesis — the edge is regime-dependent drawdown insurance

Stage-timing is **drawdown insurance**: it pays a premium in fast-V bulls (trails
BAH) and pays out in sustained bears (beats BAH on everything). Over a full cycle
that contains real bears, the preservation compounds and it wins. The value
proposition is not "beat the market in good times" — it's **survive bad times with
capital intact, so you compound from a higher base.**

This also sets up the trader-vs-investor test: the 30wk investor already wins the
deep window. The open question is whether the 10wk trader preset can *also* win the
bull window (faster re-entry → fewer fast-V whipsaws) **without** giving back the
deep-window edge. (`dev/plans/weinstein-trader-investor-presets-2026-05-31.md`)

## Investor (SPY timer) vs Cell E (SP500 picker) — selection >> timing

The SPY-only investor is a single-instrument *market-timer*. **Cell E** is the
multi-symbol *capital-recycling stock-picker* (the product): SP500 universe, ~20
positions (`max_position_pct_long 0.14`, `max_long_exposure 0.70`, `min_cash 0.30`)
+ `enable_stage3_force_exit` (h1) + `enable_laggard_rotation` (h2). Run on the true
2000-2026 deep window with the deep GSPC golden (the scenario's prior 341.7%/0.78
number was measured pre-GSPC-floor-fix, so it only saw ~2017-2026).

**Cell E dominates — final NAV $24.8M vs the SPY investor's $5.20M (4.8×).** The
NAV trajectory shows why:

| Date | Regime | BAH | SPY investor | **Cell E** |
|---|---|--:|--:|--:|
| 2000-01 | start | $1.0M | $1.0M | $1.0M |
| 2002-10 | dot-com bottom | $0.55M | $0.83M | **$1.61M** |
| 2007-10 | pre-GFC peak | $1.09M | $1.22M | **$10.0M** |
| 2009-03 | GFC bottom | $0.49M | $1.16M | **$8.29M** |
| 2025-12 | final | $4.70M | $5.20M | **$24.8M** |

The lesson: **index timing (investor) buys you drawdown protection + a small
return edge; stock selection (Cell E) is the big lever.** Cell E was already *up
61%* at the dot-com bottom (it picked the non-tech winners that rose 2000-02 while
the index fell) and 10× by the 2007 peak — selection captures the cross-sectional
dispersion the index can't. Cell E's MaxDD (23%) is a touch higher than the SPY
timer's (18.8%) but a third of BAH's (55.3%), and it still carries the best Calmar
(0.56) and Sortino (1.55). So the SPY-only "investor" is the timing-only *floor*;
the production multi-symbol picker is where the alpha lives.

**Caveat — Cell E stalled 2020-2026:** it hit ~$25M by the 2020 COVID period and
is flat-to-down since (final $24.8M). That mirrors the SPY investor's fast-V
whipsaw struggles in the same 2020-2026 chop — a hint that the capital-recycling
mechanics (stage3 force-exit + laggard rotation) whipsaw in the modern fast regime
too, and a candidate for the trader-vs-investor / faster-MA investigation to
address at the multi-symbol level, not just on SPY.

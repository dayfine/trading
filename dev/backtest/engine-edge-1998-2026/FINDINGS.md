# Engine edge + correct-window barbell — FINDINGS (2026-06-21, overnight)

**Headline (honest, current code, the question "do we beat S&P?"):**
Over the full cycle **1998-2026 the engine beats S&P-price (+1100% vs +599%)** —
but the edge is **100% crash-protection, ~0% upside-capture.** It wins entirely by
sidestepping 2000-02 + 2008; in the 2009-26 bull it **badly lags** plain buy-hold
S&P (+130% vs +631%). The barbell is **regime-complementary insurance**, not a free
return boost, and a fixed 70/30 weight is a compromise optimal in **neither**
regime. Everything below is top-3000 PIT-1998, long-only Cell-E, current code,
per-share \$0.01 cost, reusing `/tmp/snap_top3000_1998_ls`.

## Phase A — engine vs S&P, like-for-like

Engine NAV is valued on `close_price` (simulator.ml:150), **not** `adjusted_close`
→ price-only, **no dividends** — so it is directly comparable to **SPX price
return** (GSPC 975.04→6816.89 = **+599%**). The comparison is fair (both exclude
dividends).

| 1998-2026 | total return | realized* | MaxDD | Sharpe | Calmar |
|---|---|---|---|---|---|
| **engine** (Cell-E, top-3000) | **+1100%** | ~+836% | 48.3% | 0.54 | 0.19 |
| SPX price (BAH) | +599% | — | ~57% (GFC) | — | — |
| SPY-timing floor | +478% | — | 24.3% | 0.57 | 0.26 |

*realized ≈ total − open MTM (unrealized \$2.64M of \$12M terminal NAV ≈ 24%). Even
on a realized basis (+836%) the engine beats SPX-price (+599%).

**Re-pin vs the cached headline:** `project_deep_1998_2026_contiguous` recorded
+1552% / MaxDD 35.9%. Current code (18 days of fixes: lazy market-state #1481,
cash-floor #1556, stale-exit #1487, per-share cost) gives **+1100% / MaxDD 48.3%**
— a **smaller edge and a materially WORSE drawdown**. The +1552%/35.9% headline was
optimistic; the honest current-code number is +1100% with a scary ~48% drawdown.

## Phase B — barbell weight surface (the user's #1 question)

Blend (`blend.awk`) engine vs the 1998-26 SPY-timing floor, full floor-weight grid:

| floor w | return | Sharpe | MaxDD | Calmar | Ulcer |
|---|---|---|---|---|---|
| 0.00 (pure engine) | 1100% | 0.537 | 48.3% | 0.183 | 16.2 |
| 0.20 | 1019% | 0.583 | 41.9% | 0.205 | 12.6 |
| 0.30 | 965% | 0.607 | 38.6% | 0.218 | 11.3 |
| 0.40 | 904% | 0.630 | 35.0% | 0.234 | 10.3 |
| 0.50 | 838% | 0.649 | 31.4% | 0.253 | 9.4 |
| 0.70 | 696% | **0.660** | 23.6% | **0.311** | 7.9 |
| 1.00 (pure floor) | 478% | 0.566 | 24.3% | 0.255 | 9.9 |

**Every weight beats S&P-price (+599%) up to ~0.65 floor** — even the Sharpe/Calmar
optimum (≈0.70) keeps +696%. So the barbell does NOT surrender the edge; it trades
return for drawdown on a smooth frontier. There is **no sharp knee** — the choice is
mandate-driven:
- **Keep the edge, light insurance:** w=0.30-0.40 → 900-965% return (beats S&P by
  +300-365pp), DD cut 48%→35-39%, Sharpe 0.61-0.63.
- **Max risk-adjusted:** w=0.70 → Sharpe 0.66 / Calmar 0.31, DD 23.6%, still +696%.

## The decomposition that reshapes the thesis (sub-window robustness)

Same surface on disjoint regimes — **vs S&P-price in each** (GSPC: 1998-2008
**−7.4%**, 2009-2026 **+631%**):

| 1998-2008 (dotcom+GFC) | return | Sharpe | | 2009-2026 (bull) | return | Sharpe |
|---|---|---|---|---|---|---|
| engine (w=0) | **+421%** | **0.77** | | engine (w=0) | +130% | 0.36 |
| floor (w=1) | +38% | 0.31 | | floor (w=1) | **+318%** | **0.73** |
| **S&P price** | **−7%** | — | | **S&P price** | **+631%** | — |

- **Crash decade:** engine **+421% vs S&P −7%** = +428pp alpha; adding floor *hurts*
  (Sharpe 0.77→0.62). Pure engine is optimal.
- **Bull decade:** engine **+130% vs S&P +631%** = **−501pp** (badly lags); even the
  timing floor (+318%) lags S&P by −313pp. Adding floor *helps* monotonically; pure
  floor is optimal.

**So the full-window "70/30 optimal" is a regime-averaging artifact.** In the crash
decade you want pure engine; in the bull you want pure floor (or just S&P BAH). 70/30
is optimal in neither — it's the least-bad compromise across two opposite regimes.
(This is the same bear→engine / bull→floor pattern the 06-20 grid showed in cells D
vs B/C; the 1998-26 split makes it unambiguous.)

## What this means (transferable why)

1. **The strategy's edge is crash-protection, not stock-picking upside.** It beats
   S&P over full cycles by losing far less in 2000-02 + 2008 (and catching the
   recoveries), NOT by outperforming in bulls — where it lags buy-hold badly. Any
   eval window that excludes a crash will show the strategy LOSING to S&P. This is
   the precise, honest answer to "do we beat S&P": **yes over full cycles via
   downside protection; no in sustained bulls.**
2. **The barbell is regime-complementary insurance.** Engine = crash alpha, floor =
   bull participation; they are anti-correlated by regime, which is *why* the
   full-cycle blend cuts drawdown so well. But a *fixed* weight can't be optimal in
   both regimes, and **regime-timing the weight is the known-dead lever**
   (`project_next_lever_decision_grading`: regime-gating = SPY-timing, worse). So the
   deployable recommendation is a *fixed* light-to-medium floor (0.30-0.50) chosen by
   drawdown tolerance, accepting it's a compromise — not a regime-switched weight.
3. **The cached +1552%/35.9% headline must be retired.** Honest current-code number:
   **+1100% / 48.3% DD**, edge concentrated in the crash decade.

## Recommendation
- For "beat S&P with a smoother ride over full cycles": **light-to-medium floor
  (w≈0.30-0.40)** keeps ~90% of the engine's S&P-beating return while cutting the
  48% drawdown to ~35-39% and lifting Sharpe. NOT 70/30 (gives up too much return
  for a marginal Sharpe gain that's itself a regime artifact).
- **Set expectations honestly:** this strategy will *underperform* S&P in sustained
  bull markets. Its mandate is full-cycle outperformance via crash avoidance.
- Open lever (Phase C): does a faithful *trader* preset (10wk MA / continuation /
  full sizing) reduce the 2009-26 bull-lag while keeping crash alpha? Motivated by
  the −501pp bull gap. Tested next if config-ready.

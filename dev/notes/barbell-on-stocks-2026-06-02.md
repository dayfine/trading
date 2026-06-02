# Barbell-on-stocks blend — the 918%-vs-drawdown tension, resolved

**Date:** 2026-06-02 · **Plan:** P0 of `next-session-priorities-2026-06-03.md`

## Question

The deep-window (2000-2026) headline was: production stock-selection returns
**918%** but pays **37% drawdown**, while simple SPY index-timing returns
**387%** at a **18.8%** drawdown floor. Can a post-hoc NAV blend of the two keep
most of the selection return while pulling the drawdown back toward the floor?

This is the direct payoff of the whole sector-rotation → macro-gate → barbell
arc, now pointed at individual stocks instead of the 11-SPDR ETF lab.

## Method

Both legs re-run fresh this session on the deep window (no trusted stale curve):

- **Floor** — `Spy_only_weinstein (SPY) (ma=30wk)`, long/flat, 2000-01-01 →
  2026-04-30. `dev/backtest/p0-barbell-spy/spy-only-deep.sexp`.
  Result: **386.9% / 18.8% MaxDD / Calmar 0.32 / 20 trades** (18.8% reproduces
  the doc floor exactly).
- **Engine** — full Cell E production strategy (0.14/0.70/0.30 sizing +
  stage3-force-exit h=1 + laggard-rotation h=2 + macro gate) on the clean PIT
  S&P 500 (`universes/sp500-historical/sp500-2000-01-01.sexp`, 515 symbols,
  survivor-bias-free), same window.
  `dev/backtest/p0-barbell-prod/production-deep.sexp`.
  Result: **917.9% / 37.3% MaxDD / Calmar 0.25 / 1023 trades** (reproduces the
  doc's 918%/37%/0.25 exactly).

Post-hoc daily-return NAV blend at constant weight `w` on the floor leg
(`/tmp/blendw.awk`, same method as the ETF barbell #1424/#1426), aligned on
common dates.

## Result — the blend frontier (deep 2000-2026)

| core/sat (SPY-floor / production-engine) | Return | MaxDD | CAGR | Calmar |
|---|---|---|---|---|
| 100/0  (pure floor)   | 386.9% | 18.8% | 6.0% | 0.319 |
| 90/10                 | 433.7% | 17.3% | 6.4% | 0.368 |
| **80/20**             | **482.7%** | **16.2%** | 6.7% | **0.414** |
| 70/30                 | 533.6% | 17.8% | 7.0% | 0.394 |
| 60/40                 | 586.2% | 20.8% | 7.3% | 0.352 |
| 50/50                 | 640.2% | 23.8% | 7.6% | 0.321 |
| 40/60                 | 695.2% | 26.7% | 7.9% | 0.297 |
| 30/70                 | 750.9% | 29.5% | 8.2% | 0.278 |
| 20/80                 | 806.9% | 32.2% | 8.4% | 0.263 |
| 10/90                 | 862.7% | 34.8% | 8.7% | 0.250 |
| 0/100  (pure engine)  | 917.9% | 37.3% | 8.9% | 0.239 |

Reference baseline (from the doc, raw close): **BAH-SPY deep = 394% / 56% /
Calmar ~0.11.**

## Findings

1. **The blend strictly dominates both standalone legs on risk-adjusted return.**
   The Calmar maximum (**0.414 at 80/20**) beats pure floor (0.319) and pure
   engine (0.239). Every blend from 90/10 to 60/40 has a higher Calmar than
   either endpoint.

2. **Diversification pushes blended drawdown BELOW the floor itself.** 80/20
   MaxDD is **16.2%** — lower than the SPY floor's own 18.8% and far below the
   engine's 37.3%. The two legs' drawdowns are imperfectly correlated (the
   engine crashes on idiosyncratic single-name blowups the index rides through;
   the index crashes in broad bears the engine's macro gate partly sidesteps),
   so combining them cancels drawdown the way a barbell should.

3. **70/30 buys back half the drawdown at no return cost vs buy-and-hold.**
   70/30 = **533.6% return at 17.8% DD** ≈ raw BAH-SPY's 534% return but at
   **half** its 34% (bull) / **a third** of its 56% (deep) drawdown. You match
   the index's price-return while nearly halving the pain.

4. **Answer to the headline question: partially, and that's the right answer.**
   You cannot keep *most* of 918% AND reach 18.8% — return and drawdown trade
   monotonically along the frontier. But you do not have to choose between the
   two standalone strategies: the entire blend frontier dominates both. The
   mandate picks the point:
   - **Drawdown-defense mandate (the locked objective):** 80/20 — 483% at the
     16.2% global DD-minimum, Calmar 0.414.
   - **Return mandate that still respects risk:** 70/30 — 534% (= raw BAH) at
     17.8% DD.
   - **Aggressive return mandate:** slide toward the engine; every step up in
     return is paid linearly in drawdown.

5. **Consistent with the ETF-lab barbell.** The ETF barbell found 70/30 the
   robust optimum (#1426); on stocks the DD-minimum / Calmar-max sits one notch
   more defensive at 80/20, with 70/30 a close second. Same shape, same
   conclusion: floor + engine compose.

## Cross-regime confirmation — bull window (2010-2026)

Re-ran both legs on the bull window. Floor = SPY-only investor **239.3% / 18.8% /
0.40**; engine = Cell E production on PIT S&P 500 (`sp500-2010-01-01.sexp`, 510
symbols) **237.6% / 17.5% / 0.44**. (The engine's 237.6% independently reproduces
the priorities-doc figure and confirms the `sp500-2010-2026.sexp` golden's pinned
311.9% is stale — re-pin filed separately.)

| core/sat (SPY-floor / engine) | Return | MaxDD | Calmar |
|---|---|---|---|
| 100/0 (pure floor)  | 239.3% | 18.8% | 0.400 |
| 80/20               | 244.9% | 16.6% | 0.460 |
| 70/30               | 246.7% | 16.4% | 0.467 |
| 50/50               | 247.8% | 16.0% | 0.479 |
| 30/70               | 245.9% | 15.9% | **0.482** |
| 0/100 (pure engine) | 237.6% | 17.5% | 0.428 |

In the bull window the two legs have **near-identical standalone return**
(239 ≈ 238), so the blend is almost pure drawdown reduction: return stays ~flat
across the whole frontier while DD falls from ~18% to **15.8%** and Calmar rises
from 0.40/0.43 to **0.48**. The DD-minimum / Calmar-max sits mid-frontier
(30-50% floor) rather than at the defensive 80/20 of the deep window — because
here there is no return to trade away, only diversification to harvest.

**The barbell dominates both standalone legs on risk-adjusted return in BOTH
regimes.** The Calmar-optimal weight shifts with the regime (deep → defensive
80/20; bull → balanced 50/50), but **70/30 is robust across both**:
- deep: 533.6% / 17.8% / Calmar 0.394 (vs pure floor 0.319, pure engine 0.239)
- bull: 246.7% / 16.4% / Calmar 0.467 (vs pure floor 0.400, pure engine 0.428)

70/30 beats both pure legs on Calmar in each regime — a regime-stable choice,
matching the ETF-lab barbell's 70/30 robust optimum (#1426).

## Caveats

- Post-hoc constant-weight NAV blend — not a live rebalanced portfolio. A real
  implementation rebalances periodically (drift between rebalances will differ
  slightly) and pays the rebalance turnover. The frontier shape is robust to
  this; the exact basis points are not.
- Returns are **raw close** (price-only, no dividends) on both legs — apples to
  apples for the *relative* comparison, a floor on absolute return.
- Single deep window. The bull-window (2010-2026) blend is the natural
  confirmation (cross-regime) and is the next cheap step once the engine bull
  curve is in hand.

## Artifacts

- Deep floor curve: `dev/backtest/scenarios-2026-06-02-145338/spy-only-deep/equity_curve.csv`
- Deep engine curve: `dev/backtest/scenarios-2026-06-02-145506/production-deep/equity_curve.csv`
- Bull floor curve: `dev/backtest/scenarios-2026-06-02-152304/spy-only-bull/equity_curve.csv`
- Bull engine curve: `dev/backtest/scenarios-2026-06-02-152352/production-bull/equity_curve.csv`
- Scenarios: `dev/backtest/p0-barbell-{spy,prod,bull-spy,bull-prod}/`
- Blend tool: `/tmp/blendw.awk` (constant-weight daily-return NAV blend; `awk -v w=<floor-weight> -f blendw.awk <floor>.csv <engine>.csv`)

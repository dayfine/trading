# SPY strategy-mode comparison — investor / trader / Cell E / buy-and-hold

The consolidated comparison of every Weinstein "mode" on SPY, across a bull regime
and a deep bear-containing regime. Answers: *which mode, and does the
capital-preservation thesis hold?* Built on the SPY reference testbed (#1397) +
the `ma_period_weeks` dial (#1401) + the deep-history data (#1388, SPY 1993-2026).

## The matrix

**Bull window — 2009-06-01 → 2025-12-31** (post-GFC bull + fast V-dips, no deep bear):

| Mode | Total return | Trades | Win % | MaxDD | Sharpe | Calmar |
|---|--:|--:|--:|--:|--:|--:|
| Buy-and-hold SPY | **619.1%** | 0 | — | 34.0% | 0.78 | 0.37 |
| **Investor (SPY 30wk)** | 317.9% | 10 | 70% | **18.8%** | 0.77 | **0.48** |
| Trader (SPY 10wk) | 186.7% | 28 | 14% | 26.9% | — | — |
| Cell E (SP500 picker)¹ | — | — | — | — | ~0.94 (15y) | — |

**Deep window — 2000-01-01 → 2025-12-31** (dot-com −49% + GFC −57% + COVID + modern):

| Mode | Total return | Final NAV | Trades | Win % | MaxDD | Sharpe | Calmar |
|---|--:|--:|--:|--:|--:|--:|--:|
| Buy-and-hold SPY | 369.9% | $4.70M | 0 | — | 55.3% | 0.41 | 0.11 |
| **Investor (SPY 30wk)** | 420.3% | $5.20M | 19 | 47% | **18.8%** | 0.61 | 0.35 |
| Trader (SPY 10wk) | 172.5% | $2.73M | 46 | 24% | 30.4% | — | — |
| **Cell E (SP500 picker)** | **2379.3%** | **$24.8M** | 820 | 36% | 23.0% | 0.62 | **0.56** |

¹ Cell E on the bull window is from the prior 15y measurement (Sharpe ~0.94), not a
directly-comparable single-backtest; its deep-window number is a fresh 2000-2026 run
with the deep GSPC golden.

## Four findings

**1. Investor 30wk is the sweet spot for index timing — drawdown insurance.**
MaxDD **18.8% on BOTH windows** (vs BAH 34%/55%). It *trails* BAH in the fast-V bull
(missed-upside-in-cash > drawdown saved) but *beats* BAH on every metric through the
deep window (return, Sharpe, Calmar, Sortino, MaxDD) — because the two sustained
bears produce favorable exit-high/re-enter-low round-trips (dot-com exit ~144 /
re-enter 92; GFC exit 149 / re-enter 92). At the GFC bottom the investor held 2.4×
BAH's capital. The compounding thesis holds **in the regime it was designed for**.
(`spy-deep-window-2026-05-31.md`, `spy-stage-timing-trades-2026-05-31.md`.)

**2. Trader 10wk is REJECTED — strictly worse everywhere.** The faster MA does NOT
fix the whipsaws; it *amplifies* them. On both windows the 10wk preset has ~3× the
trades, ~⅓ the win rate, HIGHER drawdown, and roughly half the return of the 30wk
investor — and it loses to plain buy-and-hold on the deep window. The intuition that
"a faster MA re-enters closer to the V-bottom" is overwhelmed by its noise
sensitivity: it exits on every minor dip and re-enters on every minor bounce
(death by a thousand cuts; 14-24% win rate). **For index timing, 30wk dominates
10wk.** (Caveat: this tests the MA-period dial *in isolation* — not Weinstein's full
trader *package* of 10wk + continuation entries + early exits + sizing, which is
meant for individual stocks, not index timing. But the faster-MA-alone hypothesis is
clearly dead.)

**3. Selection ≫ timing — Cell E is the real lever.** The multi-symbol
capital-recycling stock-picker returned **2379% / $24.8M** on the deep window — 4.8×
the SPY investor's $5.20M and 5.3× buy-and-hold. Index *timing* (investor) buys
drawdown protection + a small return edge; stock *selection* (Cell E) captures the
cross-sectional dispersion the index can't (Cell E was already up 61% at the dot-com
bottom, picking the non-tech winners). The single-instrument timer is the
*timing-only floor*; the production picker is where the alpha lives.

**4. The edge is regime-dependent.** Stage-timing is drawdown insurance: it costs a
premium in fast-V bulls and pays out in sustained bears. Over a full cycle with real
bears, capital preservation compounds and it wins. The value proposition is not "beat
the market in good times" — it's "survive bad times with capital intact, so you
compound from a higher base."

## Implications for the main strategy

- **Keep the 30-week MA.** The faster-MA "trader mode" is a net negative on index
  timing; do not pursue 10wk for the main strategy on the basis of whipsaw-reduction
  — it does the opposite.
- **Cell E stalled 2020-2026** (flat from ~$25M; mirrors the SPY investor's fast-V
  whipsaw struggles). The modern fast-chop regime hurts the multi-symbol recycler
  too — but the answer per finding 2 is NOT a faster MA. Candidate investigations:
  the *other* trader dials (continuation entries, sizing) as a coherent package, or
  regime-aware exposure, tested per `weinstein-faithful-core.md`.
- The `ma_period_weeks` dial (#1401) stays as a **default-off experiment axis**
  (default 30 = investor, bit-identical); the trader-10wk rejection is recorded, so
  the next session doesn't re-test it.

## Reproduce
`scenario_runner --dir <dir>` with `spy-investor.sexp` / `spy-trader.sexp` (bull) and
deep variants (`ma_period_weeks 10/30`, period 2000-2026, `TRADING_DATA_DIR` → the
deep SPY+GSPC data). Deep SPY: `build_deep_universe.sh` / `fetch-historical-data`
skill (SPY.US 1993-2026).

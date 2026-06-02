---
name: Rolling drawdown / loss tracking
description: Design item — 20-25% portfolio drawdown circuit breaker per Weinstein Ch. 7, partially covered by macro signal
type: project
originSessionId: 13cc0e7c-1511-4185-b9fc-fec28936391c
---
Weinstein (Ch. 7) prescribes a weekly portfolio valuation with a 20-25% drawdown circuit breaker: "move to the sidelines until the probabilities of success become favorable." He identifies two failure modes:

1. **Buying too far above stops** — position sizing issue. Already handled by `risk_per_trade_pct` which calibrates size to stop distance.
2. **Whipsawed by repeated small losses** — choppy market where breakouts keep failing. The macro filter (Stage 4 → no new buys) does NOT catch this, because the market isn't clearly Stage 4 — it's oscillating. You bleed 1% at a time across many positions.

**Current coverage:** The macro signal handles regime shifts (clear bear markets), and per-trade risk sizing limits individual losses. But neither catches the "death by a thousand cuts" scenario in choppy sideways markets.

**Decision (2026-04-12):** Add max drawdown as a simulation metric first (already computed in backtest tests). Leave the hard stop ("move to sidelines") as a future config option. The metric enables tuning; the hard stop needs more design (what triggers re-entry?).

**How to apply:** When working on simulation metrics or portfolio risk, consider whether the drawdown tracking belongs as:
- A simulation output metric (near-term, useful for parameter sweeps)
- A strategy-level circuit breaker (future, needs re-entry criteria design)

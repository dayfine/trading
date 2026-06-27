# Margin & trade-safety model

How the simulator models real broker margin, short-side capital requirements,
and tradeability — and how each control maps to actual broker/regulatory rules.
All controls are **default-off no-ops** (`.claude/rules/experiment-flag-discipline.md`):
with defaults, the simulator is bit-identical to a frictionless long-only engine.
Research basis: `dev/notes/long-short-margin-mechanics-2026-06-12.md` (Reg-T,
FINRA 4210, Schwab/IBKR).

## 1. Margin accounting (`Margin_config`, issue #859)

`trading/trading/weinstein/portfolio_risk/.../margin_config.mli`. Master switch
`enabled` (default `false`). When off, short proceeds credit cash directly
(legacy Stance-A) — no collateral lock, no fee, no maintenance check.

| Field | Default | Real-world rule it models |
|---|---|---|
| `initial_margin_pct` | 0.50 | **Reg-T initial margin** (12 CFR 220): a short locks 150% of notional — 100% from the short proceeds (held as collateral) + 50% additional equity. `total_collateral_factor = 1.0 + initial_margin_pct = 1.50`. |
| `maintenance_margin_pct` | 0.25 | **FINRA 4210 maintenance**: when equity ratio `(entry·qty + locked − price·qty)/(price·qty)` falls below this, the position is flagged for forced buy-to-cover. |
| `short_borrow_fee_annual_pct` | 0.005 (50 bps) | **Stock-borrow / hard-to-borrow fee** (liquid SP500 reference). Accrued daily as `notional · rate / 252`. |

Key correctness property (refuted the "shorts inflate via free leverage" premise,
`project_short_realism_p0`): with collateral pre-locked at entry, a long entry is
**no longer funded by short proceeds pledged as collateral** — fixing the
Stance-A long-sizing inflation. NAV never goes negative even margin-off because
the per-position sizing caps prevent free leverage.

## 2. Short-side price floor (`short_min_price`)

Scenario default 17.0. **Why $17:** FINRA's maintenance is the *greater of* a
per-share dollar floor or a percentage — `$5.00/share or 30%` for shorts ≥ $5,
and `$2.50/share or 100%` below $5. The 30% tier only binds cleanly above
`$5.00 / 0.30 ≈ $16.67`. Below that, shorts pay 83–100%+ maintenance — capital
parity with the position itself. The $17 floor keeps the short universe on the
efficient 30% tier and is the policy reason cheap shorts are excluded.

## 3. Force-liquidation (defense in depth)

`Force_liquidation` (portfolio_risk). Two triggers beyond stops: a portfolio
drawdown circuit-breaker and the margin-maintenance breach (§1). On trip it
returns force-liquidation events and can enter a `Halted` state that **suppresses
new entries** until recovery — the broker margin-call analogue. Aggregate
short-notional cap (G15) limits total short exposure at entry-decision time.

## 4. Liquidity-realism overlay (`Liquidity_config`, PR #1760)

`trading/trading/weinstein/strategy/.../liquidity_config.mli`. Default-off
(`min_entry_dollar_adv = 0.0`, `min_hold_dollar_adv = 0.0`).

| Field | Armed value (deep runs) | Models |
|---|---|---|
| `min_entry_dollar_adv` | 1e6 ($1M/day) | Entry gate: drop a candidate whose trailing dollar-ADV is below this — you cannot establish a position you can't fill. |
| `min_hold_dollar_adv` | 5e5 ($0.5M/day) | Held-position degradation exit: a name we already hold whose ADV decays below this is exited *before* it becomes untradeable. |

Motivation: a delisted micro-cap held into illiquidity (ELCO ~2 shares/day)
produced a fake −48% single-day NAV crash when a spurious high-tick tripped the
short stop's worst-case cover. The overlay detects the degradation from
decision-time data and exits first. Armed on the broad deep run: worst day
−48% → −8.45%, MaxDD 55% → 41.5% (`dev/backtest/DEEP_RESULTS.md`).

## 5. Known consistency gap (universe vs gate)

The broad PIT top-3000 universe is built by liquidity **rank** (top-N by trailing
60-day $-volume) plus optional `min_price` / `min_avg_dollar_volume` floors — not
an absolute $-ADV standard equal to the overlay's `min_entry_dollar_adv`. So with
the overlay **off** (default), the backtest admits names the armed-live strategy
would gate out (the ELCO/APPB class), especially in early years when the 3000th
name's ADV is well below $1M. **Two fixes, single-source-of-truth preferred:**
(a) build the universe with a $-ADV floor matching the gate, or (b) always arm the
entry gate so the strategy enforces the standard regardless of universe
composition. See `dev/notes/regime-edge-synthesis-2026-06-27.md` §Thread-D.

## Broker mapping summary

| Control | Reg-T / FINRA | Schwab / IBKR practice |
|---|---|---|
| 150% short collateral | Reg-T initial | Both ≥ Reg-T; IBKR risk-based can exceed |
| 25% long / 30% short maintenance | FINRA 4210(c) | Both ≥ FINRA; per-share floors as above |
| 50 bps borrow fee | n/a (market) | Liquid names ~ tens of bps; HTB far higher |
| $17 short floor | derived from 4210 tiers | policy choice for capital efficiency |
| Force-liq / halt | margin call | both auto-liquidate on maintenance breach |

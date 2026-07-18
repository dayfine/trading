# Status: margin-realism

## Last updated: 2026-07-17

## Status
IN_PROGRESS

## Interface stable
NO

## Track scope

Levered long-short realism per
`dev/plans/levered-longshort-margin-realism-2026-07-14.md`: a margin model that
prices leverage and survives squeezes, so a levered long-short config can be
quoted with honest costs (not old Run-E's free-leverage fiction). Four milestones
M1–M4; each lands default-off behind its own config field (R1/R2).

## M1 — Long buying power + priced margin interest

Plan: `dev/plans/margin-m1-buying-power-2026-07-16.md`. Split into M1a (this PR)
and M1b (follow-up).

- [x] **M1a — buying-power ceiling + priced-interest primitives (default-off).**
  Branch `feat/margin-m1-buying-power`.
  - New pure module `Long_buying_power`
    (`trading/trading/weinstein/strategy/lib/long_buying_power.{ml,mli}`):
    `long_notional_ceiling` (generalizes the #1965 exposure cap into
    `min(exposure_term, margin_term)`; `margin_term = equity / initial_long_margin_req`
    for a fractional requirement, `Float.infinity` for a cash account `req >= 1.0`),
    `daily_long_margin_rate`, `long_margin_interest_charge`.
  - Config (`weinstein_strategy_config.{ml,mli}`): `initial_long_margin_req`
    `[@sexp.default 1.0]` (leverage dial) + `long_margin_rate_annual_pct`
    `[@sexp.default 0.0]` (priced debit). Both R1 no-ops at default; both
    Overlay_validator-targetable axes (R2).
  - Wiring: `Screening_notional.make_entry_walk_state` now derives
    `long_notional_cap` via `Long_buying_power.long_notional_ceiling` — bit-identical
    at defaults (both terms `infinity`) and for E-capped (`min(equity, inf) = equity`).
  - Tests: `test_long_buying_power.ml` pins ceiling math (default→infinity,
    E-capped→equity, exposure/margin/min interplay, req≤0 guard), interest math
    (rate 0→0, positive debit→`debit*annual/252`, debit≤0→0), config round-trip +
    pre-M1 back-compat parse.
  - Verify: `dune build && dune runtest trading/trading/weinstein/strategy/test`
    (container: `docker exec -e TRADING_DATA_DIR=/workspaces/trading-1/trading/test_data
    trading-1-dev bash -c 'cd /workspaces/trading-1/<ws>/trading && eval $(opam env)
    && dune runtest trading/trading/weinstein/strategy/test'`).

## Follow-ups

- [x] **M1b-1 — entry-walk cash-gate leverage relaxation (default-off).**
  Branch `feat/margin-m1b-live-leverage`. The strategy-layer half of M1b: the
  entry-walk cash gate (`Entry_audit_capture.check_cash_and_deduct`) now lets a
  LONG draw beyond available cash when leverage is engaged
  (`initial_long_margin_req < 1.0`), driving `remaining_cash` negative (the debit
  / `borrowed_balance`). The buying-power ceiling from M1a
  (`long_notional_cap = min(exposure_term, equity/req)`, finite whenever leverage
  engages) is the sole bound, enforced by the existing `check_long_notional_cap`
  gate + cash-refund path — so the debit is capped at `equity/req`.
  `Screening_notional.entry_walk_state` gains `leverage_enabled : bool` (derived
  in `make_entry_walk_state` from the config) + a `borrowed_balance` accessor
  (`max 0 (-remaining_cash)`). R1: at the default cash-account setting
  (`req = 1.0` → `leverage_enabled = false`) and for every short, the cash gate
  is byte-identical to pre-M1b; `classify_candidate`'s new `?leverage_enabled`
  defaults `false`, so all existing callers/goldens are unchanged. No new config
  field (reuses M1a's `initial_long_margin_req`). Tests in
  `test_entry_audit_capture.ml` (7 new): default-rejects-over-cash,
  leverage-funds-over-cash (debit), leverage-does-not-relax-shorts,
  funds-under-ceiling-keeps-debit, ceiling-binds-and-refunds,
  walk-state-flag-from-config, borrowed_balance-derives-from-debit.
  Verify: `dune runtest trading/weinstein/strategy/test` (container path
  `/workspaces/trading-1/.claude/worktrees/<ws>/trading`).
- **M1b-2 — make the debit persist + priced (default-off).** M1b-1 changes only
  the strategy-layer entry decision; the resulting levered buys are still
  rejected by the **portfolio cash floor** (`Portfolio_cash_floor.check` requires
  `current_cash + cash_change + neg_pnl >= 0`, applied at every fill via
  `Cancel_handler._try_apply_trade → Portfolio.apply_single_trade`). To make the
  debit persist and be priced, M1b-2 needs: (a) a portfolio-side debit mechanism
  — either a dedicated `long_margin_debit` field on `Portfolio.t` written by a
  long-margin-aware apply routed at the `Cancel_handler` fill seam (mirroring the
  short-side `Portfolio_margin.apply_single_trade_with_margin`), or a relaxation
  of the cash floor to permit negative cash bounded by the buying-power headroom;
  (b) per-tick interest accrual of `Long_buying_power.long_margin_interest_charge`
  on the outstanding debit, mirroring how `Margin_runner.tick` invokes
  `Portfolio_margin.accrue_daily_borrow_fee` from the simulator; (c) exits pay
  down the debit before free cash; (d) thread `long_margin_rate_annual_pct` from
  the Weinstein config into the simulator deps. **This is the A1 structural piece
  — it modifies core `Portfolio` / simulator beyond the sanctioned accrual mirror,
  so it needs a decision-item review (coordinate with feat-weinstein).** Kept out
  of M1b-1 to keep that PR strategy-scoped and <500 LOC. `[non-blocking]`.
- **M2** — long-side maintenance / force-reduce (documented sell ordering).
- **M3** — short-side squeeze robustness (borrow availability, HTB tiers, buy-in).
- **M4** — validation protocol (parity gates, squeeze stress cells, leverage
  surface via experiment-gap-closing + confirmation grid). No default flips and no
  levered number is quoted until M4.

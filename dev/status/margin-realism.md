# Status: margin-realism

## Last updated: 2026-07-16

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

- **M1b — make leverage live + priced (default-off).** The buying-power ceiling
  and interest math ship in M1a but are inert alone: the entry-walk `remaining_cash`
  gate still bounds new long funding by available cash, so a fractional
  `initial_long_margin_req` never binds and no debit balance is ever created.
  M1b relaxes the entry-walk cash gate to fund longs beyond cash up to the ceiling
  (tracking a `borrowed_balance`) and accrues `Long_buying_power.long_margin_interest_charge`
  per simulator tick (mirroring `Portfolio_margin.accrue_daily_borrow_fee`). Touches
  the entry walk + the simulation/portfolio seam (A1 core — coordinate with
  feat-weinstein). `[non-blocking]`.
- **M2** — long-side maintenance / force-reduce (documented sell ordering).
- **M3** — short-side squeeze robustness (borrow availability, HTB tiers, buy-in).
- **M4** — validation protocol (parity gates, squeeze stress cells, leverage
  surface via experiment-gap-closing + confirmation grid). No default flips and no
  levered number is quoted until M4.

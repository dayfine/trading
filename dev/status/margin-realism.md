# Status: margin-realism

## Last updated: 2026-07-19

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
- [x] **M1b-2 — make the debit persist + priced (default-off).** Branch
  `feat/margin-m1b2-portfolio-debit`. Shipped **Option A** (dedicated debit field
  on core `Portfolio`, mirroring the short-side precedent) — **user-approved
  decision item 2026-07-19**; the rejected Option B (relaxing
  `Portfolio_cash_floor` to allow negative cash) was NOT implemented, so the cash
  floor's semantics stay byte-identical for all non-levered paths.
  - `Portfolio.t += long_margin_debit : float` (default 0.0); the margin-cash
    accessors `available_cash` / `equity_cash` (`current_cash - long_margin_debit`)
    relocated into `Portfolio_margin` (portfolio.ml was at the 500-line hard
    limit; the accessors read margin fields that module maintains).
  - `Portfolio_margin.apply_single_trade_with_long_margin ~initial_long_margin_req`
    routes at the `Cancel_handler` fill seam: a levered long BUY
    (`req < 1.0`) whose cost exceeds available cash funds the shortfall into
    `long_margin_debit` (own cash spent first, `current_cash` never negative)
    instead of being floor-rejected; a long SELL pays the debit down before cash.
    At `req >= 1.0` (default cash account) it is bit-equal to
    `Portfolio.apply_single_trade`.
  - Equity honesty: `Portfolio_valuation.compute` (and the step's
    `position_value_total`) now read `equity_cash`, so NAV / drawdown / every
    metric subtract the debit — borrowed cash yields no phantom equity.
  - Per-tick interest: `Margin_runner.tick` calls
    `Portfolio_margin.accrue_daily_long_margin_interest ~rate_annual_pct`, which
    capitalizes `debit * (rate/252)` onto the debit each step (same quantity as
    `Long_buying_power.long_margin_interest_charge`, computed at the portfolio
    layer which cannot depend on the strategy layer). Rate 0.0 (default) → no-op.
  - Config threading: `initial_long_margin_req` + `long_margin_rate_annual_pct`
    flow `Weinstein config → Simulator.create_deps → fill seam / tick` (panel_runner),
    same path as `margin_config`. No new config fields (M1a's two suffice; R2 met).
  - R1: at defaults (`req = 1.0`, `rate = 0.0`) `long_margin_debit` stays 0, the
    floor is untouched, and every existing portfolio/simulator test passes
    unchanged. Tests: `test_margin_accounting.ml` (+10 long-margin unit tests —
    parity pin, levered-fill debit, equity-subtracts-debit, exit paydown
    ordering, N-tick interest, disarmed rejection, no-debit/zero-rate no-ops);
    `test_margin_runner.ml` (+2 — end-to-end levered run funds+prices the debit
    with honest NAV, and the `accrue_long_margin_interest` wrapper).
- [x] **M2 — long-side maintenance force-reduce (default-off).** Branch
  `feat/margin-m2-maintenance`. Marked-basis maintenance check for the LONG book:
  when `equity / marked_long_exposure < maintenance_long_pct` on a weekly (Friday)
  close, held longs are force-reduced weakest-first until the ratio is restored.
  - New pure module `Long_maintenance`
    (`trading/trading/simulation/lib/long_maintenance.{ml,mli}`), the long-book
    mirror of the short-side force-cover. `equity = equity_cash + marked_long_exposure`
    where `equity_cash = current_cash - long_margin_debit` (M1b-2), so only a
    levered book (debit > 0 pushing equity_cash down) can ever breach — an
    unlevered book has ratio ≥ 1.0.
  - **Sell ORDERING (the design center; Portfolio_floor bottom-tick lesson).**
    Weakest-first = **ascending unrealized return since entry** (`mark/entry - 1`),
    ties by symbol for determinism. Deliberately NOT the laggard-rotation metric
    (RS-vs-benchmark needs benchmark history + a `Bar_reader`, neither available at
    the margin seam; a margin reduce wants the position closest to underwater).
    Selling at the mark leaves equity unchanged and only shrinks the denominator,
    so ordering decides which names the book *keeps* — shedding losers keeps the
    let-winners-run tail. **Incremental, whole-position** (mirrors the short-side
    force-cover which closes whole flagged shorts): sheds one at a time until
    `equity / marked_long_exposure ≥ maintenance_long_pct*(1 + restore_buffer_pct)`
    (buffer 0.02, so mark noise doesn't re-trigger next tick), then stops —
    stronger positions untouched. Never a whole-book sweep unless equity ≤ 0
    (insolvent → liquidate). Every forced sale carries
    `exit_reason = StrategySignal { label = "maintenance_reduce" }` so forensics
    separate margin reduces from strategy exits; proceeds pay down
    `long_margin_debit` first (M1b-2), which is what restores the ratio.
  - **Cadence:** weekly-close (Friday) only, gated in
    `Long_maintenance.maintenance_reduce_transitions`, invoked from
    `Margin_runner.tick` alongside the short-side force-cover (dedup via the
    existing `dedup_strategy_exits_for_margin`: margin wins). Bar-cadence caveat
    (intraweek gap-through-maintenance) documented in the `.mli` as M3/M4 territory.
  - Config: `maintenance_long_pct` `[@sexp.default 0.0]` on
    `weinstein_strategy_config` (+ the re-declared `weinstein_strategy.mli` record).
    R1 no-op at 0.0 (a cash account has no maintenance requirement); R2
    Overlay_validator float axis (`test_variant_matrix.ml` +
    `test_maintenance_long_pct_axis_expands`). Threaded
    `Weinstein config → Simulator.create_deps → Margin_runner.tick` (panel_runner),
    same path as `long_margin_rate_annual_pct`.
  - Tests: `test_long_maintenance.ml` (10 — R1 default-never-fires, no-breach,
    weakest-first ORDER on a 3-position fixture, incremental restore, equity-wiped
    full liquidation, Friday-gate no-op on Monday, `maintenance_reduce` exit tag,
    unlevered/no-debit no-op, no-positions no-op) + `test_long_buying_power.ml`
    config round-trip / back-compat / default-no-op extended to `maintenance_long_pct`.
  - Also fixed a #2005 QC follow-up: `portfolio_summary.mli` / `metric_types.mli`
    now qualify the `portfolio_value - current_cash` identity as cash-account-only
    (a long-margin debit shifts the split by `+ long_margin_debit`).
- [x] **M3a — borrow availability + HTB/maintenance tier tables (default-off).**
  Branch `feat/margin-m3a-borrow-htb`. The deterministic half of M3's short-side
  squeeze robustness: three default-off mechanisms, each R1 no-op at its default,
  each an R2-searchable axis. Bit-identical to pre-M3a at every default (parity
  pinned by unit tests, no golden re-pin needed).
  - **Tier-table primitive** — new pure module `Short_margin_tiers`
    (`trading/trading/portfolio/lib/short_margin_tiers.{ml,mli}`): a
    price-banded, order-independent, piecewise-constant lookup (`tier_value
    ~tiers ~flat_fallback ~price` picks the tightest band strictly covering the
    price, else the flat fallback). An empty table is a bit-identical no-op.
    Thresholds live in tests / example configs, not baked in code.
  - **HTB tiered borrow rate** — `Margin_config` gains
    `short_borrow_rate_tiers : Short_margin_tiers.tier list [@sexp.default []]` +
    helpers `borrow_fee_annual_for_price` / `daily_borrow_rate_for_price`.
    `Portfolio_margin.accrue_daily_borrow_fee` now accrues {b per short position}
    at its marked price using the tiered daily rate; empty table → every price
    resolves to the flat 50bps → per-position sum equals the legacy
    `sum_short_notional * flat_daily_rate` bit-for-bit (distributivity).
  - **Maintenance tier table** — `Margin_config` gains
    `short_maintenance_tiers : Short_margin_tiers.tier list [@sexp.default []]` +
    `maintenance_pct_for_price`. `Portfolio_margin.check_maintenance_margin` uses
    the price-tiered threshold (sub-$5 → 100%, ~$5-17 → ≈83%, ≥ ~$17 → 30% base
    per the 2026-06-12 mechanics note) so low-priced HTB shorts flag for
    force-cover sooner; empty table → flat 25% → bit-identical.
  - **Borrow-availability entry gate** — new module `Short_borrow_gate`
    (`trading/trading/weinstein/strategy/lib/short_borrow_gate.{ml,mli}`, pure
    `filter` + bar-reader adapter `apply`), re-exported on `Weinstein_strategy`.
    Drops SHORT candidates whose trailing dollar-ADV (no-lookahead) is below the
    borrow-supply floor; longs untouched; missing reading never drops. Wired as
    the last gate in `Entry_assembly.assemble`. Config field
    `short_borrow_min_dollar_adv : float [@sexp.default 0.0]` on
    `weinstein_strategy_config` (+ re-declared `weinstein_strategy.mli` record).
    Dollar-ADV is the borrow-supply proxy (we have no locate feed).
  - **R2 axes** — top-level `short_borrow_min_dollar_adv` + nested
    `margin_config.short_{borrow_rate,maintenance}_tiers` all resolve through
    `Overlay_validator`; axis-expansion tests
    (`test_short_borrow_min_dollar_adv_axis_expands`,
    `test_short_maintenance_tiers_axis_expands`) in `test_variant_matrix.ml`.
  - **Bar-cadence caveat** documented in `short_borrow_gate.mli` + the tier
    `.mli`s: weekly-close marks cannot see an intraweek borrow recall / gap
    squeeze. Probabilistic buy-in / gap-through-maintenance stress paths are
    **M3b** territory (a documented seam, not built here).
  - Tests: `test_short_margin_tiers.ml` (6 — lookup: empty→fallback,
    tightest-band, middle band, uncovered→fallback, exclusive boundary,
    order-independence); `test_margin_accounting.ml` (+6 — tiered borrow fee
    per-price, empty-tiers flat parity, tiered maintenance flags a cheap short
    the flat 25% doesn't + flat-parity, config round-trip + pre-M3a back-compat
    parse); `test_short_borrow_gate.ml` (4 — zero-floor no-op, drops illiquid
    short / keeps liquid, never drops longs, missing-reading keeps); extended
    `test_long_buying_power.ml` (config default no-op + round-trip + pre-M3a
    parse for `short_borrow_min_dollar_adv`).
  - Verify: `dune runtest trading/portfolio/test trading/weinstein/strategy/test
    trading/backtest/walk_forward/test` (container path
    `/workspaces/trading-1/.claude/worktrees/<ws>/trading`).
- **M3b** — buy-in stress mode (PENDING follow-up): probabilistic forced cover
  on HTB names (config-gated, default-off) OR a stress-path mode for the
  promotion grid, including gap-through-maintenance scenarios (bar-cadence marks
  can't see intraweek gap squeezes — the documented M3a seam).
- **M4** — validation protocol (parity gates, squeeze stress cells, leverage
  surface via experiment-gap-closing + confirmation grid). No default flips and no
  levered number is quoted until M4.

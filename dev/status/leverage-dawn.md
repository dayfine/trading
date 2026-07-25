# leverage-dawn

Regime-conditional long leverage (P1b) — run the long book levered
(`initial_long_margin_req < 1.0`) ONLY while the primary index is in a young
post-bear "dawn" (its weekly MA has recently flipped up, a lagging real-time
signal), cash-account otherwise. The single regime payload the 2026-07-24 P1b
memo (`dev/notes/regime-dependency-evaluation-2026-07-24.md` §1/§3) green-lit
for a designed default-off WF-CV surface, after the M4 leverage REJECT's
barbell-shaped fold table. Deployment-intensity dial off the weekly MA — spine
untouched, not reversal timing (the label errs late by construction).

## Status
READY_FOR_REVIEW

Mechanism BUILT default-off (PR `feat/leverage-dawn`). The WF-CV surface run +
confirmation grid are a separate scheduled step (post-merge), NOT this PR.

## Last updated: 2026-07-24

## behavioral_qc
- 2026-07-24 rework (QC iteration 1, PR #2077): addressed B1 — the dawn leverage
  never funded. The mechanism swapped `initial_long_margin_req` only on the
  entry-walk config (sizing), but the simulator (the FUNDING authority,
  `Panel_runner` → `Simulator.create_deps`, fixed per run at the base req) still
  ran at the base 1.0 cash-account req and floor-rejected the levered dawn
  increment. Redesigned to **permissive funding / gated sizing**: the simulator
  funds at a permissive base `initial_long_margin_req` (armed cells set it to the
  most-permissive dawn rung, e.g. 0.75); the entry walk gates *when* to request
  leverage — dawn week → dawn rung, off-dawn → raised to cash-account so no new
  borrowing starts. `Leverage_dawn.validate` now enforces `base ≤ dawn` req. WF
  spec sets base `initial_long_margin_req 0.75` on every cell. Added an
  end-to-end funding test (dawn week funds `long_margin_debit > 0`; non-dawn
  control creates no new debit; base=1.0 would floor-reject). Corrected the false
  `.mli` "only functional reader" claim (both readers now named).

## Interface stable
YES

Surface: three `Weinstein_strategy.config` fields (`dawn_leverage_enabled`,
`dawn_initial_long_margin_req`, `dawn_max_ma_flip_age_weeks`) + the
`Weinstein_strategy.Leverage_dawn` module (`is_dawn` / `flip_age_weeks` /
`effective_initial_long_margin_req` / `dawn_active` / `dawn_effective_config` /
`validate`). All defaults are the exact pre-mechanism no-op.

## Ownership
feat-backtest. Next dispatchable work is user-gated (the surface run + grid).

## Completed
- **Mechanism BUILT, default-off** (experiment-flag-discipline R1/R2). Three real
  config fields on `Weinstein_strategy.config`:
  `dawn_leverage_enabled : bool [@sexp.default false]`,
  `dawn_initial_long_margin_req : float [@sexp.default 1.0]`,
  `dawn_max_ma_flip_age_weeks : int [@sexp.default 78]`. Merging changes no
  backtest result: the wiring short-circuits to the unchanged config before any
  bar fetch when disabled.
- **Signal** (`trading/trading/weinstein/strategy/lib/leverage_dawn.ml`, pure
  core): dawn = the primary index's weekly MA is currently *rising* (stage
  classifier's Rising: slope over `slope_lookback` weeks ≥ `slope_threshold`) AND
  the most recent neg→pos slope flip happened ≤ `dawn_max_ma_flip_age_weeks` weeks
  ago. Lookahead-free (offsets ≥ 0 only). Reuses the Stage MA kernel via
  `Panel_callbacks.stage_callbacks_of_weekly_view` (no MA re-implementation).
- **Effect / seam (permissive funding, gated sizing — B1 fix)**:
  `Weinstein_strategy_screening.screen_universe` computes the dawn-effective config
  just before `Entry_walk.entries_from_candidates`, setting the entry-walk
  `initial_long_margin_req` to the levered `dawn_initial_long_margin_req` on a dawn
  week and RAISING it to a cash account off-dawn. `initial_long_margin_req` has
  **two** functional readers: (1) the entry-walk buying-power ceiling
  (`Screening_notional` / `Long_buying_power.long_notional_ceiling`) — the SIZING
  authority the dawn signal gates; and (2) the simulator fill path
  (`Panel_runner` → `Simulator.create_deps` →
  `Portfolio_margin.apply_single_trade_with_long_margin`) — the FUNDING authority,
  fixed per run at the base req, which actually borrows a levered buy's shortfall
  into `long_margin_debit`. Because (2) is immutable per run, armed cells set the
  base `initial_long_margin_req` to the most-permissive dawn rung so the levered
  dawn fill funds (priced by M1 interest + M2 maintenance); off-dawn the raised
  entry-walk req keeps new orders cash-fitting so no fresh debit is created. Deep
  index history is fetched via `Bar_reader.weekly_view_for` (armed weeks only).
- **Validation** (`Leverage_dawn.validate`, called at `Weinstein_strategy.make`):
  `dawn_leverage_enabled = true` requires `margin_config.enabled` (dawn leverage
  runs margin-armed by convention — memo §2 item 3), `dawn_initial_long_margin_req
  ∈ (0.0, 1.0]`, AND `initial_long_margin_req ≤ dawn_initial_long_margin_req` (the
  simulator's base funding req must be at least as permissive as the dawn rung, or
  the levered dawn entry is floor-rejected). Raises `Failure` otherwise; no-op when
  disabled.
- **Tests** (`test/test_leverage_dawn.ml`, 23 cases, all pass): flip-age on
  synthetic tapes (young→dawn, boundary-inclusive, old-flip→not, current-slope-
  negative→not, data-boundary-inconclusive→not); `effective_initial_long_margin_req`
  (dawn→dawn-rung / not-dawn→cash-account / disabled→base); `validate` (disabled
  no-op, enabled-requires-armed, armed-ok, req>1→raise, req=0→raise, base>dawn→raise);
  R1 defaults-are-no-op + sexp round-trip; effect on a synthetic bar-reader dawn
  V-tape (levers to 0.75) vs decline tape vs disabled; **end-to-end funding**: on a
  dawn week the entry-walk sizing (`dawn_effective_config`) + the base-req funding
  path (`apply_single_trade_with_long_margin`) fund a levered position into
  `long_margin_debit > 0`, the non-dawn control creates no new debit, and the OLD
  base req 1.0 floor-rejects the same levered order (the B1 root-cause pin).
- **WF spec (deliverable, NOT run)**:
  `trading/test_data/walk_forward/leverage-dawn-BROAD-2000-2026.sexp` mirrors
  `margin-m4-leverage-BROAD-2000-2026.sexp` (same base scenario, rolling 13×730d,
  gate `(Sharpe, m 7, n 13, worst_delta 0.0)`, same priced margin dials). Axes:
  base `initial_long_margin_req` fixed at 0.75 (most-permissive rung → simulator
  funds any dawn rung) × `dawn_initial_long_margin_req ∈ {0.90, 0.85, 0.75}` ×
  `dawn_max_ma_flip_age_weeks ∈ {52, 78}`, dawn-armed, shorts off. fold-012
  (2024-25) is the named melt-up-lag falsifier; milder rungs {0.90, 0.85} because
  1.33×'s DD price exceeds any promotable bar. Verified to parse via
  `Walk_forward.Spec.load` (6 cells + baseline; all axis keys resolve against the
  canonical config → R2 confirmed at the overlay surface).

## Follow-up (user-gated, post-merge — [blocking: by user scheduling])
- Run the surface (`walk_forward_runner --spec
  test_data/walk_forward/leverage-dawn-BROAD-2000-2026.sexp`), score continuously
  across fold boundaries (fold-reset forgiveness is the biggest flattering bias per
  the memo), exclude fold-012, DSR + Pareto.
- If a value survives → confirmation grid (`promotion-confirmation.md`) with ≥1
  macro-regime-diverse deep cell (2000-02 + 2008) before any default flip (R3).
- Verify verdict, if any, in the experiment ledger.

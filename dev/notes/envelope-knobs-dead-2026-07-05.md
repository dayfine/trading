# Envelope knobs are dead code — P0 pair-sweep cancelled (2026-07-05)

**TL;DR:** The planned P0 experiment (min_cash_pct × max_long_exposure_pct
coupled pair-sweep, `next-session-priorities-2026-07-06.md`) is **invalid**.
Both knobs are dead in the simulation path. The backtest already runs at
**89–99% deployment** — there is no 70% envelope ceiling to loosen. The sweep
would have produced 9 bit-identical cells and burned ~9h (the #1051
inert-sweep class). Cancelled before launch.

## The code trace (decisive)

- `Portfolio_risk.min_cash_pct` — sole consumer is
  `Portfolio_risk.check_limits` (`_check_cash`, portfolio_risk.ml:337).
  `check_limits` has **zero callers** outside tests (verified: grep over
  `trading/` + `analysis/`, all `.ml`, non-test → empty). The `.mli` already
  says so: *"Deprecated as of 2026-05-01: never wired into the entry walk."*
- `Portfolio_risk.max_long_exposure_pct` — two consumers:
  1. `compute_position_size` (portfolio_risk.ml:204): **per-position**
     `min(side_exposure_cap, position_cap)`. With production values
     (0.70 exposure vs 0.30 `max_position_pct_long`) the per-position cap
     always binds → inert for any value ≥ 0.30. This is the mechanical root
     of the 2026-06-25 ledger finding "exposure {0.70,0.90} bit-identical"
     (`2026-06-25-capacity-concentration-surface.sexp`) — recorded then as
     "never binds", actually "not an aggregate cap at all".
  2. `check_limits._check_exposure` — the only *aggregate* exposure check;
     dead (no callers).
- **Bonus finding:** the entire `check_limits` battery is unwired —
  `max_positions`, `min_cash_pct`, aggregate long/short exposure, sector
  *count* caps. Live entry-path gates are only: remaining-cash walk
  (`weinstein_strategy_screening.ml` seeds `remaining_cash = portfolio.cash`
  — the full balance, no reserve), per-position sizing caps
  (`compute_position_size`), short-notional cap, and the opt-in
  `max_sector_exposure_pct` dollar gate. Portfolio-level cash floor is
  absolute-dollar *solvency* (`Portfolio_cash_floor`), not a percentage
  reserve.

## The empirical confirm (11 minutes, the #1846 lesson applied)

`backtest_runner --smoke --csv-mode --baseline` with variant override
`portfolio_config.min_cash_pct=0.90` (absurd: if live, blocks nearly all
entries; baseline default 0.10). Artifacts:
`dev/experiments/envelope-knob-liveness-2026-07-05/`.

| Window | Baseline vs variant | Deployment at end (baseline) |
|---|---|---|
| bull 2019H2 | bit-identical (Δ=0 on every metric) | $1,115,426 / $1,131,817 = **98.6%** |
| crash 2020H1 | bit-identical | 93.6% |
| recovery 2023 | bit-identical | 88.6% |

Variant `params.sexp` confirms the override was applied (`min_cash_pct 0.90`)
— not an override-plumbing no-op.

## What this corrects

- **`next-session-priorities-2026-07-06.md` P0** — premise "the binding cash
  constraint (min_cash_pct 0.30 / max_long_exposure_pct 0.70 — the same 70%
  ceiling from both sides)" is false. The binding constraint is **cash itself
  at ~full deployment**. The `Insufficient_cash` skips (~10/Friday) happen at
  ~0% reserve, not at a 30% floor.
- **`project_capital_mgmt_scale_in_design` memory** — same claim ("≤70%
  invested, forces the cash-skips") corrected.
- **Base scenario fixtures** — the "production caps" overrides
  `((portfolio_config ((max_long_exposure_pct 0.70))))` and
  `((portfolio_config ((min_cash_pct 0.30))))` carried by
  `goldens-sp500-historical/*` and experiment bases are **inert decoration**.
  Left in place (removing them changes nothing and churns fixtures), but do
  not read them as behavior.

## Implications (the transferable why)

1. **The envelope cannot be loosened** — it is already ~100%. The only true
   expansion is margin/leverage, a structural + faithfulness question, not a
   knob. Therefore the stated precondition for ever revisiting
   continuation-adds ("pair with an envelope change") is **unsatisfiable in
   the current architecture** — the v2 REJECT's WHY #4 (adds financed by
   displaced entries) is structural and final. Scale-in program stays closed.
2. **The only buildable envelope experiment is tightening** — a *working*
   cash-reserve mechanism (default-off, new flag per
   `experiment-flag-discipline.md`) testing whether holding 10–30% reserve
   buys enough DD/dispersion relief to justify the return cost. The fat-tail
   law predicts it's a breadth tax; measuring it would price "how valuable is
   the marginal entry" directly. Not obviously worth 9h of broad WF-CV —
   decision item, not a default next step.
3. **Decision item (needs human/review approval per CLAUDE.md core-module
   rule):** wire or delete `check_limits`. A limits API that looks load-bearing
   but is test-only invited this wrong premise twice (the 06-25 misread +
   this P0). Deleting the dead fields (or wiring them for real) removes the
   trap. Cross-module change — propose, don't bundle.

## Process note

Cost of the wrong premise: one merged priorities doc + one memory claim.
Caught by tracing consumers before authoring the spec (~30 min) + an 11-min
smoke A/B — vs ~9h of bit-identical sweep. The check that caught it
generalizes: **before sweeping any knob, grep its consumers to the actual
call site in the sim path** — `.mli` deprecation notes and ledger
"inert/bit-identical" rows are the smoke; a dead knob is the fire.

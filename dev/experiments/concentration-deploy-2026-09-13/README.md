# Concentration / deployment probe on the 26y record — item 3 of the 09-14 queue (2026-09-13)

**Status: PRE-REGISTERED** (written 18:35 PT before any cell ran). Two arms, three salts each, on the record convention.

## Why

- The record's gap is entry-side (`project_exit_stack_survives_fixed_basis`, `project_monster_funnel_top_of_funnel`) and the
  item-6 screen on the 2019 grid null (`cadence-12w-v10-2026-09-13/README.md` §"Item-6 screen") shows `long_top_n_admitted`
  = 20 on every screening week through spring 2020 while 1–3 entries fill per week: deployment in a recovery is bound by
  sizing and exposure, not by admission. `project_record_gap_is_concentration`: 4.9 concurrent positions in the reference
  record vs our 10.6 at the same 70% exposure — dilution, not selection.
- Prior evidence (`project_capacity_concentration_surface`, 2026-06-25, sp500-PIT WF-CV, single path): concentration is a
  real, tail-amplifying lever with a return-for-drawdown trade-off; the 0.25 cell was a knife-edge above both neighbours and
  read as path-dependent overfit; `max_long_exposure_pct` alone was inert because the cash floor binds. Neither was measured on
  the broad record with salts.

## Arms (specs/, run by chain-conc.sh; null = the committed `stop-width-by-state-2026-09-08/results/a0-breadth-on-null-s{0,1,2}-v10`)

| arm | change vs the a0 null | question |
|---|---|---|
| `c1-conc25` | `max_position_pct_long` 0.14 → 0.25 (exposure 0.70, min cash 0.30 unchanged) | does per-position concentration survive three salts on the broad record, or is 0.25 the same knife-edge? |
| `c2-deploy85` | `max_long_exposure_pct` 0.70 → 0.85 AND `min_cash_pct` 0.30 → 0.15 (per-position 0.14 unchanged) | does deploying more capital (six slots, lower cash floor) help, and specifically in Recovering weeks? |

Same build for both arms and (by inspection) runtime-inert vs the null's build 969637974: main 90552b910 differs from the
null's build only by docs and default-off flags (#2758 build-time, #2759 flag-off bit-identical, #2767 devtools, #2778
publisher, docs). Pairing gate: `validator_diff -check V6` exit 0 on every pair (V6 = 0 on all null cells).

## Pre-registered decision rule

Per arm: **clears if realised P&L AND Calmar are both better than the null at ≥ 2 of 3 salts.** Calmar rather than maxDD
because concentration is a return-amplifier: a worse maxDD is the expected cost, and the question is whether return pays for
it (`project_capacity_concentration_surface` "use a return/Calmar gate"). MaxDD, Sharpe, level, trade count, exit mix,
open-MTM are reported; level is NOT a criterion (the null's salt-2 level is $3.84M of open MTM).

Cohort read (the item-6 question): `symbol|entry_date` join → shared / null-only / arm-only; then entries grouped by the
breadth state of their screening week (`by_state` as in the screens README) — the Recovering cohort's paired P&L and count
is the specific number this probe exists to produce. Per-year realised, largest movers by name, and the drawdown episode
from `equity_curve.csv` (peak/trough dates) for every cell.

A clearing arm is a **knob value**, not a mechanism: promotion would be a config-default change under
`config-default-blast-radius.md` (paired goldens) and `promotion-confirmation.md` (a grid on the 2009/2019 vintages —
which the 12%-weekly candidate just failed on exactly the regime-dependence this lever is also known for). A failing arm
retires the value on this base; the knob stays an axis (it already is one).

## Log


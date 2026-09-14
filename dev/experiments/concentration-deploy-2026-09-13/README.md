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

- 21:40 PT: **c1-conc25, salt 0** (wall 8,556 s; `results/c1-conc25-s0-v10-*` incl. `equity_curve.csv`) vs the committed
  `a0-breadth-on-null-s0-v10`. V16/V17 PASS, V6 = 0 on both, `validator_diff -check V6` exit 0. Level 382.74 → 313.12,
  trades **710 → 474**, Sharpe 0.445 → 0.403, **realised $3.24M → $2.82M (−$421k)**, **Calmar 0.163 → 0.159**, maxDD
  **37.6 → 34.6** (episode 2018-01-26 → 2020-04-08 on the arm), unrealised $777k → $450k on 5 open names vs 4.
  **Fails both pre-registered criteria at this salt.** Exit mix `stop_loss` 450 → 265, `laggard_rotation` 244 → 197.
  Join (`symbol|entry_date`): **239 shared, +$1.22M → +$1.80M (drift +$574k — the same trades earn more at the wider
  cap)**; but null-only 471 trades +$2.02M vs arm-only 235 trades +$1.02M: the arm makes a third fewer trades and holds
  fewer names (concurrent 4 / 5 / 6 vs 5 / 8 / 9 on 2020-04-06 / 08-20 / 12-21), and the missing set carries the record's
  2020 monsters — NVDA 2020-04-06 (+$450k), UPBD 2020-12-21 (+$324k), plus PCYC 2015, CMA-WS 2016, WNC 2003 — while the
  freed cash bought MKSI 2016 (+$428k) and BBWI 2020-08-05 (+$355k). By entry year the arm gives back 2020 (+$1.69M →
  +$0.89M), 2013 (+$989k → +$509k) and 2006/2004, and gains 2021 (−$103k → +$334k), 2022 (−$667k → +$21k) and 2024.
  Mean cost basis of 2019–23 entries is actually *smaller* on the arm ($479k vs $530k, 137 vs 188 entries): at 0.25 an
  occasional large fill leaves less cash for the next signals, so the book turns over less rather than sizing up
  uniformly. **Breadth-state cohorts** (`by_state.pl`, states from `cadence-12w…/screens/weekly_states_s1.txt`):
  Recovering **n=18 +$496k → n=11 +$618k (mean +$28k → +$56k, win 28% → 55%)** — the item-6 hypothesis holds in the
  cohort it was about; Bullish +$2.06M → +$1.92M, Neutral +$831k → +$751k, Deteriorating −$267k → −$88k, **Bearish-week
  fills +$119k → −$381k**. Read: concentration pays exactly where deployment was slot-bound (the recovery) and loses it
  back on resting-ticket fills into a Bearish tape and on the broad Bullish cohort — one salt; salts 1–2 running.
- 22:12 PT: **c2-deploy85, salt 0** (wall 10,503 s; `results/c2-deploy85-s0-v10-*`) — **bit-identical to the null**:
  `trades.csv` identical row for row (all 710 trades, every column but `position_id`), every `actual.sexp` metric identical
  (382.74 / 710 / 0.445 / 37.60 / Calmar 0.163 / unrealised $777k), while `params.sexp` confirms the overrides took
  (`max_long_exposure_pct` 0.85, `min_cash_pct` 0.15). The book never reaches the 70% exposure ceiling or the 30% cash
  floor at `max_position_pct_long 0.14` (max nine concurrent names, positions sized below the cap by the risk-based sizer),
  so neither knob binds. This reproduces the 06-25 finding (`project_capacity_concentration_surface`: exposure inert) on
  the broad record and extends it to the cash floor. **Lane G2 stopped by the dispatcher after this cell**: salts 1–2 of
  an inert arm would reproduce the nulls digit for digit and cost ~5.8 h of container. **c2 = INERT; the "deploy more"
  lever does not exist at this per-position size** — deployment in a recovery is bound by per-position sizing and slot
  turnover, not by the aggregate ceiling. Item-6 consequence: any "Recovering-week ramp" must act on per-position size
  (the c1 axis), which is where c1 salt 0 showed both the gain (Recovering cohort +$122k) and the cost (Bearish-week
  fills −$500k).
- 00:12 PT 09-14: **c1-conc25, salt 1** (wall 9,129 s; `results/c1-conc25-s1-v10-*`) vs `a0-breadth-on-null-s1-v10`. V16/V17
  PASS, V6 = 0 on both, `validator_diff -check V6` exit 0. Level 311.75 → 204.08, trades 707 → 504, Sharpe 0.427 → 0.337,
  **realised $2.94M → $2.05M (−$892k)**, **Calmar 0.168 → 0.092**, **maxDD 32.8 → 46.7** (episode 2017-10-11 → 2020-06-12:
  the concentrated book rides the 2018 and 2020 drawdowns with bigger positions), unrealised $315k → $139k on 4 names vs 5.
  **Fails both criteria — two of two salts, so c1 cannot clear the pre-registered rule.** Exit mix `stop_loss` 458 → 277,
  `laggard_rotation` 236 → 210. Join: 241 shared +$1.23M → +$1.54M (drift +$311k, the same shape as salt 0 but half the
  size); null-only 466 trades +$1.71M vs arm-only 263 trades +$0.51M — BBWI 2020-08-08 (+$377k), NVDA 2020-04-06 (+$316k),
  WNC 2003, CMA-WS 2016, B 2025 are null-only; the freed cash bought BBWI 2020-08-05 (+$315k) and KATE 2013 (+$222k). By
  entry year: **2020 +$1.10M → −$174k**, 2018 −$299k → −$515k, 2025 +$510k → +$119k; gains in 2021 (+$75k → +$395k),
  2022, 2010, 2005. **Breadth-state cohorts:** Recovering **n=20 +$454k → n=16 +$52k** (mean +$23k → +$3k, win 35% → 25%)
  — the salt-0 Recovering gain (+$122k) does not survive a salt: it was one draw, not a property; Neutral +$757k → +$1.26M,
  Bullish +$1.78M → +$1.04M, Deteriorating −$272k → −$231k, Bearish-week fills +$222k → −$71k (negative at both salts).

## Verdict (2026-09-14, 00:15 PT; c1 salt 2 still running for the band, c2 stopped after salt 0)

**Neither arm clears. The "deploy more in recoveries" hypothesis has no lever on this base.**

| arm | salt 0 | salt 1 | status |
|---|---|---|---|
| c2-deploy85 (exposure 0.85, cash floor 0.15) | bit-identical to the null | not run | **INERT** — neither knob binds at 0.14 per position |
| c1-conc25 (per-position 0.25) | realised −$421k, Calmar 0.163 → 0.159, maxDD 37.6 → 34.6 | realised −$892k, Calmar 0.168 → 0.092, maxDD 32.8 → 46.7 | **fails both criteria at 2 of 2 salts** |

**Why (transferable).** The shared-trade term is positive at both salts (+$574k, +$311k: the same trades earn more at the
wider cap), but concentration cuts the trade count by a third (710 → 474, 707 → 504) and the concurrent-name count (4–6
vs 5–9 in 2020), so the book is *fuller per name and emptier per slot* exactly when the recovery monsters screen in:
NVDA 2020-04-06 and BBWI 2020-08-08 are null-only at both salts, and the arm's 2020 realised falls from +$1.69M / +$1.10M
to +$0.89M / −$0.17M. The Recovering-week cohort — the item-6 question — gained at salt 0 (+$122k on 11 entries) and lost
at salt 1 (−$402k on 16 entries): a cohort of 11–20 trades is far below the 230-trade measurability floor and its sign
is a draw. The drawdown side is unambiguous: a concentrated book rides 2018 and 2020 deeper (maxDD 46.7 at salt 1, the
worst cell in this program's record). This is the 06-25 surface's "return-for-DD trade-off, knife-edge at 0.25" reproduced
on the broad record with salts: **the 0.25 cell is a lottery** (it won on the sp500 single path, loses here at both salts).
Consistent with `project_edge_is_the_fat_tail` from the other side — a bigger ticket in fewer names does not buy more of
the tail, it buys less breadth in the weeks the tail is caught.

**Consequences.**
- Item 6 (Recovering-week deployment ramp) is a **no-build**: the aggregate ceiling and cash floor are inert (c2), and the
  per-position axis (c1) is a drawdown lever with no salt-robust return term. The deployment-in-recovery cohort is too small
  to measure and its sign flips with the salt. Retire the idea; keep both knobs at their record values (0.14 / 0.70 / 0.30).
- The entry-side gap remains what the monster-funnel memo said: **top of funnel** (breakout gate + top-N), not funding.
  Next screens should widen the funnel (breakout-gate width, top-N) rather than resize the ticket.
- `max_long_exposure_pct` / `min_cash_pct` can be dropped from future capacity surfaces on this base (inert);
  `max_position_pct_long` stays a default-off-style axis at 0.14 with a documented REJECT-as-default at 0.25.

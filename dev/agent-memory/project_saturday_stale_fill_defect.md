---
name: project_saturday_stale_fill_defect
description: "SIMULATOR DEFECT (found 2026-09-01): Friday-tick EXIT orders fill on the Saturday calendar step against the retained Friday bar at FRIDAY'S OPEN, dated Saturday — every volume_eject/laggard/liquidity/stage3 exit and ~22% of stops, in EVERY arm incl. the record. Next_open_fill_gate (sim_entry_fill_next_open) covers entries only. First-order: arc 26y +$525k, record 26y −$601k if filled Monday open."
metadata:
  type: project
  originSessionId: ea0190a3-7ee9-4a89-9d5b-89dfd6df71d3
  modified: 2026-09-02T06:24:59.062Z
---

**The defect.** `simulator.ml:443` steps one CALENDAR day; on Saturday
`_get_today_bars` is empty and `Market_state.update` (engine) keeps Friday's
bars; the exit Market order submitted at the Friday tick fills against that
stale bar's OPEN and `_extract_trades ~date` stamps it Saturday. All 2,500
Saturday-dated arc exits = the preceding Friday's open at 2 dp (2,231 exact
at 4 dp; one 2-dp tie with Friday's close; never Monday open). Fresh 26y
run (09-02): 2,144/2,144, first-order +$1.05M if filled Monday open. Weekday stop exits are already
"next-day open" fills; Friday triggers get Friday's own open — a price that
predates the decision.

**Who it hits.** 100% of `volume_eject`, `laggard_rotation`,
`liquidity_exit`, `stage3_force_exit`, `extension_stop` exits (all decided
on the Friday screening tick) and every stop whose trigger bar is a Friday.
Record convention 08-24: 269/269 laggard exits, 98/503 stops. A 2026-05-13
note read Saturday-dated fills as "executed Monday" — wrong: the DATE moved,
the PRICE did not.

**MEASURED with both fixes armed (26y arc, build 94a8c6857, salt 0) — ⚠ CONTAMINATED by a +$513,550 CHS ticker-splice phantom (2004-12-20; issue #2646) that the Monday-open fill exposed:** raw −29.2% → −0.6% is NOT a number (it compounds on the phantom); ex-ALL-phantom realised **+$83.6k unfixed → +$85.6k fixed — NEUTRAL** (the unfixed run carried a −$169k ICT phantom; the fixed run +$514k CHS, −$161k ICT, −$220k AGR); the eject leg gains ~+$0.9M and the stop leg gives it back (−$2.54M → −$3.68M: day-0 artifacts become later, larger real stops); ejects +$763k → +$1.66M ex-phantom (first-order said +$1.22M — direction confirmed); zero Saturday exits, same-day stops 233 → 1; stops run longer and lose more (−$2.54M → −$3.68M); MaxDD 57 → 61%. 5y cell B: −24.4% → −10.4%, MaxDD 38 → 26%. D3 (fill-week eject, 1,924/2,518 trades) remains the arc's binding constraint.

**Direction is arm-dependent.** Reprice at Monday open, quantities fixed
(`dev/experiments/arc-rerun-2026-09-01/results/reprice-*.csv`): arc 26y
+$524,745 (ejects +$535k — weak pokes keep rising Monday); record 26y
−$601,280 (stops −$337k, laggards −$263k — Friday selloffs continue Monday).
Any high-turnover-vs-record comparison is contaminated until fixed.

**Fix LANDED 2026-09-02 (PR #2644, main 94a8c6857):** `sim_exit_fill_next_open`
default-off; `Next_open_fill_gate.make ~defer_entries ~defer_exits` holds a
Market order that closes an `Exiting` position until a fresh bar (routed by
symbol + exit side, so a scale-in sibling is not misrouted — gate-level test).
`test_exit_unaffected_when_flag_on` still pins the old behaviour; promotion to
default-on needs the paired-golden protocol (it moves the record by ~−$0.6M). Validator V13 (fill date must have a bar; price within that
bar's range) is the mechanical guard.

**Sibling defect D2 (same session):** a fresh position's stop is judged
against its own ENTRY bar's pre-fill low (fills run before the strategy in
each step) — 173/3,029 arc entries killed on day 0 while closing above the
stop. Fix LANDED 2026-09-02 (PR #2642, main 60d50867a): `stops_config.stop_skip_entry_bar`
default-off (book Ch. 6 settles it: the GTC sell-stop exists only from the
purchase forward — write-back in weinstein-book-reference §5.1). Validator V13 (fill date has a bar, price inside its range) + V14
(entry-bar stop-out) LANDED in PR #2641 (main 7da7f249c) after two rework
rounds — every Skip branch mutation-caught.

Related: [[project_fill_model_inversion]], [[project_exit_fill_reject_zombie]],
[[project_arc_faithful_costs_the_tail_at_scale]] (its −62.4% predates this
finding; first-order the defect alone exceeds the arc's realised loss).

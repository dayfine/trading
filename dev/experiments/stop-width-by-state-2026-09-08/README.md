# Item 3 surface — per-macro-state initial stop width (2026-09-08)

Mechanism: `initial_stop_buffer_by_macro_state` (#2718, default-off axis; plan `dev/plans/stop-width-by-macro-state-2026-09-06.md`). Question: does sizing the FALLBACK initial stop by the five-state breadth read (#2685) beat the record's flat 4% on the clean 2000-vintage basis? Motivation: the 09-04 yearly review's per-state P&L (Deteriorating entries −$604k, Recovering +$627k) and the 09-05 width surface (12% wins at 26y on the OLD basis — every pre-#2672 width read must be re-measured).

## Arms (salt 0 first; salts 1–2 on anything that moves)

All three = the record spec `rec26y-new` (clean `_v7mark` 2000 warehouse, record convention, 2000-01-01..2026-06-26, build main e7dde095a in `sweep-item3`) + `((macro_config ((breadth_direction ((enabled true))))))` so all five states can fire:

| arm | per-state map | why |
|---|---|---|
| `a0-breadth-on-null` | EMPTY (every slot unset → scalar 1.0 = 4%) | **null control**: the breadth read is documented as purely additive; this cell must reproduce the record salt-0 cell (263.16% / 723 / DD 42.37) digit-for-digit or the read is not inert |
| `a1-map-neutral8` | bullish/recovering 0.9167 (12%), neutral 0.96 (8%), deteriorating/bearish 1.0 (4%) | the plan's candidate map, Neutral at the low end |
| `a2-map-neutral10` | same with neutral 0.94 (10%) | Neutral at the high end |

Comparator: the record band (`project_record_rebase_2026_09_07`: 263% median, 181–562% across salts, maxDD 42–45%). Read per `mechanism-validation-rigor.md`: distribution (salts), the join (`symbol|entry_date`) to decompose shared vs arm-only P&L, per-state entry counts (the breadth state at entry is in `trade_audit.sexp`), and the exit mix (stop whipsaws vs rotation). A map that helps only through one monster is a lottery, not a lever (`project_stop_anchor_surface_is_dds`).

Universe discipline: top-3000-2000 (broad) — a measurement surface, not sp500.

## Run log

- 08:12 PT: lanes launched (`chain.sh A a0 a2`, `chain.sh B a1`), logs `/tmp/item3-run/chain-{A,B}.log`, artifacts `/tmp/sweeps/item3/`.

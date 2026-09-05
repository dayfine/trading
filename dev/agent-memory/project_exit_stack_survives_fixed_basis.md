---
name: project_exit_stack_survives_fixed_basis
description: "2026-09-04 exit-lever surface (18 cells, record convention, fixed basis, 2019-23 + 2000-04 x salts 0-2): every exit mechanism the record arms SURVIVES the D1/D2 fix — laggard rotation (regime dial: −$214k..−$369k ex-monster to switch off on 2000-04; 2019 +97pp is one unsold NVDA), extension stop (−$187k..−$190k + 4-9pp maxDD to switch off where it fires), stage-3 force-exit inert (0-1 fires), clock 52 = MSTR lottery on 2019 (ex-MSTR loses 3/3, maxDD +11-13pp) and neutral on 2000. Record convention unchanged; exit stack settled; gap is entry-side."
metadata:
  type: project
  modified: 2026-09-04
---

**Record:** `dev/experiments/exit-lever-surface-2026-09-04/` (README has the
per-salt tables; `dissect.sh` + `unreal.sh` are the tools; raw per-arm
artifacts under `results/`). Build `e4984c5fe`, same as
[[project_record_rebase_2026_09_03]] and [[project_stop_width_regime_dependent]],
so their nulls were reused.

**Per arm (arm − null, realised + unrealised, ex-monster):**

- `enable_laggard_rotation false`: 2000–04 −$320k / −$369k / −$214k, shared
  drift −$170k every salt (rotation sold WNC at +$271k where holding stopped at
  +$154k; freed capital funded CNX/IPIXQ). 2019–23 raw +$970k / +$885k / +$969k
  is the NVDA 2020-04-06 ticket held to window end (+$852k unrealised, all three
  salts) which the null rotated out on 2020-11-30 for +$117k; ex-NVDA ≈
  +$150–235k from fewer whipsaw re-entries, with shared drift −$160–182k
  against. **Regime dial, keep on.** Rotation = top-seller in a bear tape,
  monster-ejector in a melt-up.
- `extension_stop_config` off: 2000–04 −$283k / −$217k / −$280k, all shared
  drift on 3 blow-off exits (APWR +$89k→+$2k, IPIXQ +$256k→+$184k, BDLN),
  maxDD +4–9pp. Never fires on 2019–23 (digit-identical). **Keep on.**
- `enable_stage3_force_exit false` (hysteresis 1): 0 fires on 2019–23, 1 on
  2000–04 (−$6k). **Inert** — stop + rotation preempt it.
- `entry_order_max_rest_weeks 52` (record pins 0): 2019–23 +$515k / +$316k /
  +$507k = MSTR 2020-10-12 +$561k arm-only (book one slot lighter that week —
  same admission as the 5.9% stop); ex-MSTR −$46k / −$247k / −$55k, **maxDD
  +10.8 / +13.0 / +10.8pp**. 2000–04 neutral (realised +$4–15k). **Record keeps
  the 0 pin.**

**Contrast with the arc:** the arc's §4.2 eject gate was a defect artifact
([[project_lever_reads_invert_on_fixed_sim]]); the record's mechanisms are not —
their footprint is the same named trades at every salt.

**Flag — RESOLVED the same evening** (`dev/experiments/clock-default-fixed-basis-2026-09-04/`): on the DEFAULT bundle, fixed basis, 2019-vintage warehouse, the clock is maxDD −11.7 / +0.55 / +0.33pp across salts — never materially worse; the record-convention worsening was the record's pins (MSTR slot), not the clock. KEEP-52 stands; cite the clock as a drawdown floor, not a win ([[project_clock52_promoted]]).

**Method notes:** the hold-longer arm's return gap lived in OPEN positions —
invisible to the closed-trade `symbol|entry_date` join; read `unreal.sh`
(open_positions × final_prices) alongside `dissect.sh`. A mechanism that never
fires is digit-identical to the null at every salt — trim those cells.

Related: [[project_edge_is_the_fat_tail]], [[project_stop_anchor_surface_is_dds]],
[[project_warehouse_vintage_coverage]] (2019 levels survivor-tilted).

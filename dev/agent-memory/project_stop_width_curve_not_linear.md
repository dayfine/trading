---
name: project_stop_width_curve_not_linear
description: "09-13 screens on the wide arm's own trades (3 salts, _v10dedup 26y): initial-stop width is NOT linear — flat ≤6%, knee 7→9% (+$1.1–2.2M per step 8→9), plateau 9–12% (±$0.4M). Four of five breadth states gain from wide, Deteriorating included (stop-out 81%→59%); only Bearish-week FILLS of resting tickets lose (3/3). NO-BUILD with tables: tighten/exit resting stops on Deteriorating, Bearish onset, leaving-Bullish, or index speed (all negative at every salt, 79–93% of open positions get hit); selective poor-RS exit; per-state 4/8/12 map. Promotable value = the plateau → 10%-weekly neighbour arm owed; cancel-on-Bearish is the one state axis left."
metadata:
  type: project
  modified: 2026-09-13
---

**Record:** `dev/experiments/cadence-12w-v10-2026-09-13/screens/README.md` (scripts + tables). Counterfactuals over
committed `trades.csv` + CSV `adjusted_close`; sign at three salts is the read, not the dollars.

**Why it transfers:** the record's per-state P&L asymmetry (Deteriorating entries −$604k on 09-04) was whipsaw under a
4% trail, not selection; the same cohort is +$0.3–0.4M at two salts under 12%-weekly. Any label that marks
drawdown-in-progress (breadth direction, index speed, market Stage 4) marks the weeks where 9 in 10 open positions
dip past a tight stop — acting on it converts dips into exits and forfeits the recovery
([[project_edge_is_the_fat_tail]]). The book's Ch. 8 "pull stops up tightly in a Stage-4 market" tested directly loses
at every salt on 2000–2026 (V-shaped bears; his own faster-market caveat licenses the dial).

**Open axes:** 10%-weekly neighbour for the promotion grid; `cancel_resting_longs_on_bearish` (Bearish fills are the
one cohort wide hurts, and the per-state map cannot reach them — it sizes at placement). Related:
[[project_cadence_12w_v10dedup_accept]], [[project_deteriorating_gate_reject]], [[project_stop_buffer_by_macro_state_axis]].

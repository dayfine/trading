---
name: project_deteriorating_gate_reject
description: "deteriorating_blocks_longs (#2755/#2759, default-off) REJECT-as-default/keep-as-axis (amended per #2780; first recorded do-not-revive) on 09-13: 3 salts on _v10dedup vs the a0-v10 band, V6=0 — realised −$1.70M / −$0.82M / −$1.25M (0/3), maxDD worse/worse/better (1/3, the win on the null's $3.84M open-MTM cell). Deteriorating fires INSIDE recoveries (6 wks 2020, 20 wks 2022–23) and removes NVDA 2020-04-06 (3 salts), UTHR 2020-12-02 (2), BBWI 2020-08-08 (2). Closes the state-conditioning line from the 09-04 yearly review. Ledger 2026-09-13-deteriorating-breadth-long-gate."
metadata:
  type: project
  modified: 2026-09-13
---

**Result (dev/experiments/deteriorating-gate-2026-09-13/):** arm = a0 spec + the flag, build 31e4bb9c3,
paired against the committed a0-v10 nulls (build 969637974; runtime-inert by inspection). Level −203 /
−83 / −442pp; realised loses at every salt; only 10–38 net entries vanish but 290–330 later fills re-draw.
Exit mix moves TOWARD stops (s0 450→459 stop_loss, 244→227 rotations). Gate verified live in the sim:
`long_top_n_admitted` = 0 on all 52 Deteriorating weeks (audit table in the README).

**Why it transfers:** a regime LABEL applied to admission is anti-predictive because the label turns
over inside the moves the edge comes from; the 09-04 cohort read (−$604k, n=80) was below the
230-trade floor and, paired and salted, removing the cohort costs 1.3–2.8× what the cohort lost.
Entry-side work must be tail-preserving (funnel breadth, top-N, breakout-gate width), never a narrower
admission by state. Sibling: [[project_stop_buffer_by_macro_state_axis]] (REJECT-as-default / keep-axis).
Same law as [[project_edge_is_the_fat_tail]], [[project_cascade_selection_inversion]].

**Process:** #2759 needed two QC rounds — the first behavioral pass found the fresh-candidate thread
unpinned (two severing mutations green) and flag-off not bit-identical when `neutral_blocks_longs` was
also on; the rework threaded `~macro_trend` so the gate is a pure conjunct. Flag stays default-off as a legitimate axis; NOT on the Rule-4 retirement worklist (#2780: do-not-revive needs a second vintage cell failing both criteria; salts are not independent contexts). Calmar gate 0.100/0.133/0.105 vs null 0.163/0.168/0.183.

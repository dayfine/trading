---
name: project-funding-grid-monster-lottery
description: "A1-4 funding grid CLOSED (PR #2473): saved tickets MAKE money (+$47k..$490k direct, pure-cohort corrected) but top-line gaps (null +305% > g2a1 +219% > g2a2 +198% > g2b +174%) are a monster LOTTERY inside the 132.5pp floor — CLS-2023 (+$658k) null-only vs SKYW-2023 (+$428k) arm-only; one reshuffle ≈ 66pp. G3 reservation = REJECT as default, terminal (53 trades in 26y). G2a/G2b keep default-off as axes."
metadata:
  type: project
  originSessionId: 7959dddf-3101-4cab-8f02-c90b77a7d8fd
  modified: 2026-08-22T17:55:59.587Z
---

**The funding program is closed.** Five-arm 26y grid on the record-convention
base (build 1281dab97, same warehouse/data root, sequential): null destroy /
G2a retry ×{1,2} / G2b resize / G3 reserve.

**Event level (the verdict surface — `symbol|placement_date` ticket join,
`position_id` trade join):**
- Null placed 2,013 tickets, destroyed 527 for funding (522 pure — 5 cancelled-then-traded ids excluded). Arms destroy fewer
  (371–431) and fill ~1,600.
- **Saved tickets are net-profitable in every arm**: g2a1 159 saved → +$490k;
  g2b 167 → +$295k; g2a2 186 → +$47k (fragile). Corrected in QC rework: join is
  symbol|col2 of the tickets TSV (the audit header entry_date = true
  placement), NOT the lifecycle placement_date field. The AXTI-class premise is confirmed.
- **Top-line ordering is monster reshuffling**: MSTR-2020 caught by ALL four
  (+$539k…+$795k, size varies with cash state); CLS-2023 +$658k caught ONLY
  by null; SKYW-2023 +$428k/BPT-2022 caught only by arms. One monster ≈ 66pp
  ≈ the whole inter-arm spread ([[project-edge-is-the-fat-tail]],
  [[project-clock26-is-a-tail-lottery]]).
- One extra retry rewrote a third of the trade set (g2a1∩g2a2 = 895 of
  ~1,370; first divergence RYAAY 2003-10-20; only 209 shared pairs P&L-identical) — the
  cash-pool cascade dominates everything downstream.

**Verdicts:** G3 `reserve_cash_for_resting_tickets` = **REJECT as global
default, terminal** (53 trades in 26y; ~98% cash for decades; population
collapse is structural, not noise) — flag stays as R1 no-op; a capital-rich
preset may revisit, never as default. G2a/G2b = **keep default-off as axes**,
no promotion case (direct effect positive but monster-lottery variance
dominates; a promotion would need salted confirmation grids and nothing here
justifies that spend).

**Transferable why:** funding handling is tail-preserving in intent,
tail-RESHUFFLING in effect — saved cohort is median-sized, displacement risk
is monster-sized. Any future funding lever must protect *monster* entries
specifically (e.g. reserve-only-for-A+-grade), not aggregate ticket counts.

**Method traps recorded:** WARN-line counts are per-attempt, not per-ticket
(g2a1 logged MORE lines than null while destroying FEWER tickets);
ticket-identity joins overstate displacement (MSTR caught via different
tickets — check opportunity level, symbol+year, before claiming a loss).

Record: `dev/notes/funding-grid-writeup-2026-08-22.md`, artifacts
`dev/experiments/funding-grid-2026-08-22/` (PR #2473).

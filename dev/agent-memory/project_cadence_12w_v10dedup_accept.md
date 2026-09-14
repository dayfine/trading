---
name: project_cadence_12w_v10dedup_accept
description: "12%×WEEKLY cadence: single-surface ACCEPT on 26y _v10dedup (3/3 salts, realised +$2.0–2.6M, maxDD −4.7 to −9.9pp) but the CONFIRMATION GRID FAILED 09-13: both 5y vintage cells (2009, 2019) lose realised AND maxDD at 2 of 3 salts. NOT promotable; default-off axis. Wide-weekly wins in fast-crash-then-recovery tapes, loses in slow grinds (2021–23, 2010–12)."
metadata:
  type: project
  modified: 2026-09-13
---

**Record:** `dev/experiments/cadence-12w-v10-2026-09-13/`, ledger `2026-09-13-stop-width-12pct-weekly-cadence-v10dedup`
(Accept). Arm = a0 spec + the two overrides, build 31e4bb9c3, paired against the committed a0-v10 nulls.

**The read that matters:** at salt 1 the arm-only and null-only sets net to zero and the entire +$1.97M is the
359 shared trades running wider (+$1.98M drift). At salts 0/2 the shared term is +$0.6M / +$1.65M and the
arm-only monsters (NOVT 2016, KTOS 2025, BBWI 2020-08-20, KLIC 2020-11) recur by name. The maxDD win is the same
shape at every salt (−4.7 to −9.9pp). This is the first exit-side lever to survive the fixed basis + deduped
warehouse + V6 gate at 3/3 on both criteria; it is tail-PRESERVING (let the same trades run) — the opposite of
the same-day admission gate ([[project_deteriorating_gate_reject]]). Supersedes the OLD-basis/_v7mark read in
[[project_stop_width_cadence_surface_2026_09_05]] (761% / 29.7 at s0 there; 752 / 30.0 here — the direction held).

**Costs:** +125–141 trades, 5–6 force liquidations vs 2–3, `delisted` 8–10 vs 5–7, 7–9 open names at the end.

**Before promotion:** confirmation grid ≥ 3 broad cells (2009 + 2019 `_v10dedup` at 3 salts vs their own nulls;
this 26y cell is the bear-regime cell), dissect the force liquidations, paired goldens for BOTH knobs
(`config-default-blast-radius.md`), and the W2 argument — 12% sits outside the book's §5.3 4–6% band and must be
framed as a modern-regime adaptation of a dial; weekly re-evaluation is L3 (book-faithful).
Related: [[project_stop_width_regime_dependent]] (5.9% vs 4% by window), [[project_edge_is_the_fat_tail]].

**Grid verdict (09-13 evening, ledger `2026-09-13-stop-width-12pct-weekly-confirmation-grid`):** both 5y cells fail
both criteria at every salt read (2019: $469k→$166k / 22.6→30.9 and $258k→$207k / 22.5→31.1; 2009: $106k→−$23k /
17.9→27.1 and $277k→$10k / 20.4→25.2). Shared-trades-run-wider stays positive everywhere; the path re-draw and the
drawdown EPISODE flip the sign — the null's 2019 maxDD is the Covid crash, the wide arm's is the 2021-05→2023-10 grind.
Consequences: no promotion, no 10% neighbour arm, item-3 cancel-on-Bearish no-build (cohort is positive on the record).
Same lesson as [[project_early_admission_mechanism]] and [[project_stop_width_regime_dependent]].

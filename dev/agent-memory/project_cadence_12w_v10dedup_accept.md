---
name: project_cadence_12w_v10dedup_accept
description: "12% initial stop (initial_stop_buffer 0.9167) × weekly trail cadence (stop_update_cadence Weekly) = single-surface ACCEPT on 09-13: 3 salts on _v10dedup vs the a0-v10 band — realised +$2.59M / +$1.97M / +$2.48M, maxDD 37.6→30.0 / 32.8→28.1 / 43.0→33.0, Sharpe better everywhere; band 627–752% vs 312–640%. Mechanism = the SHARED trades run wider (stop_loss ~460→~320, rotation ~240→~490 per cell); not a twin artifact (V6 = 0 on nulls; one −$2.8k IAC/MTCH spin-off twin on arm s1/s2, #2782). NOT promoted: grid (2009/2019 _v10dedup × 3 salts) + force-liquidation dissection + two-knob paired goldens + book §5.3 argument owed first."
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

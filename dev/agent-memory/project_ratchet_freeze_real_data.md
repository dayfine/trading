---
name: project-ratchet-freeze-real-data
description: "#2486 verified on real data 08-24: 88.7% of entries take the fallback stop; fallback positions ratchet at 9% vs support-floor 49% (held >=13wk) — artifact confirmed; 85% of fallback trades exit stop_loss at ~initial width (median -1.71%)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 41ec5d1b-6286-4c79-b63e-e9772f9eb5d9
  modified: 2026-08-24T06:31:14.008Z
---

Instrumented 26y run (instr-null, main 2b11c60dd, top-3000, artifacts in
`dev/experiments/instrumented-record-2026-08-23/`) settled issue [[project-fallback-stop-half-book-band]]'s
open ratchet question (#2486):

- **Fallback = 88.7% of entries** (1,621/1,827 `Buffer_fallback` vs 206 `Support_floor`).
- **Freeze confirmed**: closed-trade ratchet rate 1.1% (fallback) vs 17.1% (support).
  Held ≥13wk: **9% vs 49%**; ≥26wk: 17% vs 53% — same tape, so correction scarcity
  is ruled out; the anchor deadlock (see PR #2492's invariant) ate the cycles.
- **Consequence**: 861/1,018 fallback trades (85%) exit `stop_loss` clustered at the
  initial 2.08% width (median −1.71%, IQR −3.0…−0.2). Only 11% of fallback trades
  survive 13 weeks (vs 34% support-floor).
- Book verdict (PR #2498, Ch. 6 XYZ walk-through): freeze = implementation artifact;
  #2492's `reset_anchor_on_stalled_cycle` semantics is the faithful reading.
- Join key: position_id (trades.csv cols: 20=position_id, 22=max_stop, 23=n_stop_raises;
  stop_floor_kind from trade_audit entry_decision).

Paired arm (`instr-unfreeze`, flag on, same build) measures the unfreeze impact.
⚠ Absolute levels NOT comparable to pre-08-23 records — see [[project-record-basis-divergence-0823]].

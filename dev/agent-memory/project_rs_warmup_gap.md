---
name: project_rs_warmup_gap
description: "ROOT CAUSE of ~77% rs_value=None: warmup 210 < RS's 52wk need; first 22wk of every window rs=None all symbols. FIX EXECUTED 2026-07-08 (warmup=364, goldens re-pinned, warehouse rebuilt; ledger warmup-364-basis-change). Absolute numbers shift from that date; relative verdicts stay. GME-squeeze floor-brake pathology surfaced on sp500-2010-2026."
metadata: 
  node_type: memory
  type: project
  originSessionId: 6a3b1c78-78e9-47b1-82b4-6ff9c6ad695e
---

**Diagnosed 2026-07-07** (P0a of the multivariate-screen arc).

Chain: `Rs.analyze` None below 52 aligned weekly bars (`rs.ml:89`) ×
`lookback_bars = 52` views × `warmup_days_for Weinstein = 210` (`runner.ml:22`)
× panel clipped at `warmup_start` (both CSV `Csv_snapshot_builder` and
snapshot-mode `build_scenario_snapshots`) ⇒ first 52−30 = 22 weeks of every
backtest window: `analysis.rs = None` for every symbol.

- CSV data alignment is PERFECT (probed 10 sp500 names vs GSPC 52/52) — not a
  date-join artifact.
- 77% figure = short smoke windows (~28wk → RS present only last ~6wk). On a
  contiguous 26y run it is ~1.6% of screens → **P0b multivariate generation
  does NOT block on the fix**.
- Effects: RS scoring points silently zero (up to 20+), ranked-Quality
  tiebreak sorts None last, live/sim divergence (live fetches full history),
  score-tie plateau pile-ups (interacts with alphabetical tiebreak).
- WF-CV verdicts: baseline+variant hit equally → relative verdicts largely OK;
  absolute levels + RS-interacting axes distorted.
- `Sector_rotation_weinstein` already warms 364d for EXACTLY this reason (its
  doc comment says so) — Weinstein arm never got the same.

Decision note (options + blast radius): `dev/notes/rs-warmup-gap-2026-07-07.md`.

**EXECUTED 2026-07-08** (`dev/notes/warmup-364-repin-2026-07-08.md`, ledger
`2026-07-08-warmup-364-basis-change`):
- `warmup_days_for Weinstein|Spy_only_weinstein = 364`; hardcoded 210s in
  `all_eligible_runner` + `optimal_strategy_runner` now reference the constant.
- Sanity diff shape as predicted (day-1 picks change, cadence unchanged).
  covid-recovery small golden: 78.5→106.4%, DD 23.8→17.7.
- All tight-band goldens re-pinned vs their own store; deep research goldens
  sanity-wide, PASS. Warehouse `/tmp/snap_top3000_1998_2026` rebuilt
  (window 1999-01-02..2026-04-30; old kept at `.bak-210`).
- **NEW FINDING — floor-brake/meme-squeeze pathology**: RS-honest basis
  faithfully enters GME Sept-2020 (+$7.8M realized on sp500-2010-2026); the
  squeeze MTM peak ($28.9M) poisons the monotonic Peak_tracker → NAV never
  re-clears 0.4×peak → Portfolio_floor fires 2021-02-02 and STERILIZES the
  remaining 5y (32 floor liqs, OPV 0, flat equity). Longshort twin healthy.
  Floor-quality-program (P1b) input: HWM semantics of the floor brake are
  fragile to MTM squeezes — [[project_floor_quality_program]].

Related: [[project_decision_audit_faithful]] [[project_screener_alphabetical_tiebreak]]

---
name: project_rs_warmup_gap
description: "ROOT CAUSE of ~77% rs_value=None: warmup_days_for Weinstein=210 (30wk) < RS's 52wk requirement; panel clipped at warmup_start → first 22 weeks of EVERY window/fold have rs=None for ALL symbols (zero RS score points, spine-7 silently inert ~21% of every 2y WF-CV fold). Fix = 364d (one constant, like Sector_rotation) but re-pins all goldens + warehouse rebuilds → DECISION ITEM dev/notes/rs-warmup-gap-2026-07-07.md."
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
Related: [[project_decision_audit_faithful]] [[project_screener_alphabetical_tiebreak]]

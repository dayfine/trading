# cascade-selection-inversion-2026-06-10

Forensic validation of the cascade-score selection inversion (P0,
2026-06-10). Full writeup + tables: `dev/notes/cascade-selection-inversion-2026-06-10.md`.

## Contents
- `scn-top{3000,1000,500}.sexp` — single full-period Cell-E scenarios
  (2011-2026, snapshot mode). Reuse the `snap_top3000_2011` warehouse for all
  three (superset; narrower cells swap `universe_path`). `name` + `universe_path`
  are the load-bearing fields; the `description` string is stale-copied (says
  "top-3000" in all three) — harmless.

## Headline
Cascade `score==85` (grade A+ = confirmed Stage1→2 breakout, `w_stage2_breakout
+30`) is the **worst** bucket on win-rate + mean return across top-3000/1000/500
— net-negative total pnl on the two narrow ones. The higher-win-rate trades are
`score==70` early-Stage2 entries (`weeks_advancing ≤ 4`, +15). The cascade ranks
the worse entries higher.

Caveat: the **return** edge is non-stationary (strong 2011-18, gone/reversed
2019-26 as breakouts caught the bull's fat-tail winners). The **win-rate**
inversion persists. A reweight must clear `experiment-gap-closing` WF-CV + the
confirmation grid — budget for a likely no-promote.

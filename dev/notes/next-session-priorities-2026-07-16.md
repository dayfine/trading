# Next-session priorities — 2026-07-16

**Supersedes** `next-session-priorities-2026-07-15.md`. Its P0 (resistance-v2)
shipped END-TO-END this session; P1/P2 carried unchanged.

## What the 07-15 session shipped

The entire resistance-v2 code track, 6 PRs, all 3-gate merged:

1. **#1974** plan doc (`dev/plans/resistance-v2-supply-sketches-2026-07-15.md`).
2. **#1975 PR-B** — 24 sketch columns appended to `Snapshot_schema` (13→37):
   rolling max-high 130/260/520w, true `Res_bars_seen`, 20-bucket
   close-anchored log histogram; per-day in `Resistance_sketch` (deque sliding
   max + oracle-pinned). Virgin test `breakout >= Res_max_high_520w` bit-equal
   v1 incl. tie. No format-version bump — schema-hash gate. **All pre-existing
   local warehouses stale.**
3. **#1979 PR-C** — `Resistance_supply`: continuous score [0,1]
   (proximity-weighted hist mass sat. 8 bars; horizon floors .4/.25/.1 only
   when hist blind; virgin 0; Insufficient 0.5 = unknown ≠ virgin); letter
   grade derivable (score/display split).
4. **#1982 PR-B2** — deep-history feed (§D4): `compute_windowed ~deep_bars`,
   `Pipeline ?deep_bars` (sketch-only; 13 columns bit-identical basis-guard),
   `Build_runner` deep-load split, `-sketch-deep-days` (default 3650).
5. **#1983 PR-D** — screener wiring, default-off: `w_overhead_supply : int
   option [@sexp.default None]` replaces binary `_resistance_signal` points
   with `round(w·(1−score))` when armed; `Stock_analysis` supply threading;
   `Resistance_sketch_reader`; Variant_matrix axis validated. 1 QC rework
   (replace-not-add + reader-guard pins).
6. **#1980** track file `dev/status/resistance-v2.md` + index row.

**Warehouse rebuild LAUNCHED at session end** (in-container, detached):
`/tmp/snap_top3000_dedup_v3_sketch` — dedup-v2 flags + new sketch columns +
deep feed; log `/tmp/wh_rebuild.log` (marker line `exit:0` when done).
3015 symbols, window 1999-01-02..2026-06-26.

## P0 — PR-E: the WF-CV score-weight surface

1. **Verify the rebuild**: `docker exec trading-1-dev tail /tmp/wh_rebuild.log`
   (want `exit:0`); spot-check a .snap has 37 columns (dump_snap) and that
   `Res_bars_seen` at an early-2000 row for an old symbol is > window count
   (deep feed live).
2. **Do-no-harm cell**: record convention, weight None, new warehouse vs the
   dedup-v2 record run (#1949 / Run D basis). Expect: NOT bit-identical to Run
   D (deep feed doesn't change the 13 columns, but the WAREHOUSE is rebuilt —
   should be bit-identical actually IF CSV inputs unchanged; any drift =
   investigate before the surface).
3. **Surface**: `((key (screening_config weights w_overhead_supply))
   (values (0 5 10 15 20 30)))` (0 = today), record convention, top-3000 deep
   window, WF-CV + DSR/Pareto per experiment-gap-closing; also arm
   `overhead_supply` strategy config with `Resistance_supply.default_config`.
   Ledger entry either way. THE question: were the false virgins luck or
   structure ([[project_false_virgins_load_bearing]]).
4. **Perf acceptance**: armed wall ≈ unarmed (~1.5h, not 5h).

## P1 — levered long-short margin realism (unchanged)

`dev/plans/levered-longshort-margin-realism-2026-07-14.md` (M1-M4).

## P2 — research queue (carried)

- Trader-preset bundle audit + WF-CV (presets as wholes, W3).
- Floor-quality P1b step 3: SPY-sleeve lens screen vs TR-SPY.
- decision_audit Phase-2 forward-return counterfactual.
- P3 grind-weeks exposure; P4 faithful per-week universes.

## Standing constraints (additions from 07-15)

- Live weekly-review keeps `resistance_lookback_bars 520` armed for text
  honesty until PR-E verdict; live CSV path still uses v1 binary grade
  (get_sketch → None) — snapshot-mode live picks would get v2 display.
- Long dune in the container: run DETACHED with file log + `exit:$?` marker
  (`memory/feedback_docker_exec_dune_wedge.md`) — reaped docker-exec clients
  wedge dune at 0% CPU on the dead pipe; kill -9 corrupts `_build/.db`
  (fix: rm it).
- PR merges kept failing "expected checks": orchestrator summary merges move
  main ~2×/day → `gh pr update-branch` + re-wait is the loop.
- A PR with **mergeStateStatus DIRTY runs NO pull_request workflows** ("no
  checks reported") — a conflicted PR looks like a CI outage; rebase first
  (#1983 lesson, conflict was the track status file).
- qc-structural still misses dune-wired linters; devtools/checks via CI or
  detached local run is the authority (#1979 nesting caught by CI only).

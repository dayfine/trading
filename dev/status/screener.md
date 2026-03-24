# Status: screener

## Last updated: 2026-03-24

## Status
READY_FOR_REVIEW

## QC Review
NEEDS_REWORK — See dev/reviews/screener.md

## Interface stable
YES

## Blocked on
data-layer interface: STABLE (confirmed via feat/data-layer branch)

## Completed
- Created `analysis/weinstein/` directory structure with dune-project
- `types/` — Shared Weinstein domain types (stage, grade, RS trend, MA slope, etc.)
  - `stage` variant with metadata (weeks_in_base, weeks_advancing, late flag)
  - `grade` with derived ordering (A+ > A > B > C > D > F)
  - All types have `[@@deriving show, eq]`
- `indicators/sma/` — SMA and linearly-weighted MA with slope calculation
  - `simple`: N-period SMA, returns list of (date, ma) values
  - `weighted`: Linearly-weighted MA (newest weight=N, oldest weight=1)
  - `slope_pct`: Percentage slope over a lookback window
- `stage/` — Stage 1-4 classifier (pure function, configurable thresholds)
- `rs/` — Relative strength vs benchmark (Mansfield normalization)
- `volume/` — Volume confirmation for breakouts and pullbacks
- `resistance/` — Overhead resistance grading (Virgin/Clean/Moderate/Heavy)
- `stock_analysis/` — Composite analysis record combining all sub-analyses
- `sector/` — Sector health classification from constituent stage distribution
- `screener/` — Full cascade filter: macro gate → sector filter → additive scoring → grade

All modules: `.mli` + `.ml` + OUnit2 test suite

## In Progress
- Docker build verification not possible in worktree env — QC agent must verify

## Next Steps
- QC agent: verify `dune build && dune runtest` passes
- Future: Macro analyzer module (DJI stage + A-D line + breadth indicators)
- Future: Breakout detector module

## Recent Commits
- 7b634c1 Add Weinstein analysis pipeline: types, SMA, stage classifier, RS, volume, resistance, screener

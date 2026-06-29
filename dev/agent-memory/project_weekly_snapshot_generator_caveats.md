---
name: project_weekly_snapshot_generator_caveats
description: "generate_weekly_snapshot (M6.6) live-pick caveats — macro=index-stage-only, alphabetical-cap scoring gap, stale-exclusion brittleness, CSV-mode slow at 3k"
metadata: 
  node_type: memory
  type: project
  originSessionId: 697feacb-3bb3-4fcf-b0b1-2706070b55c0
---

`generate_weekly_snapshot` (M6.6, `trading/trading/weinstein/snapshot/gen/`) runs
live/backfill weekly Weinstein pick snapshots → `dev/weekly-picks/<sysver>/<date>.sexp`
(+ `render_weekly_report` → `.md`, **stdout only — redirect to file**). Run in
container `trading-1-dev`; CSV bar store `/workspaces/trading-1/data` (sharded
`<c>/<c>/<SYM>/data.csv`). Index symbol = `GSPC.INDX`. Eligible universe via
`build_eligible_universe_runner` (gates price≥$5, 30d avg$vol≥$1M, ≥30wk).

Four caveats found 2026-06-28 (backfilling a 5-week series 05-29..06-26):

1. **Macro regime = ONLY the primary-index (GSPC.INDX) Weinstein Stage.** The
   generator calls `Macro.analyze ~ad_bars:[] ~global_index_bars:[]`, so 4 of 5
   macro indicators degrade to Neutral and the index-stage vote (weight 3.0) alone
   decides Bullish(score 1)/Bearish(0). ⇒ GSPC.INDX bars MUST be present+fresh or
   macro is wrong. The committed 06-12 SEED (`58ff1e79/`, Bearish, 0 longs) was a
   **broken-data artifact** — re-run on clean data = Bullish + 20 longs. "0 longs +
   all-shorts" is the broken-macro-gate symptom.

2. **Pick "ranking" is alphabetical, not scored.** Every long candidate ties at
   score 70 / grade A; ties break alphabetically then cap at 20 ⇒ output is "first
   20 A-ticker grade-A breakouts" (ACA..AXTA), never reaches B+. "Top 3" is
   meaningless. Needs a discriminating score (RS rank / breakout quality). Echoes
   [[project_cascade_selection_inversion]] (score anti-predictive at top grade).

3. **Eligibility silently drops stale symbols.** `build_eligible_universe._is_active`
   requires `entry.data_end_date >= as_of_date`. A symbol not fresh to the EXACT
   screening date is excluded — our backfill left AAPL/MSFT/NVDA 2 trading days
   stale (last bar 06-22 vs as-of 06-26) → mega-caps dropped from the universe
   (2,686 vs 3,158 once fetched fresh). Brittle: one missing day silently shrinks
   the universe. Fix data first (fetch the STALE set, not the already-in-universe
   set — that's circular), then rebuild. AAPL fresh still wasn't a pick (not a
   Stage-2 breakout — correct).

4. **CSV mode is slow at scale:** ~2h20m for a 3,158-symbol single-date snapshot.
   Use snapshot-warehouse mode for N≳1000 (see [[feedback_large_n_needs_snapshot_mode]]).

No live cron exists (M6.6 scheduling DEFERRED, `dev/status/weekly-snapshot.md`);
backfill is run by hand. GHA can't — bars live only in the persistent container.

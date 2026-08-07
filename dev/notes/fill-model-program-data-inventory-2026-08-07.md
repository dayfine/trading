# Fill-model program — data inventory + re-run recipe (deep-dive handoff)

Handoff for a fresh-session deep dive into the entry fill-model program
(#2158 arc). Reading order for the findings:
`sim-entry-fill-ladder-2026-08-05.md` → `bke-order-diagnosis-2026-08-05.md`
→ `honest-ladder-2026-08-05.md` → `localtop-deepdive-2026-08-06.md` →
`fullbook-ladder-2026-08-06.md`. Memory: `project_fill_model_inversion` (⭐),
`project_entry_trigger_decision`, `project_sim_entry_stoplimit_reject`.

## The nine runs (all 26y, top-3000 PIT-2000, 2000-01-01→2026-06-26, split-safe basis)

| Arm | Config delta vs record-convention | Realized | Sharpe | MaxDD |
|---|---|---:|---:|---:|
| control (record) | none (market fill, deep floor) | +8,367% | 0.90 | 37.1% |
| cap15 (deep-pair) | stoplimit + ext_max 15, close-trigger | +4,108% | 0.77 | 40.9% |
| trigonly (deep-pair) | stoplimit + ext_max 1000, close-trigger | +2,852% | 0.71 | 40.7% |
| estop2 | + sim_entry_trigger_at_suggested, band 2 | +965%† | 0.30 | 29.5% |
| estop15 | + trigger_at_suggested, band 15 | +244% | 0.41 | 37.7% |
| localtop26 | estop2 + entry_anchor_local_range_weeks 26 | +474% | 0.57 | 39.3% |
| localtop52 | estop2 + local_range_weeks 52 | +177% | 0.38 | 29.5% |
| fullbook-graded | estop2 + stop_anchor_at_entry_base | +287% | 0.48 | 23.2% |
| fullbook-local26 | localtop26 + stop_anchor_at_entry_base | +268% | 0.44 | 40.8% |

† estop2 contaminated by one corrupt-bar trade (ELI +$4.26M); corrected
≈ +400-500%. See localtop-deepdive Finding 2.

## What is COMMITTED (durable, in-repo)

`dev/experiments/stoplimit-entry-wfcv-2026-08-04/`:
- `deep-pair/` — control, cap15, trigonly: actual.sexp + trades.csv
- `honest-ladder/` — control, estop2, estop15: actual.sexp + trades.csv
- `localtop-ladder/` — localtop26, localtop52: actual + trades + equity_curve;
  control-equity.csv
- `fullbook-ladder/` — fullbook-graded, fullbook-local26: actual + trades +
  equity_curve
- WF-CV surface (sp500 31-fold): aggregate.sexp, fold_actuals.sexp,
  walk_forward_report.md; ledger `_ledger/2026-08-04-sim-entry-stoplimit-surface.sexp`

**trades.csv schema (20 cols)** — rich enough for most deep dives:
`symbol, side, entry_date, exit_date, days_held, entry_price, exit_price,
quantity, pnl_dollars, pnl_percent, entry_stop, exit_stop, exit_trigger,
entry_stage, entry_volume_ratio, stop_initial_distance_pct, stop_trigger_kind,
days_to_first_stop_trigger, screener_score_at_entry, position_id`

## What is NOT committed (ephemeral — removed with the sweep worktrees)

Regenerate by re-running (deterministic; see recipe): `trade_audit.sexp`
(screening context per entry: cascade components, `alternatives_considered`
with skip reasons — the "AXTI skipped 24× Stop_too_wide" source — macro/stage/RS
at entry, resistance grades, AND execution-faithfulness records),
`open_positions.csv` (end-of-run open book), macro_trend / stale_holds /
fold_health / summary / splits sexps. Also missing: equity curves for
cap15/trigonly/estop2/estop15 (only control-basis/localtop/fullbook curves
survived).

## Reproducibility dependency (CHECK FIRST in a fresh session)

Warehouse `/tmp/snap_top3000_dedup_v5thin_adj` (1.3G, schema_hash
`060588c0224b7d7e73f367fbd1801084`) in container `trading-1-dev`. It lives in
ephemeral `/tmp` — if reaped, rebuild is a multi-hour split-safe job before any
re-run works. Verify:
```
docker exec trading-1-dev bash -c 'ls /tmp/snap_top3000_dedup_v5thin_adj/manifest.sexp && du -sh /tmp/snap_top3000_dedup_v5thin_adj'
```

## Re-run recipe (regenerates trade_audit.sexp + open_positions.csv for any arm)

Scenarios are committed under
`trading/test_data/backtest_scenarios/staging-record-convention/`
(9 files: `...-record-convention[-{cap15,trigonly,estop2,estop15,localtop26,
localtop52,fullbook-graded,fullbook-local26}].sexp`).

GOTCHA (from this arc): `scenario_runner` writes output to
`dev/backtest/scenarios-<ts>/` UNDER the run tree — so run from a pinned
worktree and copy artifacts out before removing it, or they vanish. Use a
pinned worktree per sweep-hygiene:
```
# HOST: pin a clean worktree at a commit containing the scenarios (main is fine now)
SHA=$(git rev-parse --short origin/main)
git worktree add --detach .claude/worktrees/rerun-audit "$SHA"
docker exec trading-1-dev bash -c 'cd /workspaces/trading-1/.claude/worktrees/rerun-audit/trading && eval $(opam env) && dune build trading/backtest/scenarios/scenario_runner.exe'
mkdir -p /tmp/sweeps/rerun-scen  # copy the target arm sexp(s) in
docker exec -d trading-1-dev bash -c '
  WT=/workspaces/trading-1/.claude/worktrees/rerun-audit/trading
  cd "$WT" && eval $(opam env) && export TRADING_DATA_DIR=$WT/test_data && export SNAPSHOT_CACHE_MB=1024
  _build/default/trading/backtest/scenarios/scenario_runner.exe \
    --dir /tmp/sweeps/rerun-scen --snapshot-dir /tmp/snap_top3000_dedup_v5thin_adj \
    --no-emit-all-eligible --parallel 1 --progress-every 26 > /tmp/sweeps/rerun.log 2>&1'
# output: $WT/dev/backtest/scenarios-<ts>/<arm>/{trade_audit.sexp,open_positions.csv,...}
# COPY OUT before removing the worktree.
```
Wall time ~30-90 min per E-anchored arm (resting orders are slow); the
market-fill control arm is faster. `dump_snap` for raw bars:
`_build/.../snapshot_warehouse/dump_snap/dump_snap.exe <SYM>.snap <from> <until>`.

## The open decision (unchanged, for the fresh session)

A/B in `project_fill_model_inversion` / `fullbook-ladder-2026-08-06.md`:
(A) align live tickets to the record rule (market/limit-at-open + deep floor)
vs (B) re-base records to the book ticket (~+287%, DD 23%). No compute running;
all four levers default-off, promotion gated on WF-CV + confirmation grid.

# Next-session priorities — 2026-05-09

## Where we are (post-2026-05-08-evening)

20 PRs merged 2026-05-08. State at end of day:
- **Q1 memory cliff fixed** (15y peak 11.4 GB → 1.95 GB).
- **15y Cell A baseline refreshed** (`#1006`): 110.84% / 302 trades / 0.46 Sharpe / 23.33% MaxDD. Old pin (5.15%) was 105 ppt stale.
- **Cell E generalization confirmed**: 11/12 ≈ 92% win-rate across 4 full windows + 7/8 walk-forward halves. (`#1002`, `#1005`)
- **Cell E 15y measurement BLOCKED** by O(N²) trade-history scaling (`#1007`).
- ocamlformat skew permanently fixed (`#991` opam-repo SHA pin + image rebuild).

## P0 — investigate + fix the O(N²) trade-history hotspot

This is the single biggest unblocker for the strategic flip-defaults decision. Until it's fixed:
- Cell E h=2 cannot be measured on 15y (we only got 54% through, 200+ hours projected).
- Any high-frequency strategy variant on long windows will hit the same wall.
- Live trading at expected trade-rate (~200-400 round-trips/year per portfolio) may degrade as trade history accumulates over months.

### What was observed

`dev/notes/cell-e-15y-engineering-blocker-2026-05-09.md` documents the symptom:

| | Vanilla 15y | Cell E 15y partial @ 2018-07-13 |
|---|---|---|
| Trades | 302 (full) | 1,994 (54% through window) |
| CPU time | ~50 min | 46 min CPU but only 54% done |
| Cycle rate (early) | ~30 cycles/min | similar |
| Cycle rate (late) | ~30 cycles/min | **~1 cycle / 30 min** |

The cycle-rate collapse correlates with trade count growth — after the first ~1,000 trades accumulate, each subsequent cycle takes ~30 min instead of ~2 sec. This is the classic O(N) (or worse) per-step fold over a growing list.

### Suspect hot paths (in rough order of likelihood)

1. **`Trade_audit.t.trades` list growth** — `trading/trading/backtest/lib/trade_audit.ml`. Every call to log/lookup/filter trades may iterate the full list. At 2,000 trades, a single fold/filter is 2,000 iterations × however-often-it's-called-per-cycle.
2. **`Laggard_rotation.evaluate`** — `trading/trading/weinstein/laggard_rotation/lib/laggard_rotation.ml`. Called every Friday cycle. May re-score all open positions, scanning trade history for prior performance.
3. **`step_history` end-of-run analytics** — Q1 Fix B (#993) projected `step_result.portfolio` to skinny summary, but `step_history` itself is still O(days) and the metric folds over it might be quadratic.
4. **Stop-state per-position bookkeeping** — `trading/trading/weinstein/stops/lib/weinstein_stops.ml`. As more positions cycle through, the closed-position map could leak.

### Investigation plan (recommended order)

1. **Reproduce on smaller scale.** Run Cell E on a 5y / 302-symbol scenario (we have those from `cell-e-walk-forward-2026-05-08`). Capture a baseline wall-time + cycle-rate-vs-trade-count chart. The pattern should hold at smaller scale.
2. **Memtrace the suspect run.** PR #538 added `--memtrace <path>` to `backtest_runner.exe`. Run Cell E 5y with `--memtrace dev/perf/cell-e-memtrace.ctf`. Then `memtrace_viewer dev/perf/cell-e-memtrace.ctf` shows callsite-attributed allocation rates. The function whose allocation rate scales with cumulative trade count is the hot path.
3. **Confirm with a counter.** Add a per-call counter to the suspect function (one log line at intervals). If the call count per cycle scales with trade count, that's the smoking gun.
4. **Fix the structure.** Likely options:
   - **Bounded ring buffer** for step_history — keep only the last N steps; let metric folds compute incrementally.
   - **Online metric folding** — Q1 Fix D (deferred, ~300-500 LOC) of the original investigation. Compute Sharpe / MaxDD / etc. incrementally during the simulation rather than over `step_history` post-run.
   - **Trade-audit indexing** — keep `trades : Trade.t list` but build a per-symbol or per-week index for quick lookup; avoid full-list scans.
5. **Verify with Cell E 15y rerun.** Target: complete in ≤2 hours wall-time post-fix. Compare numbers to vanilla 15y.

### Success criteria

- Cell E h=2 on 15y completes in ≤2h wall-time (currently >200h projected).
- Vanilla 15y wall-time should not regress (currently ~50 min on GHA).
- 5y goldens (sp500, small) wall-time should not regress.
- Cell E 5y returns (already measured 120% / 0.93 Sharpe) should be bit-equal post-fix — a pure perf optimization should not change strategy outputs.

### Estimate

Investigation: ~2-4 hours (dispatch + memtrace + analysis).
Fix: ~200-500 LOC depending on which structure is hot. Probably 1-2 PRs.

## P1 — re-run Cell E 15y after the fix lands

Once the hotspot is fixed, re-run `dev/experiments/cell-e-15y-2026-05-09/scenarios/sp500-2010-2026-cell-E.sexp` to completion. Compare to vanilla 15y baseline (110.84% / 302 trades).

If Cell E 15y wins by ≥30 ppt return AND ≥0.2 Sharpe (proportional to the small-window deltas), the **flip-defaults case is ironclad** (12/12 windows, including 15y).

Then the flip itself: change `enable_stage3_force_exit` + `enable_laggard_rotation` defaults to `true` in `weinstein_strategy_config.mli`. ~10 LOC + scenario fixture refresh + design doc update.

## P1 — Cell D measurement on small-windows + walk-forward

While the engineering investigation is in flight, run **Cell D** (Stage3-k1 + Laggard-h4 — less aggressive than Cell E h=2) on the same 4-window + walk-forward grid we ran for Cell E. Cell D had 164 trades over 5y vs Cell E's 196, so should scale better to 15y.

If Cell D's 15y is measurable + still beats vanilla, that's the practical default flip even if Cell E never gets to a measurable state on 15y.

Scenarios already exist for Cell D config (`dev/experiments/capital-recycling-combined-2026-05-07/scenarios/cell-D-stage3-k1-laggard-h4.sexp`) — just needs to be ported to the 4-window + walk-forward grids we built today (`dev/experiments/cell-e-generalization-2026-05-08/`, `dev/experiments/cell-e-walk-forward-2026-05-08/`).

## P2 — broader Cell E coverage on goldens-broad

After the engineering fix lands, run Cell E on `goldens-broad/decade-2014-2023.sexp` and `goldens-broad/sp500-30y-capacity-1996.sexp`. Multi-decade test of generalization. Local-only (broad-universe data not in CI).

## P3 — refresh small-universe Cell A baselines

Side-finding from `#1002`: small-universe Cell A measurements today (e.g. bull-crash 6.3%) are far below their pinned baselines (e.g. 339%). Pins are likely stale from a different code era. Either re-pin or root-cause the drift. Lower priority than P0/P1.

## P3 — promote `golden-runs-sp500-15y.yml` to per-push

Currently nightly cron. After P0 + P1 land + 15y reliably passes within new pin tolerance bands, promote to per-push trigger.

## Tools added this session

- `dev/experiments/capital-recycling-combined-2026-05-07/run_with_perf.sh` — wrapper for cell-style experiments needing wall + RSS capture.
- `dev/experiments/cell-e-generalization-2026-05-08/scenarios/` — 6 scenarios.
- `dev/experiments/cell-e-walk-forward-2026-05-08/scenarios/` — 16 scenarios.
- `.github/workflows/golden-runs-sp500-{5y,15y}.yml` — both upload artefacts (`actual.sexp`, `equity_curve.csv`, `splits.csv`) with 7-day retention. Use `gh run download <run_id>` to fetch postmortem evidence.
- `dev/experiments/m5-4-e3-stop-buffer-sweep/report.md` — 1.00 buffer wins.
- `dev/experiments/m5-4-e4-scoring-weight-sweep/report.md` — resistance-heavy wins.
- `dev/experiments/cell-e-generalization-2026-05-08/report.md` + `cell-e-walk-forward-2026-05-08/report.md` — full Cell E case writeup.

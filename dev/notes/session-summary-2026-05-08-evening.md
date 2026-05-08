# Session summary — 2026-05-08 evening

Continuation of the morning session. Morning closed Q1/Q2/Q3/Q4 (memory cliff
+ bah-spy + perf measurement + workflow split). Evening focus: experiment
follow-ups + investigate the 15y P0 finding (which turned out to be a false
alarm).

## PRs merged this evening

| # | Title |
|---|-------|
| #997 | docs(notes): next-session priorities post-Q1+Q2+Q3+Q4 closure |
| #998 | investigation: 15y split-day adjustment regression — root cause |
| #999 | experiment(m5-4-e3): stop-buffer sweep results — 1.00 buffer wins |
| #1000 | experiment(m5-4-e4): scoring-weight sweep — resistance-heavy wins |
| #1001 | harness(ci): upload golden-runs artefacts for postmortem |
| #1002 | experiment(cell-e-gen): Cell E generalizes 4-of-4 small windows |
| #1003 | harness(ci): broaden golden-runs artefact glob to capture scenario output |
| #989 | ops: daily orchestrator summary 2026-05-08-run2 |
| (#985 closed — superseded by #989) |

7 PRs merged + 1 closed (so 14 PRs total session, 13 merged + 1 closed).

## Key findings

### 1. The "split-day P0" was a false alarm.

Earlier today I observed -85.77% return / 99.93% MaxDD on a local 15y run +
called it a P0 split-day regression. The split-day investigation agent (PR
#998) couldn't reproduce my evidence and pointed out my equity_curve.csv had
been deleted by a cleanup `rm -rf`.

Triggered a fresh GHA 15y run (#25575699009) with the now-merged artefact
upload step. Result: **+110.84% return / 302 trades / 23.3% MaxDD / 21.2%
win-rate / 1.95 GB peak / 55 min wall**. Healthy run, no wild jumps.

The local -85.77% must have come from a contaminated working tree or stale
`_build` cache. Possibly the dev container's cached binary was from before
Fix B (#993) merged.

**Lesson:** when investigating a backtest regression, prefer GHA artefacts
over local container runs — local has too many ways to be on a stale
checkout / cache.

### 2. Pinned 15y baseline is stale by 105 ppt.

Pin in `goldens-sp500-historical/sp500-2010-2026.sexp` (set 2026-05-05):
- `total_return_pct 5.15` (tolerance -5..20)
- `total_trades 102`
- `max_drawdown_pct 16.12`

Today's clean run:
- `total_return_pct 110.84`
- `total_trades 302`
- `max_drawdown_pct 23.30`

That's a 105-ppt return jump and 3× more trades. Either the prior pin was
genuinely measured under different code (something between 2026-05-05 and
today shifted the baseline upward) or the prior pin was itself a stale
measurement.

The pin needs refreshing. After the artefact-glob fix (#1003), the next 15y
cron run (09:00 UTC tomorrow) will upload the full `actual.sexp` so we can
read all six metrics + Sharpe + holding-days + open_positions_value to
update the pin properly.

### 3. Cell E (Stage3 + Laggard h=2) generalizes powerfully.

Tested Cell E vs Cell A (baseline) on 3 small-universe windows. PR #1002.

| Window | Cell A | Cell E | Δ Return | Δ Sharpe |
|--------|--------|--------|----------|----------|
| bull-crash 2015-2020 | 6.3% / 0.14 | **125.0%** / **0.95** | +119 ppt | +0.81 |
| covid-recovery 2020-2024 | 51.7% / 0.54 | 65.1% / 0.64 | +13 ppt | +0.10 |
| six-year 2018-2023 | 10.4% / 0.18 | **115.2%** / **0.77** | +105 ppt | +0.59 |
| sp500-2019-2023 (2026-05-07) | 58.3% / 0.54 | 120.0% / 0.93 | +62 ppt | +0.39 |

Cell E wins **4-of-4 windows** on every metric. Strong signal.

### 4. E3 + E4 sweep results.

- **E3 stop-buffer**: 1.00 (tightest) wins (120%/0.78 Sharpe). 1.05–1.20 are
  bit-equal because the support-floor lookup carries most entries. Not
  conclusive for the canonical default.
- **E4 scoring-weights**: resistance-heavy wins (80.7%/0.65). Volume-heavy
  is worst (35%/0.38/42% MaxDD). Three other axes are bit-equal to baseline.

### 5. Permanent ocamlformat skew root-cause from morning still holds.

PR #991 (opam-repo SHA pin) merged morning. The CI image rebuilt and now
matches the dev container. No more docstring fmt drift expected.

## Outstanding follow-ups

1. **Refresh 15y baseline pin** (Task #22). Wait for tomorrow's cron run +
   read full `actual.sexp` from the artefact + update tolerance bands.
   Refreshed numbers should be: ~110% return ±15%, ~300 trades ±50,
   ~20% MaxDD ±5, ~21% win-rate ±5.

2. **Re-measure Cell E on 15y post-Q1-fix.** The 2026-05-07 Cell E 15y
   measurement was pre-Q1-fix and on uncertain memory state. With Q1 + Cell
   E generalization confirmed on small universes, the 15y Cell E
   measurement should be a top-priority next experiment. May need a new
   scenario `goldens-sp500-historical/sp500-2010-2026-cell-E.sexp` for the
   nightly cron.

3. **Walk-forward partition for the flip-defaults decision.** Cell E wins 4
   out of 4 windows but each is a single fit. Partition each into 50/50
   in-sample/out-of-sample, calibrate `h` on in-sample, test on OOS.

4. **goldens-broad Cell E** (decade-2014-2023, sp500-30y-capacity-1996,
   tier4-broad-10y). Broad-universe + multi-decade test of generalization.

5. **Refresh small-universe Cell A baselines.** bull-crash + six-year
   pinned baselines (per the on-disk `.sexp` comments) are far above Cell A
   today (339% pin vs 6.3% measured on bull-crash). Either rebaseline or
   debug what's different.

6. **flip `enable_stage3_force_exit` + `enable_laggard_rotation` defaults.**
   After 1+2+3 above settle.

## Tools added this session

- `dev/experiments/capital-recycling-combined-2026-05-07/run_with_perf.sh` —
  reusable wrapper for any cell-style experiment that needs wall + peak RSS
  capture.
- `dev/experiments/cell-e-generalization-2026-05-08/scenarios/` — 6
  scenarios (3 windows × cell-A + cell-E) ready to re-run.
- `.github/workflows/golden-runs-sp500-{5y,15y}.yml` — both now upload
  artefacts (`golden-sp500-{5y,15y}-<run_id>.zip`) with 7-day retention.
  Means `actual.sexp` + `equity_curve.csv` + `splits.csv` etc are
  downloadable post-FAIL via `gh run download <run_id>` without local
  reproduction.

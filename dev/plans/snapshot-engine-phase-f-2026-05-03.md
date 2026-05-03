# Plan: snapshot streaming Phase F — Default-flip + Bar_panels.t retirement (2026-05-03)

## Status

PROPOSED. Phase F of the daily-snapshot streaming pivot. Sub-phase F.1
landed today (#793, deprecation marker on `Bar_panels.t`'s top-level
docstring). F.2 + F.3 remain ahead.

Parent plan: `dev/plans/daily-snapshot-streaming-2026-04-27.md` §Phasing
Phase F ("Optional — retire `Bar_panels.t` / `Indicator_panels.t`. Once
`Daily_panels.t` is canonical, the old panel modules go away.").

## Context

Phase A landed the snapshot schema + file format (#779). Phase A.1
extended the schema with OHLCV columns (#786). Phase B landed the
offline pipeline (#781) and was later sped up O(N²) → O(N) (#792).
Phase C landed the runtime layer (`Daily_panels.t` + `Snapshot_callbacks.t`,
#782). Phase D wired the runtime into the simulator's per-tick OHLCV
reads behind a `--snapshot-mode --snapshot-dir <path>` feature flag
(#790). Phase E captured empirical validation on a 7-symbol × 6-month
fixture (`parity-7sym`, #791).

Phase F retires the legacy bar-panels path. The Weinstein strategy still
reads bars via `Bar_panels.t` (through `Bar_reader` / `Weekly_ma_cache` /
`Panel_callbacks` / `Macro_inputs`), so today both paths coexist:
simulator-side OHLCV is opt-in snapshot, strategy-side bar reads stay on
panels. F.2 flips the runner default; F.3 deletes the module.

## Goal

Make snapshot mode the canonical runtime path. After F lands:
- `--snapshot-mode` is the default; CSV mode is the opt-out.
- `Bar_panels.t` is gone from the build.
- The simulator + strategy both read through `Daily_panels.t`.
- Tier-4 release-gate at N≥5,000 becomes feasible (RSS bounded by LRU
  cache cap, not by per-symbol panels-loaded cost).

## Sub-phases

Three sub-PRs at most.

### F.1 — Deprecation marker (DONE, #793)

Documentation-only change to `bar_panels.mli`'s top-level docstring,
naming the trajectory and the two follow-up sub-deliverables (F.2 + F.3).
No `[@@deprecated]` attribute (would emit warnings at every existing
call site and break `-warn-error`). Runtime unchanged. Closed; no
further work.

### F.2 — Default flip + auto-build

Two coupled changes:
1. **Universe-shape extension to the offline writer.** `build_snapshots.exe`
   today rejects `Full_sector_map` universes (writer.ml line 122). The
   runner builds universes via `sector_map_override` from `sectors.csv`
   files in single / smoke / fuzz / baseline modes. F.2 must teach the
   writer to accept this shape (or convert at the boundary).
2. **Auto-build mode in the runner.** Add an `auto_build` mode to
   `Backtest_runner_args`. When `--snapshot-mode` is set without
   `--snapshot-dir`, the runner calls the writer to materialize a snapshot
   directory under a stable conventional path (e.g.
   `data/snapshots/<schema-hash>/`). Idempotency check — re-runs reuse the
   existing directory when the schema hash matches.
3. **Flip the runner default.** `Backtest_runner_args.bar_data_source`
   defaults to `Snapshot { auto_build = true }` instead of `Csv`. CSV
   mode stays available via an explicit `--csv-mode` opt-out flag for the
   transition window. Once F.2 has run uneventfully for several weeks
   across all baseline + tier-3 + tier-4 scenarios, F.3 can proceed.

Estimated 300–500 LOC (writer adapter ~150 LOC; runner auto-build wiring
~100 LOC; default flip + opt-out flag ~50 LOC; tests ~150 LOC).

### F.3 — `Bar_panels.t` retirement

Port the strategy's bar-shaped reads off `Bar_panels.t`. Today, four
modules consume `Bar_panels.t`:
- `Bar_reader` (daily / weekly bar history for stage classification + RS).
- `Weekly_ma_cache` (30-week MA + 52-week RS pre-aggregation).
- `Panel_callbacks` (the strategy's outward-facing read shim).
- `Macro_inputs` (benchmark + sector index reads).

Each must be ported to `Snapshot_runtime.Snapshot_callbacks` (or thin
compat shims that wrap it). Then `bar_panels.{ml,mli}` + tests delete.
Gate: F.2 has run uneventfully across all baseline + tier-3 + tier-4
scenarios for several weeks. Estimated 800–1200 LOC across multiple
PRs (one per consumer + the deletion PR).

## Verification gaps (must clear before F.2 default-flip merges)

Three distinct verifications surfaced during user investigation
(2026-05-02 → 2026-05-03). All three pin a specific behavioural property
that the existing Phase E validation does not cover, and all three must
clear before F.2 makes snapshot mode the canonical path.

### V1 — sp500 5y full-universe parity (snapshot ≡ CSV bit-equality)

**Why.** Phase E (#791) validated bit-equal parity on a 7-symbol ×
6-month fixture (`parity-7sym`, two windows). The original Phase B
writer was O(N²) per symbol (~80 s per AAPL on 30y CSVs), making the
full sp500 5y parity intractable as a single-shot run (~11 h projected).
The Phase B writer was rewritten O(N²) → O(N) in #792 (2026-05-02),
restoring the plan's "~5 min wall" target. The full sp500 5y parity has
not yet been re-run.

Without this verification, F.2 would flip the default for production
users on the strength of a 7-symbol fixture alone — far too narrow a
proof of identity to cover universe-scale behaviours (cross-symbol
ordering, holiday-cluster edge cases on inactive sectors, benchmark vs
universe symbols at scale, etc.).

**Acceptance.** Bit-equal `summary.sexp`, `trades.csv`,
`equity_curve.csv`, `final_prices.csv`, `open_positions.csv`,
`splits.csv`, `universe.txt` between CSV mode and snapshot mode on the
canonical `goldens-sp500/sp500-2019-2023` scenario. Same protocol as
Phase E §F1: run twice, `diff` every output file, exit 0.

**Blocker.** None — Phase B writer perf fix (#792) merged 2026-05-02.

**Local-only.** sp500-2019-2023 universe is 491 symbols; same
universe-scale data path that scopes tier-4 release-gate to local. Not
GHA-runnable.

**Owner.** Maintainer. (Could be packaged for a feat-backtest agent if
the universe-data prereq is satisfiable in the agent's worktree.)

### V2 — ±2w start-date fuzz on snapshot mode

**Why.** PR #788 ran a ±2w `start_date` fuzz on `goldens-sp500/sp500-2019-2023`
on 2026-05-02 13:48Z. That run completed before Phase D (#790,
2026-05-02 14:33Z) wired snapshot reads into the simulator. Result:
the fuzz distribution covers CSV mode only. Snapshot mode under F.2's
default-flipped runtime is a different code path through the simulator's
OHLCV reads, even though Phase E proves point-equality. The fuzz needs
to re-run on snapshot mode to confirm the distribution (trade-count
mean / variance, return mean / variance, max-drawdown) matches CSV-mode
within tolerance.

This catches regressions that Phase E + V1 cannot: the bit-equal
parity guarantee at the seam holds for any individual fixture, but
distribution shifts across a fuzz sweep would surface (a) any path-
sensitive divergence triggered by start-date jitter, (b) any cache-
warmup ordering dependency that only fires under repeated runs against
the same snapshot directory, (c) any LRU-eviction-under-Friday-cycle-
churn ordering effect that affects a small fraction of cells.

**Acceptance.** Re-run #788's ±2w start_date fuzz spec on
`goldens-sp500/sp500-2019-2023` under snapshot mode (with the F.2
default-flip applied, or with `--snapshot-mode --snapshot-dir <prebuilt>`
explicitly). Trade-count distribution + return distribution + max-
drawdown distribution within ±5% of #788's CSV baseline distributions
(spec wording matches #788's own internal tolerance bands).

**Blocker.** Pre-built sp500 snapshot corpus (~5 min build via #792).

**Worktree-feasible.** Yes — once the snapshot corpus is built once,
the fuzz runs entirely within the worktree.

**Owner.** Maintainer or feat-backtest if scope permits.

### V3 — Numeric-key fuzz at scale paired with E3 sweep

**Why.** PR #788's follow-up #3 (stop-buffer fuzz on the full window) is
pending. Separately, the M5.4 E3 stop-buffer sweep agent is in flight on
change-id `vxzkwpyn` (`sweep_spec.{ml,mli}` + `sweep_comparison.{ml,mli}`
+ `--sweep` runner mode). Both produce parameter-jitter distributions
that intersect with V2's snapshot-mode question.

The pair: numeric-key fuzz (e.g. stop_buffer_atr_multiplier ±20%, atr_period
±5, etc.) uses the same spec format as the E3 sweep, and **both should
run on snapshot mode** as the canonical runtime. Running them on CSV
mode now and snapshot mode after F.2 doubles the validation cost; doing
both natively under snapshot mode (after F.2 + V1 + V2 clear) lands the
result in one cycle.

**Acceptance.** PR #788 follow-up #3 + M5.4 E3 sweep both produce their
distributions on snapshot mode (under F.2-default or explicit
`--snapshot-mode`). Sweep-comparison output cells flag any
distribution-shift regression before the result lands as a baseline.

**Blocker.** F.2 default-flip + #788 follow-up #3 PR + E3 sweep PR
all land. Order-of-arrival not strict (E3 sweep can happen on CSV
mode too, but pairing it with snapshot avoids re-running for the
release-gate baseline).

**Owner.** feat-backtest (E3 sweep) + maintainer (#788 follow-up #3
authorship); coordination point at integration time.

## RSS-formula caveat (read before quoting any RSS number)

The matrix fit `RSS ≈ 67 + 3.94·N + 0.19·N·(T−1)` MB
(`dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md`) was
measured **pre-Phase-D, on the CSV-mode loader**. After F.2
default-flips snapshot mode in:

- The β = 3.94 MB / loaded-symbol coefficient is no longer the dominant
  RSS source. Snapshot mode RSS is bounded by `max_cache_mb` (Phase E
  §F3), not by per-symbol panels-loaded cost.
- Plan §C5's literal "30 days × 720 KB = 22 MB" framing assumed a
  per-day file format that Phase A diverged from (per-symbol files).
  Realistic snapshot-mode peak RSS is 50–200 MB depending on
  `max_cache_mb` config + working-set size — still ~50× under the CSV
  baseline at production scale.
- Tier-4 release-gate budgets (8 GB ubuntu-latest ceiling) need to be
  re-derived against snapshot mode after F.2 lands. The N≥5,000 gate
  that motivated the streaming pivot is the headline consumer of this
  re-derivation.

When citing RSS numbers in F.2 / V1 / V2 / V3 PRs, link to Phase E §F3
explicitly and call out which loader was active during measurement. Do
not mix CSV-mode β-fits with snapshot-mode cache-bounded numbers in the
same row of the same matrix.

## Files to touch

F.2 (estimated):
- `trading/analysis/scripts/build_snapshots/build_snapshots.ml` — accept
  `Full_sector_map` universe shape (or boundary converter).
- `trading/analysis/weinstein/snapshot_pipeline/lib/writer.ml` — drop
  the `Full_sector_map` reject at line 122 (or relax it to gate on a
  boundary converter).
- `trading/trading/backtest/runner_args/backtest_runner_args.{ml,mli}` —
  `auto_build` mode + default-flip.
- `trading/trading/backtest/lib/runner.ml` (or `panel_runner.ml`) —
  auto-build dispatch + `--csv-mode` opt-out plumbing.
- `trading/trading/backtest/bin/backtest_runner.ml` — flag parsing for
  `--csv-mode`.
- `trading/trading/backtest/test/test_runner_default_flip.ml` (NEW) —
  parity gate that pins default = snapshot, opt-out = CSV.

F.3 (estimated):
- `trading/trading/data_panel/bar_panels.{ml,mli}` — DELETE.
- `trading/trading/weinstein/lib/bar_reader.{ml,mli}` — port to
  `Snapshot_runtime.Snapshot_callbacks`.
- `trading/trading/weinstein/lib/weekly_ma_cache.{ml,mli}` — port.
- `trading/trading/weinstein/lib/panel_callbacks.{ml,mli}` — port.
- `trading/trading/weinstein/lib/macro_inputs.{ml,mli}` — port.
- All call-site dune files that depend on `data_panel.bar_panels`.

## Open questions

1. **Auto-build idempotency under schema bumps.** What happens when an
   `auto_build` run finds a stale `data/snapshots/<old-hash>/` from a
   prior schema? Default policy proposed: rebuild silently into
   `<new-hash>/`, leave the old directory in place; emit a one-line
   stderr WARN listing both directories. Garbage collection of stale
   directories is a separate concern (manual `rm -rf` or a periodic
   sweep script).
2. **`--csv-mode` lifetime.** F.3's gating criterion ("snapshot-mode-as-
   default has run uneventfully for several weeks") is qualitative.
   Need a concrete trigger — e.g. "after 3 consecutive weekly tier-3
   runs + 1 tier-4 release-gate run all complete with no snapshot-vs-CSV
   delta detected by the V1 / V2 / V3 baselines". Pin this in F.3's plan
   doc when it lands.
3. **Ordering: V1 / V2 / V3 vs F.2 PR sequence.** Two valid orderings:
   - **(a) Verify before flip.** V1 + V2 land as standalone validation
     PRs (just like #791 was for Phase E), then F.2 flips the default
     citing the verifications. V3 follows F.2 because it depends on the
     E3 sweep work landing first.
   - **(b) Flip with verification in-PR.** F.2 includes V1 + V2 as
     gates in its PR description; V3 follows. Smaller PR count, larger
     individual PR.
   Recommendation: **(a)** — keeps each PR ≤500 LOC and matches the
   one-concern-per-PR convention. F.2's PR description cites V1 / V2
   PR numbers as preconditions.

## References

- Parent plan: `dev/plans/daily-snapshot-streaming-2026-04-27.md`
  §Phasing Phase F.
- Phase D plan: `dev/plans/snapshot-engine-phase-d-2026-05-02.md`.
- Phase F.1 (DONE): PR #793.
- Phase E validation: `dev/experiments/m5-3-phase-e-validation/README.md`.
- Phase B writer perf fix: PR #792.
- ±2w fuzz baseline: PR #788 (pre-Phase-D).
- E3 stop-buffer sweep: in flight on `vxzkwpyn` change-id.
- RSS-formula caveat source: `dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md`
  (CSV-mode pre-Phase-D measurement) + Phase E §F3 (snapshot-mode
  cache-bounded).
- Bar_panels deprecation marker: `trading/trading/data_panel/bar_panels.mli`
  §"Deprecation trajectory (M5.3 Phase F)".

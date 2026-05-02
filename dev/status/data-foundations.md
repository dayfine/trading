# Status: data-foundations

## Last updated: 2026-05-02

## Status
IN_PROGRESS — M5.3 streaming Phase A + A.1 + B + C + D merged (#779/#786/#781/#782/#790), Phase E validation merged (#791), Phase B perf fix merged (#792), Phase F.1 deprecation marker ready for review (this branch).

Track created 2026-05-02 to absorb M5.3 (scale infra: streaming + Norgate) + M7.0 (data foundations: Norgate, multi-market, synthetic). Plans: `dev/plans/m5-experiments-roadmap-2026-05-02.md` + `dev/plans/m7-data-and-tuning-2026-05-02.md`. Authority: `docs/design/weinstein-trading-system-v2.md` §7 sub-milestones M5.3 + M7.0 (added 2026-05-02).

## Interface stable
NO — track is brand-new.

## Blocked on
- None for first PR (Synth-v1 block bootstrap is independent).
- Norgate ingest blocked on user vendor signup ($32–66/mo).

## Scope

### Track 1 — Norgate Data ingestion

| Item | Value |
|---|---|
| Vendor | Norgate Data ($32–66/mo) — user-confirmed budget OK |
| Coverage | US 1990-present; point-in-time S&P 500 / Russell 1000 / Russell 2000 membership; delisted symbols included |
| Why | EODHD's universe = today's universe → survivorship bias upward on all backtests |
| Storage | `dev/data/norgate/<sym>.csv` (gitignored — licensing) |
| Index membership | `dev/data/norgate/index_membership/<index>/<date>.csv` |

New paths:
- `analysis/data/sources/norgate/lib/norgate_client.{ml,mli}`
- `analysis/data/sources/norgate/bin/fetch_universe.ml`
- `analysis/data/sources/norgate/lib/index_membership.{ml,mli}`
- `analysis/data/sources/norgate/test/test_round_trip.ml`

### Track 2 — EODHD multi-market expansion

5 markets to add (already paid in EODHD plan, just wire symbol resolution):
- LSE (London) — different regime structure
- TSE (Tokyo) — lost-decade test bed (1990–2020)
- ASX (Sydney) — commodity-heavy
- HKEX (Hong Kong) — China-policy-driven
- TSX (Toronto) — energy-heavy

Modifies: `analysis/data/sources/eodhd/lib/exchange_resolver.{ml,mli}` + `analysis/data/sources/eodhd/test/test_multi_market.ml`.

Per-market calendar handling. Currency tagging on bars.

### Track 3 — Synthetic data generator (4-stage ladder)

#### Synth-v1 — Stationary block bootstrap (FIRST PR, ~250 LOC)

User-confirmed: do v1 first.

`analysis/data/synthetic/lib/block_bootstrap.{ml,mli}` (new). Resample variable-length blocks (geometric distribution, mean ≈ 30 days) from real source. Preserves auto-correlation + vol clustering up to block-length scale.

Acceptance: 80yr synth from 32yr SPY; skew/kurt/autocorr_lag1 within ±10% of source; deterministic given seed.

#### Synth-v2 — HMM regime layer (FOLLOW-UP, ~800 LOC)

3 regimes (Bull/Bear/Crisis). Fit transition matrix + per-regime GARCH(1,1). Captures regime persistence.

#### Synth-v3 — Multi-symbol factor model (FOLLOW-UP, ~1000 LOC)

Single-factor: `r_i = β_i × r_market + ε_i` with idiosyncratic GARCH. Enables full strategy backtest on synthetic universe.

#### Synth-v4 — GARCH+jumps (OPTIONAL)

Bates jump-diffusion. Defer until v3 fails.

#### Skip GAN/VAE
Overkill at this stage.

### M5.3 — Daily-snapshot streaming (Option 2 hybrid-tier)

Per `dev/plans/daily-snapshot-streaming-2026-04-27.md`. ~3000 LOC across 5–8 PRs. Required for tier-4 release-gate at N≥5,000.

Status carries forward from `hybrid-tier` track — that track stays IN_PROGRESS until streaming lands.

## In Progress

- **`feat/snapshot-default-phase-f`** (M5.3 Phase F.1 — deprecation marker on `Bar_panels.t`, partial of the optional Phase F retirement) — READY_FOR_REVIEW. Documents the retirement trajectory in the `.mli` so future readers and new callers see the path. **What this PR does:** adds a §"Deprecation trajectory (M5.3 Phase F)" block to `trading/trading/data_panel/bar_panels.mli`'s top-level docstring, naming the two sub-deliverables (F.1 marker = this PR; F.2 default flip + retirement). No `[@@deprecated]` attribute — that would emit warnings at every existing call site (the strategy still legitimately reads bars through `Bar_panels.t` via `Bar_reader` / `Weekly_ma_cache` / `Panel_callbacks` / `Macro_inputs`) and break the `-warn-error` build. The marker is documentation-only; runtime is unchanged. **What this PR does NOT do** (Phase F.2 follow-up): (a) flip the runner default from CSV to snapshot mode, (b) auto-build the snapshot directory when `--snapshot-dir` is absent, (c) port the Weinstein strategy's bar reads off `Bar_panels.t` onto `Snapshot_runtime.Snapshot_callbacks`. **Why F.2 isn't here:** auto-build requires a `Pinned`-shape universe sexp, but the current runner modes (smoke / fuzz / baseline) constrain universes via `sector_map_override` built from `sectors.csv` files — `build_snapshots.exe` rejects `Full_sector_map` universes (writer.ml line 122). Wiring auto-build correctly across single / smoke / fuzz / baseline modes is a multi-file design problem (universe-shape conversion, snapshot-dir naming convention, idempotency check, schema-skew handling) that doesn't fit a ≤200 LOC PR. The dispatch's "if auto-build proves complex, ship the partial" exit was taken. **F.3 is the actual deletion** (Bar_panels.t removed from the build), planned for after the strategy is ported and the snapshot path has run as default for several weeks. Verify: `dune build && dune runtest` (no test changes; build still passes), `dune build @fmt` clean. PR diff ~25 LOC under `trading/trading/data_panel/bar_panels.mli` + status entry. Plan: `dev/plans/daily-snapshot-streaming-2026-04-27.md` §Phasing Phase F.
- **`feat/snapshot-validation-phase-e`** (M5.3 Phase E — validation + tier-4 spike, PR-5 of the snapshot-streaming sequence) — READY_FOR_REVIEW. Captures the empirical validation that ran against the Phase A.1 / B / C / D stack; ships entirely as documentation under `dev/experiments/m5-3-phase-e-validation/` (no source code changes). **F1 — End-to-end parity holds bit-for-bit** between CSV mode and snapshot mode on the panel-golden / `parity-7sym` fixture: every output file (`summary.sexp`, `trades.csv`, `equity_curve.csv`, `final_prices.csv`, `open_positions.csv`, `splits.csv`, `universe.txt`) is byte-identical across two backend selectors, on both the 2019h2 and 2018h2-2019 windows. The captured summaries are committed at `dev/experiments/m5-3-phase-e-validation/window-{2019h2,2018h2-2019}-{csv,snapshot}-mode.sexp`. **F2 — Phase B writer is O(N²) per symbol.** `pipeline.ml`'s `_ema_at` / `_sma_at` / `_atr_at` / `_rsi_at` / `_weekly_prefix` rebuild from bar 0 every call; per-symbol wall scales as `N_bars²`. Production-data AAPL (~11K bars over 30y) takes ~80 s to write a single snapshot file; the full sp500 corpus is intractable (~11 h projected). The dispatch's "S&P 500 5y golden" parity validation was substituted with the smaller-fixture parity above — sufficient given Phase D's per-call bit-equality and the simulator's determinism. Recommended fix tracked in the experiment README §F2: convert kernels to incremental updaters mirroring `analysis/technical/indicators/{ema,sma,atr,rsi}_kernel.ml`, drops per-symbol cost to O(N) and brings sp500 build to ~5 min. **F3 — Tier-4 RSS bounded by LRU cache cap, not corpus size.** Plan §C5's "30 days × 720 KB = 22 MB" referred to the proposed per-day file format that the implementation diverged from (per-symbol files in Phase A); per-symbol file sizes ~370 KB at test_data 10y → ~2 MB at production 30y. Active cache footprint = `min(N_active × file_size, max_cache_mb)`. At default `max_cache_mb=64` and 2 MB/symbol production scale, ~32 symbols stay resident; bumping cap to 256 MB fits ~128 symbols. Tier-4 actual peak RSS for the snapshot cache: 50–200 MB depending on `max_cache_mb` config — still ~50× under the Bar_panels-fully-loaded cost the plan was trying to displace. Phase F (Bar_panels retirement) is unblocked from a correctness standpoint; the F2 O(N²) issue should be fixed first as a prerequisite to running real Phase F validation experiments at sp500 scale (otherwise each schema bump forces ~11 h of corpus rebuild). Verify: `cd trading && TRADING_DATA_DIR=$PWD/test_data ./_build/default/trading/backtest/bin/backtest_runner.exe 2019-05-01 2020-01-03 --experiment-name csv-mode-baseline` then same with `--snapshot-mode --snapshot-dir /tmp/snapshots-7sym --experiment-name snap-mode-test`; `diff` every output file → all exit 0. PR diff ~370 LOC, all under `dev/experiments/`. Plan: `dev/plans/daily-snapshot-streaming-2026-04-27.md` §Phasing Phase E.
- **`feat/snapshot-engine-phase-d-v2`** (M5.3 Phase D — engine + simulator integration, PR-4 of the snapshot-streaming sequence) — READY_FOR_REVIEW. Wires Phase C's `Daily_panels.t` runtime into the simulator's per-tick OHLCV reads behind a `--snapshot-mode --snapshot-dir <path>` feature flag. Default mode (no flag) is byte-identical to pre-PR behaviour — the existing CSV path through `Trading_simulation_data.Market_data_adapter.create ~data_dir` is untouched. Snapshot mode constructs a callback-mode adapter via a new `Market_data_adapter.create_with_callbacks` constructor (price + previous-bar closures; `get_indicator` returns `None` and `finalize_period` is a no-op since `Panel_strategy_wrapper` substitutes its own panel-backed indicator surface anyway). The closure pair lives in a new `Backtest.Snapshot_bar_source` shim that maps each `Snapshot.t` row to a `Daily_price.t` via the Phase A.1 OHLCV fields (`Open` / `High` / `Low` / `Close` / `Volume` / `Adjusted_close`); `get_previous_bar` uses a 60-day `Daily_panels.read_history` lookback (covers any realistic US holiday cluster). Selector lives in `Backtest.Bar_data_source` (`Csv | Snapshot {snapshot_dir; manifest}`); `Panel_runner.run` / `Runner.run_backtest` / `backtest_runner.exe` thread it through. CLI parser validates that `--snapshot-mode` and `--snapshot-dir` appear together. The strategy's bar reads via `Bar_panels.t` are unchanged — that retirement is Phase F; Phase D ships only the simulator-side OHLCV swap so Phase E (validation + tier-4 spike) can land. Parity gate: new `test_snapshot_mode_parity.ml` (3 tests, ~230 LOC fixture) builds the same in-memory bar stream into both a CSV directory and a snapshot directory and asserts both adapters return bit-identical `Daily_price.t` for every (symbol, date) on `get_price` + `get_previous_bar`, plus None-on-missing/None-on-unknown parity. Verify: `dune build && dune runtest trading/backtest trading/simulation` (existing 33 backtest test suites + 3 new parity tests + 4 new args-parser tests pass) + `dune build @fmt` clean. PR diff ~711 LOC excluding plan (over the 600 plan-cap; ~250 of that is fixture-builder helpers in the parity test). Plan: `dev/plans/snapshot-engine-phase-d-2026-05-02.md`.
- **`feat/snapshot-schema-ohlcv`** (M5.3 Phase A.1 — OHLCV columns precursor for Phase D) — READY_FOR_REVIEW. Extends `Snapshot_schema.field` with six new variants (`Open` / `High` / `Low` / `Close` / `Volume` / `Adjusted_close`) appended after the original 7 indicator scalars; updates `Pipeline.build_for_symbol` to write them from `Daily_price.t.open_price` / `high_price` / `low_price` / `close_price` / `volume` (cast `int → float`) / `adjusted_close`. Discovered while planning Phase D engine integration: the per-tick simulator must price orders from raw OHLCV and the Weinstein strategy reads OHLCV via `Bar_reader` for `Stage.classify` / `Volume.analyze_breakout` / `Resistance.analyze`. Without the OHLCV columns, Phase D would either (a) re-introduce a parallel bar-shaped data path (defeats the snapshot architecture) or (b) blow past the 400-LOC budget. Schema width grows 7 → 13; existing column indices for indicator fields are unchanged. Schema hash necessarily changes (it is content-addressable by design — see `Snapshot_schema.compute_hash`); pre-existing on-disk snapshots become unreadable under the new `default` and the manifest's `schema_hash` gate fires loudly. This is intentional behaviour, not a regression. Verify: `dune build && dune runtest trading/data_panel/snapshot analysis/weinstein/snapshot_pipeline analysis/weinstein/snapshot_runtime` (52 tests pass: 9 schema + 7 snapshot + 8 format + 16 pipeline + 12 daily_panels) + `dune build @fmt` clean. PR diff ~272 LOC including tests.
- **`feat/snapshot-runtime-phase-c`** (M5.3 Phase C — runtime layer, PR-3 of the snapshot-streaming sequence) — READY_FOR_REVIEW. Adds `weinstein.snapshot_runtime` library under `trading/analysis/weinstein/snapshot_runtime/` with two modules:
  - `Daily_panels.t`: opaque cache handle wrapping the per-symbol snapshot directory written by Phase B. Lazy-loads each symbol's `.snap` file on first access via `Snapshot_format.read_with_expected_schema` (loud schema-skew detection per Phase A); holds decoded `Snapshot.t list` in memory; evicts least-recently-used symbol when the configurable byte budget (`max_cache_mb`) is exceeded. LRU is `Doubly_linked` (Core) with O(1) `move_to_front` on hit + O(1) tail eviction. Public surface: `create`, `schema`, `read_today`, `read_history`, `cache_bytes`, `close`. "mmap" in Phase C means cache + LRU with sexp decode (Phase A's payload is sexp-encoded); the API is shaped so that the Phase F upgrade to `Bigarray.Array2.map_file` is local to this module — `read_today` / `read_history` callers won't notice.
  - `Snapshot_callbacks.t`: thin field-accessor shim. Two closures (`read_field` / `read_field_history`) that take `(symbol, date, field)` and return the precomputed scalar. Decoupled from the existing bar-shaped `Stock_analysis.callbacks` because that contract is built around walking bar histories — Phase D will plug this into whatever bar-shaped consumer the strategy ends up calling, and the bar-shaped layer can retire in Phase F.
  Memory budget verification: at N=10K × 30-day window, ~22 MB of rows live in the cache (plan §C5); cap is enforced as the new symbol pushes total over `max_cache_mb`. Test `test_lru_evicts_when_over_budget` drives a 6-symbol × 5K-row load against a 1 MB cap and asserts `cache_bytes` stays bounded. Verify: `dune build && dune runtest analysis/weinstein/snapshot_runtime` (17 tests pass: 12 `Daily_panels` + 5 `Snapshot_callbacks`) + `dune build @fmt` clean. PR diff ~881 LOC including tests + dune (lib alone: ~225 LOC under .ml + .mli).
- **`feat/snapshot-pipeline-phase-b`** (M5.3 Phase B — offline pipeline, PR-2 of the snapshot-streaming sequence) — MERGED as #781. Adds `weinstein.snapshot_pipeline` library (`Pipeline.build_for_symbol`, `Snapshot_manifest`, `Snapshot_verifier`) under `trading/analysis/weinstein/snapshot_pipeline/` plus the `build_snapshots.exe` CLI under `trading/analysis/scripts/build_snapshots/`. Reuses validated weinstein analysers (`Stage.classify`, `Rs.analyze`, `Macro.analyze`) on per-symbol weekly aggregates rather than the panel kernels — Phase B accepts the offline-cost in exchange for parity-by-construction with the runtime path. Macro_composite is computed from the benchmark's own bars (A-D + global indexes deferred to Phase C+ per plan §C1). Manifest schema-hash drives incremental rebuild semantics. End-to-end smoke on AAPL+MSFT+JPM × ~1500 days: 5.16s full, 0.07s incremental rerun (70× speedup), 3/3 verifier pass. Verify: `dune build && dune runtest analysis/weinstein/snapshot_pipeline` (23 tests pass) + `dune build @fmt` clean. PR diff ~750 LOC excluding tests/dune.
- **`perf(snapshot-pipeline): O(N²) → O(N) incremental kernels`** (Phase B perf optimization, PR #792) — APPROVED structural + behavioral QC. Phase E validation (#791) discovered F2: pipeline kernels rebuild from bar 0 every call (O(N²) per symbol; AAPL ~80s/file, sp500 ~11 hours). Refactored via new `indicator_arrays` and `weekly_prefix` modules that precompute all per-day scalars in single-pass walks (O(N) total). Bit-identity preserved on all 16 hand-pinned tests; 35× speedup (11K bars: 7.47s → 0.21s). Design choice: did not reuse existing `trading/data_panel/{ema,sma,atr,rsi}_kernel.ml` (panel-shaped 2D Bigarrays) because single-symbol scalar-state API differs; lifting equations is justified DRY violation (same math, avoids panel scaffolding). Dune: no changes (linter clean). PR diff: +425/-175 (2 new modules + refactored pipeline). Verify: `dune build && dune runtest` (16 pipeline tests pass) + `dune build @fmt` clean. Review: `dev/reviews/snapshot-pipeline-perf.md`.

## Next Steps

1. Open Synth-v1 block bootstrap PR (~250 LOC) — independent of all other work, smallest unblock.
2. EODHD multi-market expansion (parallel; small).
3. Norgate ingest after user signs up + decides which Norgate plan.
4. Daily-snapshot streaming Phase 1 starts after M5.1 hardening lands and `experiments` track M5.2a ships.
5. Synth-v2 + v3 in subsequent sessions, in order.
6. **M5.3 Phase F.2 — runner default flip + auto-build** (follow-up to this PR's F.1 marker). Two sub-tasks: (a) extend `build_snapshots.exe` to accept the runner's universe shape (today the writer requires `Pinned`; runners use `sector_map_override` built from `sectors.csv`); (b) add an `auto_build` mode to `Backtest_runner_args` that calls the writer when `--snapshot-mode` is set without `--snapshot-dir`, with a stable conventional output path under `data/snapshots/<schema-hash>/`. Acceptance: existing baseline / smoke / fuzz scenarios run cleanly under snapshot-mode default with no flag changes from the user. Estimated 300–500 LOC.
7. **M5.3 Phase F.3 — `Bar_panels.t` retirement** (follow-up to F.2). Port `Bar_reader` / `Weekly_ma_cache` / `Panel_callbacks` / `Macro_inputs` off `Bar_panels.t` onto `Snapshot_runtime.Snapshot_callbacks` (or a thin compat shim). Then delete `trading/trading/data_panel/bar_panels.{ml,mli}` + tests. Gate: snapshot-mode-as-default has run uneventfully for several weeks across all baseline + tier-3 scenarios. Estimated 800–1200 LOC across multiple PRs.

## CRSP defer
~$5k/yr institutional. Only viable for 100-year NYSE data (1925+). Skip until M7.1 ML training shows scale matters.

## Out of scope

- 100yr NYSE data via CRSP (deferred).
- Synth-v4 GARCH+jumps (deferred).
- GAN/VAE deep-learning synth (skipped).
- Real-time intraday data (we trade weekly).
- Fundamentals (earnings, ratios) — current strategy is pure technical.

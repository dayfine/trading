# Status: data-foundations

## Last updated: 2026-05-02

## Status
IN_PROGRESS — M5.3 streaming Phase A + A.1 + B merged (#779/#786/#781), Phase C ready for review (#782), Phase D ready for review (this branch).

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

- **`feat/snapshot-engine-phase-d-v2`** (M5.3 Phase D — engine + simulator integration, PR-4 of the snapshot-streaming sequence) — READY_FOR_REVIEW. Wires Phase C's `Daily_panels.t` runtime into the simulator's per-tick OHLCV reads behind a `--snapshot-mode --snapshot-dir <path>` feature flag. Default mode (no flag) is byte-identical to pre-PR behaviour — the existing CSV path through `Trading_simulation_data.Market_data_adapter.create ~data_dir` is untouched. Snapshot mode constructs a callback-mode adapter via a new `Market_data_adapter.create_with_callbacks` constructor (price + previous-bar closures; `get_indicator` returns `None` and `finalize_period` is a no-op since `Panel_strategy_wrapper` substitutes its own panel-backed indicator surface anyway). The closure pair lives in a new `Backtest.Snapshot_bar_source` shim that maps each `Snapshot.t` row to a `Daily_price.t` via the Phase A.1 OHLCV fields (`Open` / `High` / `Low` / `Close` / `Volume` / `Adjusted_close`); `get_previous_bar` uses a 60-day `Daily_panels.read_history` lookback (covers any realistic US holiday cluster). Selector lives in `Backtest.Bar_data_source` (`Csv | Snapshot {snapshot_dir; manifest}`); `Panel_runner.run` / `Runner.run_backtest` / `backtest_runner.exe` thread it through. CLI parser validates that `--snapshot-mode` and `--snapshot-dir` appear together. The strategy's bar reads via `Bar_panels.t` are unchanged — that retirement is Phase F; Phase D ships only the simulator-side OHLCV swap so Phase E (validation + tier-4 spike) can land. Parity gate: new `test_snapshot_mode_parity.ml` (3 tests, ~230 LOC fixture) builds the same in-memory bar stream into both a CSV directory and a snapshot directory and asserts both adapters return bit-identical `Daily_price.t` for every (symbol, date) on `get_price` + `get_previous_bar`, plus None-on-missing/None-on-unknown parity. Verify: `dune build && dune runtest trading/backtest trading/simulation` (existing 33 backtest test suites + 3 new parity tests + 4 new args-parser tests pass) + `dune build @fmt` clean. PR diff ~711 LOC excluding plan (over the 600 plan-cap; ~250 of that is fixture-builder helpers in the parity test). Plan: `dev/plans/snapshot-engine-phase-d-2026-05-02.md`.
- **`feat/snapshot-schema-ohlcv`** (M5.3 Phase A.1 — OHLCV columns precursor for Phase D) — READY_FOR_REVIEW. Extends `Snapshot_schema.field` with six new variants (`Open` / `High` / `Low` / `Close` / `Volume` / `Adjusted_close`) appended after the original 7 indicator scalars; updates `Pipeline.build_for_symbol` to write them from `Daily_price.t.open_price` / `high_price` / `low_price` / `close_price` / `volume` (cast `int → float`) / `adjusted_close`. Discovered while planning Phase D engine integration: the per-tick simulator must price orders from raw OHLCV and the Weinstein strategy reads OHLCV via `Bar_reader` for `Stage.classify` / `Volume.analyze_breakout` / `Resistance.analyze`. Without the OHLCV columns, Phase D would either (a) re-introduce a parallel bar-shaped data path (defeats the snapshot architecture) or (b) blow past the 400-LOC budget. Schema width grows 7 → 13; existing column indices for indicator fields are unchanged. Schema hash necessarily changes (it is content-addressable by design — see `Snapshot_schema.compute_hash`); pre-existing on-disk snapshots become unreadable under the new `default` and the manifest's `schema_hash` gate fires loudly. This is intentional behaviour, not a regression. Verify: `dune build && dune runtest trading/data_panel/snapshot analysis/weinstein/snapshot_pipeline analysis/weinstein/snapshot_runtime` (52 tests pass: 9 schema + 7 snapshot + 8 format + 16 pipeline + 12 daily_panels) + `dune build @fmt` clean. PR diff ~272 LOC including tests.
- **`feat/snapshot-runtime-phase-c`** (M5.3 Phase C — runtime layer, PR-3 of the snapshot-streaming sequence) — READY_FOR_REVIEW. Adds `weinstein.snapshot_runtime` library under `trading/analysis/weinstein/snapshot_runtime/` with two modules:
  - `Daily_panels.t`: opaque cache handle wrapping the per-symbol snapshot directory written by Phase B. Lazy-loads each symbol's `.snap` file on first access via `Snapshot_format.read_with_expected_schema` (loud schema-skew detection per Phase A); holds decoded `Snapshot.t list` in memory; evicts least-recently-used symbol when the configurable byte budget (`max_cache_mb`) is exceeded. LRU is `Doubly_linked` (Core) with O(1) `move_to_front` on hit + O(1) tail eviction. Public surface: `create`, `schema`, `read_today`, `read_history`, `cache_bytes`, `close`. "mmap" in Phase C means cache + LRU with sexp decode (Phase A's payload is sexp-encoded); the API is shaped so that the Phase F upgrade to `Bigarray.Array2.map_file` is local to this module — `read_today` / `read_history` callers won't notice.
  - `Snapshot_callbacks.t`: thin field-accessor shim. Two closures (`read_field` / `read_field_history`) that take `(symbol, date, field)` and return the precomputed scalar. Decoupled from the existing bar-shaped `Stock_analysis.callbacks` because that contract is built around walking bar histories — Phase D will plug this into whatever bar-shaped consumer the strategy ends up calling, and the bar-shaped layer can retire in Phase F.
  Memory budget verification: at N=10K × 30-day window, ~22 MB of rows live in the cache (plan §C5); cap is enforced as the new symbol pushes total over `max_cache_mb`. Test `test_lru_evicts_when_over_budget` drives a 6-symbol × 5K-row load against a 1 MB cap and asserts `cache_bytes` stays bounded. Verify: `dune build && dune runtest analysis/weinstein/snapshot_runtime` (17 tests pass: 12 `Daily_panels` + 5 `Snapshot_callbacks`) + `dune build @fmt` clean. PR diff ~881 LOC including tests + dune (lib alone: ~225 LOC under .ml + .mli).
- **`feat/snapshot-pipeline-phase-b`** (M5.3 Phase B — offline pipeline, PR-2 of the snapshot-streaming sequence) — MERGED as #781. Adds `weinstein.snapshot_pipeline` library (`Pipeline.build_for_symbol`, `Snapshot_manifest`, `Snapshot_verifier`) under `trading/analysis/weinstein/snapshot_pipeline/` plus the `build_snapshots.exe` CLI under `trading/analysis/scripts/build_snapshots/`. Reuses validated weinstein analysers (`Stage.classify`, `Rs.analyze`, `Macro.analyze`) on per-symbol weekly aggregates rather than the panel kernels — Phase B accepts the offline-cost in exchange for parity-by-construction with the runtime path. Macro_composite is computed from the benchmark's own bars (A-D + global indexes deferred to Phase C+ per plan §C1). Manifest schema-hash drives incremental rebuild semantics. End-to-end smoke on AAPL+MSFT+JPM × ~1500 days: 5.16s full, 0.07s incremental rerun (70× speedup), 3/3 verifier pass. Verify: `dune build && dune runtest analysis/weinstein/snapshot_pipeline` (23 tests pass) + `dune build @fmt` clean. PR diff ~750 LOC excluding tests/dune.

## Next Steps

1. Open Synth-v1 block bootstrap PR (~250 LOC) — independent of all other work, smallest unblock.
2. EODHD multi-market expansion (parallel; small).
3. Norgate ingest after user signs up + decides which Norgate plan.
4. Daily-snapshot streaming Phase 1 starts after M5.1 hardening lands and `experiments` track M5.2a ships.
5. Synth-v2 + v3 in subsequent sessions, in order.

## CRSP defer
~$5k/yr institutional. Only viable for 100-year NYSE data (1925+). Skip until M7.1 ML training shows scale matters.

## Out of scope

- 100yr NYSE data via CRSP (deferred).
- Synth-v4 GARCH+jumps (deferred).
- GAN/VAE deep-learning synth (skipped).
- Real-time intraday data (we trade weekly).
- Fundamentals (earnings, ratios) — current strategy is pure technical.

# Status: data-foundations

## Last updated: 2026-05-13

## Status
READY_FOR_REVIEW

## Notes
M5.3 streaming Phases A + A.1 + B + C + D + E + F.1 all merged (#779/#786/#781/#782/#790/#791/#793); Phase B writer perf fix O(N²)→O(N) merged (#792). **F.2 default-flip COMPLETE 2026-05-03** (#797/#800/#802 — snapshot mode is now the canonical runtime path). **Wiki+EODHD PR-A/B/C/D MERGED** (#803/#808/#809/#813). **F.3.a sub-sequence COMPLETE 2026-05-04** (#825/#827/#828/#829). **F.3.b–F.3.e ALL MERGED 2026-05-04..06** (#833 b-1, #837 c-1, #842 d-1, #861/#864 #848 forward fix, #866 b-2/c-2/d-2 caller migration, #868/#869 e-1/e-2 type relocation + `Bar_reader.of_panels` deletion, #875/#876/#877 e-3 stack — `Bar_panels.{ml,mli}` DELETED; sp500-2019-2023 baseline bit-equal 58.34%/81 across the stack). **M5.3 streaming Phase F COMPLETE.**

**Synth-v1 — block bootstrap — MERGED 2026-05-02 (#755).** **Synth-v2 — HMM + GARCH — MERGED 2026-05-02 (#775).** **Synth-v3 — multi-symbol factor model — MERGED 2026-05-11 (#1028)** (`factor_model.{ml,mli}` + `synth_v3.{ml,mli}` + `generate_synth_v3.exe` CLI; 44 new tests passing; cross-sectional avg pairwise correlation in [0.3, 0.7] target band; 500-sym × 80yr universe smoke-tested via the CLI). **EODHD multi-market expansion MERGED 2026-05-02 (#772)** — LSE/TSE/ASX/HKEX/TSX symbol resolution.

**15y memory-cliff fixes MERGED 2026-05-08** — three parallel fixes from `dev/notes/15y-memory-cliff-2026-05-08.md`: Fix A (#992 dedupe `Daily_panels` LRU caches), Fix B (#993 skinny `step_result.portfolio` projection), Fix C (#988 stream `csv_snapshot_builder` per-symbol); root-cause investigation (#987); split-day-adjustment investigation (#998). Combined with simulator-side #1024 (Closed-positions prune) the 15y wall dropped 5h → 13.6 min (~22×).

Only Norgate ingest (vendor-blocked) remains. Owner authorized: feat-data per `dev/decisions.md` 2026-05-03 §"Agent scope: extend feat-backtest + create feat-data".

Track created 2026-05-02 to absorb M5.3 (scale infra: streaming + Norgate) + M7.0 (data foundations: Norgate, multi-market, synthetic). Plans: `dev/plans/m5-experiments-roadmap-2026-05-02.md` + `dev/plans/m7-data-and-tuning-2026-05-02.md`. Authority: `docs/design/weinstein-trading-system-v2.md` §7 sub-milestones M5.3 + M7.0 (added 2026-05-02).

## Interface stable
NO

## Blocked on
- Norgate ingest blocked on user vendor signup ($32–66/mo). All other
  Synth ladder rungs (v1, v2, v3) shipped; EODHD multi-market shipped
  (#772).

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

(M5.3 streaming Phases A through F COMPLETE on main as of 2026-05-06.
Synth-v1/v2/v3 all MERGED. EODHD multi-market MERGED. 15y memory-cliff
fixes MERGED 2026-05-08. Only Norgate ingest remains — vendor-blocked.)

### Merged (data-pipeline-automation track)

- **#819** — Automation PR 1/4: snapshot build checkpointing
  (`Snapshot_manifest.update_for_symbol` per-symbol atomic upsert + periodic
  `progress.sexp` emission from `build_snapshots.exe` via `--progress-every N`,
  plus `dev/scripts/build_broad_snapshot_incremental.sh` and
  `dev/scripts/check_snapshot_freshness.sh`). Plan:
  `dev/plans/data-pipeline-automation-2026-05-03.md` §"PR 1".
- **#820** — Automation PR 2/4: backtest progress checkpointing — extends
  `backtest_runner.exe` with `--progress-every N` so a tail-able
  `progress.sexp` is rewritten under the experiment output dir every N Friday
  cycles plus an unconditional final write. New `Backtest.Backtest_progress`
  module owns the accumulator + atomic-rename writer. Single-run mode only;
  baseline / smoke / fuzz modes ignore the flag. Resumability deferred per
  plan §"Open question 4". Plan §"PR 2 — backtest checkpointing".
- **#821** — Automation PR 3/4: ops-data dispatch entry-point + runbook
  — extends `.claude/agents/ops-data.md` with §"Snapshot corpus refresh"
  documenting inputs (`--universe`, `--output-dir`, `--max-wall`),
  three-step workflow (probe → wrapper → re-probe), and the resume
  contract under `--max-wall`-bounded dispatches. Adds
  `dev/notes/snapshot-corpus-runbook-2026-05-03.md` (canonical user-facing
  runbook with dispatch prompt template + outcome / failure-mode tables)
  and `dev/notes/snapshot-corpus-status.md` (lightweight per-dispatch
  ledger with `NOT_STARTED` / `PARTIAL` / `FRESH` / `STALE` states). No
  auto-cron yet — deferred to PR 4. Plan §"PR 3 — ops-data dispatch +
  runbook".
- **PR 4/4** (this session): local cron / launchd recipes — adds
  `dev/notes/local-automation-2026-05-03.md` covering (1) why local-only
  (corpus is gitignored, no GHA path), (2) macOS launchd recipe with a
  full `~/Library/LaunchAgents/com.dayfine.trading.snapshot-refresh.plist`
  example (3am daily; `--max-wall 30m`; `plutil -lint` + `launchctl
  load/list/kickstart/unload` cheatsheet), (3) Linux crontab one-liner
  for the same wrapper, (4) freshness pre-flight gate using
  `check_snapshot_freshness.sh --threshold-pct 5` to skip rebuild on
  already-fresh nights, (5) audit / monitoring via
  `snapshot-corpus-status.md` + an optional staleness-alert cron that
  posts to Slack/mail after 7+ days without refresh (recommendation:
  don't wire by default), (6) disable / full-rebuild recipes. Plan §"PR
  4 — local-cron / launchd recipes". This closes the
  data-pipeline-automation track.

### Merged (M5.3 streaming)

- **#779** — Phase A: snapshot schema + file format.
- **#786** — Phase A.1: OHLCV columns appended.
- **#781** — Phase B: offline pipeline + manifest + verifier.
- **#792** — Phase B writer perf fix (O(N²) → O(N) per symbol, 35× speedup).
- **#782** — Phase C: runtime layer (`Daily_panels.t` + `Snapshot_callbacks.t`).
- **#790** — Phase D: simulator wire-in behind `--snapshot-mode --snapshot-dir`.
- **#791** — Phase E: validation + tier-4 spike (parity-7sym fixture).
- **#793** — Phase F.1: deprecation marker on `Bar_panels.t`'s docstring.
- **#825/#827/#828/#829** — Phase F.3.a: `Bar_reader` migrated off `Bar_panels.t` (a-1 `of_in_memory_bars`, a-2 strategy test migrations, a-3 `Panel_runner` CSV → snapshot, a-4 delete `of_panels`). F.3.a-3's strategy-side flip was partially reverted 2026-05-04 (closes #843); the forward fix landed via #861/#864.
- **#833** — Phase F.3.b staged b-1: `Weekly_ma_cache.of_snapshot_views` parallel constructor.
- **#837** — Phase F.3.c staged c-1: `Panel_callbacks.*_of_snapshot_views` parallel constructors (8 callees).
- **#842** — Phase F.3.d staged d-1: `Macro_inputs.*_of_snapshot_views` parallel constructors (3 functions) + 5 parity tests pinning bit-equal output.
- **#861** — #848 forward fix PR1: `Snapshot_bar_views.{daily_view_for,low_window}` take a `~calendar` parameter and walk panel-style calendar columns; `_assemble_daily_bars` reads `Snapshot_schema.Open` instead of returning NaN. Closes the cell-by-cell parity gap.
- **#864** — #848 forward fix PR2: rewired `Panel_runner._setup_hybrid` to use `Bar_reader.of_snapshot_views` over the shared `Daily_panels.t`.
- **#866** — F.3.b-2 + c-2 + d-2 caller migration: `Weinstein_strategy._run_macro_only` + `_run_screen_after_macro` migrated off `Macro_inputs.{build_global_index_views, build_sector_map} ~bar_reader` onto the `*_of_snapshot_views ~cb` variants. New `Bar_reader.snapshot_callbacks` accessor.
- **#868** — F.3.e-1: relocate `weekly_view` / `daily_view` types to `Data_panel_snapshot.Panel_views` neutral hub; `Bar_panels` retains alias re-exports.
- **#869** — F.3.e-2: delete `Bar_reader.of_panels` + 4 `_panel_*` helpers (zero live callers).

### Merged (Synth-v3 — 2026-05-11)

- **#1028 — Synth-v3 multi-symbol factor model** (MERGED 2026-05-11; plan `dev/plans/synth-v3-multi-symbol-factor-2026-05-11.md`).
  - **factor_model** library — single-factor cross-section sampler. `loading_distribution` (β truncated normal), `idio_distribution` (per-symbol log-normal omega + shared α/β GARCH), `sample_betas`, `sample_idio_params`, `generate_symbol_returns`. 25 unit tests covering validation, sampling determinism, range/empirical-mean properties, and degenerate-β reproduction checks.
  - **synth_v3** orchestrator — pairs `Synth_v2` market with the factor model. `config` mirrors Synth-v2's shape; optional explicit `symbols` list with default `SYNTH_NNNN` naming. Seed cascade keeps market / β / idio-param / per-symbol streams independent (offsets 100k / 200k / 1M+i). 19 integration tests including the load-bearing cross-sectional acceptance test (50sym × 5_000bars avg pairwise corr in [0.3, 0.7], target ~0.5 per m7 plan).
  - **generate_synth_v3** CLI bin (writes one CSV per symbol under `--output-dir`) + nesting-linter refactor on `_log_returns_from_bars`, `_generate_validated`, `sample_idio_params`.

  Acceptance pinned in tests:
  - 500-sym × 80yr universe smoke-tested via the CLI (`-n-symbols 500 -target-days 20000`).
  - Cross-section avg pairwise correlation in target band.
  - Deterministic given seed; per-symbol streams independent; OHLC well-formed; calendar-aligned across symbols.

  Deferred to follow-up (out of feat-data scope):
  - Strategy-side end-to-end smoke run on the generated universe → Sharpe/MaxDD. The data side is done; the integration belongs in `feat-backtest`.
  - Real-cross-section calibration of β / idio params from EODHD history.

### Merged (15y memory-cliff fixes — 2026-05-08)

- **#987** — investigation: 15y SP500 memory cliff root cause (doc-only PR pinning the structural diagnosis to `dev/notes/15y-memory-cliff-2026-05-08.md`).
- **#988** — Fix C: stream `csv_snapshot_builder` per-symbol (avoid materializing the whole corpus in memory).
- **#992** — Fix A: dedupe `Daily_panels` LRU caches (one cache per process, not per-strategy).
- **#993** — Fix B: project `step_result.portfolio` to a skinny summary (drop the full `Trading_portfolio.Portfolio.t` from each retained step).
- **#998** — split-day adjustment investigation (root-causes the 15y split-day regression surfaced during 15y SP500 baseline pinning).

  Combined with simulator-side #1024 (Closed-positions prune), 15y wall dropped 5h → 13.6 min (~22×). See `dev/status/backtest-perf.md` for the simulator-side share.

### In Progress / READY_FOR_REVIEW

- **[x] Phase 3 — `Daily_price.active_through` field**
  (`dev/notes/historical-universe-status-2026-05-13.md` §2 action item 1;
  original 2026-04-30 design phase 3).
  - Adds `active_through : Date.t option` to `Types.Daily_price.t`
    (`trading/analysis/data/types/lib/daily_price.{ml,mli}`) — typed
    delisted-date marker; default `None` = "still trading / unknown".
  - CSV round-trip (`trading/analysis/data/storage/csv/lib/{parser,csv_storage}.ml`):
    reader accepts both 7-column (legacy → `None`) and 8-column input;
    writer always emits the new column, empty cell when `None`.
  - EODHD `/api/eod` parser leaves `active_through = None` (the bar
    response carries no delisting marker — separate enrichment pass
    would attach it).
  - `Snapshot_bar_views` daily-price assembly preserves the field
    (snapshot has no delisting source today → `None`).
  - Mechanical update of 127 `Types.Daily_price.t` record literals
    across 74 files (test helpers + builders) to thread
    `active_through = None`.
  - Tests: 4 new unit tests in `analysis/data/types/test/test_daily_price.ml`
    (helper defaults to `None`, threads explicit dates, equality
    respects the field); 5 new round-trip tests in
    `analysis/data/storage/csv/test/` (both schemas + populated /
    unpopulated active_through). `dune runtest analysis/data/`,
    `dune runtest trading/backtest/`, `dune runtest analysis/weinstein/`,
    `dune runtest trading/weinstein/` all green — no golden drift.
  - A1 (qc-structural): touches a base type, will FLAG. Mitigation:
    change is strategy-agnostic broker-data-side; default `None` keeps
    every existing CSV / fixture loading unchanged → goldens bit-equal.
  - Natural follow-on: **Phase 5 — screener point-in-time filter**
    (`membership_at` callback in `Screener.screen` keyed on
    `active_through`). Highest-leverage gain once this lands.

### Pending

- **Norgate ingest** (vendor-blocked; user must sign up).
- **Phase 5 — screener point-in-time filter** (next natural step;
  ~250–400 LOC per design note §4).

### Detail (kept for reference; all entries below are MERGED on main)

#### Phase F.1 — deprecation marker on `Bar_panels.t` (MERGED as #793)

Documents the retirement trajectory in `bar_panels.mli`'s top-level
docstring, naming the two follow-up sub-deliverables (F.2 default-flip +
F.3 deletion). No `[@@deprecated]` attribute (would warn at every
existing call site and break `-warn-error`). Runtime unchanged. PR diff
~25 LOC. Plan: `dev/plans/daily-snapshot-streaming-2026-04-27.md`
§Phasing Phase F (F.2/F.3 detail in
`dev/plans/snapshot-engine-phase-f-2026-05-03.md`).

#### Phase E — validation + tier-4 spike (MERGED as #791)

Captures empirical validation against the Phase A.1 / B / C / D stack;
ships entirely as documentation under
`dev/experiments/m5-3-phase-e-validation/`. Key findings: (F1) end-to-end
CSV ≡ snapshot bit-equality on the `parity-7sym` fixture; (F2) Phase B
writer was O(N²) per symbol — *now fixed by #792*; (F3) tier-4 RSS is
bounded by LRU cache cap (`max_cache_mb`), not corpus size — actual peak
50–200 MB depending on cache config, ~50× under the Bar_panels-fully-
loaded baseline. Phase F unblocked from a correctness standpoint
post-#792.

#### Phase B writer perf fix (MERGED as #792)

Converted `_ema_at` / `_sma_at` / `_atr_at` / `_rsi_at` / `_weekly_prefix`
in `pipeline.ml` from prefix-rebuild-from-bar-0 (O(N²) per symbol) to
incremental updaters mirroring
`analysis/technical/indicators/{ema,sma,atr,rsi}_kernel.ml`. Drops
per-symbol cost from ~80 s on AAPL 30y to ~5 s, restoring the plan's
"~5 min wall" target on the full sp500 corpus. Unblocks V1 (sp500 5y
full-universe parity follow-up).

#### Phase D — simulator wire-in (MERGED as #790)

Wires `Daily_panels.t` runtime into the simulator's per-tick OHLCV reads
behind `--snapshot-mode --snapshot-dir <path>` feature flag. Default
mode (no flag) byte-identical to pre-PR behaviour. Adds
`Market_data_adapter.create_with_callbacks`, `Backtest.Snapshot_bar_source`
shim, `Backtest.Bar_data_source` selector, CLI flag plumbing through
`Panel_runner.run` / `Runner.run_backtest` / `backtest_runner.exe`. New
`test_snapshot_mode_parity.ml` pins per-call bit-equality. Strategy's
bar reads via `Bar_panels.t` unchanged — retirement is Phase F.

#### Phase A.1 — OHLCV columns (MERGED as #786)

Extends `Snapshot_schema.field` with `Open` / `High` / `Low` / `Close`
/ `Volume` / `Adjusted_close` appended after the original 7 indicator
scalars. Schema hash necessarily changes (content-addressable by
design); pre-existing on-disk snapshots become unreadable under the new
default and the manifest's `schema_hash` gate fires loudly.

#### Phase C — runtime layer (MERGED as #782)

Adds `weinstein.snapshot_runtime` library under
`trading/analysis/weinstein/snapshot_runtime/` with `Daily_panels.t`
(opaque cache handle wrapping per-symbol snapshot dirs; LRU eviction;
`max_cache_mb` budget) and `Snapshot_callbacks.t` (thin field-accessor
shim with `read_field` / `read_field_history` closures).

#### Phase B — offline pipeline (MERGED as #781)

Adds `weinstein.snapshot_pipeline` library
(`Pipeline.build_for_symbol`, `Snapshot_manifest`, `Snapshot_verifier`)
+ `build_snapshots.exe` CLI. Reuses validated weinstein analysers
(`Stage.classify`, `Rs.analyze`, `Macro.analyze`) on per-symbol weekly
aggregates. Manifest schema-hash drives incremental rebuild.

## Next Steps

Synth-v1 (#755) + Synth-v2 (#775) + Synth-v3 (#1028) all MERGED.
EODHD multi-market expansion MERGED (#772). M5.3 Phase F retirement
COMPLETE. 15y memory-cliff fixes MERGED (#988/#992/#993 + #1024).
The track is effectively unblocked from a feature-completion standpoint
— only the vendor-gated Norgate ingest remains.

1. **Norgate ingest** — after user signs up + decides which Norgate plan
   (vendor-blocked; not orchestrator-dispatchable until then).
2. Optional follow-ups (non-blocking):
   - Strategy-side smoke test on a Synth-v3 universe (Sharpe/MaxDD) —
     belongs in `feat-backtest`, not feat-data.
   - Real-cross-section calibration of Synth-v3 β / idio params from
     EODHD history (defaults are hand-set in #1028).

## CRSP defer
~$5k/yr institutional. Only viable for 100-year NYSE data (1925+). Skip until M7.1 ML training shows scale matters.

## Out of scope

- 100yr NYSE data via CRSP (deferred).
- Synth-v4 GARCH+jumps (deferred).
- GAN/VAE deep-learning synth (skipped).
- Real-time intraday data (we trade weekly).
- Fundamentals (earnings, ratios) — current strategy is pure technical.

# Status: data-foundations

## Last updated: 2026-05-04

## Status
IN_PROGRESS

## Notes
M5.3 streaming Phases A + A.1 + B + C + D + E + F.1 all merged (#779/#786/#781/#782/#790/#791/#793); Phase B writer perf fix O(N²)→O(N) merged (#792). **F.2 default-flip COMPLETE 2026-05-03** (#797/#800/#802 — snapshot mode is now the canonical runtime path). **Wiki+EODHD PR-A/B/C/D MERGED** (#803/#808/#809/#813). **F.3.a sub-sequence COMPLETE 2026-05-04**: a-1 (#825 `Bar_reader.of_in_memory_bars`), a-2 (#827 migrate 5 strategy test files / 17 callsites), a-3 (#828 `Panel_runner` CSV path through snapshot via `Csv_snapshot_builder`), a-4 (#829 delete `Bar_reader.of_panels` + `Weinstein_strategy.make ?bar_panels`). **F.3.a-3 PARTIALLY REVERTED 2026-05-04** (closes #843): the runner's strategy bar_reader is back on `Bar_reader.of_panels` over a CSV-loaded `Bar_panels.t`; the simulator's `Market_data_adapter` stays snapshot-backed (F.2 RAM bound preserved). The path-dependent divergence in `of_snapshot_views` that drove sp500-2019-2023 to 22.2%/112 (vs baseline 60.9%/86) requires a forward fix; tracked as the follow-up issue cited in the partial-revert PR. Bisect record: `dev/notes/parity-bisect-2026-05-04.md`. **F.3.b staged b-1 MERGED** (#833 `Weekly_ma_cache.of_snapshot_views`). **F.3.c staged c-1 MERGED** (#837 `Panel_callbacks.*_of_snapshot_views`). **F.3.d staged d-1 READY_FOR_REVIEW 2026-05-04** (#842 `Macro_inputs.*_of_snapshot_views` — 3 parallel constructors + 5 parity tests). Remaining F.3 sub-PRs: **F.3.b/c/d** caller migrations from `bar_reader`-backed → `*_of_snapshot_views` paths; **F.3.e** delete `bar_panels.{ml,mli}` + tests (NOW BLOCKED on the F.3.a-3 forward fix; the strategy reader still depends on `Bar_panels.t`). Plus: Synth-v3; Norgate ingest (vendor-blocked). F.3 is gated on three verification follow-ups (V1 sp500 5y full-universe parity, V2 ±2w fuzz on snapshot mode, V3 numeric-key fuzz at scale paired with E3 sweep). Owner authorized: feat-data per `dev/decisions.md` 2026-05-03 §"Agent scope: extend feat-backtest + create feat-data".

Track created 2026-05-02 to absorb M5.3 (scale infra: streaming + Norgate) + M7.0 (data foundations: Norgate, multi-market, synthetic). Plans: `dev/plans/m5-experiments-roadmap-2026-05-02.md` + `dev/plans/m7-data-and-tuning-2026-05-02.md`. Authority: `docs/design/weinstein-trading-system-v2.md` §7 sub-milestones M5.3 + M7.0 (added 2026-05-02).

## Interface stable
NO

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

(M5.3 streaming sequence — all phases through F.1 are MERGED on main as of
2026-05-03. F.2 + F.3 not yet started. See
`dev/plans/snapshot-engine-phase-f-2026-05-03.md` for the F.2 + F.3 plan,
including the V1/V2/V3 verification follow-ups that gate F.2.)

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
- **#825/#827/#828/#829** — Phase F.3.a: `Bar_reader` migrated off `Bar_panels.t` (a-1 `of_in_memory_bars`, a-2 strategy test migrations, a-3 `Panel_runner` CSV → snapshot, a-4 delete `of_panels`). **Note: F.3.a-3's strategy-side flip was partially reverted 2026-05-04** (closes #843). The runner's strategy bar_reader is back on `Bar_reader.of_panels`; `of_panels` was restored. The simulator's snapshot adapter stays. Forward fix tracked separately.
- **#833** — Phase F.3.b staged b-1: `Weekly_ma_cache.of_snapshot_views` parallel constructor.
- **#837** — Phase F.3.c staged c-1: `Panel_callbacks.*_of_snapshot_views` parallel constructors (8 callees).

### Ready for review

- **#842** — Phase F.3.d staged d-1: `Macro_inputs.*_of_snapshot_views` parallel constructors (3 functions: `build_global_index_views_of_snapshot_views`, `build_global_index_bars_of_snapshot_views`, `build_sector_map_of_snapshot_views`) + 5 parity tests pinning bit-equal output. Verify: `dune exec trading/weinstein/strategy/test/test_macro_inputs.exe`.

### Pending (M5.3 Phase F.2 + F.3 + verification gates)

Per `dev/plans/snapshot-engine-phase-f-2026-05-03.md`. Three verification
follow-ups gate F.2's default-flip merge:

- **V1 — sp500 5y full-universe parity** (CSV ≡ snapshot bit-equality on
  `goldens-sp500/sp500-2019-2023`; previously intractable under the O(N²)
  writer — unblocked by #792). Local-only.
- **V2 — ±2w start-date fuzz on snapshot mode** (re-run #788's fuzz spec
  under snapshot mode; CSV-mode-only baseline ran before Phase D wired
  snapshot reads).
- **V3 — Numeric-key fuzz at scale paired with E3 sweep** (PR #788
  follow-up #3 + M5.4 E3 stop-buffer sweep both run on snapshot mode
  natively).

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

1. Open Synth-v1 block bootstrap PR (~250 LOC) — independent of all other work, smallest unblock.
2. EODHD multi-market expansion (parallel; small).
3. Norgate ingest after user signs up + decides which Norgate plan.
4. Synth-v2 + v3 in subsequent sessions, in order.
5. **M5.3 verification gates V1 / V2 / V3** before Phase F.2 default-flip lands. See `dev/plans/snapshot-engine-phase-f-2026-05-03.md`:
   - **V1 — sp500 5y full-universe parity**: re-run `goldens-sp500/sp500-2019-2023` under both modes (CSV ≡ snapshot bit-equality across all output files). Unblocked by #792 (Phase B writer perf fix). Local-only.
   - **V2 — ±2w start-date fuzz on snapshot mode**: re-run #788's fuzz spec under snapshot mode; CSV-mode-only baseline ran before Phase D wired snapshot reads.
   - **V3 — Numeric-key fuzz at scale paired with E3 sweep**: PR #788 follow-up #3 + M5.4 E3 stop-buffer sweep both run on snapshot mode natively.
6. **M5.3 Phase F.2 — runner default flip + auto-build** (gated on V1 + V2). Two sub-tasks: (a) extend `build_snapshots.exe` to accept the runner's universe shape (today the writer requires `Pinned`; runners use `sector_map_override` built from `sectors.csv`); (b) add an `auto_build` mode to `Backtest_runner_args` that calls the writer when `--snapshot-mode` is set without `--snapshot-dir`, with a stable conventional output path under `data/snapshots/<schema-hash>/`. (c) flip the runner default; add `--csv-mode` opt-out. Acceptance: existing baseline / smoke / fuzz scenarios run cleanly under snapshot-mode default with no flag changes from the user. Estimated 300–500 LOC.
7. **M5.3 Phase F.3 — `Bar_panels.t` retirement** (follow-up to F.2). Port `Bar_reader` / `Weekly_ma_cache` / `Panel_callbacks` / `Macro_inputs` off `Bar_panels.t` onto `Snapshot_runtime.Snapshot_callbacks` (or a thin compat shim). Then delete `trading/trading/data_panel/bar_panels.{ml,mli}` + tests. Gate: snapshot-mode-as-default has run uneventfully for several weeks across all baseline + tier-3 + tier-4 scenarios. Estimated 800–1200 LOC across multiple PRs.

## CRSP defer
~$5k/yr institutional. Only viable for 100-year NYSE data (1925+). Skip until M7.1 ML training shows scale matters.

## Out of scope

- 100yr NYSE data via CRSP (deferred).
- Synth-v4 GARCH+jumps (deferred).
- GAN/VAE deep-learning synth (skipped).
- Real-time intraday data (we trade weekly).
- Fundamentals (earnings, ratios) — current strategy is pure technical.

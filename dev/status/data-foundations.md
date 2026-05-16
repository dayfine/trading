# Status: data-foundations

## Last updated: 2026-05-17

## Status
READY_FOR_REVIEW

## Blocking Refactors
- **2026-05-16 Option B pivot — IWV scrape becomes the primary
  survivorship-correct source.** Phase 1.1 (EODHD Fundamentals
  `HistoricalTickerComponents` on `GSPC.INDX`) FAILED verification per
  PR #1106 — our EODHD subscription is the EOD-only tier; the
  Fundamentals endpoint returns HTTP 403 across every variant probed
  (including bulk + historical-market-cap with explicit denial
  messages). Tier upgrade ($59.99/mo Fundamentals Data Feed or
  €99.99/mo All-In-One) rejected per the Option B decision.
  Phase 1.4 (DIY iShares IWV scrape, 2006-present) was promoted to
  primary path: URL pattern verified working HTTP 200 across the full
  2006-09-29 → 2026-05-08 range with byte-identical line-10 headers
  per PR #1108. Phase 1.1 is parked indefinitely. Full reasoning in
  `dev/notes/vendor-comparison-historical-universe-2026-05-16.md`.

  Phase 1.1 verification checklist — outcome:
  - [x] Confirm current EODHD plan tier includes Fundamentals —
    **FAIL** (EOD-only tier; HTTP 403 across 10 URL variants per PR
    #1106).
  - [ ] Spot-check 5 known SP500 events (LEH 2008-09-15 / KODK 2009-12
    / FB 2013-12-23 / TSLA 2020-12-21 / GE 2018-06-26) —
    **NOT_RUN** (blocked on tier 403).
  - [ ] Confirm `IsDelisted` symbols include OHLCV history in our
    existing EODHD price subscription — **NOT_RUN** (blocked on tier
    403).
  - [ ] Verify the JSON path: `HistoricalTickerComponents` vs
    `Components` — **NOT_RUN** (blocked on tier 403; vendor public
    docs hedge between the two shapes per
    `dev/notes/phase1.1-eodhd-verification-2026-05-16.md` §"Schema
    caveat").

- Historical record: Phase 1.1 had previously been BLOCKED on Norgate
  signup (`dev/notes/phase1.1-1996-membership-blocker-2026-05-15.md` —
  Wikipedia-only path insufficient pre-2010); re-scoped 2026-05-16
  morning to EODHD Fundamentals, then FAILED-and-parked 2026-05-16
  evening per the Option B pivot above.

## Notes

**2026-05-16 vendor-landscape pointers added.** Beyond the Phase 1.4 IWV
work (point-in-time Russell membership), see
`dev/notes/deep-history-data-pointers-2026-05-16.md` for the broader
vendor catalog covering deep-history (Shiller 1871, Kenneth French 1926),
free cross-check (Stooq, Tiingo), and commodities (World Bank Pink Sheet,
datahub.io). **Next-pursue candidate: shillerdata.com ingest** — free,
~200 LOC, unlocks long-horizon S&P index anchor + EODHD adjusted-close
cross-validation. Companion memory:
`memory/reference_deep_history_data_sources.md`.

**2026-05-15 strategic pivot — track elevated to P0.** Per
`dev/notes/next-session-priorities-2026-05-15.md`, broader-universe +
longer-horizon survivorship-correct data is now the load-bearing
prerequisite for the next round of strategy work. Two cross-window
inversions in one week (M5.5 axis-2 PR #1086 + continuation combined
PR #1095) confirmed Cell E is locally near-optimal on the levers it
exposes; the limiting factor is what the optimizer is looking at. New
Phase 1 work below:

1. **SP500 PI membership via EODHD Fundamentals (2000-present) +
   optional fja05680 tail (1996-1999)** — **PARKED 2026-05-16**
   after verification FAILED (PR #1106; subscription tier does not
   include Fundamentals, tier upgrade rejected per Option B). Source
   was `/api/fundamentals/GSPC.INDX?historical=1` exposing
   `HistoricalTickerComponents`. Phase 1.4 (IWV scrape) is now the
   primary path and strictly contains SP500 in its Russell 3000
   universe. Authority:
   `dev/notes/vendor-comparison-historical-universe-2026-05-16.md` +
   `dev/notes/phase1.1-eodhd-verification-2026-05-16.md`.
2. **[x] `broad-3000-2010-01-01.sexp` cohort** — DONE 2026-05-15
   (PR #1103). 3000-symbol Pinned-shape universe sourced
   alphabetically from `data/sectors.csv` via new
   `trading/trading/backtest/scenarios/pick_broad_3000_universe/pick_broad_3000.exe`.
   No bar-coverage pre-filter (per
   `memory/project_broad_universe_semantics.md`). Per-symbol
   delisting awareness flows through `Daily_price.active_through`
   (PR #1076 / #1094) and is opted in via `enable_pi_filter = true`
   (PR #1089). Caveat: this is NOT a true Russell 3000 historical
   reconstitution — the committed sectors.csv is a 2026-04-14
   snapshot, so the membership list is forward-looking-biased.
   Header in the emitted sexp documents this. True PI-aware
   reconstitution is now tracked as Phase 1.4 below (IWV scrape).
3. **Survivorship-correct re-pin of `goldens-sp500-historical/sp500-2010-2026.sexp`** —
   replace current pinned baseline (measured on survivorship-biased
   data per #1076's hypothesis) with one where PI filter is ON by
   default.
4. **Russell 3000 true historical reconstitution via DIY iShares IWV
   scrape** — **IN_PROGRESS, PRIMARY PATH** (added 2026-05-16; URL
   pattern verified 2026-05-16 per PR #1108). Pure HTTP GET against
   `https://www.ishares.com/us/products/239714/ishares-russell-3000-etf/1467271812596.ajax?fileType=csv&fileName=IWV_holdings&dataType=fund&asOfDate=YYYYMMDD`;
   no auth; CSV per `asOfDate`; tenure inferred by diffing
   consecutive snapshots (entry = first appearance, exit = first
   disappearance). Coverage 2006-09-29 → present (cadence:
   quarterly through 2008-12, monthly through 2012-04, daily
   thereafter). Sentinel for unavailable dates is HTTP 200 + 4585-
   byte template with `Fund Holdings as of,"-"` on line 2 — must
   parse line 2, not status code. Implementation in OCaml `cohttp` —
   no Python dependency; `talsan/ishares` is a reference doc only,
   not a runtime dep. ~3,550 snapshots × ~430 KB ≈ 1.5 GB raw
   uncompressed; ~3 hr backfill at 2s polite spacing. Replaces the
   sectors.csv proxy used by PR #1103 and replaces the parked
   Phase 1.1. Next step: plan-first dispatch to `feat-data`.
   Authority:
   `dev/notes/vendor-comparison-historical-universe-2026-05-16.md`
   §Option 1 + `dev/notes/phase1.4-iwv-url-probe-2026-05-16.md`.

Owner: feat-data. Status flipped READY_FOR_REVIEW → IN_PROGRESS on
the strategic pivot (2026-05-15), re-confirmed IN_PROGRESS on the
2026-05-16 vendor pivot, and re-confirmed IN_PROGRESS again on the
2026-05-16 Option B pivot — Phase 1.4 (IWV scrape) is now the
load-bearing item.

**Prior notes retained below.**

M5.3 streaming Phases A + A.1 + B + C + D + E + F.1 all merged (#779/#786/#781/#782/#790/#791/#793); Phase B writer perf fix O(N²)→O(N) merged (#792). **F.2 default-flip COMPLETE 2026-05-03** (#797/#800/#802 — snapshot mode is now the canonical runtime path). **Wiki+EODHD PR-A/B/C/D MERGED** (#803/#808/#809/#813). **F.3.a sub-sequence COMPLETE 2026-05-04** (#825/#827/#828/#829). **F.3.b–F.3.e ALL MERGED 2026-05-04..06** (#833 b-1, #837 c-1, #842 d-1, #861/#864 #848 forward fix, #866 b-2/c-2/d-2 caller migration, #868/#869 e-1/e-2 type relocation + `Bar_reader.of_panels` deletion, #875/#876/#877 e-3 stack — `Bar_panels.{ml,mli}` DELETED; sp500-2019-2023 baseline bit-equal 58.34%/81 across the stack). **M5.3 streaming Phase F COMPLETE.**

**Synth-v1 — block bootstrap — MERGED 2026-05-02 (#755).** **Synth-v2 — HMM + GARCH — MERGED 2026-05-02 (#775).** **Synth-v3 — multi-symbol factor model — MERGED 2026-05-11 (#1028)** (`factor_model.{ml,mli}` + `synth_v3.{ml,mli}` + `generate_synth_v3.exe` CLI; 44 new tests passing; cross-sectional avg pairwise correlation in [0.3, 0.7] target band; 500-sym × 80yr universe smoke-tested via the CLI). **EODHD multi-market expansion MERGED 2026-05-02 (#772)** — LSE/TSE/ASX/HKEX/TSX symbol resolution.

**15y memory-cliff fixes MERGED 2026-05-08** — three parallel fixes from `dev/notes/15y-memory-cliff-2026-05-08.md`: Fix A (#992 dedupe `Daily_panels` LRU caches), Fix B (#993 skinny `step_result.portfolio` projection), Fix C (#988 stream `csv_snapshot_builder` per-symbol); root-cause investigation (#987); split-day-adjustment investigation (#998). Combined with simulator-side #1024 (Closed-positions prune) the 15y wall dropped 5h → 13.6 min (~22×).

**2026-05-16 Option B pivot:** Norgate retired (Windows-only); EODHD
Fundamentals path FAILED at verification (PR #1106) and parked. New
Phase 1 surface = DIY iShares IWV scrape (Russell 3000 2006-present)
as primary, with optional fja05680 static seed (SP500 1996-1999)
deferred. Owner authorized: feat-data per `dev/decisions.md`
2026-05-03 §"Agent scope" and 2026-05-16 §"Option B pivot — IWV
scrape as primary, EODHD Fundamentals retired".

Track created 2026-05-02 to absorb M5.3 (scale infra: streaming + Norgate) + M7.0 (data foundations: Norgate, multi-market, synthetic). Plans: `dev/plans/m5-experiments-roadmap-2026-05-02.md` + `dev/plans/m7-data-and-tuning-2026-05-02.md`. Authority: `docs/design/weinstein-trading-system-v2.md` §7 sub-milestones M5.3 + M7.0 (added 2026-05-02).

## Interface stable
NO

## Blocked on
- **Nothing blocking.** Phase 1.4 (DIY iShares IWV scrape) is the
  primary path and needs no vendor signup, no subscription, no
  Python — it's straight OCaml `cohttp` work against a verified
  public endpoint (PR #1108). Next step is a plan-first dispatch to
  `feat-data` against `analysis/data/sources/ishares/`.
- **Local IP Akamai cooldown (2026-05-16 transient):** If local
  egress IP is still blocked, use the GHA-runner workflow as an
  IP-independent alternative: `.github/workflows/iwv-scrape-once.yml`.
  GHA runner uses a different egress IP from GitHub's range (not
  previously flagged by iShares WAF). Dispatch:
  `gh workflow run iwv-scrape-once.yml -f from_date=2006-09-29 -f until_date=2026-05-16`.
  Full instructions in
  `dev/notes/iwv-scrape-akamai-block-2026-05-16.md` §"GHA-runner workflow".
- Phase 1.1 (EODHD Fundamentals) is parked — would need a tier
  upgrade ($60/mo) to revive; not pursued per Option B.
- Norgate ingest retired 2026-05-16 (Windows-only client; see
  vendor-comparison doc). Synth ladder rungs (v1, v2, v3) all
  shipped; EODHD multi-market shipped (#772).

## Scope

### Track 1 — Historical universe ingestion (Option B pivot, 2026-05-16)

**Option B pivot 2026-05-16:** Phase 1.1 (EODHD Fundamentals)
FAILED verification (PR #1106) — our subscription is EOD-only,
Fundamentals returns HTTP 403. Tier upgrade rejected. Phase 1.4
(DIY iShares IWV scrape, 2006-present) is now the **primary
survivorship-correct source** — URL pattern verified working per
PR #1108. Russell 3000 strictly contains every SP500 name. Full
vendor comparison in
`dev/notes/vendor-comparison-historical-universe-2026-05-16.md`.

**SP500 (2000-present) via EODHD Fundamentals: PARKED**

| Item | Value |
|---|---|
| Vendor | EODHD Fundamentals Data Feed tier ($59.99/mo standalone) |
| Status | **PARKED 2026-05-16** — current EODHD subscription does NOT include Fundamentals; tier upgrade rejected per Option B |
| Reference | `dev/notes/phase1.1-eodhd-verification-2026-05-16.md` |

**Russell 3000 (2006-present) via DIY iShares IWV scrape: PRIMARY PATH (Phase 1.4)**

| Item | Value |
|---|---|
| Source | iShares.com per-date holdings CSV (no auth, no key) |
| Coverage | 2006-09-29 → present (verified PR #1108); cadence quarterly through 2008-12, monthly through 2012-04, daily thereafter |
| Universe | Russell 3000 (~3000 names; strictly contains every SP500 name) |
| Tenure | Inferred by diffing consecutive snapshots (entry = first appearance, exit = first disappearance) |
| URL pattern | `https://www.ishares.com/us/products/239714/ishares-russell-3000-etf/1467271812596.ajax?fileType=csv&fileName=IWV_holdings&dataType=fund&asOfDate=YYYYMMDD` |
| Header stability | Line 10 header byte-identical 2006-12-29 → 2026-05-08 (verified PR #1108) |
| Sentinel | Unavailable date returns HTTP 200 + 4585-byte template with `Fund Holdings as of,"-"` on line 2 — parse content, not status code |
| Sibling ETFs | IWB (Russell 1000) and IWM (Russell 2000) follow the same URL pattern with different product IDs |
| Storage | `dev/data/ishares/iwv/<YYYYMMDD>.csv` (gitignored — public website, cache locally, do not redistribute) |
| Volume | ~3,550 snapshots × ~430 KB ≈ 1.5 GB raw uncompressed |
| Backfill | ~3 hr at 2s polite spacing |

Likely new paths (subject to plan-first pass):
- `analysis/data/sources/ishares/lib/iwv_client.{ml,mli}` — `cohttp` GET + CSV decode (no Python)
- `analysis/data/sources/ishares/lib/membership_inference.{ml,mli}` — diff-based tenure reconstruction
- `analysis/data/sources/ishares/bin/build_russell_universe.ml` — backfill + emit `r3k-<as-of>.sexp`
- `analysis/data/sources/ishares/test/test_iwv_roundtrip.ml` + pinned snapshot fixtures

**1996–1999 SP500 tail (optional): `fja05680/sp500` static seed**

- Repo: `https://github.com/fja05680/sp500` (MIT). Pin a commit; ship
  `sp500_ticker_start_end.csv` under `analysis/data/sources/fja05680/data/`.
- Caveat: author flags "first ~5 years incomplete" — best-effort hobbyist
  source. Mark manifest entries `source=fja05680-best-effort`.

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

### READY_FOR_REVIEW (Stooq drift-check module — 2026-05-17)

- **`stooq` data source** (branch `feat/stooq-drift-check`,
  `analysis/data/sources/stooq/`). Independent integrity-audit module for
  the 41,575-symbol EODHD cache. Pairs naturally with manifest/hash-verify
  Phase 1 (PR #1142) — detects EODHD silent split-revisions (G14-class)
  and adjusted-close drift via a free second source. Authority:
  `dev/notes/deep-history-data-pointers-2026-05-16.md` §"Stooq cross-check
  design".
  - `lib/stooq_client.{ml,mli}` — pure CSV parser + URI builder. Output
    type `daily_observation = { date; open_; high; low; close; volume }`.
    Header pinned verbatim (`Date,Open,High,Low,Close,Volume`). Header
    drift / empty body / unparseable date or numeric all surface as
    `Status.error_invalid_argument`. URI builder lowercases symbol +
    appends `.us` suffix; optional apikey query param.
    `is_apikey_error_body` detects Stooq's plaintext apikey-required
    sentinel (HTTP 200 + body starting `Get your apikey:`).
  - `bin/stooq_curl_fetch.{ml,mli}` — curl-shellout HTTP fetcher mirroring
    PR #1137's pattern: tempfile-staged body via `curl -o` + status via
    `-w "%{http_code}"`, no `Cohttp_async` dependency.
  - `bin/stooq_drift_check_core.{ml,mli}` — pure drift pipeline. Pairs
    each EODHD bar with the Stooq observation for the same trading date,
    computes signed `rel_diff = (eodhd_adj_close - stooq_close) /
    stooq_close`, emits flagged-row list sorted by descending |rel_diff|
    + summary stats (n_compared, n_flagged, mean / max |rel_diff|).
    **Comparison fields:** Stooq `Close` (split-adjusted, NOT
    dividend-adjusted) vs EODHD `adjusted_close` (both split-AND-dividend
    adjusted) — chosen because comparing against EODHD `close_price`
    (raw, NOT split-adjusted) produces post-split-ratio false-positives
    (e.g. AAPL 4:1 split 2020-08-31 produces ~300% drift pre-split).
    Trade-off: ~1-2% structural drift per year from dividend adjustment
    is expected; the audit signal is sudden discontinuities, not the
    baseline level.
  - `bin/stooq_drift_check.exe` — single-symbol probe CLI. Flags:
    `-symbol SYM`, `-eodhd-cache-dir DIR`, `-apikey KEY` (or env
    `STOOQ_APIKEY`), `-threshold` (default 0.005 = 0.5%), `-stooq-csv
    PATH` (offline mode using a pre-fetched CSV — bypasses the apikey
    requirement). `Command.basic` (not `Command.async`) with
    `Thread_safe.block_on_async_exn` only for the actual curl fetch, so
    synchronous error paths flush stderr cleanly via `Stdlib.exit`.
  - `test/test_stooq_client.ml` + `test/data/stooq_aapl_sample.csv` —
    pinned 8-row AAPL fixture. 17 OUnit2 tests covering parse counts,
    row equality, source-order preservation, header drift / empty body /
    unparseable date / wrong column count / unparseable numeric error
    paths, UTF-8 BOM tolerance, `build_uri` lowercase + `.us` suffix +
    apikey appending, apikey-error sentinel detection (and negative
    check on real CSV body).
  - `test/test_stooq_drift_check_core.ml` — 11 OUnit2 tests on the pure
    drift pipeline: exact overlap → zero diff, signed direction
    (positive/negative), date-merge dropping stooq-only / eodhd-only
    dates, threshold flagging, empty rows, overlap-bound endpoints,
    flagged-rows descending sort, empty overlap, unmatched date counts,
    Markdown surface contains summary lines.
  - **Stooq API surprise (verified 2026-05-17):** the documented CSV
    endpoint `stooq.com/q/d/l/?s=<symbol>.us&i=d` now REQUIRES an apikey
    (free, captcha-gated via `stooq.com/q/d/?s=<symbol>.us&get_apikey`).
    Bare GETs return HTTP 200 with a `Get your apikey:` plaintext body
    that the parser must detect. The bulk-download path
    (`stooq.com/db/d/?b=d_us_txt`, 507 MB) is captcha-gated too. The
    CLI takes the apikey via `-apikey` flag or env `STOOQ_APIKEY`. Once
    a user-driven apikey signup happens, the CLI is ready to run live.
  - **Probe (live, 2026-05-17):**
    - Fixture mode: `./_build/.../stooq_drift_check.exe -symbol AAPL
      -eodhd-cache-dir test_data -stooq-csv
      analysis/data/sources/stooq/test/data/stooq_aapl_sample.csv` →
      5-day overlap (2020-01-02 → 2020-01-08), all 5 days flagged with
      structural drift ~3.58% (consistent across days — exactly the
      6-year cumulative dividend-adjustment delta expected; EODHD's
      adjusted_close compounds dividend reinvestments while Stooq does
      not). **AAPL baseline drift level: ~3.58% over ~6 years.** Sudden
      discontinuity beyond this baseline would indicate a split-revision
      bug.
    - Live mode (no apikey): clean exit 1 with hint pointing at
      `https://stooq.com/q/d/?s=aapl.us&get_apikey`.
    - Missing symbol: clean stderr message + exit 1.
  - Linters green: `dune build @fmt`, `no_python_check`,
    `fn_length_linter` (no functions > 50 LOC), `linter_magic_numbers`,
    `linter_mli_coverage`. ~415 source LOC (`.ml` + `.mli`: 159 lib +
    97 curl + 156 core + 130 cli). Tests ~310 LOC. Pinned fixture (8
    rows) excluded per PR-sizing rules.
  - Not consumed yet — pure data-source infrastructure under
    `analysis/`. Bulk-fetch across the full 41k EODHD cache and
    auto-driven detection over many symbols are deferred (Phase 2+).

### READY_FOR_REVIEW (CSV-manifest Phase 2 — hash-verify on load — 2026-05-17)

- **`csv_storage` manifest integration** (branch `feat/csv-manifest-phase2`,
  `trading/analysis/data/storage/csv/`). Phase 2 of
  `dev/plans/data-inventory-and-reproducibility-2026-05-02.md`. Wires the
  Phase 1 manifest module (#1142) into `Csv_storage.save` + adds a new
  `load_with_verify` that consults the manifest's sha256.
  - `Csv_storage.save` now also writes/upserts a per-shard manifest entry
    at `<data-dir>/<L1>/<L2>/manifest.sexp` after every successful CSV
    write. New optional provenance params: `?source` (default
    `"unknown"`), `?endpoint`, `?vendor_revision_tag`, `?fetch_id`,
    `?api_key_id` — backward-compatible (all defaults are empty / sane).
    Manifest write failures are **non-fatal**: a warning is logged to
    stderr and `save` itself returns `Ok ()` so existing pipelines do not
    break when the sidecar cannot be updated.
  - `Csv_storage.load_with_verify : ?strictness:[ \`Strict | \`Warn | \`Off ]`
    is a new function (sibling to `get`) that reads the manifest entry
    and compares the on-disk file's MD5 against the recorded value.
    `\`Strict` returns `Error (Status.Internal ...)` on mismatch; `\`Warn`
    (default) logs and returns `Ok`; `\`Off` skips verification entirely.
    A missing manifest / missing entry is tolerated under all strictness
    settings — pre-Phase-2 data still loads.
  - `Csv_storage.shard_manifest_path` exposed as a public helper for
    callers (inspectors, bulk-rehash tools in Phase 3) that need to
    locate the manifest without re-implementing sharding.
  - `t` now carries `data_dir` + `symbol` in addition to `path` so the
    manifest extension can locate the shard sidecar. Existing `t` is
    abstract; the change is invisible to callers.
  - 8 new OUnit2 tests under `csv/test/test_csv_storage.ml` (Matchers
    library wired in): manifest entry written + sha256 matches CSV;
    save-twice upserts (not appends); round-trip `load_with_verify`;
    tampered file detected under `\`Strict` (Internal); tampered file
    tolerated under `\`Warn` + `\`Off`; missing manifest tolerated
    under `\`Strict` + `\`Warn`.
  - Out-of-scope (deferred to Phase 3): reconcile-on-refetch diff log;
    bulk-rehash CLI for the existing 41k cached symbols; cross-source
    dispatch (Shiller, Stooq, etc.).
  - Linters green: `dune build @fmt`, `no_python_check`,
    `fn_length_linter` (longest new function ≤ 24 LOC),
    `linter_magic_numbers`. `dune runtest analysis/data/storage` clean
    (25 csv tests + 14 manifest tests + 12 metadata tests + 5
    interface tests = 56 total).
  - Sizing: ~140 LOC added to `csv_storage.{ml,mli}` + ~30 LOC dune
    edits (libraries) + ~155 LOC new tests (status + plan + fixtures
    don't count). Plan:
    `dev/plans/data-inventory-and-reproducibility-2026-05-02.md` §Phase 2.
### READY_FOR_REVIEW (Shiller deep-history ingest — 2026-05-17)

- **`shiller` data source** (branch `feat/shiller-ingest`,
  `analysis/data/sources/shiller/`). Free monthly S&P composite series from
  Robert Shiller's dataset (1871-01 → present), ingested via the
  `datasets/s-and-p-500` GitHub mirror (auto-tracks Shiller's `ie_data.xls`;
  pure CSV — no spreadsheet parser needed). Companion authorities:
  `dev/notes/deep-history-data-pointers-2026-05-16.md` §"Shiller dataset" +
  `memory/reference_deep_history_data_sources.md`. Unlocks long-horizon
  S&P anchor for backtests + cross-validation against EODHD's adjusted-close
  construction.
  - `lib/shiller_client.{ml,mli}` — pure CSV parser + URI constant. Output
    type `monthly_observation = { period; sp_price; dividend; earnings;
    cpi; long_rate }` where the four fundamental columns are `float option`
    with sentinel `0.0` mapped to `None` (Shiller's typical 1-3 month
    fundamental-release lag emits zeros for the head of the series). Header
    pinned verbatim; drift surfaces as a structural `Status.error_invalid_argument`.
  - `bin/shiller_curl_fetch.{ml,mli}` — curl-shellout HTTP fetcher mirroring
    PR #1137's pattern: tempfile-staged body via `curl -o` + status via
    `-w "%{http_code}"`, no `Cohttp_async` dependency.
  - `bin/fetch_shiller_history.exe` — operator CLI; one flag (`-out PATH`)
    plus the fetch+parse+write pipeline. Emits a 6-column canonical CSV
    (`period,sp_price,dividend,earnings,cpi,long_rate`) with empty cells for
    `None` options. Cache target convention `dev/data/shiller/shiller-monthly-YYYYMMDD.csv`
    (gitignored under `dev/data/`).
  - `test/test_shiller_client.ml` + `test/data/shiller_sample.csv` — pinned
    8-row sample (3 head + 1 y2k + 1 covid + 3 sentinel-era tail). 15
    OUnit2 tests covering: parse counts, era-specific population, sentinel
    → None mapping, sub-1.0 long-rate boundary case (covid March 2020
    rate=0.87 must survive as `Some`, not become `None`), header drift /
    empty body / unparseable date / wrong column count / unparseable numeric
    error paths, UTF-8 BOM tolerance, URI shape.
  - Probe (live, 2026-05-17): `dune exec
    analysis/data/sources/shiller/bin/fetch_shiller_history.exe -- -out
    /tmp/shiller-test.csv` wrote 1865 observations from 1871-01-01 to
    2026-05-01 (155y × 12 ≈ 1860 expected; matches). Output well-formed;
    empty cells appear for the 2023-2026 fundamental-lag tail.
  - Linters green: `dune build @fmt`, `no_python_check`, `fn_length_linter`
    (longest function in lib = 27 LOC, all bin helpers ≤ 12 LOC). ~330
    source LOC (`.ml` + `.mli` 75 lib + 56 + 12 curl + 75 + 8 cli + dune
    boilerplate); 200 LOC tests. Fixture (8-row CSV) excluded per
    PR-sizing rules.
  - Not consumed yet — pure data-source infrastructure under `analysis/`.
    Strategy-side wire-up + adjusted-close cross-validation against EODHD
    are follow-ups (belong in `feat-backtest`).

### READY_FOR_REVIEW (Shiller → EODHD adjusted-close validator — 2026-05-17)

- **`shiller_validator` — Shiller vs EODHD `GSPC.INDX` cross-validator**
  (branch `feat/shiller-validator`,
  `trading/analysis/data/sources/shiller/bin/`). Pure cross-validation
  on top of PR #1140's Shiller ingest. Consumes the derived CSV from
  `fetch_shiller_history.exe` and EODHD's cached SP500 index (default
  `GSPC.INDX` under `data/G/X/GSPC.INDX/data.csv`), resamples daily →
  monthly (last trading day per calendar month), aligns on
  first-of-month, computes signed relative drift, and emits a Markdown
  report.
  - `bin/shiller_validator_core.{ml,mli}` (library) — pure pipeline:
    `resample_daily_to_monthly` / `build_drift_rows` / `compute_stats` /
    `build_report` / `format_markdown_report` /
    `parse_shiller_derived_csv` (consumes the 6-column derived CSV
    produced by `fetch_shiller_history.exe`).
  - `bin/shiller_validator.ml` (CLI exe) — wires the library to file IO
    with flags `-shiller-csv`, `-eodhd-cache-dir`, `-index-symbol`
    (default `GSPC.INDX`), `-threshold` (default `0.005` = 0.5%),
    `-top-n` (default 10), `-out` (default
    `dev/data/shiller/validation_report.md`). Missing EODHD cache →
    graceful no-overlap report (exit 0), not exit 1.
  - `test/test_shiller_validator.ml` — 14 OUnit2 tests across
    resampling (last-bar-per-month, empty input), drift computation
    (signed rel diff, overlap-only join), stats (threshold flagging,
    empty rows), pipeline (overlap, empty overlap, top-N ordering),
    Markdown rendering (anchors, empty-overlap surface), and
    derived-CSV parsing (empty optionals, header drift, empty body).
  - **Alignment caveat surfaced in `.mli` + Markdown report:**
    Shiller's monthly price is the *monthly average of daily closing
    prices* (per his `ie_data` documentation); the validator pairs
    each Shiller month with the *last trading day* of that calendar
    month in the EODHD cache. The two definitions diverge by 5-20% in
    high-volatility months (1929-1940, 1987-10, 2008-09, 2020-02)
    even when both sources are internally consistent. Persistent
    monotone drift in recent months would be the real vendor-revision
    signal; large bidirectional drift in volatile historical months is
    structural.
  - **Probe (live, 2026-05-17):** 1865-row Shiller series ×
    GSPC.INDX cache (1927-12 → 2026-04). 1,181 months compared in
    overlap. Mean |rel_diff| = 1.94%, max |rel_diff| = 20.36%, 971
    months flagged at 0.5% threshold. Top drift months cluster in
    1929-1940 + COVID era — consistent with the
    average-vs-month-end alignment caveat above, not vendor split
    drift. No EODHD adjusted-close revision detected.
  - `dune build && dune runtest analysis/data/sources/shiller/` clean;
    `dune build @fmt` clean; 14 new validator tests + 15 existing
    Shiller-client tests all pass.
  - Sizing: ~410 LOC (`.ml` + `.mli` validator-core 234 + 90 ml + cli
    87). Tests ~250 LOC. Pinned fixtures not added (validator-core is
    pure; CLI integration exercised by live probe).

### Merged (Phase 1.4 IWV scraper stack — 2026-05-16)

All four PRs of the IWV scraper stack landed in a single session per
`dev/plans/iwv-scraper-2026-05-16.md`. The stack provides the tooling
to scrape iShares IWV holdings CSVs, infer point-in-time membership
by diffing snapshots, and emit a Pinned-shape Russell 3000 universe
sexp. **Next step is operational, not feature work:** an `ops-data`
session must run the actual ~3-hour backfill against ishares.com to
populate `dev/data/ishares/iwv/*.csv` and emit
`russell-3000-2006-2026.sexp`.

- **#1112 — Phase 1.4 PR-A — `ishares_holdings_client`** — pure CSV
  parser + URI builder under
  `trading/analysis/data/sources/ishares/lib/ishares_holdings_client.{ml,mli}`.
  `parse : string -> parse_outcome Status.status_or` returns
  `Parsed snapshot` (era-agnostic; preserves source order; preserves
  non-equity rows) or `No_data_sentinel` (line-2 `-` check).
  `build_uri : as_of:Date.t -> Uri.t` constructs the verified
  `IWV_holdings` URL. 4 pinned era fixtures (quarterly 2007-09-28,
  cutover 2012-04-30, modern 2020-06-01, sentinel) + 14 OUnit2 tests.
- **#1118 — Phase 1.4 PR-B — `ishares_membership_replay`** — pure
  tenure-replay layer under
  `trading/analysis/data/sources/ishares/lib/ishares_membership_replay.{ml,mli}`.
  Forward-scan with per-ticker `absent_streak` counter; threshold
  misses close the tenure at last-observed date; re-appearance opens
  a fresh tenure. 9 OUnit2 tests pinning all hysteresis edges.
- **#1120 — Phase 1.4 PR-C — `fetch_iwv_history.exe`** — resume-safe
  + polite IWV backfill CLI under
  `trading/analysis/data/sources/ishares/bin/`. Cache layout
  `<cache_dir>/YYYY-MM-DD.csv` + `.sentinel` markers. Cadence policies
  auto / daily / monthly / quarterly; auto pins quarter-ends pre-2009,
  month-ends through 2012-04, weekdays after. Atomic-rename writes
  via `.tmp` sibling. 17 OUnit2 tests on the lib (no live HTTP in CI).
- **#1122 — Phase 1.4 PR-D — `build_iwv_universe.exe`** — completes
  the stack. Reads cached snapshots, pipes through
  `Ishares_membership_replay.replay`, emits a Pinned-shape universe
  sexp matching `broad-3000-2010-01-01.sexp`. Equity + US-location
  filter in the lib (per-backtest policy). 14 OUnit2 tests including
  schema parity check.

### In Progress / READY_FOR_REVIEW

(none — all four IWV PRs merged this session)

### Historical README (pre-merge entries below; preserved for review traceability)

- **Phase 1.4 PR-D — `build_iwv_universe.exe` (READY_FOR_REVIEW
  2026-05-16, branch `feat/iwv-build-universe`).**
  - New CLI `trading/analysis/data/sources/ishares/bin/build_iwv_universe.{ml,dune}`
    + pure helper lib `build_iwv_universe_lib.{ml,mli}` — completes the
    IWV scraper stack (PR-A → PR-B → PR-C → PR-D). Reads the cached
    snapshot directory produced by PR-C's `fetch_iwv_history.exe`,
    pipes parsed snapshots through PR-B's
    `Ishares_membership_replay.replay`, and emits a point-in-time
    universe sexp matching the existing `broad-3000-2010-01-01.sexp`
    shape (PR #1103).
  - CLI flags: `--cache-root`, `--output`, `--start`, `--end`, `--as-of`,
    `--threshold-misses`. Defaults: `--start 2006-09-29`, `--end today`,
    `--as-of = --end`, `--threshold-misses 3`. All knobs routed through
    the lib's `run` entry point — no magic numbers.
  - Equity + US-location filter applied in the lib (per plan §2.3.3,
    NOT in the replay layer), exposed as `filter_config` so per-backtest
    policy can vary. Default drops `Asset Class != Equity` (futures hedges,
    cash) and `Location != United States` (pre-2012 cross-listings).
  - Sample fixture: 5 hand-curated snapshots × 9 tickers under
    `test/data/sample_history/2007-09-28.csv` through `2020-06-01.csv`.
    Covers: always-present (AAPL/MSFT/JNJ/IBM), single-miss survival
    (KODK absent in 1 of 5 → tenure stays open with threshold=3),
    confirmed removal via 3 misses (LEH only in 2007 → closed by snap 4,
    excluded from output), late-entry (TSLA/FB first seen 2012), futures
    filter (ESM6 dropped before replay).
  - 14 OUnit2 tests pass: cache-entry scanning (window filter; missing
    dir error), load_and_filter (default filter drops ESM6 → 7 equity
    tickers; no-filter keeps 8; full-window loads all 5 snapshots in
    ascending date order), build_universe (7 members at as_of=2020-06-01
    with full sexp shape pinned; mid-window pi-filter excludes pre-2012
    arrivals; threshold=1 closes KODK and re-opens with new
    sector_at_first), write_outcome_to_file (header comment + sexp body;
    sexp roundtrips via Sexp.of_string), run end-to-end pipeline,
    schema parity check vs `broad-3000-2010-01-01.sexp`.
  - Does NOT generate the actual `russell-3000-2006-2026.sexp` fixture —
    that requires running the full ~3 hour scrape against iShares;
    follow-up ops session ships the artifact. This PR ships the TOOL.
  - Linters green: `dune build @fmt`, `no_python_check`,
    `fn_length_linter` (all functions ≤ 25 LOC). 386 source LOC
    (`.ml` + `.mli` 86+185+115); 408 test LOC. Sample CSV fixtures
    (5 files, ~6 KB) excluded per PR-sizing rules. Plan:
    `dev/plans/iwv-scraper-2026-05-16.md` §PR-D.

- **Phase 1.4 PR-C — `fetch_iwv_history.exe` (READY_FOR_REVIEW
  2026-05-16, branch `feat/iwv-fetch-history`).**
  - New CLI `trading/analysis/data/sources/ishares/bin/fetch_iwv_history.{ml,dune}`
    + pure helper lib `fetch_iwv_history_lib.{ml,mli}`. Backfills the
    on-disk cache of iShares IWV holdings CSVs across a date window;
    resume-safe (skips already-cached + sentinel dates), polite (2 s
    default spacing), and `--dry-run`-capable.
  - Cache layout: `<cache_dir>/YYYY-MM-DD.csv` for data responses,
    `<cache_dir>/YYYY-MM-DD.sentinel` (one-byte marker) for the iShares
    no-data template. Atomic-rename writes via `.tmp` sibling guard
    against half-cached CSVs.
  - Cadence policies: `auto` (quarterly pre-2009 → monthly through
    2012-04-29 → weekly weekdays from 2012-04-30 per the Phase 1.4 URL
    probe), `daily`, `monthly`, `quarterly`. Era cutovers + polite-
    sleep default are named constants — no magic numbers.
  - 17 OUnit2 tests on the lib: cadence parsing (case/whitespace
    tolerance + reject unknown), enumeration across all four policies
    (daily skips weekends; monthly picks month-ends; quarterly picks
    Mar/Jun/Sep/Dec ends; auto handles the 2012-04-30 cutover and
    the quarterly→monthly→daily era transitions), plan classification
    over a mixed cache (cached / sentinel / fetch), zero-byte-CSV
    refetch fallback, no-resume mode, format_plan_summary, sentinel
    roundtrip, write_csv_body roundtrip, cache-dir mkdir_p.
  - No live HTTP tests (would hit ishares.com — rate-limit / flaky);
    hand-tested via `dry-run`. Linters green: `dune build @fmt`,
    `no_python_check`, `fn_length_linter`, `linter_magic_numbers`.
    ~450 LOC across `.ml` + `.mli` + `test.ml` (within PR-sizing cap).
    Plan: `dev/plans/iwv-scraper-2026-05-16.md` §PR-C.

- **Phase 1.4 PR-B — `ishares_membership_replay` (READY_FOR_REVIEW
  2026-05-16, branch `feat/iwv-membership-replay`).**
  - New module `trading/analysis/data/sources/ishares/lib/ishares_membership_replay.{ml,mli}`
    — pure tenure-replay layer. Consumes the forward-ordered
    `(Date.t * Ishares_holdings_client.snapshot)` stream from PR-A and
    emits one `tenure_record` per `(ticker)` observed.
  - `replay : ?index:string -> threshold_consecutive_misses:int -> _ list -> tenure_record list`.
    `tenure_record = { ticker; first_seen; last_seen; sector_at_first;
    index }`. Default `index = "IWV"`; the `threshold_consecutive_misses`
    knob defaults to 3 in callers (per plan §2.3.2) but is required-named
    in the lib to keep the policy explicit.
  - Algorithm: forward scan with a per-ticker `absent_streak` counter;
    threshold misses close the tenure at the last-observed date, and
    re-appearance opens a fresh tenure. Un-tickered escrow rows
    (`ticker = "-"`) are dropped; other vendor-specific filters
    (Asset Class, location) are intentionally deferred to the
    universe-builder CLI (PR-D) so per-backtest policy varies cleanly.
  - 9 OUnit2 tests pass: single snapshot, 2-snapshot overlap,
    single-miss-below-threshold preservation, 3-consecutive-miss
    closure-at-last-seen, era-mixing `sector_at_first` pinning,
    `threshold=1` collapse + re-open, un-tickered drop, empty input,
    custom `?index` plumbing.
  - Linters green: `dune build @fmt`, `no_python_check`,
    `fn_length_linter`. ~490 LOC across `.ml` + `.mli` + `test.ml`
    (under PR-sizing cap; status / plan / fixtures don't count). Plan:
    `dev/plans/iwv-scraper-2026-05-16.md` §PR-B.

- **Phase 1.4 PR-A — `ishares_holdings_client` (READY_FOR_REVIEW
  2026-05-16, branch `feat/iwv-holdings-client`).**
  - New module `trading/analysis/data/sources/ishares/lib/ishares_holdings_client.{ml,mli}`
    — pure CSV parser + URI builder. No HTTP, no Async; live fetch
    deferred to PR-C.
  - `parse : string -> parse_outcome Status.status_or` returns
    `Parsed snapshot` (era-agnostic; preserves source order; preserves
    non-equity rows) or `No_data_sentinel` (line-2 `-` check per Phase
    1.4 URL probe). Fails loudly on header drift, missing header,
    unparseable as-of, or wrong column count.
  - `build_uri : as_of:Date.t -> Uri.t` constructs the verified
    `IWV_holdings` URL with zero-padded YYYYMMDD `asOfDate`.
  - 4 pinned era fixtures under `test/data/` (quarterly 2007-09-28,
    cutover 2012-04-30, modern 2020-06-01, sentinel) — each truncated
    to 9 rows + provenance header (commit small samples per
    `dev/plans/iwv-scraper-2026-05-16.md` §6 risk #5).
  - 14 OUnit2 tests pass: per-era schema, sector quirks (empty vs
    populated), non-equity preservation, source-order preservation
    (descending in 2020 fixture), sentinel detection, three structural
    error paths, URI shape.
  - Linters green: `dune build @fmt`, `nesting_linter` (after
    refactoring three offenders), `no_python_check`, `fn_length_linter`.
  - ~540 LOC across `.ml` + `.mli` + `test.ml` (at PR-sizing cap;
    fixtures don't count). Plan: `dev/plans/iwv-scraper-2026-05-16.md`
    §PR-A.

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

- **Phase 1.4 — Russell 3000 via IWV scrape (PRIMARY PATH) — TOOLING
  COMPLETE 2026-05-16.** URL pattern verified PR #1108; plan landed
  PR #1109 (`dev/plans/iwv-scraper-2026-05-16.md`, 4-PR stack); all
  four PRs merged this session:
  - **[x] PR-A `ishares_holdings_client`** — MERGED 2026-05-16 (#1112).
  - **[x] PR-B `ishares_membership_replay`** — MERGED 2026-05-16 (#1118).
  - **[x] PR-C `fetch_iwv_history.exe`** — MERGED 2026-05-16 (#1120).
  - **[x] PR-D `build_iwv_universe.exe`** — MERGED 2026-05-16 (#1122).
  Tooling shipped; **next action is operational**, not feature work.
  An `ops-data` session must run the ~3-hour backfill against
  ishares.com:
    1. `dune exec analysis/data/sources/ishares/bin/fetch_iwv_history.exe --
       --cache-dir dev/data/ishares/iwv --start 2006-09-29
       --end <today> --cadence auto --polite-spacing 2.0`
    2. `dune exec analysis/data/sources/ishares/bin/build_iwv_universe.exe --
       --cache-root dev/data/ishares/iwv
       --output trading/test_data/goldens-russell-3000-historical/russell-3000-2006-2026.sexp`
  No vendor signup; Linux/Mac OCaml native; zero marginal cost.
- **Phase 1.3 — Survivorship-correct re-pin** — deferred until 1.4
  lands (no longer downstream of the parked 1.1).
- **Phase 1.5 — fja05680 SP500 1996-1999 static seed** — deferred
  per the broader-first pivot.
- **Phase 5 — screener point-in-time filter** — independent of
  Phase 1 source; can run in parallel (~250-400 LOC per design
  note §4).

- **Phase 1.1 — PARKED** (SP500 PI via EODHD Fundamentals; failed
  verification PR #1106). Not actively scheduled; would require a
  tier upgrade to revive.

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
broad-3000-2010-01-01 cohort MERGED (#1103, sectors.csv proxy).
**Phase 1.4 IWV scraper stack: ALL 4 PRs MERGED 2026-05-16
(#1112 / #1118 / #1120 / #1122).**

**2026-05-16 Option B pivot:** Phase 1 work is sourced from DIY
iShares IWV scrape (primary, 2006-present Russell 3000) with
fja05680 1996-1999 SP500 tail deferred. EODHD Fundamentals
parked after verification FAIL (PR #1106). Norgate retired. See
`dev/notes/vendor-comparison-historical-universe-2026-05-16.md`.

1. **Phase 1.4 — run the actual IWV scrape (ops-data, ~3-hour
   wall-clock).** Tooling complete; data is not. Dispatch `ops-data`
   to run `fetch_iwv_history.exe` over 2006-09-29 → today against
   ishares.com (polite 2s spacing), then `build_iwv_universe.exe`
   over the cache to emit
   `trading/test_data/goldens-russell-3000-historical/russell-3000-2006-2026.sexp`.
   See `dev/notes/next-session-priorities-2026-05-17.md` §P0a for
   the exact commands.
2. **Phase 1.3 re-pin** — gated on (1). Re-pin
   `goldens-sp500-historical/sp500-2010-2026.sexp` baseline on the
   IWV-derived cohort. The new cohort is wider than SP500 (Russell
   3000) so the baseline numbers will differ; this needs fresh
   sign-off, not a like-for-like comparison against the current
   510-symbol baseline. Owner: `feat-backtest` (re-pin) + `ops-data`
   (run the actual sweep).
3. **Phase 5 — screener point-in-time filter** — MERGED 2026-05-14
   (PR #1089). The `membership_at` callback is wired into
   `Screener.screen` and is opt-in via `enable_pi_filter`. No further
   feat-data work remains on this item.
4. Optional follow-ups (non-blocking):
   - Strategy-side smoke test on a Synth-v3 universe (Sharpe/MaxDD) —
     belongs in `feat-backtest`, not feat-data.
   - Real-cross-section calibration of Synth-v3 β / idio params from
     EODHD history (defaults are hand-set in #1028).
   - fja05680 1996-1999 SP500 tail seed (deferred; per
     `memory/project_strategic_pivot_broader_first.md` the
     broader-first pivot prioritizes universe breadth over deeper
     history).

## CRSP / Sharadar defer
- **CRSP / WRDS**: institutional-only ($5k+/yr). Only viable for
  100-year NYSE data (1925+). Skip until M7.1 ML training shows
  scale matters.
- **Sharadar via Nasdaq Data Link**: $150–$300/mo personal tier;
  SP500 changes since 1957. The only credible >30y step-up for
  non-institutional pricing. Deferred until 20y horizon (post Phase
  1.4 IWV scrape) proves out. See vendor-comparison-historical-universe
  doc §Option 4.

## Out of scope

- 100yr NYSE data via CRSP (deferred).
- Synth-v4 GARCH+jumps (deferred).
- GAN/VAE deep-learning synth (skipped).
- Real-time intraday data (we trade weekly).
- Fundamentals (earnings, ratios) — current strategy is pure technical.

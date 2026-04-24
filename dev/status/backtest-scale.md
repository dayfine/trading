# Status: backtest-scale

## Last updated: 2026-04-24

## Status
READY_FOR_REVIEW

**Seed-timing fix (PR #519, MERGED 2026-04-24 03:42Z)** — closes the
residual post-#517 gap on `tiered-loader-ab`. Verified on GHA
workflow_dispatch (run 24870169890) — all three broad goldens
(`bull-crash-2015-2020`, `covid-recovery-2020-2024`,
`six-year-2018-2023`) now report PV delta $0.0000 between Legacy and
Tiered; trade lists bit-identical.

**Actual root cause (different from the CreateEntering-timing
hypothesis in the original write-up below).** The Tiered wrapper's
`_run_friday_cycle` cascaded Metadata → Summary → Full and only seeded
`Bar_history` for symbols that reached Full tier. Promotion to Summary
required `Summary_compute.compute_values` to return `Some`, which is
gated on all of `ma_30w` (30 weekly bars), `atr_14`, `rs_line` (52
weekly bars — the binding constraint), and `stage_heuristic`. On the
7-symbol CI fixture (CSV starts 2017-01-03), no symbol has 52 weekly
bars until early 2018, so Tiered's `Bar_history` was EMPTY for the
universe through the entire 2015-01..2018-01 window. Legacy's
day-by-day `Bar_history.accumulate` has no minimum-history requirement
and populated history from the simulator's first step regardless. The
`CreateEntering` path was not the smoking gun — the problem was that
inner's `_screen_universe` never saw the universe's bars at all on
early Fridays, so no entries were generated. Once the RS window
resolved (~Jan 2018), Summary/Full promotions started succeeding and
trades began firing — but by then the portfolio state had diverged
from Legacy.

**Fix shape (PR #519):**
- `Bar_loader._promote_one_to_full` now treats Summary scalar
  resolution as best-effort. Full-tier promotion proceeds even when
  Summary returns `None`, as long as Metadata succeeded and at least
  one bar loaded. The resulting `Full.t` entry has `summary = None`;
  consumers can check `get_summary` if they need indicator scalars.
- `Tiered_strategy_wrapper._run_friday_cycle` drives Full directly via
  a new `_promote_universe_to_full` helper instead of cascading through
  Summary first. The seed call still pair-fires with each Full promote,
  so `Bar_history` gets populated with whatever bars the loader has.
- `test_runner_tiered_cycle`: Friday-trigger tests now expect
  `Promote_full` (the wrapper's only tier-op now) instead of
  `Promote_summary`.

**Memory cost.** `Bar_history` grows monotonically to universe size
(one row per symbol with any CSV bars in window). The `Full.t.bars`
cache stays bounded by `Full_compute.tail_days`, independent of
`Bar_history`. This matches Legacy's footprint for `Bar_history` and
keeps Tiered's Full-tier savings on the OHLCV cache side.

**Note on the broad-universe CI fixture.** `trading/test_data/sectors.csv`
is 7 symbols, not 1654 — separate bug, tracked in § Follow-up. Doesn't
block the merge gate: GHA reports PV delta $0.0000 on the 7-symbol
fixture across all three goldens, which proves the fix works at this
scale. The broad-universe fixture rebuild is a separate follow-up.

**Bull-crash A/B parity fix (2026-04-23, MERGED as #517)** — was on
`feat/backtest-bull-crash-parity`. Resolved one part of the post-#507
Tiered/Legacy divergence on `bull-crash-2015-2020`
(nightly A/B run 24818087082: $20709.16 PV drift on bull-crash, $0.00
on the other two scenarios). Two coupled bugs:

1. **`_friday_promote_set` capped Full-promotions at
   `max_buy_candidates + max_short_candidates` (~30) via
   `Shadow_screener.screen` ranking.** The inner Weinstein screener's
   `_screen_universe` only analyzes symbols with bars in `Bar_history`,
   and `Bar_history` only grows for Full-tier symbols. So inner saw
   only ~30 candidates per Friday vs Legacy's full universe scan. On
   broad universes the divergence was a $20k PV drift; on the
   small-universe variant (used as a local repro because broad takes
   ~7 hours) it was a 7x trade-count divergence (Legacy 696 trades vs
   Tiered 101 trades over 6 years).
2. **`Bar_loader.promote ~symbols:[...]` short-circuits on the FIRST
   per-symbol error.** Used to batch-promote the universe to Summary
   from `_run_friday_cycle`, this meant one missing CSV near the start
   of the alphabet silently dropped every later symbol — a steady
   decline in Tiered's effective candidate pool over time.

Fix in `tiered_strategy_wrapper.ml`:
- Drop the `Shadow_screener.screen` call from `_run_friday_cycle`.
  Promote every Summary-tier symbol to Full each Friday and seed
  `Bar_history` from the loader's `Full.t.bars`.
- Switch all Friday and per-CreateEntering promotions in the wrapper
  from batch `Bar_loader.promote` to a per-symbol helper
  (`_promote_each_to`) that mirrors the same per-symbol-tolerance
  pattern `Tiered_runner.promote_universe_metadata` already uses for
  Metadata.

Local A/B verification (small-universe `bull-crash-2015-2020.sexp`,
302 symbols, 6 years, ~7 minutes per run × 2):

| State | Legacy trades | Tiered trades | Legacy return | Tiered return |
|---|---|---|---|---|
| Pre-fix (post-#507) | 696 | 101 | 301.7% | 73.4% |
| Drop-cap (shadow) | 690 | 339 | 338.3% | 79.8% |
| **+ per-symbol promote** | **694** | **470** | **340.2%** | **334.5%** |

Return delta closed from 228 percentage points to 5.7. Trade-count
delta closed from -85% to -32%. Bar_history seeding contract
(parity test, 7 symbols, 6 months) still bit-identical: same final
PV, same step PVs at sampled indices.

Residual ~32% trade-count gap on small-universe was self-flagged in
#517's PR description as a third-order effect (Bar_history seed timing
for CreateEntering vs Friday-cycle promotion order). The 2026-04-24
post-merge nightly confirmed it: same $20709.16 cent-precision drift
on the 7-symbol CI fixture, same direction (Tiered ~2.08% under
Legacy). **PR #519 closes this** — see § Status above for the actual
root cause (Summary tier's RS window, not the CreateEntering hypothesis
originally posited).

**Strategy ↔ bar_loader integration (2026-04-22, MERGED as #507)** —
flipped Tiered from "bookkeeping-only" (PV deltas $0.00 on all 3
broad goldens per run 24761375492) to "actually throttles
Bar_history + consumes Full bars". Parity test
(`test_tiered_loader_parity`) green — trade count identical, final
PV within $0.01, sampled step PVs within $0.01 per step. Tier stats
at end of parity sim: `Metadata=0 Summary=0 Full=22`. Resolution
chosen: Option b-seed from
`dev/plans/backtest-tiered-strategy-integration-2026-04-22.md`. Broad
A/B not run locally (~40min per scenario × 3 × 2 = 4 hours); nightly
workflow (`.github/workflows/tiered-loader-ab.yml`) provided the
post-merge empirical signal that surfaced the bull-crash divergence
fixed above.

structural_qc: APPROVED (2026-04-22 run-2) — feat/backtest-scale-3h; merged as #496. See dev/reviews/backtest-scale-3h.md.

Plan `dev/plans/backtest-tiered-loader-2026-04-19.md` reviewed + open questions resolved (2026-04-19). 3a (Metadata) merged; 3b-i (Summary_compute) merged; 3b-ii (Summary tier wiring) merged as #445; 3c (Full tier) merged as #447; 3d (tracer phases) merged as #452; 3e (runner + scenario plumbing for `loader_strategy`) merged as #459; 3f-part1 (shadow_screener adapter) merged as #463; 3f-part2 (tiered runner skeleton) merged as #466; 3f-part3a (refactor-only Tiered_runner extraction) merged as #477; 3f-part3b (Tiered runner Friday cycle + per-transition promote/demote) merged as #478; F2 (Summary tail_days fix) merged as #492; 3g (parity acceptance test) merged as #484; **3h (nightly A/B comparison) merged as #496 on 2026-04-22**; **workflow activated as `.github/workflows/tiered-loader-ab.yml` via #498 (2026-04-22)** — first nightly run fires at 04:17 UTC tonight. **Missing-CSV tolerance fix (2026-04-22) — see §Follow-up / escalation:** `Tiered_runner._promote_universe_metadata` softened from `failwith`-on-first-error to per-symbol `continuing` log, matching Legacy's silent missing-CSV behaviour. Branch `feat/backtest-scale-tiered-missing-csv-tolerance`. **Next merge-gate: strategy↔bar_loader integration** (`feat/backtest-scale-strategy-bar-loader-integration`) — flips Tiered from no-op bookkeeping to actual Bar_history throttling + Full-tier bar consumption. After that lands + a few nightly A/B runs: flip `loader_strategy` default Legacy→Tiered (~20-line PR).

## Interface stable
NO

All three tier getters return their proper typed option: `get_metadata : Metadata.t option`, `get_summary : Summary.t option`, `get_full : Full.t option`. Core `Bar_loader.create` / `promote` / `demote` / `tier_of` / `stats` signatures remain stable; `create` gained optional `?full_config` in 3c and `?trace_hook` in 3d. Remaining churn will come from 3e (runner wiring) and 3f (tiered runner path).

## Open work
- This doc PR (#521) — narrative update reflecting #519's actual root
  cause; supersedes the speculative seed-timing hypothesis that PR
  #518 had landed in the docs while #519 was being investigated.

## Blocked on
- **Final flip (`loader_strategy` default Legacy→Tiered)** — gate
  CLOSED by #519. Optional 1-2 confirming scheduled nightlies for
  paranoia; otherwise ready to ship the ~20-line flip PR.

## Goal

Tier-aware bar loader. Backtest working set scales with actively tracked symbols (~20-200), not inventory (10k+). Today's loader materializes all inventory bars; step 3 introduces three data-shape tiers so Memory budget becomes ~29 MB vs today's >7 GB.

## Scope

See `dev/plans/backtest-scale-optimization-2026-04-17.md` §Step 3 for the overall spec and `dev/plans/backtest-tiered-loader-2026-04-19.md` for the detailed, increment-level implementation plan. Summary:

1. **Three tiers defined as types, not subsets.**
   - `Metadata.t` — all inventory (~10k) — last_close, sector, cap, 30d_avg_volume
   - `Summary.t` — sector-ranked subset (~2k) — 30w MA, RS line, stage heuristic, ATR
   - `Full.t` — breakout candidates + held positions (~20-200) — complete OHLCV

2. **`Bar_loader` module** with `promote : t -> symbols:string list -> to_:tier -> t`. Screener cascade calls promote as symbols advance through stages. Demotion on exit/liquidation frees Full-tier memory.

3. **Runner flag `loader_strategy = Legacy | Tiered`.** Default `Legacy` at merge time. Acceptance gate = parity test on golden-small scenario (diffs trade count / total P&L / final portfolio value / each pinned metric within float ε). Merge blocked until parity holds.

4. **Post-merge ramp:** flip default to `Tiered` in a tiny follow-up PR after a few weeks; retire `Legacy` in the one after.

## Scope boundary

Do NOT touch in this track:
- Strategy, screener cascade logic (orchestrate calls, don't rewrite)
- Incremental indicators (separate axis; likely unnecessary once tiers cut the 10k loop)
- Parallel backtest workers (orthogonal)

Build alongside existing `Bar_history` — don't modify it.

## Branch
`feat/backtest-tiered-loader`

## Ownership
`feat-backtest` agent (architectural scope). See `.claude/agents/feat-backtest.md`.

## Increments (from `backtest-tiered-loader-2026-04-19.md`)

| # | Name | Scope | Size est. |
|---|---|---|---|
| 3a | Metadata tier | `Bar_loader` types + Metadata loader + tests | ~180 |
| 3b | Summary tier | `Summary.t` + summary_compute + promote/demote | ~220 |
| 3c | Full tier | `Full.t` + promotion/demotion semantics | ~150 |
| 3d | Tracer phases | `Promote_summary`/`Promote_full`/`Demote` in `Trace.Phase.t` | ~120 |
| 3e | Runner flag plumbing | `loader_strategy` on Runner + Scenario + CLI | ~150 |
| 3f | Tiered runner path | `_run_tiered_backtest` + shadow screener adapter | ~300 |
| 3g | Parity acceptance test | merge gate on `smoke/tiered-loader-parity.sexp` | ~200 |
| 3h | Nightly A/B comparison | GHA workflow + compare script | ~100 |

3a→3g are the merge-gate increments; 3h is a post-merge follow-on (tracked here for continuity).

## References

- Detailed implementation plan: `dev/plans/backtest-tiered-loader-2026-04-19.md`
- Parent plan: `dev/plans/backtest-scale-optimization-2026-04-17.md` (PR #396)
- Engineering design: `docs/design/eng-design-4-simulation-tuning.md` — note that tier-aware loading is a pragmatic optimization over the design, not a change to the DATA_SOURCE abstraction
- Prerequisite: PR #419 (per-phase tracing) — merged

## Size estimate

~500-800 lines total for 3a-3g (merge gate). Per increment: see table above. Nightly A/B (3h) is ~100 additional lines, post-merge.

## Next Steps

1. QC review of 3h (`feat/backtest-scale-3h` head) — nightly A/B compare
   script + staged GHA workflow. Verify parity contract (hard gate on
   trade-count; warn on PV drift) and the `dev/ci-staging/` → `.github/workflows/` install path.
2. Human or workflow-scoped agent: rename
   `dev/ci-staging/tiered-loader-ab.yml` → `.github/workflows/tiered-loader-ab.yml`
   so the nightly cron activates. Can fold into the 3h merge, or ship as
   a separate 1-line PR immediately after.
3. Post-merge: flip default `loader_strategy` from `Legacy` to `Tiered`
   in a tiny follow-up PR after a few weeks of nightly A/B data
   confirms parity + savings.
4. Post-Tiered-default: retire `Legacy` codepath (`_run_legacy` in `runner.ml`).

## Follow-up / escalation

- **AD-breadth + inventory loading saturate memory at ≥10K-symbol
  universes; Tier 3's bar_loader savings only realize at small
  universes (2026-04-24).** Local A/B on `goldens-small/bull-crash-2015-2020.sexp`
  with `TRADING_DATA_DIR` pointed at the real `data/sectors.csv` (10472
  symbols + 4 index/sector ETFs = 10476 total) OOM-killed BOTH
  strategies inside the dev container's 7.75 GB limit before the
  backtest loop started:
  - **Legacy peak RSS:** 7,679,768 KB (~7.68 GB) → SIGKILL
  - **Tiered peak RSS:** 7,772,432 KB (~7.77 GB) → SIGKILL (+92 MB)
  Last log line for both: `Loading universe from sectors.csv... |
  Universe: 10472 stocks | Loading AD breadth bars... | Total symbols
  (universe + index + sector ETFs): 10476 | Running backtest (...,
  loader_strategy=...)`. Tiered also: `Tiered loader: Metadata=4643
  Summary=0 Full=0 after bulk Metadata promote` — only metadata loaded
  before OOM. The shared `Loading universe from sectors.csv` and
  `Loading AD breadth bars` paths run before any tier-aware throttling
  kicks in, so Tier 3's `Bar_history` / `Full.t.bars` accounting (the
  "29 MB vs 7 GB" target in § Goal) never gets the chance to apply at
  10K-symbol scale. Goal-statement footnote needed: the design's memory
  budget is a Bar_loader-only accounting and assumes upstream loading
  is bounded by something else (universe scoping, lazy load, or a
  separate Tier 4 that lazy-loads AD breadth itself).
  
  **What this does NOT change:** the Tiered flip is still safe at the
  universe sizes the system actually backtests today (302-symbol
  goldens-small, 7-symbol CI fixture both fit comfortably). The flip
  PR can proceed once one or two confirming nightlies land.
  
  **What this DOES change:** the design claim "Memory budget becomes
  ~29 MB vs today's >7 GB" can't be cited as accomplished without
  scoping. New work needed (out of this track or a sibling): instrument
  AD-breadth + inventory-load phases for memory attribution; either
  scope the universe upstream of those calls or convert them to lazy /
  streamed loaders. Tracked here pending a decision on whether this
  becomes its own track (suggest: `dev/status/backtest-perf.md` for
  CPU + memory continuous monitoring + AD/inventory profiling).

  **Scoped re-run (2026-04-24, 292-symbol universe via filtered
  `sectors.csv` at `/tmp/data-small-302`).** Both ran to completion
  (no OOM at this scope). But two unexpected results:

  | | Legacy | Tiered | Δ |
  |---|---|---|---|
  | Peak RSS | 1,871,240 KB (~1.87 GB) | **3,652,852 KB (~3.65 GB)** | **+95% more** |
  | Final PV | $1,873,648.70 | $2,670,361.59 | **+$796,712.89** |
  | Round trips | 608 | 613 | +5 |
  | Total PnL | -$80,956.12 (losing) | +$184,640.50 (winning) | flipped sign |
  | Sharpe | 0.66 | 0.92 | +0.26 |
  | Max DD | 33.62% | 33.34% | -0.28pp |

  (1) **RSS regression.** Tiered uses ~1.78 GB more than Legacy at
  this scope — opposite of the design hypothesis. Tiered's `Bar_history`
  grows to universe size monotonically (per #519's docstring trade-off),
  AND the loader keeps `Full.t.bars` bounded by `Full_compute.tail_days`
  per Full-tier symbol. With 302 symbols going to Full at end-of-run
  (`Tiered loader: Metadata=5 Summary=0 Full=302 at end of simulator
  run`), the duplicated `Bar_history` + `Full.t.bars` may explain the
  delta. Worth attributing exactly.

  (2) **PV diverges by $796,713 — a parity break.** #519 verified
  $0.0000 PV delta on the GHA `tiered-loader-ab` 7-symbol fixture and
  on the goldens-broad scenarios; the agent's report explicitly noted
  "302-symbol small-universe verification was not run as a separate
  test". This run is the first 302-symbol verification post-#519 and
  it's NOT bit-identical. Possible causes:
  - Real Tiered bug at 292-symbol scale that the 7-symbol fixture
    didn't expose (the seed-timing fix in #519 may have a different
    boundary than tested);
  - Synthesized data dir at `/tmp/data-small-302` may be missing
    supporting fixtures (the symlink loop only linked top-level
    `*.csv` files; ad_breadth subdirs / sector_etf paths might
    resolve differently between Legacy and Tiered);
  - Universe membership artifact: filtered sectors.csv has 292
    symbols (9 of small.sexp's 302 weren't in the full sector map),
    which may exercise different code paths.
  
  Repro: build `/tmp/data-small-302` per the synthesis script in this
  doc's git history (filter `data/sectors.csv` to symbols in
  `universes/small.sexp`, symlink per-letter dirs); then
  ```
  TRADING_DATA_DIR=/tmp/data-small-302 \
    /usr/bin/time -o legacy.rss -f '%M' \
    dune exec --no-build -- trading/backtest/bin/backtest_runner.exe \
    2015-01-02 2020-12-31 --loader-strategy legacy
  TRADING_DATA_DIR=/tmp/data-small-302 \
    /usr/bin/time -o tiered.rss -f '%M' \
    dune exec --no-build -- trading/backtest/bin/backtest_runner.exe \
    2015-01-02 2020-12-31 --loader-strategy tiered
  ```
  
  **Action required before flipping `loader_strategy` default:**
  diagnose the 292-symbol PV divergence. Either:
  - It's a fixture artifact (synthesized data dir is incomplete) →
    rebuild a complete fixture and re-test; if still bit-identical,
    Tiered flip is fine.
  - It's a real Tiered bug → fix before flipping. The gate stated at
    the top of this doc ("PV drift inside warn threshold") is broken
    on 292-symbol; the GHA verification on 7-symbol is insufficient
    coverage.

  **RSS regression diagnosis: Bar_history is append-only, never
  trimmed.** From `bar_history.mli`:

  > `accumulate` ... pull today's bar via [get_price] and append it
  > to the buffer — but only if the bar's date is strictly later than
  > the last recorded bar.
  >
  > `daily_bars_for` ... Return the **full** accumulated daily bar
  > history for [symbol] in chronological order ... Callers that need
  > a bounded window should slice the result themselves.

  `Bar_history` is `Daily_price.t list Hashtbl.M(String).t` — a
  hashmap from symbol to **append-only** bar list. No max-age trim,
  no rolling window, no LRU eviction, no `trim_before` function
  exists. Over 6 years × 292 symbols × 1510 trading days × ~64 bytes
  per `Daily_price.t`: roughly **30 MB minimum** at the OCaml-record
  level, multiplied by GC overhead and Hashtbl slack to easily reach
  hundreds of MB. Both Legacy and Tiered keep this state forever
  within a run. Strategy readers (52-week RS line, 30-week MA, ATR)
  only need ≤365 days of history; the older bars are dead weight.

  **Why Tiered shows MORE RSS than Legacy** despite both having the
  same Bar_history growth pattern: Tiered post-#519 carries TWO
  parallel caches per Full-tier symbol —
  `Bar_history` (1510 bars after 6 years, never trimmed) PLUS
  `Full.t.bars` (bounded at `Full_compute.tail_days` ≈ 250 bars).
  Per the design intent, `Full.t.bars` is the bounded cache, but
  `Bar_history` was never converted to a windowed view; it's the
  same monotonic append-only list Legacy uses. So Tiered pays for
  Legacy's cache shape PLUS its own bounded one. End-of-run state
  for the 292-symbol scenario per the Tiered log: `Metadata=5
  Summary=0 Full=302 at end of simulator run` — 302 symbols ×
  (1510 + 250) bars each.

  **Suggested fix (sequenced, NOT in this doc PR — see
  `dev/plans/bar-history-trim-2026-04-24.md`):** add
  `Bar_history.trim_before : t -> as_of:Date.t ->
  max_lookback_days:int -> unit` and call it once per backtest day
  with `max_lookback_days` derived from the longest-window strategy
  reader (52 weeks × 7 days = 364 days). With a 365-day window the
  per-symbol Bar_history caps at ~365 daily bars vs current ~1510
  after 6 years — a ~4× reduction independent of the Tiered flip.
  Both Legacy and Tiered benefit. Plan + start tracked in
  `dev/plans/bar-history-trim-2026-04-24.md`.

- **Broad-universe goldens are testing on a 7-symbol fixture (2026-04-24).**
  `trading/test_data/sectors.csv` has 8 lines (~7 tickers); the broad
  scenarios under `trading/test_data/backtest_scenarios/goldens-broad/`
  declare `universe_path "universes/broad.sexp"` which is the
  `Full_sector_map` sentinel — i.e., "use whatever is in
  `${TRADING_DATA_DIR}/sectors.csv`". In CI that's the 7-symbol slice.
  The scenario file headers explicitly say `STATUS: SKIPPED — ranges
  stale (1,654-symbol era); re-pin pending a GHA workflow.` Effect:
  the nightly `tiered-loader-ab` workflow runs each scenario in ~5s
  with 14 trades, not 1654 symbols × 6 years × 70–110 trades. Until
  this is rebuilt, the only honest broad-universe coverage is the
  302-symbol small-universe goldens (~7min × 2 per A/B locally). Two
  shapes of fix: (a) ship a real broad sector map + matching CSVs as a
  CI fixture (download or commit; non-trivial size), or (b) treat the
  302-symbol goldens-small as the broad gate and retire `goldens-broad/`.
  Decide after the seed-timing fix lands. Tracked here because Tiered
  flip readiness practically depends on what we use as the gate.

- **Reciprocal short-side practical block.** Per memory note
  `project_short_side_reprioritize.md` (2026-04-?): the three
  `short-side-strategy.md` § Follow-ups (bear-window backtest
  regression, full short cascade, Ch.11 spot-check) are gated on the
  Tiered flip landing — not by hard interface coupling but because they
  need broad-universe scale to be feasible. Update
  `dev/status/short-side-strategy.md` to flip Status off MERGED once
  the Tiered flip lands so the orchestrator picks them up.

- **F2 (CLOSED 2026-04-22) — Summary_compute default tail_days too short.**
  The 3g QC behavioral review flagged that parity was holding for the
  wrong reason: Tiered reported `Summary=0 Full=0` on every Friday
  because `Summary_compute.compute_values` returned `None` for every
  universe symbol. Root cause: `default_config.tail_days = 250` is below
  `rs_ma_period * 7 = 364` calendar days, so 250 days of daily bars
  aggregate to only ~36 weekly bars — strictly under the 52-bar
  Mansfield zero-line threshold that `Relative_strength.analyze` checks.
  `rs_line` returns `None`, `compute_values` short-circuits on the first
  `None` in its Option chain, and the symbol stays at Metadata. Fixed
  by bumping `default_config.tail_days` from 250 to 420 (~60 weekly
  bars after aggregation). Branch `feat/backtest-scale-f2`, see
  §Completed.

- ~~**`Tiered_runner._promote_universe_metadata` is strictly intolerant of missing CSVs.**~~
  **[x] RESOLVED 2026-04-22** — picked option (a) (soften to per-symbol
  `continuing` log). Branch `feat/backtest-scale-tiered-missing-csv-tolerance`.
  `_promote_universe_metadata` rewritten as a per-symbol
  `List.filter_map` over `Bar_loader.promote` that collects all failures,
  never raises (even when every symbol fails — symmetry with Legacy's
  empty-backtest behaviour). Logs capped at first 10 per-symbol lines plus
  a summary count (`N of M symbols failed metadata promote`). Function is
  also exposed in the `.mli` as `promote_universe_metadata` (dropped the
  leading underscore) so the regression test can pin the contract without
  spinning up a full simulator. Regression test in new file
  `trading/trading/backtest/test/test_runner_tiered_metadata_tolerance.ml`
  with three cases: (i) partial missing — HAVE reaches Metadata, MISSING1
  / MISSING2 not tracked, no raise; (ii) all missing — no raise, loader
  empty; (iii) all present — all 3 reach Metadata. Closes the parity gap
  the nightly A/B (which uses complete fixtures) wouldn't catch.

- **`Bar_loader.create` defaults `benchmark_symbol = "SPY"` but the
  Runner's primary index is `GSPC.INDX`.**
  The Tiered path currently logs per-symbol `Bar_loader.promote`
  errors for SPY on every Summary promote because the Runner never
  provides an SPY CSV. Legacy uses `GSPC.INDX` directly as its
  benchmark. This is a separate low-severity divergence from the
  missing-CSV hard-fail issue above: it doesn't block the parity
  scenario (RS computation in the Tiered shadow-screener degrades to
  no-RS, which is one of the known divergences the 3f-part1 .mli
  documents), but it does mean the Tiered loader's RS line is
  computed against "no benchmark" rather than against `GSPC.INDX`.
  Proposed follow-up: thread `config.indices.primary` from
  `Weinstein_strategy.config` through `Tiered_runner._create_bar_loader`
  to `Bar_loader.create ~benchmark_symbol:_`.

## Completed

- **3h — Nightly A/B trace comparison** (2026-04-22). Ships the
  nightly-advisory A/B comparison surface called out by plan §3h: a
  POSIX-sh compare script plus a staged GHA workflow that exercises it
  against the 3 broad goldens.
  **Compare script.** `dev/scripts/tiered_loader_ab_compare.sh` takes a
  scenario sexp + output dir, extracts `start_date` / `end_date` via
  `grep`+`sed`, and runs `trading/backtest/bin/backtest_runner.exe`
  twice — once with `--loader-strategy legacy`, once with
  `--loader-strategy tiered`. The runner's
  `Output written to: <path>/` stderr line pins each run's output dir
  so we don't race on a shared `dev/backtest/` listing. Outputs are
  copied into stable `<out>/legacy/` and `<out>/tiered/` trees.
  Parity comparison uses plan §Resolutions #1:
    - **Hard gate (exit 1):** trade-count diff != 0, or either side's
      `trades.csv` absent. Surfaces as a `::error::` GHA annotation.
    - **Warn gate (exit 0, ::warning::):** final-PV delta above
      `max($1.00, 0.001% * legacy_pv)`. Drift is a signal to
      investigate, not a regression.
  Universe / config_overrides are ignored — broad goldens already
  default to the full sector-map, which is `backtest_runner`'s own
  no-override behaviour.
  **Workflow.** `tiered-loader-ab.yml` (staged at
  `dev/ci-staging/tiered-loader-ab.yml` pending manual rename, see
  §Blocked on) runs the compare against
  `bull-crash-2015-2020.sexp`, `covid-recovery-2020-2024.sexp`, and
  `six-year-2018-2023.sexp` from
  `trading/test_data/backtest_scenarios/goldens-broad/` nightly at
  04:17 UTC. Each scenario step sets `continue-on-error: true` so all
  three runs execute even if one fails; an aggregate step re-surfaces
  any failure as the job exit status. All output trees + diff.txt +
  per-run stdout/stderr logs upload as a 30-day workflow artefact.
  **POSIX-sh linter scope.** `posix_sh_check.sh` now scans
  `dev/scripts/` in addition to `dev/lib/` so the new script is
  covered by the `dash -n` parse gate landed in #493. Clean-count
  increments from 41 to 42.
  **Verification.** Smoke run on `smoke/tiered-loader-parity.sexp`
  (6-month 7-symbol window) reports
  `Legacy trades: 3, Tiered trades: 3, legacy PV $1,096,397.65,
  tiered PV $1,096,397.65, PV delta $0.00 within warn threshold
  $10.96`, confirming both strategies produce identical output under
  the parity scenario that 3g pins.
  - Files: `dev/scripts/tiered_loader_ab_compare.sh`,
    `dev/ci-staging/tiered-loader-ab.yml` (staged — see §Blocked on),
    `trading/devtools/checks/posix_sh_check.sh` (scope extension).
  - Verify:
    `dash -n dev/scripts/tiered_loader_ab_compare.sh` (parse-only);
    `dev/lib/run-in-env.sh dune runtest trading/devtools/checks` —
    prints `OK: posix-sh linter -- 42 scripts clean.`; full
    `dev/lib/run-in-env.sh dune build && dev/lib/run-in-env.sh dune runtest`
    green.

- **F2 — Summary-tier default tail_days fix** (2026-04-22). Closes the
  residual gap the 3g behavioral QC flagged: under the Tiered path the
  parity test was reporting `Tiered loader: Metadata=22 Summary=0
  Full=0 at end of simulator run`, meaning the Shadow_screener pipeline
  and per-transition promote/demote bookkeeping never saw any real
  data. Parity held only because both paths fell through to the
  simulator's pre-loaded bar cache.
  **Diagnosis.** `Summary_compute.default_config.tail_days = 250` is
  below the minimum needed for the 52-weekly-bar Mansfield RS window.
  250 calendar days of daily input aggregate to ~36 weekly bars via
  `Time_period.Conversion.daily_to_weekly` — strictly under the 52-bar
  threshold `Relative_strength.analyze` checks with `n < rs_ma_period`.
  `rs_line` returns `None`, `compute_values` short-circuits on the
  first `None` in its Option monadic chain, and the symbol is left at
  its prior tier (Metadata after the auto-promote cascade). Neither
  the Shadow_screener cascade nor the Summary→Full pipeline sees any
  input.
  **Fix.** Bump `default_config.tail_days` from 250 to 420 (~60 weekly
  bars after aggregation, covering `rs_ma_period = 52` with headroom
  for market-holiday gaps and partial-week edges). Updated both
  `summary_compute.ml`'s `default_config` binding and the
  `summary_compute.mli` doc comment to spell out that the binding
  constraint is `rs_ma_period * 7` calendar days, not the 30-week MA
  (which only needs ~210 days). No strategy / screener / runner code
  touched — fix is scoped to `bar_loader/summary_compute.ml`.
  **Verification.** The parity scenario now reports
  `Tiered loader: Metadata=0 Summary=19 Full=3 at end of simulator
  run`, meaning all 19 symbols with sufficient history reach Summary
  and the Shadow_screener's top-3 candidates reach Full tier. All
  three parity assertions (round-trip count exact, final value within
  $0.01, sampled step values within $0.01) still hold — now for the
  right reason. Added a regression test
  `test_promote_to_summary_with_default_config` that pins the contract
  "with defaults only, a stock with exactly `default_config.tail_days`
  of history must promote to Summary tier" — it fails loudly if
  anyone ever reduces `tail_days` below the RS threshold again.
  - Files: `trading/backtest/bar_loader/{summary_compute.ml,summary_compute.mli,test/test_summary.ml}`.
  - Verify:
    `dev/lib/run-in-env.sh dune build &&
     dev/lib/run-in-env.sh dune runtest trading/backtest --force` —
    3 parity tests (test_tiered_loader_parity) pass with Tiered loader
    reporting `Summary=19 Full=3` at sim-run end (was 0/0 before);
    9 test_summary tests pass (was 8 before — 1 new regression test);
    all other backtest tests still green; full-workspace `dune runtest`
    passes; `dune build @fmt` clean.

- **3g — Parity acceptance test (merge gate)** (2026-04-21). New
  test binary at `trading/trading/backtest/test/test_tiered_loader_parity.ml`
  runs the same scenario twice — once under `Loader_strategy.Legacy`,
  once under `Loader_strategy.Tiered` — and asserts observably
  identical output across the four dimensions the plan §3g pins:
  1. `summary.n_round_trips` matches exactly (hard fail on any diff).
  2. `summary.final_portfolio_value` matches within $0.01.
  3. Sampled `steps[].portfolio_value` at indices
     `[0; n/4; n/2; 3n/4; n-1]` match within $0.01 per step (step
     date also must match exactly).
  4. Every pinned metric in the scenario's `expected` record
     (`total_return_pct`, `total_trades`, `win_rate`, `sharpe_ratio`,
     `max_drawdown_pct`, `avg_holding_days`) falls inside its
     declared range for BOTH strategies.
  Scenario at `trading/test_data/backtest_scenarios/smoke/tiered-loader-parity.sexp`:
  6-month window (2019-06-03 → 2019-12-31) over a 7-symbol universe
  pinned by `universes/parity-7sym.sexp` (AAPL, MSFT, JPM, JNJ, CVX,
  KO, HD — the intersection of `universes/small.sexp` with checked-in
  test_data/ price CSVs). `loader_strategy` absent from the scenario;
  the test binary drives both values explicitly in two passes.
  Three test cases: `test_legacy_runs_ok` (non-empty steps sanity),
  `test_tiered_runs_ok` (same for Tiered), and
  `test_parity_legacy_vs_tiered` (the four-dimensional parity check).
  **Committed fixtures.** 14 synthetic OHLCV CSVs for the macro
  symbols the Runner's `_load_deps` unconditionally adds to
  `all_symbols` — 11 SPDR sector ETFs (XLK, XLF, XLE, XLV, XLI,
  XLP, XLY, XLU, XLB, XLRE, XLC) + GDAXI.INDX + N225.INDX +
  ISF.LSE. Each spans 2018-10-01 → 2020-01-03 (covers the 210-day
  warmup before scenario start); deterministic 100.00 baseline +
  0.01/day drift so Weinstein's MA slope is consistently positive.
  Both strategies see identical macro inputs — parity assertions
  still hold. ~280 KB total fixture data.
  **Why synthetic data rather than opt-out overrides.** Attempted
  first to zero out `sector_etfs` + `indices.global` via
  `config_overrides`, but `Runner._merge_sexp` treats empty-list
  overlays as empty-record merges, so list-typed fields can't be
  cleared that way. Without macro CSVs,
  `Tiered_runner._promote_universe_metadata` hard-`failwith`s on
  the first missing symbol (see §Follow-up for the underlying
  tolerance divergence) and the test never exercises any strategy
  code. Shipping identical synthetic fixtures to both paths keeps
  the test's merge-gate purpose intact.
  - Files:
    `trading/test_data/backtest_scenarios/smoke/tiered-loader-parity.sexp`
    + `trading/test_data/backtest_scenarios/universes/parity-7sym.sexp`
    + `trading/trading/backtest/test/{dune,test_tiered_loader_parity.ml}`
    + 14 × `trading/test_data/<first>/<last>/<symbol>/data.csv`
    for the macro symbols listed above.
  - Verify:
    `dev/lib/run-in-env.sh dune build &&
     dev/lib/run-in-env.sh dune runtest trading/backtest/test --force` —
    3 parity tests pass (+ 33 pre-existing backtest tests); full-workspace
    `dune runtest` passes; `dune build @fmt` clean.

- **3f-part3 — Tiered runner Friday cycle + per-transition promote/demote**
  (2026-04-20). Completes the Tiered path first opened in 3f-part2 by
  replacing the simulator-cycle `failwith` with a live `Simulator.run`
  driven by the Weinstein strategy wrapped in a new
  `Tiered_strategy_wrapper`. The wrapper sits between the simulator and
  `Weinstein_strategy` and layers tier-bookkeeping on top of the
  unchanged inner strategy per plan §3f Commit 2:
  1. **Friday cycle** — on each bar where the primary-index date is a
     Friday (same heuristic as `Weinstein_strategy._is_screening_day`),
     promote the full universe to `Summary_tier`, harvest the summary
     values from the loader, run `Bar_loader.Shadow_screener.screen`
     over them (sector map empty — Neutral default per adapter
     contract; `macro_trend` = `Neutral` for now), then promote the top
     `max_buy_candidates + max_short_candidates` (= `full_candidate_limit`)
     to `Full_tier`. The inner Weinstein strategy still runs its own
     screener on the `universe=full_list` it received at construction —
     that's fine because the inner screener sees cached bar history for
     Full-tier symbols; non-Full symbols stay absent from its Stage2/4
     promotions.
  2. **Per-`CreateEntering` transition** — each new entering position
     triggers a `Full_tier` promote on that symbol so the simulator has
     OHLCV for the stop state machine on the next bar.
  3. **Per newly-`Closed` transition** — the wrapper holds a snapshot of
     prior-step position states keyed by `position_id` (not symbol —
     the same symbol can cycle `Closed` → fresh `Entering` under a new
     id), and on each step computes the symbols that transitioned into
     `Closed` since the previous call, then demotes them to
     `Metadata_tier`. Idempotent: a symbol already at Metadata is a
     no-op.
  The wrapper also records every transition via `Stop_log.record_transitions`
  and uses a wrapper-local `prior_stages` Hashtbl for the Shadow_screener
  so its stage-transition detection stays independent from the inner
  strategy's own `prior_stages` closure (otherwise the two shadows fight
  over writes).

  **File-length split and PR split.** To keep `runner.ml` under the
  300-line soft limit, the Tiered-path plumbing was extracted into a new
  `tiered_runner.ml{,i}` module. `Runner._run_tiered_backtest` now
  builds a `Tiered_runner.input` record from `_deps` and delegates to
  `Tiered_runner.run`, which returns the same `(sim_result, stop_log)`
  shape the Legacy path produces. `Runner.tier_op_to_phase` is re-exported
  as `Tiered_runner.tier_op_to_phase` so existing tests that asserted on
  the public mapping still pass unchanged. The original PR (#474) was
  then split into two reviewable slices:

  - **3f-part3a** (`feat/backtest-scale-3f-part3a`) — refactor-only
    extraction of `Tiered_runner`. The Tiered path still raises at the
    simulator-cycle step; observable behaviour is byte-identical to
    the post-#466 main.
  - **3f-part3b** (`feat/backtest-scale-3f-part3b`, stacked on
    part3a) — adds `Tiered_strategy_wrapper`, flips the `failwith` to
    a live `Simulator.run`, wires the Friday cycle + per-transition
    promote/demote, and ships the 8-test `test_runner_tiered_cycle`
    suite.

  **Legacy parity preserved.** The Legacy path is untouched; all
  additions are guarded behind `loader_strategy = Tiered`. 3g (parity
  acceptance test) can now run — it is the next merge gate.

  - Files: `backtest/lib/{dune,runner.mli,runner.ml,tiered_runner.mli,tiered_runner.ml,tiered_strategy_wrapper.mli,tiered_strategy_wrapper.ml}` +
    `backtest/test/{dune,test_runner_tiered_cycle.ml}`.
  - Tests: 8 new `test_runner_tiered_cycle` tests covering Friday-cadence
    Summary+Full promotion, non-Friday no-op, `CreateEntering` → Full
    promote (incl. multi-symbol), newly-`Closed` → Metadata demote
    (incl. symbol re-entering under a new position id, incl. idempotency
    across repeated calls), pass-through of inner-strategy `Ok` output,
    and error-path skip (inner `Error` does not trigger any loader
    bookkeeping). Each test builds a small temp-dir Bar_loader seeded
    with synthetic CSVs and a stub `STRATEGY` module that emits
    scripted transitions.
  - Verify:
    `dev/lib/run-in-env.sh dune build &&
     dev/lib/run-in-env.sh dune runtest trading/backtest --force` —
    31 tests pass (3 runner_filter + 5 runner_tiered_skeleton +
    8 runner_tiered_cycle + 6 stop_log + 9 trace); all linters clean;
    `dune fmt` produces no diff.

- **3f-part2 — Tiered runner skeleton** (2026-04-20).
  Implements the pre-simulator portion of the Tiered `Loader_strategy`
  path in `Backtest.Runner` and stacks on 3f-part1 (#463). Under
  `loader_strategy = Tiered`, `run_backtest` now:
  1. Builds a `Bar_loader` over `deps.all_symbols` (universe + primary
     index + sector ETFs + global indices) with a `trace_hook` that
     bridges `Bar_loader.tier_op` onto `Backtest.Trace.Phase.t` via a
     new public helper `Runner.tier_op_to_phase`
     (`Promote_to_summary → Promote_summary`, `Promote_to_full →
     Promote_full`, `Demote_op → Demote`). Keeps `bar_loader`
     independent of the `backtest` library as called out in plan §3d —
     the mapping lives on the runner side, not the loader side.
  2. Promotes every symbol to `Metadata_tier` under a single outer
     `Load_bars` wrap at `end_date`. Metadata promote is silent in the
     tracer hook (3d decision) — the outer wrap is the attribution
     point for memory/timing.
  3. Raises `Failure` at the simulator-cycle step with a pointer to
     3f-part3 so scenarios that opt into `Tiered` surface the
     incomplete contract loudly rather than silently falling back.
  Legacy path is byte-identical to pre-PR (3g parity gate
  precondition). Test module `test_runner_tiered_skeleton.ml` pins the
  observable contract with 5 tests: three unit tests for the
  `tier_op_to_phase` mapping (one per variant so a future rename/
  re-order fails loudly), plus two end-to-end tests that build a
  `Bar_loader` with a test-local `trace_hook` (shaped identically to
  the runner's internal one) and assert the right `Trace.Phase.t`
  row lands in the attached trace collector on both Summary promote
  and Demote paths.
  - **Split boundary:** 3f-part3 ships the Friday Summary-promote →
    `Shadow_screener.screen` → Full-promote cycle plus per-transition
    promote/demote bookkeeping, plus the thin strategy wrapper that
    makes the inner `Weinstein_strategy` skip its own universe
    screening (pass `universe=[]`) and consume screener-sourced
    candidates via `Weinstein_strategy.entries_from_candidates`. 3g
    (parity test) cannot run until 3f-part3 lands — the Tiered path
    still raises after Metadata promote.
  - Files:
    `backtest/lib/{dune,runner.mli,runner.ml}` +
    `backtest/test/{dune,test_runner_tiered_skeleton.ml}`.
  - Verify: `dev/lib/run-in-env.sh dune build && dev/lib/run-in-env.sh
    dune runtest trading/backtest --force` — 23 tests
    (3 runner_filter + 5 runner_tiered_skeleton + 6 stop_log +
    9 trace) + all bar_loader sub-suites pass. `dune fmt` clean.

- **3f-part1 — Shadow screener adapter** (2026-04-20).
  Pure adapter at `trading/trading/backtest/bar_loader/shadow_screener.ml{,i}`
  that synthesizes `Stock_analysis.t` stubs from `Bar_loader.Summary.t`
  values and drives the existing `Screener.screen` without changing its
  signature (plan §Open questions, adapter decision). Synthesis rules
  per plan §3f Commit 1: `Stage.result` reconstructed from
  `Summary.stage` + `Summary.ma_30w` with a conservative `ma_direction`
  proxy (Rising for Stage2 / Declining for Stage4 / Flat otherwise);
  `Rs.result` from `Summary.rs_line` thresholded at 1.0 (Mansfield
  normalization) into `Positive_rising` / `Negative_declining`;
  `Volume.result` set to `Adequate 1.5` for Stage2/4 (the floor that
  satisfies `is_breakout_candidate`) and `None` otherwise;
  `Resistance.result = None`; `breakout_price = None` (Screener
  falls back to `ma_value * (1 + breakout_fallback_pct)`). Prior-stage
  tracking is caller-managed via a `(string, stage) Hashtbl.t` — same
  mechanism as `_screen_universe` in `weinstein_strategy.ml`. Known
  divergences from Legacy documented on the .mli: missing volume
  contribution lowers scores ~20-30 pts (C becomes functional floor),
  missing resistance bonus, no RS `Bullish_crossover` / `Bearish_crossover`.
  3g parity test will quantify whether the divergence is within ε.
  Re-exported through `Bar_loader.Shadow_screener`.
  - Files: `bar_loader/{dune,bar_loader.mli,bar_loader.ml,shadow_screener.mli,shadow_screener.ml}`
    + `bar_loader/test/{dune,test_shadow_screener.ml}`.
  - Verify: `dev/lib/run-in-env.sh dune build && dev/lib/run-in-env.sh dune runtest trading/backtest/bar_loader --force` — 17 shadow_screener tests (9 synthesize_analysis + 8 screen-cascade) + 42 pre-existing bar_loader tests pass; `dune build @fmt` clean.
  - Note: 3f Commit 2 (`_run_tiered_backtest` runner integration) was planned to
    ship in the same PR but was deferred due to concurrent-agent workspace
    contention (sibling agent racing on git HEAD) that exhausted the
    Max-Iterations Policy budget. Follow-up increment tracked in §Next Steps.

- **3e — Runner + scenario plumbing for `loader_strategy`** (2026-04-20).
  Adds a tiny `Loader_strategy.t = Legacy | Tiered` library at
  `trading/trading/backtest/loader_strategy/` (kept standalone so both
  `backtest` and `scenario_lib` can depend on it without cycles).
  `Backtest.Runner.run_backtest` gains
  `?loader_strategy:Loader_strategy.t` (default `Legacy`); the `Tiered`
  branch raises `Failure` with a clear pointer to 3f so absence of an
  implementation surfaces loudly. `Scenario.t` gains optional
  `loader_strategy : Loader_strategy.t option` ([@sexp.option]) so
  individual scenario `.sexp` files can opt in; `scenario_runner`
  forwards the field through `?loader_strategy`. CLI flag
  `--loader-strategy {legacy|tiered}` added to `bin/backtest_runner`
  via a new `_extract_flags` helper. Two new sexp round-trip tests
  in `test_scenario.ml` (absent => `None`; `Tiered` round-trips).
  No scenario file in the repo sets the new field today, so
  observable behaviour is unchanged for the merge.
  - Files: `backtest/loader_strategy/{dune,loader_strategy.mli,loader_strategy.ml}`
    + `backtest/lib/{dune,runner.mli,runner.ml}`
    + `backtest/scenarios/{dune,scenario.mli,scenario.ml,scenario_runner.ml}`
    + `backtest/scenarios/test/{dune,test_scenario.ml}`
    + `backtest/bin/{dune,backtest_runner.ml}`.
  - Verify: `dev/lib/run-in-env.sh dune build && dev/lib/run-in-env.sh dune runtest trading/backtest --force` — 11 scenario tests (9 existing + 2 new) + 3 runner_filter tests pass.

- **3d — Tracer phases for tier operations** (2026-04-19). Adds three
  `Backtest.Trace.Phase.t` variants (`Promote_summary`, `Promote_full`,
  `Demote`) and wires `Bar_loader.promote` / `Bar_loader.demote` to emit
  them via a narrow callback hook (`trace_hook`) registered on
  `Bar_loader.create`. The callback carries a `Bar_loader.tier_op` tag
  + batch size; the runner (3e) will map `tier_op` to the matching
  `Trace.Phase.t` and forward to `Trace.record`. Shape rationale: keeping
  `bar_loader` independent of the `backtest` library avoids the cycle
  that would arise once 3f makes the runner depend on `Bar_loader`.
  Metadata promotion is deliberately silent (owned by the runner's outer
  `Load_bars` phase wrapper); Summary/Full promotes emit one record
  each per `promote` call; `demote` always emits regardless of target
  tier. When no hook is registered the wrappers short-circuit through
  a single `Option` match — observable behaviour is identical to the
  pre-hook version, satisfying the 3g parity gate precondition.
  - Files: `bar_loader/{bar_loader.mli,bar_loader.ml}` +
    `bar_loader/test/{dune,test_trace_integration.ml}` +
    `lib/{trace.ml,trace.mli}` + `test/test_trace.ml` (extended sexp
    round-trip to cover the 3 new variants).
  - Verify: `dev/lib/run-in-env.sh dune build && dev/lib/run-in-env.sh dune runtest trading/backtest/bar_loader trading/backtest/test --force` — 42 bar_loader tests (35 existing + 7 new trace-integration) + 9 trace tests pass.

- **3c — Full tier + promotion semantics** (2026-04-19). Adds
  `Full.t = { symbol; bars; as_of }` and a thin `Full_compute` pure
  module mirroring `Summary_compute`'s shape. `promote ~to_:Full_tier`
  cascades through Summary (→ Metadata), then loads a bounded OHLCV
  tail (`full_config.tail_days = 1800` default, ~7 years) via the
  shared `_load_bars_tail` helper — now parameterized on `tail_days`
  so Summary's 250-day window and Full's 1800-day window share the
  same CSV path. `get_full` returns `Full.t option`. Demotion
  semantics per plan §Resolutions #6: Full → Summary keeps Summary
  scalars and drops bars; Full → Metadata drops both higher tiers.
  `Types.Daily_price.t` has no sexp converters, so `Full.t` derives
  `show, eq` only (documented in the mli). `Bar_history`,
  `Weinstein_strategy`, `Simulator`, `Price_cache`, and `Screener`
  untouched (plan §Out of scope).
  - Files: `bar_loader/{bar_loader.mli,bar_loader.ml,full_compute.mli,full_compute.ml}`
    + `bar_loader/test/{dune,test_full.ml,test_metadata.ml}` (dropped
    the now-obsolete `full_promotion_unimplemented` test on metadata).
  - Verify: `dev/lib/run-in-env.sh dune build trading/backtest/bar_loader && dev/lib/run-in-env.sh dune runtest trading/backtest/bar_loader --force` — 7 Metadata + 12 Summary_compute + 8 Summary + 8 Full = 35 tests pass.

- **3b-ii — Summary tier wiring + integration tests** (2026-04-19).
  Wires `Summary_compute` (from 3b-i) into `Bar_loader`. Adds
  `Summary.t` record on per-symbol entries. `promote ~to_:Summary_tier`
  auto-promotes through Metadata, reads a bounded 250-day daily-bar
  tail via `Csv_storage` (bypassing `Price_cache` so raw bars don't
  leak into the shared cache), computes scalars via
  `Summary_compute.compute_values`, then drops the bars. Benchmark
  bars lazy-loaded and cached on the loader. `get_summary` returns
  `Summary.t option`. Insufficient history leaves the symbol at
  Metadata tier. Demote to Metadata drops Summary scalars.

- **3b-i — Summary_compute pure indicator helpers** (merged, PR #444).

- **3a — Metadata tier + types scaffold** (2026-04-19). New library at
  `trading/trading/backtest/bar_loader/`. Exposes the full
  `Metadata_tier | Summary_tier | Full_tier` variant up front so
  3b/3c don't churn it. `Metadata.t` carries sector + last_close;
  `market_cap` and `avg_vol_30d` stay `float option = None` until a
  consumer needs them (plan §Risks #4). `promote ~to_:Metadata_tier`
  reads the last bar ≤ `as_of` via the existing `Price_cache` and
  joins a caller-supplied sector table — idempotent, surfaces
  per-symbol errors without inserting failed symbols.
  - Files: `bar_loader/{dune,bar_loader.mli,bar_loader.ml}` +
    `bar_loader/test/{dune,test_metadata.ml}`.

## QC

overall_qc: APPROVED (3c — structural + behavioral, 2026-04-19)
structural_qc: APPROVED (3c, 2026-04-19 — dev/reviews/backtest-scale-3c.md)
behavioral_qc: APPROVED (3c, 2026-04-19 — data-loading increment; no strategy behavior change; tier-shape + demote/promote invariants verified against plan §Resolutions #6. Parity acceptance gate arrives with 3g — dev/reviews/backtest-scale-3c.md)

structural_qc: APPROVED (3d, 2026-04-19 — dev/reviews/backtest-scale-3d.md)
behavioral_qc: APPROVED (3d, 2026-04-19 — infrastructure-only tracer hook; no Weinstein domain logic touched; no-trace path observably silent for all three tier operations, verified by test_no_hook_promote_is_silent — dev/reviews/backtest-scale-3d.md)
overall_qc: APPROVED (3d — structural + behavioral, 2026-04-19)

structural_qc: APPROVED (3f-part2, 2026-04-20 — SHA 224031672d29434d178eba1111c8f6e6497b2a7d; dev/reviews/backtest-scale.md §3f-part2). All hard gates pass. Behavioral QC not blocked.
structural_qc: APPROVED (3e, 2026-04-20 — dev/reviews/backtest-scale.md)
behavioral_qc: APPROVED (3e, 2026-04-20 — plumbing-only PR; Legacy path byte-identical to pre-PR, Tiered branch raises loudly without silent fallback, CLI/scenario defaults flow to Legacy, sexp.option preserves backward-compat with all existing scenario files (none set the new field). Quality score 5/5. — dev/reviews/backtest-scale.md)
overall_qc: APPROVED (3e — structural + behavioral, 2026-04-20)

Reviewers when work lands:
- qc-structural — module boundaries between tiers; `Bar_history` untouched; parity test runs both strategies.
- qc-behavioral — does strategy output (trades, metrics) actually match Legacy within ε? Any regression is a behavior bug, not a perf win.

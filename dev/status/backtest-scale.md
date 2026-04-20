# Status: backtest-scale

## Last updated: 2026-04-20

## Status
READY_FOR_REVIEW

structural_qc: APPROVED (2026-04-20) — feat/backtest-scale-3e SHA c51d42bee97618ab3b67679943094fc20baa66d3. All hard gates pass. See dev/reviews/backtest-scale.md.

Plan `dev/plans/backtest-tiered-loader-2026-04-19.md` reviewed + open questions resolved (2026-04-19). 3a (Metadata) merged; 3b-i (Summary_compute) merged; 3b-ii (Summary tier wiring) merged as #445; 3c (Full tier) merged as #447; 3d (tracer phases) merged as #452. 3e (runner + scenario plumbing for `loader_strategy`) ready for review on `feat/backtest-scale-3e` (#459, rebased onto main post-#457). 3f was split into three stacked parts to respect the ~400-line per-PR budget: 3f-part1 (shadow_screener adapter) shipped as draft #463 on `feat/backtest-scale-3f` (QC APPROVED); 3f-part2 (tiered runner skeleton — Bar_loader create + bulk Metadata promote + trace bridge, raises at simulator-cycle step) shipped as DRAFT #466 on `feat/backtest-scale-3f-part2`; 3f-part3 (Friday Summary-promote → Shadow_screener → Full-promote cycle + per-transition promote/demote) ready for review on `feat/backtest-scale-3f-part3` (#474). Next outstanding increment is 3g (parity gate).

## Interface stable
NO

All three tier getters return their proper typed option: `get_metadata : Metadata.t option`, `get_summary : Summary.t option`, `get_full : Full.t option`. Core `Bar_loader.create` / `promote` / `demote` / `tier_of` / `stats` signatures remain stable; `create` gained optional `?full_config` in 3c and `?trace_hook` in 3d. Remaining churn will come from 3e (runner wiring) and 3f (tiered runner path).

## Open PR
- feat/backtest-tiered-loader-3d-tracer-phases — 3d based on main; tier-op tracer phases + callback hook. Ready for QC.
- feat/backtest-scale-3e — 3e based on main; runner + scenario plumbing for `loader_strategy`. Ready for QC.
- feat/backtest-scale-3f — 3f-part1 (#463) based on main; shadow_screener adapter only. QC APPROVED.
- feat/backtest-scale-3f-part2 — 3f-part2 (DRAFT #466) stacked on feat/backtest-scale-3f; tiered runner skeleton (Bar_loader create + bulk Metadata promote + trace bridge, raises at simulator-cycle step). Ready for QC on the skeleton scope.
- feat/backtest-scale-3f-part3 — 3f-part3 (#474) based on main (post 3f-part2 merge as #466); Friday Summary-promote → Shadow_screener → Full-promote cycle + per-transition promote/demote via a thin `Tiered_strategy_wrapper` atop the existing `Weinstein_strategy`. Ready for QC.

## Blocked on
- None. 3g (parity acceptance test) is the next outstanding increment; depends on 3f-part3 merging.

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

1. QC review of 3d (feat/backtest-tiered-loader-3d-tracer-phases head).
2. QC review of 3e (feat/backtest-scale-3e head).
3. QC review of 3f-part1 (feat/backtest-scale-3f head, PR #463) — shadow_screener adapter in isolation.
4. QC review of 3f-part2 (feat/backtest-scale-3f-part2 head, PR #466) — tiered runner skeleton (Bar_loader create + bulk Metadata promote + trace bridge + failwith at simulator-cycle step).
5. QC review of 3f-part3 (feat/backtest-scale-3f-part3 head) — Friday Summary-promote → Shadow_screener → Full-promote cycle + per-transition promote/demote via `Tiered_strategy_wrapper`.
6. Dispatch 3g (parity acceptance test) — merge gate on `smoke/tiered-loader-parity.sexp`. Runs both `loader_strategy = Legacy` and `Tiered` paths on a shared scenario and asserts trade count / total P&L / final portfolio value / pinned metrics match within float ε. Cannot run until 3f-part3 lands.

## Completed

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

  **File-length split.** To keep `runner.ml` under the 300-line soft
  limit, the Tiered-path plumbing was extracted into a new
  `tiered_runner.ml{,i}` module. `Runner._run_tiered_backtest` now
  builds a `Tiered_runner.input` record from `_deps` and delegates to
  `Tiered_runner.run`, which returns the same `(sim_result, stop_log)`
  shape the Legacy path produces. `Runner.tier_op_to_phase` is re-exported
  as `Tiered_runner.tier_op_to_phase` so existing tests that asserted on
  the public mapping still pass unchanged.

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

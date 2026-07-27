# Status: cleanup

## Last updated: 2026-05-22

## Status
IN_PROGRESS

## Interface stable
NO

Cleanup track has no public interface — it absorbs small mechanical fix-ups surfaced by `health-scanner` (deep + fast scans) so feature agents stay focused on feature work. The "interface" here is the `dev/status/cleanup.md` Backlog schema, which is maintained by the orchestrator and consumed by `code-health`.

## Ownership
`code-health` agent — see `.claude/agents/code-health.md`. Dispatched by `lead-orchestrator` Step 2e on health-scan findings, one finding per dispatch, ≤200 LOC, no behavior change.

## Backlog

- [x] citation_defect: trading/trading/weinstein/stops/lib/support_floor.mli — split the doc-comment citation: long rule now cites `Ch. 6 §5.1 ("Initial Stop Placement")`, short rule now cites `Ch. 7 §6.3 ("Short Stop (Buy-Stop) Rules")`; independently verified against docs/design/weinstein-book-reference.md that §5.1 contains only the long rule and §6.3 the short rule. Branch cleanup/support-floor-citation (2026-07-26)
- [ ] flake_root_cause: trading/trading/backtest/tuner/lib/bayesian_opt_cholesky.ml — `Tuner.Bayesian_opt:11`/`:17` fail with `Failure("LAPACKE: 9")` on SOME runner hosts, not all. **Host-dependent, not a regression** — run 3 saw exit 1 reproduced 3/3; runs 1, 2 and 4 saw exit 0, run 4 with 44/44 passing and 3/3 clean direct re-runs on the same image. Two root-cause hypotheses were ELIMINATED by reading in run 4: (a) "a failed `potrf` leaves `k` partially overwritten so the retry jitters a corrupted matrix" is FALSE — `Owl.Linalg.D.chol` (`owl_linalg_generic.ml:288`) does `let x = M.copy x in` before `potrf`, so each attempt sees a clean copy; (b) "`max_added_jitter = 1e-2 *. signal_variance` collapses to ~0" is FALSE — `bayesian_opt.ml:219` fixes `_signal_variance = 1.0`, so the cap is `1e-2` absolute and cumulative jitter reaches ~1.1% of a ~1.0 diagonal, ample for merely-duplicated points. Surviving suspects: non-finite (`NaN`/`inf`) entries in the kernel matrix, against which no jitter helps and which would produce exactly the observed "exhausts all 6 attempts"; or a genuine BLAS-kernel difference across runner CPU generations (run 3's host was an AVX-512 `Xeon 6973P-C`; `ci.yml` already carries a CPU-flag smoke step). Needs (a) a guard/assert on non-finite kernel entries with a clear error, and (b) a regression test pinning the degenerate input class. See dev/health/2026-07-26-fast-run4.md. (source: 2026-07-26 run 4, supersedes the run-3 entry which asserted a deterministic main-is-red regression)
- [ ] citation_gap: trading/trading/weinstein/stops/lib/support_floor.mli — the `min_pullback_pct` docstring asserts "Weinstein's book default is [0.08] (8%)" with **no section citation**. Nearest support is §5.2 ("WAIT for first substantial correction (8-10%+)"). Same detection-evading shape as the four confirmed citation defects: a numeric domain constant asserting book provenance without a `§N.N` token. Fix = add `(§5.2)` or correct the claim. `harness_gap: LINTER_CANDIDATE` — a linter CAN mechanically flag docstrings that assert book provenance without a section token, which would catch this whole defect family. (source: 2026-07-26 run 4 qc-behavioral on PR #2099)
- [ ] citation_precision: trading/trading/weinstein/stops/lib/support_floor.mli — the Short stop line's "BEFORE the breakdown" is not stated in §6.3; it is a two-hop inference from "**Initial** buy-stop" + §6's "Mirror image of buying" preamble + §5.1's "BEFORE the breakout". Sound and structurally licensed (§6.2 enumerates the differences from buying and stop *timing* is not among them), but derived rather than quoted. Optional one-clause note, e.g. `(§6.3; timing per §6 mirror-image preamble)`. `harness_gap: ONGOING_REVIEW` — telling a faithful paraphrase from drift needs both sections read in context; not mechanizable. (source: 2026-07-26 run 4 qc-behavioral on PR #2099)
- [ ] test_pin: trading/trading/weinstein/snapshot/gen/test/test_rename_detector.ml — the `prefilter_rel_tol = Float.infinity` correctness precondition (without it `Twin_detector`'s prefilter can drop a genuine rename pair before scoring) is pinned only **incidentally**, by the B2 `_trunc_*` fixture whose anchor-key gaps happen to be 0.041–0.050 > the stock 2e-2. The pre-existing OLDCO/NEWCO pair has min gap 0.0057 and would leave it unpinned. Nothing records the dependency, so a future fixture edit could silently unpin a stated precondition. Fix = a one-line comment on `_trunc_zombie_indices` noting the 4-session predecessor gap is load-bearing. (source: 2026-07-26 run 4 qc-behavioral F7 on PR #2100)
- [ ] linter_coverage: trading/devtools/checks/linter_file_length.sh — scope is `-path "*/lib/*.ml"`, so **test files are entirely exempt** from the 300-soft / 500-hard limits. `test_rename_detector.ml` reached 600 lines in PR #2100 with no linter signal. Either the exemption is intentional (then say so in the script header, since its absence reads as an oversight) or test files should carry a higher explicit limit. Not urgent; flagged so the gap is a decision rather than an accident. (source: 2026-07-26 run 4 orchestrator verification)
- [ ] linter_expiry: docs/design/weinstein-trading-system-v2.md — no `Current milestone:` line, so `check_11_linter_expiry.sh` cannot evaluate ANY milestone-pinned linter exception; whole subsystem silently disabled (source: 2026-07-20-deep.md, warning 31)
- [ ] linter_exception_format: trading/devtools/checks/linter_exceptions.conf — magic_numbers entry for `trading/engine/lib/price_path.ml` has unparseable `review_at: when price_path.ml is actively modified`; needs a date or milestone token (source: 2026-07-20-deep.md, warning 32)
- [x] design_doc_drift: docs/design/backtest-scale-optimization-2026-04-17.md — added a 23-subdir inventory appendix to `dev/plans/backtest-scale-optimization-2026-04-17.md` (the finding's stated path doesn't exist; no `docs/design/` file by this name — fixed the real one). PR #2096 (2026-07-26)
- [ ] design_doc_drift: docs/design/eng-design-2-screener-analysis.md — 6 `analysis/weinstein/*` subdirs exist on disk but are unmentioned (continuation, laggard_rotation, snapshot_pipeline, snapshot_runtime, stage3_force_exit, support) (source: 2026-07-20-deep.md, warnings 1-6)
- [x] nesting: garch.ml + snapshot_writer.ml + split_detector.ml — verified clean 2026-05-22; nesting_linter no longer flags any of these files (likely subsumed by PR #977 / #978 which extracted helpers for the same files)
- [x] nesting: pipeline.ml+daily_panels.ml+optimal_strategy_runner_helpers.ml+optimal_portfolio_filler.ml — extracted _build_rows, update_bench, _insert_rows, _neutral_ctx, _compare_by_r_multiple, _compare_by_score; all 5 dispatch violations cleared (branch cleanup/nesting-pipeline-batch-2, 2026-05-08)
- [x] nesting: 8 final violations — garch.ml, snapshot_writer.ml, split_detector.ml, split_event.ml, runner.ml, reconciler_writer.ml — extracted _run_garch_loop, _version_mismatch_error, _mkdir_error, _snap_if_split, _replace_if_symbol, _pos_symbol, _held_symbols_of_last_step, _write_split_row, _position_symbol; all 8 cleared. PR #978 (2026-05-08)
- [x] nesting: trading/trading/weinstein/snapshot/lib/pick_diff.ml + trading/analysis/weinstein/snapshot_pipeline/lib/snapshot_manifest.ml — verified clean 2026-05-22; nesting_linter no longer flags either file
- [x] nesting: analysis/data/synthetic/garch.ml + regime_hmm.ml + data/types/split_detector.ml + wiki_sp500/changes_parser.ml + stock_analysis.ml — extracted _validate_sample_inputs, _garch_step, _sample_step, _classify_ratio, _date_of_groups, _split_factor_of_bar; all 5 violations cleared. PR #977 (2026-05-08)
- [x] nesting: trading/analysis/data/sources/wiki_sp500/lib/ticker_aliases.ml — verified clean 2026-05-22; nesting_linter no longer flags this file (file avg below 2.5)
- [x] fn_length: trading/trading/simulation/lib/simulator.ml — verified clean 2026-05-22; fn_length_linter says "no functions exceed 50 lines" (step fn was extracted in subsequent simulator-fix PRs)

- [x] nesting: trading/trading/backtest/optimal/lib/optimal_strategy_report_sections.ml — extracted _cmp_actual_by_date, _actual_date_break, _label_actual_group, _cmp_optimal_by_date, _optimal_date_break, _label_optimal_group, _ratio_narrative; all 3 violations cleared (branch cleanup/nesting-report-sections, 2026-05-08)
- [x] nesting: trading/trading/backtest/optimal/lib/outcome_scorer.ml — extracted _step_stage3, _make_initial_state, _resolve_exit; both violations cleared. PR #950 (2026-05-08)
- [x] nesting: trading/trading/backtest/optimal/lib/optimal_run_artefacts.ml — extracted _rejection_pair_of_alternative + _pairs_of_audit_record; nesting linter clean. PR #949 (2026-05-08)
- [x] fn_length: trading/trading/backtest/optimal/lib/optimal_strategy_runner.ml — extracted 7 helpers (calendar, analysis, sector, forward, scan) to Optimal_strategy_runner_helpers; 413→282 LOC (branch cleanup/optimal-runner-split-2, 2026-05-08)
- [x] nesting: trading/trading/data_panel/snapshot/lib/snapshot_format.ml — extracted _check_all_hashes_equal, _build_manifest, _flush_to_channel, _try_write_file, _check_payload_length, _check_payload_md5, _check_row_count, _check_schema_hash; all violations cleared (branch cleanup/nesting-snapshot-format, 2026-05-08)
- [x] nesting: analysis/data/synthetic/garch.ml + regime_hmm.ml + data/types/split_detector.ml + wiki_sp500/changes_parser.ml + stock_analysis.ml — extracted _validate_sample_inputs, _garch_step, _sample_step, _classify_ratio, _date_of_groups, _split_factor_of_bar; all 5 violations cleared. PR #977 (2026-05-08)
- [x] nesting: trading/analysis/data/sources/wiki_sp500/lib/ticker_aliases.ml — verified clean 2026-05-22; nesting_linter no longer flags this file (file avg below 2.5)
- [x] fn_length: trading/trading/simulation/lib/simulator.ml — verified clean 2026-05-22; fn_length_linter says "no functions exceed 50 lines" (step fn was extracted in subsequent simulator-fix PRs)
- [x] nesting: trading/trading/simulation/lib/{antifragility,return_basics,distributional}_computer.ml — extracted _add_ols_pair, _zero_sums, _add_sq_dev, _add_moments, _bucket_loop helpers; all 5 dispatch violations cleared. PR #967 (2026-05-08)
- [x] magic_numbers: trading/trading/backtest/optimal/lib/optimal_strategy_report_sections.ml — extracted _strong_outperform_threshold=3.0 and _moderate_outperform_threshold=1.5; linter clean (branch cleanup/optimal-report-sections-magic, 2026-05-08)
- [x] nesting: trading/analysis/scripts/build_snapshots/build_snapshots.ml — extracted 5 helpers (_entry_is_current, _write_and_checksum, _file_metadata, _build_or_log, _load_benchmark_bars, _make_progress, _last_symbol, _fold_symbol); all 78 fns pass nesting linter (branch cleanup/nesting-build-snapshots-2, 2026-05-08)
- [x] nesting: trading/trading/weinstein/strategy/lib/entry_audit_capture.ml — extracted 5 helpers; classify_candidate/emit_entries/alternatives_of_decisions all pass; file avg now under 2.5 (branch cleanup/nesting-entry-audit-capture, 2026-05-08)
- [x] fn_length + magic_numbers: trading/analysis/weinstein/snapshot_runtime/lib/snapshot_bar_views.ml — condensed comments −15 lines (297); restructured to avoid bare literals on mid-comment lines. PR #924 (2026-05-07)
- [x] nesting: trading/analysis/weinstein/snapshot_runtime/lib/snapshot_bar_views.ml — extracted 9 helpers (_make_daily_price, _match_ohlcv, _fetch_and_build_weekly_view, _fetch_weekly_bars, _to_weekly_bars, _daily_view_from_idx, _find_and_build_daily_view, _low_buf_from_idx, _check_and_fetch_low); all 5 violations cleared. PR #966 (2026-05-08)
- [x] file_length: trading/analysis/weinstein/snapshot_runtime/lib/snapshot_bar_views.ml — 338->295 LOC; extracted 5 OHLCV helpers to snapshot_bar_views_helpers. PR #972 (2026-05-08)
Orchestrator populates this from `dev/health/<date>-{fast,deep}.md`. Items here are eligible for next dispatch.

## Completed
- [x] nesting: trading/trading/weinstein/snapshot/lib/round_trip_verifier.ml — extracted _stop_check/_carryover_stop/_stop_adjusted_ok/_stop_unchanged_ok helpers; all 3 violations cleared. PR #964 (2026-05-08)
- [x] nesting: trading/analysis/weinstein/screener/lib/screener.ml — extracted _filter_and_cap helper; _evaluate_longs/_evaluate_shorts nesting violations cleared. (branch cleanup/nesting-screener-eval-2, 2026-05-08)
- [x] file_length: trading/trading/engine/lib/price_path.ml (511→498) + trading/trading/weinstein/strategy/lib/entry_audit_capture.ml (305→297) — condensed private-fn docstrings; both files now within limits. PR #958 (2026-05-08)

- [x] nesting: trading/trading/weinstein/strategy/lib/exit_audit_capture.ml — extracted _pct_distance_from_callbacks, _make_exit_event, _handle_trigger_exit helpers; nesting linter now passes. (branch cleanup/nesting-exit-audit-capture, 2026-05-07)
- [x] fn_length + file_length: trading/trading/backtest/lib/runner.ml — extracted `Runner_metrics` module + `_filter_steps`/`_extract_filtered_logs` helpers; runner.ml 528→468 lines, `run_backtest` 83→49 lines. Branch cleanup/runner-fn-length (2026-05-07)
- [x] fn_length: trading/trading/backtest/optimal/lib/optimal_strategy_runner.ml — extracted 8 helpers to Optimal_friday_helpers; 413→270 lines (branch cleanup/optimal-strategy-runner, 2026-05-07)
- [x] file_length: trading/trading/backtest/optimal/lib/optimal_strategy_report.ml — extracted divergence + missed-trades sections to Optimal_strategy_report_sections; 488→281 lines (source: dispatch 2026-05-07, PR #928)
- [x] file_length: trading/trading/backtest/lib/panel_runner.ml — extracted step-loop helpers to Panel_step_loop module; 309→237 lines (source: dispatch 2026-05-07, branch cleanup/file-length-panel-runner)
- [x] file_length: trading/trading/backtest/lib/result_writer.ml — extracted trades-CSV cluster to Trades_writer module; 372→245 lines (source: dispatch 2026-05-07, PR #929)
- [x] fn_length + file_length: trading/trading/weinstein/strategy/lib/entry_audit_capture.ml — extracted entry construction + debug trace helpers to entry_audit_helpers.ml; 383→272 lines; make_entry_transition 54→31 lines (PR #930, 2026-05-07)
- [x] nesting: trading/analysis/data/storage/csv/lib/csv_storage.ml — extracted `_parse_and_accumulate` and `_read_next_line` helpers; nesting linter now passes (835 fns, all OK). (source: 2026-04-26-fast.md, PR #578 merged 2026-04-26T16:04Z)
- [x] fn_length / file_length: weinstein_strategy.ml — added @large-module annotation; file length linter now passes. (source: 2026-04-19-fast.md, PR #453, 2026-04-19)
- [x] file_length: trading/analysis/weinstein/screener/lib/screener.ml — extracted sector_rating/scoring_weights/grade_thresholds types + signal helpers + price helpers to Screener_scoring; 708→485 lines (under 500 hard limit). (source: dispatch 2026-05-07, branch cleanup/screener-large)

## Out of scope

- Behavior changes — escalate to the relevant feat-agent.
- Linter rule changes — `harness-maintainer` owns `devtools/checks/`.
- Multi-file refactors crossing module boundaries — feat-agent.

## How findings get here

`lead-orchestrator` Step 2e parses the most recent `dev/health/<date>-deep.md` and `<date>-fast.md`, picks `[medium]` or `[high]` findings (skips `[info]`), and appends one Backlog entry per finding it doesn't already see. The entry shape is:

```
- [ ] <finding type>: <file path> — <one-line context> (source: <date>-deep.md)
```

Subsequent runs may dispatch `code-health` to work the top item; agent flips to `[~]` on start, `[x]` on completion.

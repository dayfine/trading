Reviewed SHA: 71cdfe694040f28c12cf9181a920b618f816578c

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | Exit 0; only dune-project warning (pre-existing) |
| H2 | dune build | PASS | Exit 0 |
| H3 | dune runtest | PASS | Exit 0; advisory linters (fn_length, nesting, file_length, magic_numbers) print FAIL lines but all are pre-existing on main and their dune rules exit 0; confirmed by running dune runtest on main |
| P1 | Functions ≤ 50 lines — covered by fn_length_linter (dune runtest) | PASS | fn_length_linter output flags only runner.ml:193 (pre-existing); no bar_loader functions flagged |
| P2 | No magic numbers — covered by linter_magic_numbers.sh (dune runtest) | PASS | linter_magic_numbers.sh exits OK for this branch; 1800 appears only in default_config assignment in full_compute.ml — a named constant, not an inline bare literal |
| P3 | All configurable thresholds/periods/weights in config record | PASS | tail_days = 1800 is the value of Full_compute.config.tail_days; the loader routes through full_config.tail_days everywhere |
| P4 | .mli files cover all public symbols — covered by linter_mli_coverage.sh (dune runtest) | PASS | linter_mli_coverage.sh passed as part of H3; full_compute.mli covers config, default_config, full_values, compute_values; bar_loader.mli covers Full, Full_compute re-export, all new public API |
| P5 | Internal helpers prefixed with _ | PASS | All private helpers (_load_bars_tail, _benchmark_bars_for, _write_summary_entry, _promote_one_to_summary, _write_full_entry, _promote_one_to_full, _demote_one, _promote_fold, _already_at_or_above, _default_benchmark_symbol) have _ prefix; public symbols (create, promote, demote, get_full, get_summary, stats, tier_of, Full, Summary, Full_compute) do not |
| P6 | Tests use the matchers library (per CLAUDE.md) | PASS | test_full.ml and test_summary.ml use assert_that, is_ok, is_some_and, is_none, equal_to, all_of, field, gt/Int_ord, elements_are; no assert_bool or assert_equal; assert_failure used only in _ok_or_fail test-setup helper (not inside a matcher callback) |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) — FLAG if any found | PASS | No modifications to Portfolio, Orders, Position, Strategy, or Engine modules |
| A2 | No imports from analysis/ into trading/trading/ | PASS | bar_loader dune library lists only core, fpath, status, types, trading.simulation.data, csv, indicators.*, weinstein.*; no analysis/ library appears |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | Only dev/status/backtest-scale.md (status update), dev/status/harness.md (single checkbox state flip [~]) touched outside the bar_loader library; Bar_history, Weinstein_strategy, Simulator, Price_cache, Screener untouched per plan §Out of scope |

## Verdict

APPROVED

---

# Behavioral QC — backtest-scale-3c
Date: 2026-04-19
Reviewer: qc-behavioral

## Scope note

3c is an infrastructure / data-loading increment. It adds the `Full` tier and promote/demote semantics to `Bar_loader` with no runner integration and no strategy-rule changes. The Weinstein strategy (stage classifier, buy/sell signals, stop logic) is untouched — `Bar_history`, `Weinstein_strategy`, `Simulator`, `Price_cache`, and `Screener` are explicitly out of scope per plan §Out of scope and confirmed by structural QC item A3. The Tiered runner path arrives in 3f and the Legacy-vs-Tiered parity test — the actual behavioral merge gate for this whole track — arrives in 3g. Until 3f lands there is no strategy execution path that consumes Full-tier data, so no strategy-behavior regression is possible on this PR.

Behavioral checks S1–S6, L1–L4, C1–C3 are therefore NA for this increment. The checks that do apply are the domain-invariant ones: Full-tier data shape is adequate for downstream strategy needs, demote semantics match the plan contract (Resolutions #6), promote correctly cascades through lower tiers.

## Behavioral Checklist

| # | Check | Status | Notes (cite authority doc section) |
|---|-------|--------|------------------------------------|
| A1 | Core module modification is strategy-agnostic | NA | qc-structural A1 = PASS; no core modules touched |
| S1 | Stage 1 definition matches book | NA | Data-loading increment; stage classifier untouched (lives in Weinstein_strategy / indicators) |
| S2 | Stage 2 definition matches book | NA | Same |
| S3 | Stage 3 definition matches book | NA | Same |
| S4 | Stage 4 definition matches book | NA | Same |
| S5 | Buy criteria: Stage 2 entry on breakout with volume | NA | Screener/strategy not in scope |
| S6 | No buy signals in Stage 1/3/4 | NA | Same |
| L1 | Initial stop below base | NA | Stops not in scope |
| L2 | Trailing stop never lowered | NA | Same |
| L3 | Stop triggers on weekly close | NA | Same |
| L4 | Stop state machine transitions | NA | Same |
| C1 | Screener cascade order | NA | Shadow screener lands in 3f |
| C2 | Bearish macro blocks all buys | NA | Same |
| C3 | Sector RS vs. market, not absolute | NA | Same |
| D1 | Full tier represents complete OHLCV (plan §Approach, §3c) | PASS | `Full.t = { symbol; bars : Types.Daily_price.t list; as_of }` (bar_loader.mli:83–100, bar_loader.ml:34–37). Bars are loaded via `_load_bars_tail` which reads directly from `Csv.Csv_storage.get` — full OHLCV rows preserved (no projection to scalars), ordered ascending by date per the `.mli` contract |
| D2 | Full tail length is adequate for strategy windows | PASS | `default_config = { tail_days = 1800 }` (full_compute.ml:10) ≈ 7 years of calendar days ≫ 150 trading days needed for 30-week MA on weekly-aggregated bars. Value is named and configurable via `Full_compute.config`, never hardcoded at call sites. weinstein-book-reference.md §Stage Definitions requires weekly 30-week MA, 1800 daily calendar days comfortably covers it |
| D3 | Demote Full → Summary preserves Summary, drops bars (plan §Resolutions #6) | PASS | bar_loader.ml:326–329: `{ entry with tier = Summary_tier; full = None }` — Summary scalars kept verbatim, only `full` cleared. Test `test_demote_full_to_summary_keeps_summary_drops_bars` (test_full.ml:162–185) asserts `get_summary` equals `summary_before` and `get_full` is `None` after demote |
| D4 | Demote Full → Metadata drops both Summary and bars (plan §Resolutions #6) | PASS | bar_loader.ml:321–325: `{ entry with tier = Metadata_tier; summary = None; full = None }`. Test `test_demote_full_to_metadata_drops_both` (test_full.ml:187–211) asserts both `get_summary` and `get_full` return `None`, Metadata survives. Matches the plan's explicit §Resolutions #6 contract ("Full demote lands at Metadata … full drop, rebuild Summary on next promote") |
| D5 | Promote to Full cascades Metadata → Summary → Full (side-effect: Summary scalars available for downstream screening) | PASS | bar_loader.ml:279–289: `_promote_one_to_full` invokes `_promote_one_to_summary` (which itself invokes `_promote_one_to_metadata`) before loading Full bars. Test `test_promote_to_full_auto_promotes_summary` (test_full.ml:117–131) asserts `get_summary` and `get_metadata` both return populated records after a direct `promote ~to_:Full_tier` call. This is the essential invariant for 3f: a Full-tier symbol still exposes RS / stage / ATR to the screener |
| D6 | Promote is idempotent | PASS | `_already_at_or_above` guard at top of each `_promote_one_to_*` (bar_loader.ml:149, 245, 280). Test `test_promote_full_is_idempotent` (test_full.ml:147–160) asserts `get_full` equals prior state after second promote |
| D7 | Demote to Full (degenerate) is a no-op | PASS | bar_loader.ml:330–333 preserves entry as-is for `Full_tier` target. Test `test_demote_full_to_full_is_noop` (test_full.ml:213–226) confirms |
| T1 | Tests cover all 4 stage transitions with distinct scenarios | NA | Strategy-stage-classification behavior not in scope |
| T2 | Tests include a bearish macro scenario that produces zero buy candidates | NA | Same |
| T3 | Stop-loss tests verify trailing behavior over multiple price advances | NA | Same |
| T4 | Tests assert domain outcomes (correct stage, correct signal), not just "no error" | PASS | test_full.ml tests assert concrete invariants: tier state after promote/demote, exact field equality on Summary round-trip, bar-count lower bound after CSV round-trip, stats counts reflect tier occupancy. No "does not raise" tests |

## Quality Score

4 — Good. Implementation cleanly encodes the plan's data-shape contract (Resolutions #6 demote semantics are exact); tests assert the key invariants 3f will depend on (Summary survives Full→Summary demote; Summary/Metadata populated after a direct Full promote). Only reason for not-5 is that this is infrastructure in isolation — the real behavioral validation is deferred to the 3g parity test, which the plan correctly designates as the merge gate for this track.

## Verdict

APPROVED

## Domain concerns for future increments

1. 3g parity test is the real behavioral acceptance gate. 3c is clean, but no amount of tier-plumbing correctness here can prove strategy equivalence — that depends on 3f's shadow-screener adapter faithfully reproducing `Stock_analysis.analyze → Screener.screen` from Summary scalars. Per plan §Risks #1, the parity test must include a borderline stage-1→2 case to catch subtle indicator-computation divergence.
2. `Full.tail_days = 1800` is generous for a weekly-30w-MA strategy but `Summary_compute.default_config.tail_days = 250` (from 3b). When 3f wires the shadow screener path, qc-behavioral should re-verify that the Summary tail is sufficient for every indicator the real screener consumes (notably RS-line baseline and Mansfield normalization) — a Summary promote that silently skips an indicator due to insufficient history would surface in 3g as a parity miss, but could be caught earlier by an explicit windowing check.
3. On Full → Metadata demote, Summary scalars are discarded and will be recomputed on re-promote (§Resolutions #6). On broad scenarios with frequent candidate churn, this recompute cost is a measurement target for 3h's A/B trace comparison, not a correctness concern.

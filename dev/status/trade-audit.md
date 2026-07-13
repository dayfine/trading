# Status: trade-audit

## Last updated: 2026-07-13

## Status
MERGED

All five phased PRs from the plan landed 2026-04-28, plus one cascade-
rejection extension to PR-2:

- PR-1 (#638) — types + collector + persistence (`trade_audit.sexp`).
- PR-2 (#642) — capture sites in `Weinstein_strategy._run_screen` /
  `_screen_universe` / `entries_from_candidates` + exit capture in
  `_on_market_close`, threaded via strategy-side `Audit_recorder` and
  backtest-side `Trade_audit_recorder.of_collector`. Pinned by
  `test_trade_audit_capture` (5 e2e tests) + the existing panel-loader
  golden parity test. PR #647 records a follow-up regression
  investigation that did not reproduce on rebased main.
- PR-2 extension (#646) — cascade-rejection counts via
  `Screener.cascade_diagnostics` (additive). 13 new tests
  (5 screener + 5 trade_audit + 3 e2e capture). Bit-exact behavioural
  parity preserved.
- PR-3 (#643) — markdown renderer.
- PR-4 (#649) — `Trade_rating` heuristics (R-multiple, Weinstein
  conformance, decision-quality cells, hold-time anomaly,
  counterfactual looser stop, 4 behavioral metrics).
- PR-5 (#651) — wired ratings into `release_perf_report` so each
  release-gate run auto-emits `trade_audit.md` + ratings summary.

Future strategy-tuning experiments will *consume* the audit (regime-
aware stops, drawdown circuit breaker, segmentation classifier — see
`backtest-infra.md`) but those reactions are sibling-track work, not
trade-audit work. Sister track `optimal-strategy` (counterfactual
opportunity-cost analysis, plan #650 merged 2026-04-28) is now picking
up the next layer of decision-trail analysis.

## Goal

Capture the strategy's per-trade decision trail (macro / stage / RS /
cascade / alternatives) and per-trade exit context (state at exit,
trigger, MAE/MFE during hold), and emit a markdown audit report that
rates trades on R-multiple + decision-quality. Built so we can answer
*why* a trade fired and *what alternative existed at decision-time*,
not just *what happened*.

Motivated by the `goldens-sp500/sp500-2019-2023` baseline showing the
strategy under-performs buy-and-hold by a wide margin (+18.49% vs
~+95%), 28.57% win rate, 47.64% max drawdown, Sharpe 0.26 — see
`dev/notes/sp500-golden-baseline-2026-04-26.md`.

## Plan

`dev/plans/trade-audit-2026-04-28.md` — full design: data model,
capture-strategy choice (Option A — in-strategy observer, sibling
sexp file), 4–5 PR phasing, ~1,800 LOC total.

## Interface stable
NO

## Open work

(none — track MERGED 2026-04-28)

## Report-side defect fixes (2026-07-13)

Two report-analysis defects found in the 2026-07-13 deduped-record
audit run (`dev/notes/dedup-record-rerun-2026-07-13.md`), fixed in
`trading/trading/backtest/trade_audit_report/`:

- [x] **R6 (plunge-buy avoidance) now evaluates.** Was hard-coded to
      `Not_applicable` (reported `0 / 0` on the 1171-trade run). Root
      cause: the audit record carries no pre-entry bars, so R6 was
      stubbed. Fix: `evaluate_rules` / `rate_all` /
      `weinstein_aggregate_of` take an optional pre-entry-closes lookup;
      `_recent_plunge_verdict` flags a long entered within
      `recent_plunge_proximity_days` of the trough of a
      `>= recent_plunge_min_drop_pct` drawdown inside
      `recent_plunge_lookback_days`. Default (no bar source) keeps R6
      N/A — release_report path unchanged. `trade_audit_report_bin`
      gained `--snapshot-dir` to feed pre-entry daily closes from the
      warehouse (same allow-listed `Bar_reader`/`Daily_panels` pattern
      as `decision_grading`). Verify:
      `dune exec trading/backtest/test/test_trade_audit_ratings.exe`
      (R6 fail/pass/stale/NA/short cases).
- [x] **Decision-quality quartiles by cascade score, not outcome.**
      `decision_quality_matrix_of` bucketed by `r_multiple` (an
      outcome), making Q1 tautologically 100% / Q4 0%. Now takes
      `~audit` and quartiles by `cascade_score` (matches behavioural
      metric (d)). Verify: `test_decision_quality_matrix_by_score`
      (8 synthetic trades → 100/50/0/50).

Dropped from this PR to keep it bounded (separate validation module):

- [ ] **V6 known-false-positive allowlist** — add
      `v6_known_false_positive_pairs` to `check_config` in
      `trading/trading/backtest/validation/lib/validator_row_checks.ml`
      so proven non-twins (ASB/CDX_old, BALL/TAP) are skipped with a
      note. Follow-up.

## Phasing (per plan)

- [x] **PR-1** (#638) — types + collector + persistence.
- [x] **PR-2** (#642) — capture sites in `Weinstein_strategy` + exit
      capture in `_on_market_close`. 5 e2e tests. Bit-equivalence
      pinned by panel-loader golden parity.
- [x] **PR-2 ext** (#646) — `Screener.cascade_diagnostics` cascade-
      rejection counts. 13 new tests.
- [x] **PR-3** (#643) — markdown renderer.
- [x] **PR-4** (#649) — `Trade_rating` heuristics + 4 behavioral
      metrics + Weinstein conformance.
- [x] **PR-5** (#651) — wired into `release_perf_report`.

## Ownership

`feat-backtest` agent — sibling of backtest-infra and backtest-perf.
Consumes `Stop_log` (predecessor pattern), `Trace` (predecessor
pattern), and `Weinstein_strategy` capture surfaces but does not
modify strategy logic itself (audit is observer-only).

## Branch

`docs/trade-audit-plan` for the plan. Implementation branches per
phase: `feat/trade-audit-pr1`, `feat/trade-audit-pr2`, etc.

## Blocked on

Nothing structurally; implementation can begin immediately.

## Decision items (need human or QC sign-off)

1. Capture-strategy choice: plan picks Option A (in-strategy observer,
   sibling sexp file). Alternatives B (simulator event bus) and C
   (post-hoc replay) rejected; rationale in §Approach of the plan.
2. `alternatives_considered` retention: only at screen calls where ≥1
   entry actually fires (avoids ~5K wasted captures over a 5y
   backtest). Cheap to revisit if needed.
3. `counterfactual_looser_stop`: persist forward-N bars at exit time
   (Option A in §Risks item 5) vs renderer reads from data dir
   (Option B). Plan picks A — keeps the renderer's input set bounded
   to `<output_dir>/`. PR-4 implements.

## References

- Plan: `dev/plans/trade-audit-2026-04-28.md`
- Baseline: `dev/notes/sp500-golden-baseline-2026-04-26.md`
- Predecessor patterns:
  - `trading/trading/backtest/lib/stop_log.{ml,mli}` — observer shape
  - `trading/trading/backtest/lib/trace.{ml,mli}` — collector shape
- Capture surfaces:
  - `trading/trading/weinstein/strategy/lib/weinstein_strategy.ml`
    — `_run_screen` (line 393), `_screen_universe` (line 344),
    `entries_from_candidates` (line 202)
  - `trading/analysis/weinstein/screener/lib/screener.{ml,mli}`
- Sibling tracks:
  - `dev/status/backtest-infra.md` — strategy-tuning experiments that
    will *react* to audit findings (regime-aware stops, drawdown
    circuit breaker, segmentation classifier)
  - `dev/status/backtest-perf.md` — release report renderer that may
    consume `trade_audit.md` per PR-5

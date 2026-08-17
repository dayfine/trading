# Status: trade-audit

## Last updated: 2026-08-14

## Status
READY_FOR_REVIEW

### 2026-07-27 — `trades.csv` phantom SHORT / duplicate rows (issue #2059)

Fixed on branch `fix/lh-phantom-short`; full diagnosis in
`dev/status/simulation.md` §2026-07-27 and
`dev/plans/lh-phantom-short-2026-07-27.md`. Two consumer-facing consequences
for anyone reading `trades.csv`:

- [x] **A `SHORT` row can no longer be manufactured from a long-only trade
      stream.** `Metrics.extract_round_trips` dropped the residual of a partial
      exit, so the next closing `Sell` was re-read as a short open. Pre-fix, any
      `trades.csv` from a run containing partial exits may carry phantom SHORT
      rows (with inverted P&L and absurd `days_held`) plus over-stated LONG
      quantities. Re-derive rather than trust archived per-trade forensics —
      longest-hold, worst-loss-%, and short-side attribution are the affected
      statistics.
- [ ] **`position_id` is not a trustworthy grouping key.** `Trade_context`
      resolves it by a 7-calendar-day backward window over audit records for the
      symbol, not by a real position link, so distinct round-trips entered within
      a week of one entry decision all carry that decision's id. Filed in
      `dev/status/simulation.md`; not fixed here.

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

- [ ] **Give `Trade_audit_ratings` the `position_id` join too.** After the
      2026-08-14 report-path fix (§ below) one `trade_audit.md` carries **two
      joins of different fidelity**: the per-trade table is exact (id join),
      while the analysis sections — per-trade ratings, behavioural metrics,
      decision-quality matrix — keep the date-join population. `rate_all`,
      `_exit_winners` and `_quartile_assignments_by_score` in
      `trading/trading/backtest/trade_audit_report/trade_audit_ratings.ml` have
      zero `position_id` references.

      It cannot be a partial fix. `rate_all` joins audit→trade, but the other
      two join *back* from a `rating`, which carries no position id. Giving
      `rate_all` the id join alone newly admits long-gap trades into the ratings
      population, which `_exit_winners` then fails to find by date and silently
      scores at `realized_pct = 0.0` — a missing rating turned into a wrong one.
      Doing it correctly means adding `position_id` to the public `rating` type
      and rewiring all three joins.

      Until it lands, any analysis-section number in a `trade_audit.md` for a
      re-traded symbol is still date-joined and may be misattributed, even
      though the per-trade table above it is exact.

- [ ] **Enforce the "always together" invariant on the cancel pair (R1, from
      qc-behavioral on PR #2357).** `ticket_lifecycle.mli:153` asserts
      `cancel_reason` is "Always `Some` exactly when `ticket_age_weeks_at_cancel`
      is", and `:229` repeats it ("always travel together"), but they are two
      independent `int option` / `string option` fields — nothing in the type
      forbids one being `Some` with the other `None`. The invariant holds today
      only because `Trade_audit._record_cancel`
      (`trading/trading/backtest/lib/trade_audit.ml:231-235`) is the single
      writer and sets both. A second writer would silently break a documented
      guarantee. Fix shape: make the pair one `option` of a record (or a private
      constructor), so the type carries the invariant instead of a docstring.

- [ ] **Pin the cancel-reason closed list with an exhaustiveness test (R2, from
      qc-behavioral on PR #2357).** `trade_audit.mli` documents a closed list of
      "three kinds of cancel" (the two `Entry_ticket_ttl` tokens plus
      `Cancel_handler.portfolio_rejection_reason`). The list is correct at this
      SHA — verified by enumerating the production `CancelEntry {` construction
      sites (`entry_ticket_ttl.ml:17` with exactly two `Some` arms in
      `_cancel_reason_for:38-50`; `cancel_handler.ml:28`) — but no test fails if
      a fourth producer is added, so the docstring silently goes stale. Fix
      shape: a test that asserts the set of reason tokens reachable through
      `record_transitions` equals the documented three.

- [ ] **Fix the broken odoc ref at `cancel_handler.mli:76` (R4, pre-existing,
      spotted by qc-behavioral on PR #2357).** The ref reads
      `{!Weinstein_trading.Entry_ticket_ttl}`, but `Weinstein_trading` is a dune
      *public-name prefix*, not a module — the reference does not resolve. The
      correct form is `{!Weinstein_strategy.Entry_ticket_ttl}`, as used in
      `trade_audit.mli`. Pre-dates PR #2357 and was left out of its scope.

## Report-path `position_id` join (2026-08-14, follow-up to PR #2317)

PR #2317 fixed the **in-process** join: `Trade_context._lookup_audit_for_trade`
prefers an exact `position_id` match and keeps date proximity only as the
fallback. The **report path** re-reads `trades.csv` from disk and did not get
the same fix — two CSV-readback loaders hardcoded `position_id = None`, which
forced their downstream joins back onto the symmetric 7-day nearest-date scan
#2317 retired. On a re-traded symbol that scan attaches a *different*
position's audit record.

Note the report path's fallback is **not** #2317's `stop_first_by_symbol`
mechanism — that is an in-process `Trade_context` map with no report-path
counterpart, and it hands a repeat-traded symbol the *first* trade's trigger
and stops without bound. The report path's fallback is `_find_audit_by_date`:
the nearest audit record for the symbol within ±7 days. Same misattribution
class, different selector, and a materially narrower blast radius — so the
report path's damage profile should not be expected to match #2317's numbers.
(The report's window is also **symmetric** — `Int.abs (Date.diff …)` — where
`Trade_context`'s is one-sided, so the report path can attach a decision dated
*after* the fill. Pre-existing, out of scope here, recorded so it is not lost.)

- [x] **Thread `position_id` through both CSV-readback loaders.** Branch
      `feat/report-path-position-id`.

      New module `trading/trading/backtest/lib/trades_csv_schema.{ml,mli}` —
      the reader-side counterpart to `Trade_context`'s writer-side
      `csv_header_fields` / `csv_row_fields`. Surface:
      `position_id_column_name` (shared with `csv_header_fields` so the two
      cannot drift), abstract `t`, `of_header_line`, `legacy`,
      `position_id_of_cells`. The column index is resolved **by header name**,
      never hardcoded. `Trade_context.csv_header_fields` keeps an append-only
      discipline, which is what lets the positional readers named there pin
      base-column indices — but that is a property of *this* writer, not of the
      format, and it does not make index 19 stable: `position_id` sits *inside*
      the trailing context block (`stop_fill_distance_pct` follows it at 20) and
      got there by insertion ahead of that column. Appending strictly after the
      block is harmless; an insertion **at or ahead of** `position_id` shifts it,
      and a fixed index would then silently read a neighbour.
      `position_id_of_cells` returns `None` (never `Some ""`, never a wrong
      cell) when the header lacks the column, the row is shorter than the
      column index, or the cell is empty; surrounding whitespace on both header
      names and cell values is stripped.

      (It lives in its own module rather than inside `Trade_context` because
      `trade_context.ml` was already at the 300-line file-length limit; per
      `.claude/rules/code-health-discipline.md` the answer is extraction, not
      a limit bump. `trade_context.ml` is back to exactly 300 lines, its only
      change being `"position_id"` → `Trades_csv_schema.position_id_column_name`
      in `csv_header_fields`.)

      - `trading/trading/backtest/trade_audit_report/trade_audit_report.ml` —
        `_trade_metrics_of_strings` takes `~position_id`;
        `_match_post_g2_csv_row` receives the header-resolved value;
        `_match_legacy_csv_row` resolves against `legacy_csv_schema`
        (explicitly `None` — the layout predates the column).
        `_audit_index` became a record carrying both a `by_position_id` map and
        the existing `by_symbol` map; `_find_audit` now prefers the id join and
        falls back to `_find_audit_by_date` (the 7-day scan is **kept**, exactly
        as `Trade_context` keeps its own date path).
      - `trading/trading/backtest/optimal/lib/optimal_run_artefacts.ml` — same
        threading through `_trade_metrics_of_strings` / `_match_post_g2_row` /
        `_match_legacy_row` / `_parse_trade_row` / `_load_trades`.

      Both `KNOWN GAP (PR #2317)` comments are gone; the surviving comments
      describe the fallback's role rather than claiming an open gap.

      Tests (19 new):
      - new `test_trades_csv_schema.ml` (10) — direct pins on the schema module:
        populated cell → `Some`, empty cell → `None` (never `Some ""`), header
        without the column → `None`, row shorter than the index → `None`,
        `legacy` always `None`, a header with an *inserted* column ahead of
        `position_id` still reading the right cell (a fixed-index reader fails
        this one), `position_id_column_name` present exactly once in
        `Trade_context.csv_header_fields`, and three whitespace pins —
        padded header names still resolve, a padded cell value reads stripped,
        a whitespace-only cell reads `None`.
      - `test_trade_audit_report.ml` (+5) — the discriminating misattribution
        fixture: a resting AAPL ticket decided 2020-04-24 (`AAPL-1`, grade A)
        that fills 2020-11-09, with a *second* AAPL decision 2020-11-06
        (`AAPL-2`, grade D) three days from the fill. Date proximity returns D;
        only the id join returns A. Pinned end-to-end through `TAR.load`
        (populated / empty / unknown id / legacy row) and through `TAR.render`.
      - `test_optimal_run_artefacts.ml` (+4) — `RA.load` surfaces
        `trade_metrics.position_id` directly: populated, empty cell, row
        predating the column, legacy layout.

      Verify:
      `dune runtest trading/backtest/test trading/backtest/optimal/test`

      Mutation checks performed (both restored afterwards):
      - reverting `_find_audit` to the date-only path → exactly 2 failures,
        `load: position_id join beats nearer date match` and
        `render: position_id join beats nearer date match` (they read grade D
        instead of A);
      - forcing the parsed cell to `None` in both loaders → exactly 2
        failures, `load: position_id join beats nearer date match` and
        `Optimal_run_artefacts: load reads populated position_id`.

      The two mutations overlap on `load: position_id join beats nearer date
      match`, but each mechanism has an **exclusive** pin — `render: …` fails
      only under the first, `load reads populated position_id` only under the
      second — so neither rests on one over-broad assertion.

      Whitespace mutations (QC rework, both restored):
      - dropping `String.strip` on header names in `of_header_line` → exactly 1
        failure, `header name whitespace is stripped`;
      - dropping `String.strip` on the cell in `_cell_at` → exactly 2 failures,
        `cell whitespace is stripped` and `whitespace only cell reads none`.

      **Residual (what this does *not* close).** The misattribution is closed
      for id-bearing rows **whose id appears in the audit set**. Three
      populations still take the ±7-day date scan and can still inherit another
      position's record: legacy layouts, rows whose cell is empty, and rows
      carrying a well-formed id that no audit record claims (`_find_audit` is
      `Option.bind`, so an unknown id falls through rather than reporting
      nothing — exact parity with `Trade_context._lookup_audit_for_trade`, and
      pinned by `test_load_unknown_position_id_falls_back_to_date`, which
      asserts the *misattributed* grade D as expected behaviour). The analysis
      sections are a fourth, tracked under `## Open work` above.

## Externally-generated exits (2026-07-25, issue #2076)

Remaining half of #2057 (first half — the `trades.csv` / `Stop_log`
sink — fixed by PR #2074, `c9dfb9ba`). Investigated and scoped by
#2074's own PR body: `Backtest.Trade_audit`'s exit-side enrichment
(`Weinstein_strategy.Exit_audit_capture.emit_for_list`, called only
from `weinstein_strategy.ml`'s stops pass) only ever sees exits
`Stops_runner.update` emits. It has NEVER captured:

- margin-driven exits (`margin_call` / `buyin_stress` /
  `maintenance_reduce`, generated by `Trading_simulation.Margin_runner.tick`
  entirely outside the strategy's `on_market_close` call), or
- the other `StrategySignal` exit sources that also bypass
  `Exit_audit_capture` — `stage3_force_exit`, `laggard_rotation`,
  `extension_stop`, `macro_bearish_trim` (pre-existing gap, not
  margin-specific).

- [x] **`Trade_audit.record_transitions` — reason-only external-exit
      capture.** PR: `feat/trade-audit-external-exits` (#2085).
      Design: mirrors `Stop_log.record_transitions` exactly, wired into
      the same `Simulator.dependencies.on_transitions` hook #2074
      added. New type `Trade_audit.external_exit_decision` (`symbol`,
      `exit_date`, `position_id`, `exit_trigger : Stop_log.exit_trigger`
      — no macro/stage/RS, since the observer sits below the Weinstein
      analysis layer and cannot fabricate that context). New field
      `audit_record.external_exit : external_exit_decision option`,
      additive with `[@sexp.option]` so pre-existing `trade_audit.sexp`
      files (no such key) still parse. `record_transitions` fills in
      `external_exit` for any `TriggerExit` whose position has an
      `entry` on record but no enriched `exit_` yet — **enriched always
      wins**, safe by construction because the strategy's own
      `on_market_close` call (and its `Exit_audit_capture` recording)
      always completes before `on_transitions` fires for the same
      simulator step. `Panel_runner._make_simulator` composes
      `Stop_log.record_transitions` and `Trade_audit.record_transitions`
      into the single `on_transitions` closure it wires.
      `TriggerPartialExit` (`harvest_rotate`'s kind) is deliberately
      NOT handled — a partial trim isn't a round-trip close, so it has
      no `exit_decision` / `external_exit_decision` to record; this is
      correct exclusion, not a residual gap.

      **Extra credit landed for free:** the same generic
      `TriggerExit`-keyed path also captures `stage3_force_exit`,
      `laggard_rotation`, `extension_stop`, and `macro_bearish_trim` —
      no per-label special-casing was needed. Pinned by
      `test_record_transitions_captures_any_strategy_signal_label`
      (uses `stage3_force_exit` as the second label alongside
      `margin_call`). `harvest_rotate` remains out of scope (partial
      trim, not applicable to the round-trip model).

      Tests: `trading/trading/backtest/test/test_trade_audit.ml` (+7:
      margin-label capture, generic-label capture, enriched-wins/no-
      overwrite, no-entry-drop, non-TriggerExit-kinds-ignored,
      `external_exit_decision` sexp round-trip, `audit_record`
      round-trip unaffected). New end-to-end file
      `trading/trading/backtest/test/test_trade_audit_external_exits.ml`
      (1 test) mirrors `test_margin_exit_observability.ml`: drives a
      real `Simulator.run` with margin enabled through the exact
      composed `on_transitions` `Panel_runner` wires, asserts
      `Trade_audit.get_audit_records`'s `external_exit` field.

      Verify:
      `dune runtest trading/backtest/test/test_trade_audit.ml trading/backtest/test/test_trade_audit_external_exits.ml`

      Plan: `dev/plans/trade-audit-external-exits-2026-07-25.md`.

      Report-side follow-up DONE 2026-08-04 (PR #2196, closes #2076):
      `_row_of_trade`'s `exit_trigger` column now falls back to
      `external_exit` when `exit_` is `None` (enriched always wins);
      HTML report inherits via `per_trade_row.exit_trigger`. 5 pins in
      `test_trade_audit_report.ml` (external-only → `margin_call`,
      enriched-wins, neither → `—`, generic `stage3_force_exit` label,
      markdown rendering). `trade_audit_ratings.ml` intentionally
      unchanged: R7 needs `stage_at_exit` (unavailable by design →
      `Not_applicable`), MFE/MAE cannot be fed by a reason-only
      record.

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

## Interactive HTML report (2026-07-13)

- [x] **`--html <path>` self-contained interactive report.**
      `trade_audit_report_bin` gained `--html` (alongside `--out`):
      emits a single self-contained HTML file (inline CSS/JS, no
      external requests — renders under a strict CSP) with a KPI tile
      row, a NAV-vs-benchmark log-scale SVG chart with crosshair
      tooltip, a capital-utilization area chart, an end-of-run
      open-positions table, behavioural + Weinstein-conformance +
      decision-quality panels, and a sortable/filterable full-trade
      table. New library
      `trading/trading/backtest/trade_audit_html/`
      (`html_report.{ml,mli}` + `html_template.{ml,mli}`): `render`
      is pure (`data -> string`, template constant with a `/*DATA*/`
      placeholder filled by a hand-emitted JS object literal); `load`
      reuses the markdown path's aggregates (rows, behavioural,
      conformance, decision-quality from `Trade_audit_report.t`) and
      adds only the extra on-disk series (equity_curve.csv,
      open_positions.csv, final_prices.csv, summary KPIs, per-row
      qty/stop_kind from trades.csv). KPI numbers are computed from the
      run data, never hardcoded. Benchmark (`--benchmark-symbol`,
      default SPY) and capital-utilization series need a bar source:
      supplied when `--snapshot-dir` is given, omitted gracefully
      otherwise. Verify:
      `dune exec trading/backtest/test/test_trade_audit_html_report.exe`
      (5 tests: structural invariants, analysis panels, benchmark/util
      present-vs-omitted, symbol JS-escaping). Smoke: `--html` on a
      443-trade run → 91 KB (no snapshot) / 103 KB (with snapshot;
      benchmark + utilization series), `const DATA=` ×1, no placeholder
      residue.

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

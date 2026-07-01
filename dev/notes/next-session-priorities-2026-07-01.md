# Next-session priorities — 2026-07-01

**Supersedes** `next-session-priorities-2026-06-29.md`. Main is green
(tip `a8aabb038` #1797). This session closed the candidate-ranking / tiebreak
thread definitively and re-framed the next lever.

## 2026-07-01 session update — P0 (#8) BUILT + MERGED

The faithfulness decision-audit (P0 below) is **done**: **PR #1799** (merged, main
`c8e4d7333`) + index reconcile **#1800** (`a4393702c`). New `decision-audit` track.
- **Phase 0** — enriched `Trade_audit.alternative_candidate` with decision-time
  features (`stage`, `weeks_advancing`, `rs_value`, `volume_ratio`, `sector_name`,
  `score_components`), sourced in `trade_audit_recorder._alternative_of_event` from
  each near-miss's own `Screener.scored_candidate` (same reads as the funded path).
- **Phase 1** — `trading/trading/backtest/decision_audit/{lib,bin,test}/`:
  `Screen_record.of_audit_records` (group-by-screen, near-miss union/dedup/score-desc,
  inversion flag) + `Report` (funded-vs-near-miss feature roll-up + per-screen md) +
  `decision_audit_bin --audit <sexp> [--out <md>]`. 10 tests. Additive, default-off.
- Gates: qc-structural APPROVED, qc-behavioral APPROVED (5/5), CI green. Fixed a
  status-file-integrity lint miss (`## Interface stable`) before merge. Closed stale
  ci-red #1772.

**RUN ON REAL DATA — DONE (#1803):** `dev/notes/decision-audit-first-real-run-2026-07-01.md`.
Ran the report on fresh enriched data from 3 sp500 smoke windows (bull/crash/recovery,
default config). **Finding: selection is FAITHFUL** — no captured feature separates
funded from cash-rejected near-misses in an exploitable direction (score/volume are
what we already fund on; earliness separates but was already rejected #1793; rs_value
underpowered — ~77% `None`). Confirms the noise-floor grid → the only remaining
entry-side lever is **explicit capacity**, not a better sort. Calibrated as a proxy
screen, not a rejection.

**Invocation (for reruns):** built runner + report exe, then
`TRADING_DATA_DIR=…/trading/test_data ./_build/…/backtest_runner.exe --smoke --csv-mode
--experiment-name <n>` (via `docker exec -d -e TRADING_DATA_DIR=…`; note: env must be
passed with `-e`/inline — `dune exec` and `nohup … &` drop it), then
`decision_audit_bin --audit <window>/trade_audit.sexp --out report.md`.

**Next pickups from the run:** (a) **Phase-2 forward-return counterfactual** — the one
real "usable signal left on the table" test (join near-miss forward returns via
`decision_grading/post_exit`); (b) **RS-coverage harness gap** — ~77% of candidates
carry `rs_value=None` in sp500 windows; investigate before trusting any RS-based read.

--- (original P0 framing follows) ---
The report is BUILT but NOT YET RUN on real data. The payoff question:
*does any captured feature separate funded from cash-rejected near-misses?* Null →
selection is faithful, only lever left is explicit capacity (`project_capacity_
concentration_surface`). Non-null on some axis → a real lever.

## What the PRIOR session delivered (all merged)

- **#1793** — `candidate_ranking = Quality_earliness` (default-off), the 06-29
  forward directive. WF-CV breadth grid (top-500/1000/3000, 2000-2026, 13 folds):
  **REJECT** — Pareto-dominated by the `Alphabetical` baseline in all 3 cells, and
  worse than even RS-primary `Quality`. The freshest breakout is the least-confirmed;
  tilting the scarce funded slots toward it adds risk without return.
- **#1795** — 3 default-off **noise-floor control** tiebreaks (`Reverse_alphabetical`,
  `Symbol_length`, `Hash_order` = FNV-1a pseudo-random). Diagnostic: bracket the
  noise floor of the equal-score tiebreak.
- **#1797** — docs reframe of #1795 + the decision-audit spec, per user feedback.

## The headline finding — the tiebreak / candidate-ranking lever is DEAD, and why

Three independent confirmations now (RS-primary #1788, earliness #1793, noise-floor
#1795) that **no equal-score tiebreak on any entry feature adds return.** The
noise-floor grid is the clincher:

- **No informative sort escapes the noise band** — RS-primary and earliness both sit
  *inside* the scatter of the arbitrary controls (reverse / length / hash), in both
  cells. Sharpe band: top-500 ≈0.073 wide, top-1000 ≈0.278 wide.
- **The "best" arbitrary sort flips by cell** (symbol_length best in top-500,
  alphabetical/RS best in top-1000) → alphabetical's apparent edge is
  **luck-of-the-draw on one path, not signal**. It is not good, it is *unbiased*.
- **The tiebreak is a large, breadth-scaling source of pure selection VARIANCE**
  (±0.07 → ±0.28 Sharpe as breadth doubles). Broad single-tiebreak backtests carry
  hidden selection variance; lean on WF-CV fold distributions, not point estimates.

**Mechanism (answers the user's "when does this matter"):** the cap is always 20
(`max_buy_candidates`), but the binding limit is the **cash/exposure ladder — ~5
fundable slots, ~97% of entry decisions cash-constrained** (06-27 autopsy). Entries
are funded in ranked order, so the tiebreak decides *which ~5 of many tied grade-A
breakouts get the scarce cash*. Execution order matters; that's where it bites.

**Constructive redirect (user, 2026-06-30):** don't rely on alphabetical's accidental
draw. If diversification / long-tail exploration has value, do it **explicitly** via
the **concentration/capacity axis** (`project_capacity_concentration_surface`): fund
*more names at smaller size* → less dependence on which tied names get picked, and
(score is anti-predictive at the top) the lower-ranked "unvisited tail" isn't
systematically worse. Known tradeoff: more names dilutes the fat-tail amplification
bigger positions give (return↑ / DD↑ at higher concentration). An explicit knob with
a measured tradeoff — not a random tiebreak.

## Open / pick up here

1. **[DONE 2026-07-01 — see session update above; report awaits a fresh CSV-mode
   audit run] P0 — the faithfulness decision-audit report (#8).** Spec is on main:
   `dev/plans/per-screen-decision-audit-2026-06-30.md`. Recast per user feedback as
   a **faithfulness audit** (are we capturing + *using* the screener signals soundly)
   — NOT an outcome grader (grading picks by return is WAI-poor; we can't predict the
   future and don't want to overfit). Per weekly screen, compare **funded** vs
   **cash-rejected near-misses** on the *captured features* (score components, RS,
   volume_ratio, weeks_advancing, stage, sector); flag any signal we capture but don't
   fund on (= a lever). **Buildable first step surfaced by the spec: Phase-0 audit
   enrichment** — `alternative_candidate` (`trade_audit.mli:75`) currently stores only
   `{symbol, side, score, grade, reason_skipped}`, so near-misses lack RS/volume/
   earliness; enrich it (the recorder holds the full `scored_candidate` at skip time —
   cheap, additive) so the full feature comparison is possible. Then the report
   (`trading/trading/backtest/decision_audit/` lib + bin + tests). Data caveat:
   snapshot-mode runs don't emit `trade_audit.sexp` — unit-test on synthetic records
   (like `decision_grading`), and for a real smoke-test either regenerate a small
   CSV-mode audit run or wire audit emission into the snapshot runner.
   **User left the go/no-go open** ("build it, or keep refining the design first?").

2. **#1782 live-UX de-dup (unchanged from 06-29).** Live weekly picks are alphabetical-
   within-grade (all grade-A/score-70, cap 20 → only A-tickers; AIT 12/26 H1 weeks). A
   *live-display* RS-led / de-dup ordering has standalone UX value and does NOT touch
   backtest selection (so none of the noise-floor findings constrain it). Distinct from
   the backtest tiebreak, which is dead. Lower priority.

3. **Sector data refresh (#3, 06-29).** `fetch_finviz_sectors.exe` — sectors.csv ~5wk+
   stale, manifest missing ("[sector-data] manifest missing" every ops run). Marginal
   strategy impact. Deferred.

4. **Weekly live-cycle cron (M6.6) still DEFERRED.** No auto-generation; backfill by
   hand in the container (`dev/status/weekly-snapshot.md`).

5. **2026-H1 weekly series** (`dev/weekly-picks/3befbb36b/`, 26 weeks) still on disk,
   uncommitted — optional baseline record.

## Strategic context — where the frontier actually is

Entry-*selection* is exhausted (tiebreak dead; score anti-predictive at top;
winners≈losers at entry). The two live directions, both already partly mapped:
- **Explicit capacity/diversification** (`project_capacity_concentration_surface`) —
  the honest version of "spread the bets"; a knob with a return-vs-DD tradeoff, no free
  Sharpe found yet, but it's the *explicit* lever the noise-floor variance points to.
- **Regime-conditional allocation** — the barbell was deep-verified and **user-declined**
  06-27 (needs a passive SPY sleeve = portfolio construction, not a Weinstein mechanism).
  Standing conclusion: the strategy is a regime-conditional crash-protector, bull-lag
  accepted. Don't re-open without new information.

The faithfulness audit (#8) is the cheap next probe: it either confirms selection is
faithful (expected → the only lever left is explicit capacity) or surfaces a captured-
but-ignored signal (a real lever). Either outcome sharpens the frontier.

## State at handoff

- Main green; tiebreak PRs #1793/#1795/#1797 all merged.
- WF-CV warehouses on disk (gitignored): `dev/data/snapshots/wfcv-top{500,1000,3000}-1998`
  (1998-2026), `weekly-review`.
- New memory: `project_decision_audit_records_directive` (the faithfulness/near-miss
  directive).
- Experiment artifacts: `dev/experiments/{earliness-ranking-wfcv-2026-06-29,
  tiebreak-noise-floor-2026-06-30}/` + ledger entries
  `2026-06-{29-earliness,30-tiebreak-noise-floor}`.
- Container `trading-1-dev` healthy; killed 3 orphaned dune instances mid-session
  (they held a stale `_build/.lock` — watch for recurrence after backgrounded builds).
  Nothing running.

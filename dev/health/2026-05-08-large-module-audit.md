# Large-Module and Large-Function Marker Audit — 2026-05-08

## Summary

- **Total markers found:** 13 files with `@large-module` declarations
- **Markers with review_at:** 0
- **Markers missing review_at:** 13 (100%)
- **Line count trend:** All files are within the 500-line hard limit (range: 322–498 lines)
- **Status:** No files exceed the 500-line limit. All are within acceptable range for their marked justifications.

---

## Audit Details by File

### 1. `trading/trading/simulation/lib/simulator.ml`

- **Current line count:** 445 lines
- **Marker:** `(* @large-module: simulation engine orchestrates strategy dispatch, order execution, and multi-step stepping *)`
- **Has review_at:** No
- **First introduced:** 2026-04-05 (commit e66d6c02)
- **Status:** Within limit; justification remains sound (simulation engine is legitimately complex)
- **Recommendation:** Keep. This module is well-motivated; no growth beyond committed baseline.

---

### 2. `trading/trading/backtest/lib/runner.ml`

- **Current line count:** 486 lines
- **Marker:** `(* @large-module: backtest orchestration covers config-override deep-merge, universe + sector-map resolution, AD-breadth + sector-ETF loading (each gated by hypothesis-testing toggles in [Weinstein_strategy.config]), and ... *)`
- **Has review_at:** No
- **First introduced:** 2026-04-24 (commit 75894433)
- **Status:** Close to 500-line limit (486/500 = 97% utilization)
- **Recommendation:** Monitor. This module is approaching the hard limit. Consider extraction of nested config-override or universe-resolution logic if it grows further.

---

### 3. `trading/trading/portfolio/lib/portfolio.ml`

- **Current line count:** 459 lines
- **Marker:** `(* @large-module: portfolio tracks cash, positions, and trade history with full validation pipeline *)`
- **Has review_at:** No
- **First introduced:** 2026-04-05 (commit e66d6c02)
- **Status:** Comfortable headroom (459/500 = 92% utilization)
- **Recommendation:** Keep. Justification is solid; portfolio state machine is inherently multi-faceted.

---

### 4. `trading/trading/engine/lib/price_path.ml`

- **Current line count:** 498 lines
- **Marker:** `(* @large-module: price path generation covers multiple interpolation modes and order-fill simulation *)`
- **Has review_at:** No
- **First introduced:** 2026-04-05 (commit e66d6c02)
- **Status:** At the hard limit (498/500 = 99.6% utilization); virtually no headroom
- **Recommendation:** Re-evaluate. This file is functionally at the limit. Any future growth (even +2 lines) will trigger a violation. Consider extracting interpolation-mode dispatch or fill simulation helpers into a separate module if new features land.

---

### 5. `trading/trading/strategy/lib/position.ml`

- **Current line count:** 411 lines
- **Marker:** `(* @large-module: position state machine covers entry, partial fills, stop management, and exit transitions *)`
- **Has review_at:** No
- **First introduced:** 2026-04-07 (commit ecbc959f)
- **Status:** Good headroom (411/500 = 82% utilization)
- **Recommendation:** Keep. Multiple state transitions justify the size; room for future stop-management refinements.

---

### 6. `trading/analysis/weinstein/stage/lib/stage.ml`

- **Current line count:** 488 lines
- **Marker:** `(* @large-module: Stage classifier holds two parallel entry points sharing one set of stage-selection helpers — the bar-list [classify] (legacy) and the indicator-callback [classify_with_callbacks] (panel-backed). The ... *)`
- **Has review_at:** No
- **First introduced:** 2026-04-25 (commit c7c2c1b3)
- **Status:** Close to limit (488/500 = 97.6% utilization)
- **Recommendation:** Monitor. Two parallel entry points + shared helpers explain the size. Extraction candidates: consider splitting Stage1/Stage2/Stage3/Stage4 classification into a separate helpers module if the codebase adds Stage4-only analysis paths.

---

### 7. `trading/trading/weinstein/stops/lib/weinstein_stops.ml`

- **Current line count:** 495 lines
- **Marker:** `(* @large-module: stop state machine — initial, trailing, tightened, update *)`
- **Has review_at:** No
- **First introduced:** 2026-04-05 (commit e66d6c02)
- **Status:** Close to limit (495/500 = 99% utilization)
- **Recommendation:** Re-evaluate. State machine transitions are legitimate, but the file is at critical capacity. Flag for extraction of per-state update logic (INITIAL, TRAILING, TIGHTENED as separate modules) if new stop behaviors (e.g., hard floors) are added.

---

### 8. `trading/trading/weinstein/strategy/lib/panel_callbacks.ml`

- **Current line count:** 455 lines
- **Marker:** `(* @large-module: panel-shaped callback constructors for the eight strategy callees (Stage / Rs / Volume / Resistance / Stock_analysis / Sector / Macro / Support_floor) plus PR-D's cache-aware Stage path. Splitting ... *)`
- **Has review_at:** No
- **First introduced:** 2026-04-26 (commit 3f05df10)
- **Status:** Good headroom (455/500 = 91% utilization)
- **Recommendation:** Keep. Eight callees + panel shape naturally drive the size. Monitor for extraction if ninth callback is added (e.g., Liquidity_filter).

---

### 9. `trading/trading/simulation/lib/types/metric_info_registry.ml`

- **Current line count:** 496 lines
- **Marker:** `(* @large-module: per-variant dispatch table for the full metric enum; inherently parallel to the variant list and not splittable further. *)`
- **Has review_at:** No
- **First introduced:** 2026-05-02 (commit d018edb6)
- **Status:** Very close to limit (496/500 = 99.2% utilization)
- **Recommendation:** Re-evaluate. This is a per-variant dispatch table (inherently repetitive but necessary). If metrics grow beyond current enum size, consider a data-driven approach (sexp/CSV config) to reduce boilerplate. Until then, keep as-is but monitor closely.

---

### 10. `trading/analysis/weinstein/screener/lib/screener.ml`

- **Current line count:** 487 lines
- **Marker:** `(* @large-module: screener cascade integrates multiple analysis passes in a single pipeline *)`
- **Has review_at:** No
- **First introduced:** 2026-04-05 (commit e66d6c02)
- **Status:** Close to limit (487/500 = 97.4% utilization)
- **Recommendation:** Monitor. Multiple analysis passes (macro → sector → stock → score) explain the size. Extraction candidate: if a new filter stage (e.g., Liquidity_filter) is added, consider a pipeline abstraction to parameterize the cascade.

---

### 11. `trading/analysis/weinstein/stock_analysis/lib/stock_analysis.ml`

- **Current line count:** 412 lines
- **Marker:** `(* @large-module: Stock_analysis holds two parallel entry points sharing the same Stage / RS / Volume / Resistance composition — the bar-list [analyze] (legacy) and the indicator-callback [analyze_with_callbacks] (panel-backed). ... *)`
- **Has review_at:** No
- **First introduced:** 2026-04-25 (commit 18d73a96)
- **Status:** Good headroom (412/500 = 82.4% utilization)
- **Recommendation:** Keep. Two parallel entry points + four-way composition (Stage/RS/Volume/Resistance) justify the size.

---

### 12. `trading/trading/backtest/all_eligible/lib/all_eligible_runner.ml`

- **Current line count:** 495 lines
- **Marker:** `(* @large-module: pipeline orchestrator covers CLI parsing (~80 LOC), out-dir + config resolution, snapshot construction, Friday calendar, per-symbol weekly analysis, scan + score over the panel, forward-walk outlooks, ... *)`
- **Has review_at:** No
- **First introduced:** 2026-05-07 (commit bf060043)
- **Status:** Very close to limit (495/500 = 99% utilization)
- **Recommendation:** Re-evaluate. Multiple pipeline stages (CLI, config, snapshot, analysis, scoring, outlook) packed together. Extraction candidates: split CLI parsing (~80 LOC) + config resolution into a `Config` module, and per-symbol analysis into an `Analysis` module. This would free ~150 LOC headroom.

---

### 13. `trading/analysis/technical/trend/lib/segmentation.ml`

- **Current line count:** 322 lines
- **Marker:** `(* @large-module: trend segmentation integrates regression, peak/trough detection, and stage mapping *)`
- **Has review_at:** No
- **First introduced:** 2026-04-05 (commit e66d6c02)
- **Status:** Comfortable headroom (322/500 = 64.4% utilization)
- **Recommendation:** Keep. Regression + peak/trough + mapping is well-scoped; good buffer for future refinements.

---

## Summary Statistics

| Metric | Count |
|--------|-------|
| Total @large-module markers | 13 |
| At/near capacity (≥95% of 500) | 6 files |
| At critical capacity (≥99%) | 3 files |
| With review_at clauses | 0 |
| Exceeding 500 lines | 0 |

---

## Capacity Summary by Utilization Band

### Critical Capacity (≥99%: 1–2 lines headroom)
- `trading/trading/engine/lib/price_path.ml` (498/500 = 99.6%)
- `trading/trading/weinstein/stops/lib/weinstein_stops.ml` (495/500 = 99%)
- `trading/trading/simulation/lib/types/metric_info_registry.ml` (496/500 = 99.2%)

### High Capacity (95–98%: 10–25 lines headroom)
- `trading/trading/backtest/lib/runner.ml` (486/500 = 97.2%)
- `trading/analysis/weinstein/stage/lib/stage.ml` (488/500 = 97.6%)
- `trading/analysis/weinstein/screener/lib/screener.ml` (487/500 = 97.4%)

### Moderate Capacity (85–94%: 30–75 lines headroom)
- `trading/trading/simulation/lib/simulator.ml` (445/500 = 89%)
- `trading/trading/portfolio/lib/portfolio.ml` (459/500 = 91.8%)
- `trading/trading/strategy/lib/position.ml` (411/500 = 82.2%)
- `trading/trading/weinstein/strategy/lib/panel_callbacks.ml` (455/500 = 91%)
- `trading/analysis/weinstein/stock_analysis/lib/stock_analysis.ml` (412/500 = 82.4%)

### Comfortable Capacity (<85%: ≥75 lines headroom)
- `trading/trading/backtest/all_eligible/lib/all_eligible_runner.ml` (495/500 = 99%) — *See note below*
- `trading/analysis/technical/trend/lib/segmentation.ml` (322/500 = 64.4%)

**Note:** `all_eligible_runner.ml` is listed in "Comfortable" by line count but at critical capacity; see recommendation for extraction.

---

## Recommendations

### Immediate Action (next 1–2 sessions)
1. **Extract from `price_path.ml` (498 lines, 99.6% full):** Move interpolation-mode dispatch or fill-simulation helpers to a separate module. This file has no headroom for new features.

2. **Refactor `weinstein_stops.ml` (495 lines, 99% full):** Consider splitting per-state logic (INITIAL, TRAILING, TIGHTENED) into submodules. Current state-machine transitions are well-justified, but architectural headroom is critical.

3. **Review `all_eligible_runner.ml` (495 lines, 99% full):** Extract CLI parsing (~80 LOC) + config resolution and per-symbol analysis. Original commit is very recent (2026-05-07); extraction may reveal modularity opportunities missed in initial design.

### Monitoring (within 2 weeks)
1. **Stage-classifier (`stage.ml`, 488/500):** Two entry points + four stage variants — monitor if third entry point or new stage analysis is planned.

2. **Screener cascade (`screener.ml`, 487/500):** Monitor for new filter stages; consider abstracting the pipeline if >1 new filter is added.

3. **Metric registry (`metric_info_registry.ml`, 496/500):** Monitor metric enum growth; if >5 new metrics are added, migrate to data-driven (sexp/CSV) dispatch table.

### No Action Required
- `segmentation.ml` has ample room (64.4% utilization) and stable justification.
- `stock_analysis.ml`, `panel_callbacks.ml`, `position.ml`, `portfolio.ml`, `simulator.ml` all have moderate-to-good headroom and clear architectural motivation.

---

## Design Principle Note

None of these 13 files currently have `review_at: <milestone>` clauses in their markers. The absence of scheduled review dates makes it difficult to auto-detect staleness. Future markers should include a target review date (e.g., `review_at: M5` or `review_at: 2026-08-01`) tied to the milestone when the file was expected to stabilize. This enables automated warnings when review dates pass.

Example improved marker format:
```ocaml
(* @large-module: [reason] — review_at: M5 *)
```

---

## Audit Methodology

- **Source:** All `.ml` files in `/trading/` directory matched against `(* @large-module:` and `(* @large-function:` patterns
- **Line count:** `wc -l` on committed code (excludes `_build/`)
- **Git history:** `git log --follow -S "@large"` to find first-introduced commit + date
- **Review_at detection:** grep for `review_at` within marker comment text
- **Date:** 2026-05-08

No source files were modified during this audit.

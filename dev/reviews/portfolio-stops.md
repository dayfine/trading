# QC Structural Review: portfolio-stops

Date: 2026-04-07
Reviewer: qc-structural
Branch reviewed: feat/portfolio-stops-order-gen
Merge base: main@origin (fe02441e)

## Scope

This review covers the commit unique to `feat/portfolio-stops-order-gen` relative to main@origin:

1. `ed92811b` portfolio-stops/order-gen: Add Weinstein order generation module (9 tests)

New files added:
- `analysis/weinstein/order_gen/lib/order_gen.mli`
- `analysis/weinstein/order_gen/lib/order_gen.ml`
- `analysis/weinstein/order_gen/lib/dune`
- `analysis/weinstein/order_gen/test/test_order_gen.ml`
- `analysis/weinstein/order_gen/test/dune`

---

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune fmt --check | PASS | No formatting violations in order_gen files |
| H2 | dune build | PASS | All modules compile cleanly |
| H3 | dune runtest | PASS | 9/9 order_gen tests pass; all other suites pass |
| P1 | Functions <= 50 lines | PASS | Verified by fn_length linter (H3) |
| P2 | No magic numbers | PASS | No bare numeric literals in order_gen.ml; all thresholds are config-routed or named constants |
| P3 | All configurable thresholds/periods/weights in config record | PASS | order_gen.config contains all tunable params (stop_limit_buffer_pct, grade_weights) |
| P4 | .mli files cover all public symbols | PASS | order_gen.mli exports t, config, default_config, generate, show, equal |
| P5 | Internal helpers prefixed with _ | PASS | _make_entry_order, _make_stop_order, _grade_candidate all prefixed |
| P6 | Tests use the matchers library | PASS | test_order_gen.ml opens Matchers and uses assert_that throughout |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No modifications to any of these modules; all new code in weinstein/order_gen/ namespace |
| A2 | No imports from analysis/ into trading/trading/ | FLAG | order_gen is in analysis/weinstein/; it imports from trading/weinstein/ (Weinstein_stops). This crosses the analysis→trading direction — permitted by existing arch_layer exception for weinstein/ bridging modules. Non-blocking. |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | Only new files added; no existing module files modified |

---

## Verdict

APPROVED

---

# QC Behavioral Review: portfolio-stops

Date: 2026-04-07
Reviewer: qc-behavioral
Branch reviewed: feat/portfolio-stops-order-gen

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| B1 | Stage-appropriate entries only | PASS | generate only produces entry orders for Stage2 candidates (grade >= threshold); Stage 3/4 candidates produce no entry orders |
| B2 | Stop placement follows Weinstein rules | PASS | StopLimit entry orders placed below support by stop_limit_buffer_pct; consistent with eng-design-3 spec |
| B3 | Position sizing uses portfolio risk limits | PASS | generate takes position_size input from caller (Portfolio_risk.compute_position_size); does not hardcode sizing |
| B4 | Rationale field populated | PASS | All generated orders carry rationale string summarizing grade and stage |
| B5 | Short-side entries not generated for long-only mode | PASS | config.allow_short = false skips short candidate entries |
| B6 | order_gen builds alongside, not replacing, existing order_generator | FLAG | order_gen.ml imports Weinstein_screener types (scored_candidate). When feat/screener merges, the import path may need adjustment. Non-blocking — noted in Next Steps. |

---

## Verdict

APPROVED

---

## Combined Result

overall_qc: APPROVED
Both structural and behavioral QC passed on 2026-04-07.
Feature is in Integration Queue — ready to merge to main pending human decision.

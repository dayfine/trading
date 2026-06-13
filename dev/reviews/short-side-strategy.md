Reviewed SHA: 421af10704d413aeaa168e122bf9d6117f5c063e

# QC — short-side-strategy (PR #1560, MERGED 2026-06-13 08:50Z)

NOTE: PR #1560 was self-merged by the maintainer at 08:50Z while this QC pipeline
was running. The orchestrator's QC (below) APPROVED — verdict agrees with the merge.
Review comment posted to the PR (review id 4491197828). Audit:
dev/audit/2026-06-13-short-side-strategy.json.

## Structural QC — APPROVED (quality 5)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | exit 0 |
| H2 | dune build | PASS | exit 0 |
| H3 | dune runtest | PASS | exit 0; 6 new short_side_gate tests + suite green |
| P1 | fn_length | PASS | |
| P2 | magic numbers | PASS | |
| P3 | config completeness | PASS | combine takes enable_short_side + short_min_price from config |
| P4 | .mli coverage | PASS | new short_side_gate.mli covers public surface |
| P5 | helper prefix | PASS | |
| P6 | test-patterns | PASS | assert_that + matchers; no anti-patterns |
| A1 | core-module FLAG | FLAG | weinstein_strategy_screening.ml inline guard -> Short_side_gate.combine; routed to behavioral; bit-identical extraction |
| A2 | analysis->trading import | PASS | in-tree micro-lib |
| A3 | unnecessary mods | PASS | only screening seam + dune/test touched (fold_health deltas are behind-state phantom) |

## Behavioral QC — APPROVED (quality 5)

CP1–CP4 PASS: every .mli + PR-body claim pinned. Honest-suppression contract pinned at
candidate layer (test_disabled_drops_all_shorts) AND end-to-end
(test_disabled_suppresses_short_transitions_e2e on the SAME bear fixture the paired
enabled test proves emits a Short -> non-vacuous). W1 spine intact; W3/R1 no-op default
(enable_short_side=true, short_min_price=0.0 bit-identical to prior inline concat; no
golden re-pin); R3 no default flipped. Domain S/L/C/T rows NA/PASS (refactor of candidate
assembly only).

## Verdict

overall_qc: APPROVED
structural_qc: APPROVED
behavioral_qc: APPROVED

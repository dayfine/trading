Reviewed SHA: 64610f8f10517eb1457692dedbe38ed3d78d1838

## Behavioral QC — resistance-v2 (PR #1997, virgin-crossing re-admission lever)

Weinstein-domain PR (resistance/screening entry lever). Authority: `docs/design/weinstein-book-reference.md` §Buy Criteria / §Resistance-Supply grading (A+ Virgin territory, line 162/169: a new 10-year high — 520 weeks — is the strongest buy signal). Structural QC APPROVED (proceeded). All touched test dirs pass under `dev/lib/run-in-env.sh dune runtest` (resistance 20+11, stock_analysis 32+3, walk_forward variant_matrix 19, backtest hypothesis-overrides 22).

> Note: `dev/reviews/resistance-v2-pr1997.md` (the structural review file the dispatch referenced) was not present on branch `pr-1997`; structural APPROVED was taken from the dispatch. This behavioral section is authoritative for the behavioral gate regardless.

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial `.mli` docstring claim has an identified pinning test | PASS | `Resistance_supply.is_virgin` (finite-guarded `>= max_high_520w`, ties inclusive, bit-equal to `analyze`'s `Virgin_territory` branch) → `test_is_virgin_predicate` (tie/at→true, below→false, nan→false) + `test_is_virgin_agrees_with_analyze`. `Stock_analysis_supply.results` (virgin_readmission = armed ∧ sketch ∧ breakout ∧ virgin; independent of `overhead_supply`) → the 4 compute-path tests; independence is load-bearing because `armed_readmission_cfg` inherits `overhead_supply = None`. `is_breakout_candidate` re-admission arm (Stage-2 + virgin bypasses only the staleness cut) → `test_stale_virgin_readmitted_only_when_armed`. |
| CP2 | Each PR-body "Tests" claim has a committed test | PASS | Every bullet maps: is_virgin predicate + agreement (`test_is_virgin_predicate`, `test_is_virgin_agrees_with_analyze`); arm stale-only-when-armed + fresh-unaffected (`test_stale_virgin_readmitted_only_when_armed`, `test_fresh_candidate_unaffected_by_readmission_flag`); compute path 4 cases (`test_readmission_true_when_armed_and_virgin`, `..._false_when_armed_and_not_virgin`, `..._false_when_sketch_absent`, `..._false_when_config_off`); back-compat parse + override + matrix-axis (`test_strategy_config_parses_with_virgin_readmission_absent`, `test_override_virgin_crossing_readmission`, `test_virgin_crossing_readmission_flag_axis_expands`). No advertised-but-missing test. |
| CP3 | Pass-through / identity tests pin identity, not just size | PASS | The two aggregation tests use `List.count … (equal_to N)` (agreement-with-analyze count=3; v1 parity agreements=len) — element-level boolean pinning, not a bare `size_is`. Conforms to test-patterns P6 sub-rule 1. |
| CP4 | Each guard named in a docstring has a test exercising the guarded scenario | PASS | No-fabrication guards fully covered: sketch absent → `test_readmission_false_when_sketch_absent`; non-finite sketch → `test_is_virgin_predicate` nan case. Observation (non-blocking): the "volume + RS gates still apply to all arms" claim has no *virgin-arm-specific* no-volume rejection test — but `volume_ok`/`rs_ok` are shared top-level conjuncts (`stage_ok && volume_ok && rs_ok`), so bypass is structurally impossible and the pre-existing `test_breakout_candidate_false_when_no_volume_confirmation` pins the gate. A virgin+no-volume case would be redundant defense-in-depth, not a coverage hole. |

### Behavioral Checklist (Weinstein domain)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification strategy-agnostic | NA | No core Portfolio/Orders/Position/Engine module touched; all changes in `analysis/weinstein/*` + strategy config threading. |
| S1 | Stage 1 definition | NA | No stage-classification change. |
| S2 | Stage 2 definition | NA | Stage detection untouched; lever reads the existing `Stage2` verdict only. |
| S3 | Stage 3 definition | NA | |
| S4 | Stage 4 definition | NA | |
| S5 | Buy only in Stage 2, on breakout above resistance with volume | PASS | `_virgin_readmission_arm` matches `Stage2 _` only; a virgin crossing (price ≥ 520-week max) IS a breakout above all overhead resistance — the book's A+ "new high ground" entry (weinstein-book-reference.md §Buy Criteria, line 162/169). Volume confirmation preserved via the shared `volume_ok` conjunct. |
| S6 | No buy signals in Stage 1/3/4 | PASS | Arm returns `false` for any non-`Stage2` stage; even a fabricated `virgin_readmission=true` on a non-Stage2 name cannot admit (stage gate is at the arm). |
| L1–L4 | Stop rules / state machine | NA | Stops untouched. |
| C1 | Screener cascade order | NA | Cascade unchanged; only `_stock_analysis_config_for` threads the flag. |
| C2 | Bearish macro gate unconditional | NA | Macro gate untouched (lever widens Stage-2 admission only, downstream of macro/sector gates). |
| C3 | Sector RS vs market | NA | |
| T1 | Tests cover stage transitions | NA | Not a stage-transition feature. |
| T2 | Bearish-macro → zero-buys test | NA | |
| T3 | Stop trailing tests | NA | |
| T4 | Tests assert domain outcomes, not just "no error" | PASS | Every new test asserts the admission/eligibility boolean or the virgin verdict — real domain outcomes, no bare `is_ok`. |

### Weinstein-faithful-core (W1/W2) + experiment-flag-discipline (R1/R2/R3)

- **W1 spine intact** PASS — buy-only-in-Stage-2 (arm gated), breakout + volume confirmation (shared `volume_ok`), macro/sector gates + stops untouched. The lever only widens *which* Stage-2 names clear the `early_stage2_max_weeks` staleness cut; it does not create entries outside Stage 2, nor drop volume.
- **W2 dial, config-expressed** PASS — a documented dial (new-high-ground entry timing), realized as a real top-level `bool` config field, `.mli` cites weinstein-book-reference.md §Buy Criteria.
- **R1 default-off / bit-identical** PASS — `[@sexp.default false]` across `Stock_analysis.config`, `Weinstein_strategy_config.config`, `Weinstein_strategy.config`; `default_config` sets `false` in all three. Pinned by `test_virgin_crossing_readmission_defaults_off`, `test_readmission_false_when_config_off` (virgin sketch present but flag off → false), and back-compat parse (field-absent → false).
- **R2 searchable** PASS — resolves through `Overlay_validator` (`test_override_virgin_crossing_readmission`) and expands as a `Variant_matrix` `(flag …)` axis (`test_virgin_crossing_readmission_flag_axis_expands`).
- **R3 no default-on without ACCEPT** PASS/NA — default stays off; PR flips no default. Promotion deferred to its own WF-CV / confirmation grid per the PR body and status file.

## Quality Score

5 — Reference-quality default-off lever: single-source-of-truth `is_virgin` predicate with an explicit agreement-with-`analyze` test, no-fabrication guards pinned on both absent and non-finite sketches, clean flag/field/arm separation pinned independently, full R1 (default-off + back-compat parse) and R2 (override + matrix-axis) coverage, and book-faithful spine. The one absent virgin-arm+no-volume test is structurally moot (shared `volume_ok` conjunct).

## Verdict

APPROVED

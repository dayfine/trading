Reviewed SHA: a78848a9bc7998124874ef3993e6ebfe211fcd6b

## Structural QC — resistance-insufficient-history (PR #1941)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | exit 0; fmt_check.sh "OK: all .ml/.mli files are correctly formatted" |
| H2 | dune build | PASS | exit 0 (workspace root /__w/trading/trading/trading, dune-workspace spans analysis + trading subtrees) |
| H3 | dune runtest | PASS | exit 0; magic-numbers linter OK, fn/nesting/mli linters clean. `find: ... No such file or directory` in output is the known sandbox-race infra flake (not a `^FAIL:` line), exit code 0 |
| P1 | Functions <= 50 lines (linter) | PASS | fn_length linter passed as part of H3 |
| P2 | No magic numbers (linter) | PASS | linter_magic_numbers.sh "OK: no magic numbers found in lib/ files" |
| P3 | Config completeness | PASS | New tunable `min_history_bars : int` added as a `Resistance.config` field (default 0), not a hardcoded literal. Support reuses `Resistance.config` byte-for-byte so it inherits the field with no separate config change. Test literals (52/100/5) are test data |
| P4 | Public-symbol export hygiene (linter) | PASS | mli-coverage linter passed as part of H3; new variant + config field documented in weinstein_types.mli and resistance.mli |
| P5 | Internal helpers prefixed per convention | PASS | No new public helpers; existing `_classify_quality` / `_quality_for_valid_input` reused |
| P6 | Tests conform to test-patterns.md | PASS | 3 test files in diff (test_resistance.ml, test_support.ml, test_screener.ml). All three sub-rules clean: no `List.exists ... equal_to bool`, no `let _ = ... on_market_close/.run`, no `Error -> assert_failure`. Added tests use single `assert_that` per value composed with `all_of`/`field`/`is_some_and`/`size_is`/`gt Int_ord`/`ge Float_ord` |
| A1 | Core module modifications (portfolio/orders/position/strategy/engine) | PASS | No core-module files touched. Changes are in analysis/weinstein/{types,resistance,support} + a backtest feature list + tests |
| A2 | No new analysis imports into trading/trading/ outside backtest exception | PASS | No dune files changed; feature_matrix.ml (under trading/trading/backtest/) only adds a category string, introduces no new cross-layer import |
| A3 | No unnecessary modifications to existing modules | PASS | All 10 files (per gh pr view file list) are cohesive to the labeling fix: new variant, guard in resistance+support, category list, tests, status doc. No cross-feature drift |

### Experiment-flag discipline (experiment-flag-discipline.md)

- **R1 (default-off on merge):** PASS. `min_history_bars` defaults to `0`, explicitly "off by default: bit-identical to the pre-field mapper". Dedicated parity tests (`test_short_history_default_still_virgin`, `test_parity_insufficient_history`) pin that the default config still yields `Virgin_territory` and matches the callback path.
- **R2 (searchable / axis):** PASS-in-spirit. The knob is a real `Resistance.config` field (not a hardcoded constant), which is the substance of R2. It is a low-level analysis-config field, not yet wired as a top-level `Weinstein_strategy.config` `Variant_matrix` axis — acceptable while default-off; arming would be the follow-up that adds axis wiring (author notes arming is a separate decision).
- **R3 (promotion needs verdict):** NA. No default is flipped; the no-op value (0) is unchanged, so no ledger ACCEPT citation is required.

## Verdict

APPROVED

No blockers. Purely a labeling correction (new `Insufficient_history` overhead_quality variant + default-off `min_history_bars` guard). Default-off keeps behaviour bit-identical; parity tests confirm; new variant scores 0 in both screener scoring catch-alls (pinned by 2 new screener tests). All three gates green.

---

Reviewed SHA: a78848a9bc7998124874ef3993e6ebfe211fcd6b

## Behavioral QC — resistance-insufficient-history (PR #1941)

This PR touches Weinstein domain logic (overhead-resistance mapping feeds the
screener), so both the generic Contract Pinning Checklist and the domain rows
apply. It is a labeling-correctness fix: a starved history window (e.g. 52 bars
against the 520-bar virgin default) was previously mislabeled `Virgin_territory`
(the book's A+ "most explosive" bullish grade), a false positive claim. The PR
adds an `Insufficient_history` variant + a default-off `min_history_bars`
`Resistance.config` knob that degrades the grade only when armed.

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial .mli claim has an identified pinning test | PASS | (a) resistance.mli "`n_bars < min_history_bars` ⇒ `Insufficient_history`, virgin/zone classification skipped, `zones_above` still reported" → `test_short_history_armed_insufficient` (52<100 ⇒ Insufficient) + `test_insufficient_history_zones_still_reported` (quality=Insufficient AND zones_above size 1 AND nearest_zone populated). (b) resistance.mli "default 0 ⇒ branch never fires, bit-identical" → `test_short_history_default_still_virgin` (default cfg on same starved window ⇒ Virgin_territory) + `test_parity_insufficient_history`. (c) weinstein_types.mli "`Insufficient_history` distinct from `Virgin_territory`; consumers must NOT treat as virgin" → `test_insufficient_history_scores_zero_long`/`_short` (scores 0, strictly below Virgin/Clean). (d) support.mli "reuses Resistance.config byte-for-byte" → support tests exercise the shared `min_history_bars` field on the support direction. |
| CP2 | Each PR-body "what it does / test" claim has a committed test | PASS | Claims traced to tests: "analyze/analyze_with_callbacks emit Insufficient_history when armed" → `test_short_history_armed_insufficient` (via `analyze`, which delegates to `analyze_with_callbacks`, resistance.ml:228-230). "observed zones_above still reported" → `test_insufficient_history_zones_still_reported`. "Default 0 bit-identical (no golden moves)" → `test_short_history_default_still_virgin` + `test_parity_insufficient_history`. "Consumer scores Insufficient_history at 0 via catch-all" → `test_insufficient_history_scores_zero_long`/`_short`. Support mirror ("default-off bit-identical, armed starved ⇒ Insufficient, armed sufficient ⇒ normal grade") → three support tests present. All advertised tests exist and pass (`dune runtest` exit 0 on resistance+support+screener). |
| CP3 | Identity/parity tests pin whole-value identity, not just size | PASS | Parity uses `result_is_bit_identical bar_result` (whole-record equality between the two entry points), not `size_is`. The default-off parity claim is pinned by domain-outcome equality (`equal_to Virgin_territory`) on the exact starved window that arming would flip. `size_is 1` appears only in `test_insufficient_history_zones_still_reported`, which is a "zones still populated" assertion composed with quality + nearest_zone checks — not a pass-through identity test, so no CP3 concern. |
| CP4 | Each explicit guard docstring has a test exercising the guarded scenario | PASS | Guard docstring "starved history can't support any grade (in particular a false Virgin_territory)" → the guarded-against scenario (52<100 armed) is exercised on both directions (`test_short_history_armed_insufficient` resistance + support). The off-path (default 0 never fires) is exercised too. The consumer guard "must NOT treat as virgin" was the CP4 gap flagged in rework iteration 2 and is now pinned by the two screener catch-all tests (Insufficient == no-data == 0, strictly below Virgin/Clean). |

### Behavioral Checklist (domain rows)

| # | Check | Status | Notes (authority) |
|---|-------|--------|--------------------|
| A1 | Core-module change is strategy-agnostic | NA | qc-structural did not FLAG A1; no core module (portfolio/orders/position/strategy/engine) modified. |
| S1 | Stage 1 definition matches book | NA | Stage classification untouched. |
| S2 | Stage 2 definition matches book | NA | Untouched. |
| S3 | Stage 3 definition matches book | NA | Untouched. |
| S4 | Stage 4 definition matches book | NA | Untouched. |
| S5 | Buy criteria (Stage 2, breakout + volume) | NA | Buy gate untouched; this only affects an overhead-quality label that feeds a scoring bonus. |
| S6 | No buy signals in Stage 1/3/4 | NA | Untouched. |
| L1–L4 | Stop-loss rules / state machine | NA | Stops not in scope. |
| C1 | Screener cascade order (macro → sector → scoring → ranking) | PASS | Cascade order unchanged; the change is confined to the resistance-signal contribution inside individual scoring (`_resistance_signal`/`_support_signal`, screener_scoring.ml:146-171). eng-design-2-screener-analysis.md §Cascade. |
| C2 | Bearish macro blocks all buys | NA | Macro gate untouched. |
| C3 | Sector RS vs market | NA | Sector analysis untouched. |
| Overhead-supply (§4.3) | `Insufficient_history` labeling is faithful to book's Virgin/A+ definition | PASS | weinstein-book-reference.md §4.3: "A+ (Virgin territory): Stock has never traded above this price, or hasn't in 10+ years... Most explosive potential." Virgin is a *positive* claim requiring a deep lookback. A 52-bar window cannot substantiate "never / 10+ years", so grading it A+ is a false bullish signal. Degrading to `Insufficient_history` (which scores 0 in the consumer, neither A+ credit nor bearish) is a faithful correction — it withholds the explosive-potential credit rather than fabricating it. Distinct from Clean/Moderate/Heavy grades (§4.3 A/B/C), which stay reachable when history is sufficient (`test_sufficient_history_armed_grades_normally` ⇒ Heavy). |
| T1 | Tests cover the 4 stage transitions | NA | No stage logic in this PR. |
| T2 | Bearish-macro ⇒ zero buy candidates test | NA | Macro gate not touched. |
| T3 | Stop-loss trailing tests | NA | No stops. |
| T4 | Tests assert domain outcomes, not just "no error" | PASS | Every added test asserts a concrete domain outcome: exact `overhead_quality` variant (Virgin/Insufficient/Heavy), zones_above populated, and consumer score ordering (Insufficient == no-data, strictly < Virgin/Clean). No "runs without error" assertions. |

### Weinstein-faithful spine (weinstein-faithful-core.md)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| W1 | Spine intact (no change to buy-only-Stage-2, breakout-with-volume, macro/sector gate, stops, RS selection) | PASS | The change lives entirely in the overhead-resistance *quality label* and its scoring contribution. It does not alter stage classification, the Stage-2 buy gate, volume confirmation, the macro/sector gates, stop placement, or RS ranking. If anything it *strengthens* faithfulness to §4.3 by not awarding the A+ virgin bonus on evidence too thin to support it. |
| W2 | Adaptation is a documented dial, config-expressed, book-justified | PASS | `min_history_bars` is a real `Resistance.config` field (default 0 = pre-existing no-op), not a hardcoded constant, so it routes through config and is arm-able as a search axis (structural QC R2). It is a data-sufficiency threshold on the *existing* virgin-territory determination — a faithful adaptation of the book's own "10+ years" deep-lookback requirement (§4.3), not a new mechanism. It does not over-reach: it only withholds a grade on starved windows (defaults off), and the author explicitly scopes *arming* it as a separate decision. |

### Consistency with system structure

The fix aligns with the post-run validation harness check V7 (`Validator_bar_checks`),
which pins the same "Virgin_territory on too little history" defect from the
trade-record side (per resistance.mli and the PR body). Correcting it at the
mapper source is the complementary, upstream fix — consistent, not contradictory.

## Quality Score

5 — Exemplary correctness fix: closes a real false-bullish-signal defect (§4.3), lands strictly default-off/bit-identical with parity tests, and every .mli/PR claim (including the consumer catch-all and the support-side mirror) is pinned by a domain-outcome test. Could serve as a reference for a Weinstein-faithful, experiment-disciplined labeling correction.

## Verdict

APPROVED

All applicable CP1–CP4, domain, and W1/W2 rows PASS; no FAILs. Default-off keeps
`main` behaviourally identical (parity + default-config tests), the new
`Insufficient_history` grade is faithful to the book's Virgin/A+ definition, and
the spine is untouched. No NEEDS_REWORK items.

## Behavioral QC — resistance-insufficient-history (PR #1941)

Default-off / bit-identical labeling correction: starved history window previously
mislabeled Virgin_territory (book A+ bullish) now → Insufficient_history (scores 0).

| # | Check | Status |
|---|-------|--------|
| CP1 | .mli claims pinned (Insufficient_history armed; default 0 bit-identical; consumer must-not-treat-as-virgin) | PASS |
| CP2 | PR-body claims each have committed tests | PASS |
| CP3 | Parity pins whole-value (result_is_bit_identical), not size | PASS |
| CP4 | Guard "starved history ⇒ not false Virgin" + consumer catch-all pinned | PASS |
| C1 | Screener cascade order unchanged | PASS |
| Overhead-supply §4.3 | Insufficient_history faithful to Virgin/A+ definition | PASS |
| T4 | Tests assert domain outcomes (exact overhead_quality variant), not "no error" | PASS |
| W1 | Spine intact (no change to Stage-2 buy gate/volume/macro/sector/stops/RS) | PASS |
| W2 | Adaptation is a config-expressed dial (min_history_bars, default 0), book-justified | PASS |

dune build/runtest exit 0 on resistance+support+screener. Consumer catch-all routes
Insufficient_history to score 0 (strictly below Virgin/Clean), pinned by screener tests.

## Quality Score

5 — Exemplary Weinstein-faithful, experiment-disciplined labeling correction; closes a
real false-bullish-signal defect (§4.3), default-off/bit-identical with parity tests.

## Verdict

APPROVED

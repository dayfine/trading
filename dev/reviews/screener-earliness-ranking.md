Reviewed SHA: c60b51047c838322787f01f038737596f811718d

## Structural QC — screener-earliness-ranking

### Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | No format violations |
| H2 | dune build | PASS | Clean build |
| H3 | dune runtest | PASS | 217 tests in screener suite; all passed; linters clean (fn-length, magic-numbers, nesting, mli-coverage, file-length, format, posix-sh) |
| P1 | Functions ≤ 50 lines (linter) | PASS | fn_length_linter passed; all functions within 50-line limit |
| P2 | No magic numbers (linter) | PASS | linter_magic_numbers.sh passed |
| P3 | Config completeness | PASS | New `Quality_earliness` ranking mode is config-expressed via `candidate_ranking` field; all knobs are config-routed |
| P4 | Public-symbol export hygiene (linter) | PASS | mli_coverage linter passed; `screener_ranking.mli` has all needed exports |
| P5 | Internal helpers prefixed per convention | PASS | Internal helpers prefixed with underscore (`_quality_earliness_keys`, `_lex`, etc.) |
| P6 | Tests conform to test-patterns.md | PASS | 5 new tests added for `Quality_earliness` mode; all use `assert_that` + `elements_are` matchers; no nested assert_that, no List.exists with equal_to (true\|false), no bare match without is_ok_and_holds; file opens Matchers and follows composition rules |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | NA | Changes are to `analysis/weinstein/screener/` — shared screener code, not core trading modules |
| A2 | No new analysis imports into trading/trading outside backtest exceptions | NA | No changes to `trading/trading/` files; analysis-to-trading direction is not checked (reverse OK) |
| A3 | No unnecessary modifications to existing modules | PASS | Only 3 files touched (both in screener/lib, both in screener/test); all necessary; no cross-feature drift; PR file list (23 files = mostly experiment docs + 3 code) confirms focused scope |

### Experiment-Flag Discipline Verification

**R1 — Default-off:** ✓ PASS
- `candidate_ranking : candidate_ranking [@sexp.default Alphabetical]` in Screener config
- Defaults to `Alphabetical` (historical no-op), so merging the mechanism changes no backtest behavior until explicitly enabled

**R2 — Searchable/Axis-able:** ✓ PASS
- New variant `Quality_earliness` added to `candidate_ranking` type `[@@deriving sexp, eq]`
- Test `test_ranking_earliness_round_trips` explicitly validates sexp round-trip → axis-able via `Overlay_validator.apply_overrides`
- Screener config commentary confirms reachable via override path: `[((screening_config ((candidate_ranking Quality_earliness))))]`

**R3 — Promotion requires ACCEPT:** ✓ PASS (ledger rejection appropriate)
- Experiment at `dev/experiments/earliness-ranking-wfcv-2026-06-29/` shows **REJECT verdict**: earliness dominated in all 3 breadth cells (top-500/1000/3000)
- Mechanism stays default-off as axis; promotion is not required and not proposed

## Verdict

**APPROVED**

Structural QC passes all gates. Experiment results show `Quality_earliness` is rejected (dominated across breadth grid), consistent with `project_edge_is_the_fat_tail` finding — no equal-score tiebreak improves allocation. Mechanism lands correctly default-off behind flag, axis-ready for future experiments, with rigorous rejection evidence recorded.

Ready for behavioral QC (contracts on Stage 2 earliness reasoning, tiebreak order correctness, domain alignment).

---

## Behavioral QC — screener-earliness-ranking

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial .mli docstring claim pinned by a test | PASS | screener_ranking.mli claims → tests: (Quality_earliness leads with earliness asc, RS desc next) → test_ranking_earliness_leads_with_earliness + test_ranking_earliness_breaks_earliness_ties_by_rs; (distinct from Quality/RS-primary) → test_ranking_earliness_inverts_quality_on_rs_extended_fixture; (score is primary, tiebreak only among equal scores) → test_ranking_earliness_respects_score_primary; (sexp-derivable axis value) → test_ranking_earliness_round_trips. |
| CP2 | Each PR "Test plan" claim has a committed asserting test | PASS | PR lists 5 tests: earliness-leads ordering (test_ranking_earliness_leads_with_earliness ✓), inversion-vs-Quality on extended-RS fixture (test_ranking_earliness_inverts_quality_on_rs_extended_fixture ✓), RS-secondary tiebreak (test_ranking_earliness_breaks_earliness_ties_by_rs ✓), score-primary unchanged (test_ranking_earliness_respects_score_primary ✓), sexp round-trip (test_ranking_earliness_round_trips ✓). All five exist in test_screener.ml and are registered in the suite (lines 1942-1951); each asserts a concrete `elements_are` order, not "no error". |
| CP3 | Pass-through / identity tests pin identity, not just size | PASS | Alphabetical no-op back-compat pinned by test_ranking_alphabetical_is_ticker_order (full element order) + test_ranking_omitted_field_defaults_alphabetical (omitted field → Alphabetical). Default bit-identicality asserted on the value, not a count. |
| CP4 | Each guard in docstrings exercised by a test | PASS | The load-bearing guard "tiebreak reorders ONLY equal-score candidates; score stays primary" (screener_ranking.ml line 91-92) is exercised by test_ranking_earliness_respects_score_primary (HISCORE>LOSCORE despite fresher LOSCORE). None-RS/None-volume/non-Stage2 fallbacks are documented but are deterministic sentinel branches not separately scenario-tested — acceptable for a default-off axis whose ledger verdict is REJECT; noted as ONGOING_REVIEW, not a fail. |

### Behavioral Checklist (domain)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification strategy-agnostic | NA | qc-structural did not flag A1; no core (Portfolio/Orders/Position/Strategy/Engine) module touched. Change is in analysis/weinstein/screener/. |
| S1–S4 | Stage 1–4 definitions match book | NA | No stage-classifier change. Tiebreak reads existing weeks_advancing off an already-classified Stage2; it does not define or alter any stage. |
| S5 | Buy criteria: Stage 2 + breakout + volume | NA | No entry-criteria change. Candidates are already-scored grade-A breakouts; tiebreak only orders among equal scores. |
| S6 | No buy signals in Stage 1/3/4 | NA | Unchanged. |
| L1–L4 | Stop rules / state machine | NA | No stops change. |
| C1 | Screener cascade order (macro→sector→scoring→ranking) | PASS | eng-design-2 §Cascade Filter. compare_rankable keys on score first (Int.compare b.score a.score), tiebreak strictly second; ranking sits in the final ranking layer and reorders only within equal scores — cascade ordering and the additive score are untouched. |
| C2 | Bearish macro blocks all buys | NA | Macro gate not touched by this PR. |
| C3 | Sector RS vs market, not absolute | PASS | weinstein-book-reference.md §4.4. _rs_magnitude uses rs.current_normalized (Mansfield zero-line position, RS vs market), not absolute price performance. |
| T1 | Tests cover 4 stage transitions | NA | Not a stage-transition feature. |
| T2 | Bearish-macro → zero-candidate test | NA | Macro gate not in scope. |
| T3 | Stop trailing tests | NA | No stops in scope. |
| T4 | Tests assert domain outcomes, not "no error" | PASS | All 5 new tests assert exact ranked ticker order via elements_are; the inversion test pins Quality and Quality_earliness producing opposite orders on the same fixture — a real domain assertion, not a smoke test. |

### Weinstein-faithful-core / experiment-flag-discipline

- **W1 (spine intact):** PASS — the tiebreak orders only equal-score candidates; it does not buy outside Stage 2, drop volume confirmation, or alter the macro/sector gate or the score. Spine items 1–7 untouched.
- **W2 (adaptation is a config dial, cited):** PASS — Quality_earliness is a config field value (`candidate_ranking`, [@sexp.default Alphabetical]); docstrings cite weinstein-book-reference.md §Stage 2: Advancing (avoid extended Stage 2, confirmed §4.6) and §4.4 Relative Strength (spine item 7). Ranking-layer dial, not a spine change.
- **R1 (default-off):** PASS — `candidate_ranking [@sexp.default Alphabetical]`; merging changes no backtest result (bit-identical, no golden changes).
- **R2 (searchable axis):** PASS — real config field, sexp round-trip pinned (test_ranking_earliness_round_trips), resolves via Overlay_validator.
- **R3 (promotion needs ACCEPT):** PASS — PR does NOT flip the default. Ledger 2026-06-29-earliness-ranking-tiebreak-grid.sexp records `(verdict Reject)` (Pareto-dominated in all 3 breadth cells); mechanism correctly stays a default-off axis. No ACCEPT claimed, none needed.

## Quality Score

5 — Disciplined default-off axis: contracts fully pinned (CP1–CP4 PASS), the distinguishing inversion-vs-Quality test makes the two modes provably distinct, book citations are faithful, and the rejecting ledger evidence + bit-identical default are exemplary experiment hygiene.

## Verdict

APPROVED

Reviewed SHA: c33dc52a8344889912ebc8abd0f89d573959501e

## Structural QC — Failed-Breakout Invalidation (Default-Off)

### Build & Linter Gates

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | CI build-and-test: success (dune fmt linter passed) |
| H2 | dune build | PASS | CI build-and-test: success |
| H3 | dune runtest | PASS | CI build-and-test: success (all dune-wired linters: fn_length_linter, linter_magic_numbers, linter_mli_coverage, nesting_linter all passed) |

### Code Pattern Compliance

| # | Check | Status | Notes |
|---|-------|--------|-------|
| P1 | Functions ≤ 50 lines (linter gate) | PASS | CI fn_length_linter passed; screener.ml reduced from 498→483 lines via extraction (code-health-discipline §refactor-before-bump) |
| P2 | No magic numbers (linter gate) | PASS | CI linter_magic_numbers.sh passed |
| P3 | All configurable thresholds in config record | PASS | `failed_breakout_tolerance_pct : float [@sexp.default 0.0]` is a real config field in `Screener.config` (trading/analysis/weinstein/screener/lib/screener.mli:248–277); no hardcoded thresholds |
| P4 | Public-symbol export hygiene (linter gate) | PASS | CI linter_mli_coverage.sh passed; all submodules (Screener_watchlist, Screener_admission, Stock_analysis_scans) have `.mli` files |
| P5 | Internal helpers prefixed per convention | PASS | New helper functions use underscore prefix (e.g., `_long_candidate`, `_permissive_screener_config`); no violations |

### Project-Specific Architecture Rules

| # | Check | Status | Notes |
|---|-------|--------|-------|
| P6 | Tests conform to test-patterns.md (presence + conformance) | PASS | All test files use `open Matchers` and proper `assert_that` + matcher composition. Verified: test_screener.ml (245 new lines, 10+ failed-breakout tests), test_stock_analysis.ml (new current_close tests), test_runner_hypothesis_overrides.ml (3 override-resolution tests). Zero violations of P6 sub-rules: no `List.exists … equal_to (true\|false)`, no `let _ = … .run`, no bare `| Error … -> assert_failure` patterns. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No modifications to core modules. PR file list shows only changes in: trading/analysis/weinstein/ (primary), trading/trading/backtest/ (scenarios only), trading/trading/weinstein/strategy/test/ (test fixtures only). Extracting Screener_watchlist and Stock_analysis_scans are refactors within the analysis subtree, not core-module touching. |
| A2 | No new `analysis/` → `trading/trading/` imports outside backtest exceptions | PASS | Checked all modified trading/trading/ files (stage_transition_scanner.ml, test files): only additions are `current_close = None` field assignments in test fixtures; zero new `open`/`require` statements. No dune file modifications. Backtest layer remains isolated. |
| A3 | No unnecessary modifications to existing modules | PASS | Canonical PR file list (20 files via `gh pr view --json files`) shows all changes are either: (a) screener/stock_analysis lib changes (new gate logic, field extraction), (b) test additions (test_screener.ml +245, test_stock_analysis.ml +28, test_runner_hypothesis_overrides.ml +46), or (c) test fixture updates. Zero cross-feature drift detected. Refactorings (Screener_watchlist, Stock_analysis_scans extraction) are intentional code-health work to stay under linter caps. |

### Strategy Mechanism Rules (Experiment-Flag Discipline)

| Check | Status | Authority | Notes |
|---|---|---|---|
| **R1: Default-off on merge** | PASS | experiment-flag-discipline.md §"What QC can check" | `failed_breakout_tolerance_pct : float [@sexp.default 0.0]` in screener.mli:248. When k=0.0, the gate short-circuits to a no-op before any price is read — `_long_candidate`, `_long_admission`, watchlist, diagnostics counter all reproduce pre-change output bit-identically. Zero goldens move. Pinned by explicit test: `test_failed_breakout_default_is_inert`. PR body confirms "Zero results change." |
| **R2: Searchable as real config field** | PASS | experiment-flag-discipline.md R2 + PR body | Field is a real `Screener.config` member; reachable via genuine `Overlay_validator.apply_overrides` deep-merge at `((screening_config ((failed_breakout_tolerance_pct 0.05))))` (verified by test `test_failed_breakout_tolerance_axis_resolves_via_overlay_validator` in test_runner_hypothesis_overrides.ml). Routes through `Variant_matrix` axis resolution. Not hardcoded. |
| **R3: Promotion requires ledger ACCEPT** | PASS | experiment-flag-discipline.md R3 | No default flipped in this PR. Field defaults to 0.0 (no-op). PR explicitly scopes "R3 no default flip" and "Promotion needs a ledger ACCEPT plus a grid" — correctly out of scope for this merge. |

### Weinstein Faithfulness (Faithful Core)

| Check | Status | Authority | Notes |
|---|---|---|---|
| **W1: Spine intact** | PASS | weinstein-faithful-core.md §spine items 1–7 | This is a tightening of spine item 3 (entry on breakout above resistance), not a new rule. A close back below the breakout level means the resistance did not hold — the breakout failed. This re-validates an existing spine rule, not a new entry condition. No spine items altered. |
| **W2: Documented dial, config-expressed** | PASS | weinstein-faithful-core.md §dials + PR body | PR cites `weinstein-book-reference.md` §Buy Criteria: "a close back below the breakout level after the breakout week" is a failed breakout. The dial is "tolerance k (3–5% typical)" — configurable, landing as `failed_breakout_tolerance_pct` in config. Real field, not hardcoded. Authority clearly documented. |

### Code Health & Discipline

| Check | Status | Notes |
|---|---|---|
| File-length discipline | PASS | screener.ml: 498→483 lines (within 500 hard limit); stock_analysis.ml: 502→410 lines. Refactorings (Screener_watchlist, Stock_analysis_scans extraction) avoid limit bumps. Per code-health-discipline.md, extraction is the right fix, not bumping limits. No `@large-module` markers added. No linter_exceptions.conf entries. |
| Python rule | PASS | no-python.md: zero .py files added. |

### Summary

**All structural checks PASS. No FAILs. No FLAGs.**

The PR:
- Lands the failed-breakout re-validation gate (solving #2084 F1) in a default-off, properly configurable manner that preserves all goldens and backtest results on merge.
- Follows experiment-flag-discipline R1–R3 exactly: default-off (`[@sexp.default 0.0]`), searchable via real config + Overlay_validator, no ledger ACCEPT needed because no default flipped.
- Faithfully tightens Weinstein's existing breakout rule (spine item 3) per the book's criterion that a close-back failure means the breakout did not hold.
- Has comprehensive unit tests covering the gate armed/disarmed, None-value handling, demotion to watchlist, diagnostics counters, and override resolution through the real validator.
- Performs intentional code-health refactoring (Screener_watchlist, Stock_analysis_scans extraction) to stay under linter caps rather than bumping limits.
- Passes all CI build-and-test + linter checks (dune fmt, fn_length_linter, linter_magic_numbers, linter_mli_coverage, nesting_linter).

**Verdict: APPROVED**

Quality score: 5/5 (mechanically correct, thoroughly tested, follows all project disciplines, code-health intact, zero debt introduced).

Harness notes:
- P6 test-pattern conformance could be strengthened by a dune-wired linter that catches bare match statements without `assert_that`/`is_ok_and_holds`, but the QC checklist read is sufficient for now (ONGOING_REVIEW).
- A2 analysis-import rule would benefit from a dune-validation step in CI, but git-diff inspection is sufficient for this PR (ONGOING_REVIEW).

---

## Behavioral QC — Failed-Breakout Invalidation (Default-Off)

Reviewed at the same SHA as the structural pass above (`c33dc52a`). Read-only
review: CI on this SHA is green (`build-and-test`, `perf-tier1-smoke`), so test
*content* was reasoned about by reading, not by executing.

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new `.mli` docstrings has an identified test that pins it | PASS | Traced every claim across the five new/changed `.mli` surfaces. `screener_admission.mli:52-64` "invalidate iff `close < breakout *. (1-k)`" → `test_failed_breakout_armed_drops_candidate` (28.00 < 35.08 → dropped) + `test_failed_breakout_armed_keeps_holding_candidate` (35.50 ≥ 35.08 → kept); both discriminating. `screener_admission.mli:61-63` "`k <= 0.0` … always `None`" → `test_failed_breakout_reason_disabled_at_or_below_zero` (k=0.0 against close 1.0 / breakout 100.0 — maximally discriminating). `screener_admission.mli:64-67` "missing price never invalidates" → `test_failed_breakout_none_close_not_invalidated` + `test_failed_breakout_none_breakout_price_not_invalidated`; both assert the candidate **is** in `buy_candidates` via `elements_are`, so neither can pass vacuously. `screener_admission.mli:70-77` "boolean form = `Option.is_none` of the reason" → `test_failed_breakout_boolean_agrees_with_reason`. `screener.mli:249-252` "bit-identical at the default" → `test_failed_breakout_default_is_inert`. `stock_analysis.mli:113-123` "offset-0 close; `None` on empty history" → `test_current_close_is_last_bar_close` + `test_current_close_none_without_bars`. `screener_watchlist.mli:39-42` decision order → `test_failed_breakout_armed_drops_candidate` (watchlist = `["FTH"]` carrying the drop reason). |
| CP2 | Each PR-body "Test plan" claim has a corresponding committed test | PASS | All six Test-plan bullets located: armed-below → `test_failed_breakout_armed_drops_candidate`; armed-above → `..._armed_keeps_holding_candidate`; `current_close = None` → `..._none_close_not_invalidated`; `breakout_price = None` → `..._none_breakout_price_not_invalidated`; default-is-inert → `..._default_is_inert` + `..._default_config_is_zero`; watchlist demotion → asserted inside `..._armed_drops_candidate`; diagnostics counts + zero-by-default → same two tests; overrides through the real validator → `test_override_screening_failed_breakout_tolerance` + `test_failed_breakout_tolerance_axis_resolves_via_overlay_validator` (`test_runner_hypothesis_overrides.ml:702-738`). **Scope-honesty claims verified against the diff**: `grep -E 'suggested_stop\|initial_stop_pct\|screener_scoring'` over `git diff origin/main...c33dc52a` returns **zero hits** — the "#2084 Finding 2 untouched" claim is accurate. Line-count claims verified exactly: `screener.ml` = 483, `stock_analysis.ml` = 410. "`Stock_analysis_scans` is a **verbatim** move" verified — bodies byte-identical, only `_scan_max_high_callback`→`scan_max_high` / `_scan_min_low_callback`→`scan_min_low` renames. "No existing analysis path reads `current_close`" verified by repo-wide grep: the only readers are the two new screener call sites (`screener.ml:190`, `screener_watchlist.ml:28`). No overclaim, no underclaim. |
| CP3 | Identity / pass-through tests pin identity, not just size | PASS | `test_failed_breakout_default_is_inert` is the identity test for R1 and pins `buy_candidates` by `elements_are [equal_to "FTH"]`, `watchlist` by `is_empty`, and the drop counter by `equal_to 0` — no bare `size_is`. Same for the two `None`-price tests. |
| CP4 | Each guard named in a docstring has a test exercising the guarded-against scenario | **FAIL** | Two docstring/comment guard claims are asserted but not pinned. (a) `test_screener.ml:2277-2278` comment claims "a negative value is treated as disabled too (same convention as `min_price`)" — no test passes a negative `tolerance_pct`; the adjacent test only exercises `0.0`, despite being named `..._at_or_below_zero`. (b) `screener.mli:358-361` and `screener_cascade_diagnostics.mli:16-22` both claim `long_failed_breakout_dropped` is "Always `[0]` … when the macro gate closed the long side" — the existing macro-gate diagnostics tests (`test_screener.ml:1221-1240`) assert field-by-field via `field … equal_to` and do **not** include the new field, so the `zero_if long_macro_admitted` wrapper (`screener_cascade_diagnostics.ml:44-45`) is unpinned. Both are one-line test additions. See NEEDS_REWORK Items. |

**Vacuous-test audit (the #2085 / #2077 defect class).** The highest-risk
candidate was `test_failed_breakout_tolerance_sexp_round_trips`
(`test_screener.ml:2322-2336`): it deletes the field from a serialized config via
`String.substr_replace_first ~pattern:"(failed_breakout_tolerance_pct 0)"`, and
if that pattern failed to match, the field would survive with value `0` and the
assertion would still pass — pinning nothing. Resolved **non-vacuous**: this
repo's ppx renders a `float` `0.0` as the bare atom `0`, evidenced empirically by
106 occurrences of `(max_favorable_excursion_pct 0)` in machine-generated
`trade_audit.sexp` goldens on a field typed `float` at
`audit_recorder.ml:45`. The pattern matches, the field really is removed, and the
test genuinely pins the `[@sexp.default 0.0]` back-compat contract. No other test
in the diff can pass without the feature present.

### Behavioral Checklist

| # | Check | Status | Notes (authority) |
|---|-------|--------|-------------------|
| A1 | Core-module modification is strategy-agnostic | NA | qc-structural did not raise A1; no file under `portfolio/`, `orders/`, `position/`, `strategy/lib`, or `engine/` is touched. The one non-analysis lib change is `backtest/optimal/lib/stage_transition_scanner.ml`, a single `failed_breakout_tolerance_pct = 0.0` addition to a full-record `Screener.config` literal — no behaviour change. |
| S1–S4 | Stage 1/2/3/4 definitions match the book | NA | No stage-classification logic changed. `Stage.result` and `is_breakout_candidate`'s stage arms are untouched by this diff. |
| S5 | Buy criteria: entry only in Stage 2, on breakout above resistance with volume confirmation | PASS | weinstein-book-reference.md §4.1–4.2. The gate is purely subtractive: `_long_candidate` (`screener.ml:180-195`) inserts the check **after** `is_breakout_candidate` and before the volume-band exclusion, so it can only remove candidates, never admit one. The breakout-above-resistance and volume legs are unchanged. The mechanism is a re-check of §4.1 requirement 1 against the *current* close rather than the breakout bar — sound, because `_build_candidate` emits `suggested_entry = a.breakout_price` regardless of which admission arm fired, so a close far below that level makes the emitted entry stale for every arm. (The *citation* attached to this mechanism is defective — see W2.) |
| S6 | No buy signals generated during Stage 1, 3, or 4 | PASS | weinstein-book-reference.md §2 (Stage 4: "NEVER buy or hold"). All three arms of `is_breakout_candidate` (`stock_analysis.ml:360-386`) require Stage 2 (or a Stage1→Stage2 transition); unchanged, and this PR only narrows the survivor set. |
| L1–L4 | Stop placement / trailing / weekly-close trigger / state machine | NA | #2084 Finding 2 (the `entry * 0.92` structural stop) is explicitly out of scope and the diff confirms it: no occurrence of `suggested_stop`, `initial_stop_pct`, or `screener_scoring.ml` anywhere in the diff. This gate decides *whether* a candidate is emitted, not what stop it carries. |
| C1 | Cascade order: macro gate → sector filter → individual scoring → ranking | PASS | eng-design-2-screener-analysis.md §Cascade Filter. The macro gate remains upstream in `_evaluate_longs` (`screener.ml:285-292`); the sector-`Weak` rejection still precedes the new check in `_long_candidate`; the gate sits inside the individual-candidate phase before scoring. The diagnostics mirror (`_long_admission`, `screener_admission.ml:82-96`) folds the gate into the breakout phase in the same relative position, so the admitted triple stays monotone. Order preserved. |
| C2 | Bearish macro blocks all buy candidates (unconditional) | PASS | weinstein-book-reference.md §3. `_longs_admitted_by_macro` is unchanged and still short-circuits `_evaluate_longs` to `[]`; `Screener_watchlist.build` still returns `[]` when `buys_active = false`. The new drop counter is additionally wrapped in `zero_if long_macro_admitted`. (That wrapper's correctness is asserted in two `.mli`s but untested — CP4(b).) |
| C3 | Sector analysis uses relative strength vs. market | NA | No sector or RS logic touched. |
| T1 | Tests cover all 4 stage transitions | NA | No stage logic in this feature. |
| T2 | Bearish-macro scenario producing zero buy candidates | PASS | Pre-existing macro-gate tests (`test_screener.ml:1202-1240`) remain in force and unmodified. Note the new field is not among the asserted ones — that is CP4(b), not a T2 failure. |
| T3 | Stop-loss trailing tests | NA | No stop logic in this feature. |
| T4 | Tests assert domain outcomes, not just "no error" | PASS | Every new test asserts a domain outcome: ticker membership of `buy_candidates`, watchlist contents plus the drop-reason substring, `long_failed_breakout_dropped` / `long_breakout_admitted` counts, and the reason string naming both prices. No "is_ok"-only assertions. |
| W1 | Weinstein spine intact | PASS | weinstein-faithful-core.md §spine. Spine items 1–7 untouched. The gate cannot admit a non-Weinstein buy — it only removes. Verified there is no bypass: `_long_candidate` is the sole producer of `buy_candidates`, and the gate is applied unconditionally downstream of the whole `is_breakout_candidate` disjunction, so a name admitted via the ≤4-week early-Stage-2 arm, the Stage1→Stage2 arm, the continuation arm, or the virgin-readmission arm is re-validated identically — no admission path skips it. |
| W2 | Adaptation is a documented dial, config-expressed, **and justified against the book** | **FAIL** | The dial is properly config-expressed (`failed_breakout_tolerance_pct`, real field, `[@sexp.default 0.0]`, resolves through `Overlay_validator`) — that half passes. The **authority citation does not hold**: the sentence attributed to `weinstein-book-reference.md` §Buy Criteria does not appear in §4 (or anywhere in the document). See NEEDS_REWORK Items. |

### Does the gate fire on the motivating #2084 case?

Yes, and the test uses the real specimen rather than a toy.
`test_failed_breakout_armed_drops_candidate` (`test_screener.ml:2170-2199`)
constructs ticker `FTH` with `breakout_price = 36.93` and
`current_close = 28.0` — the actual 2026-07-17 report numbers — at `k = 0.05`,
and asserts the full consequence chain: dropped from `buy_candidates`,
`long_breakout_admitted = 0`, `long_failed_breakout_dropped = 1`, and demoted
onto the watchlist with a reason containing `"Failed breakout"`.

The issue's stronger shape — *close below the pick's own stop* ($33.98) — is
covered analytically rather than by assertion, correctly so, since the gate does
not read the stop (that is Finding 2). With `stop = entry * 0.92` and
`entry = breakout_price`, the gate's floor is `breakout * (1 - k)`, so for any
`k < 0.08` the floor sits **above** the stop and `close < stop ⟹ close < floor`:
within the `.mli`'s documented 0.03–0.05 range the gate strictly dominates a
"close below its own stop" check. Worth noting the containment **reverses for
`k > 0.08`** — a swept `k = 0.10` would re-admit a candidate closing below its
own stop. The `.mli` calls 0.03–0.05 "typical" but does not bound `k`; stating
the `k < 0.08` containment there would make the interaction explicit before the
arming sweep. Advisory, not a rework item.

### Behaviour-preservation spot-check of the two extractions

- `Stock_analysis_scans` — verbatim. `_max_opt`, `_min_opt`,
  `_split_jump_threshold`, `_no_split_between`, and both scan bodies are
  byte-identical to the originals; only the two public names lost their `_`
  prefix and `callback` suffix. Both call sites in
  `_breakout_and_breakdown_prices` pass the same arguments. No semantic change.
- `Screener_watchlist` — behaviour-preserving with one benign reordering. On
  main, `_watchlist_entry` computed `score_long` and *then* `_check_watchlist_grade`
  tested `in_buy_list`; the new `entry` tests `Set.mem buy_tickers` **before**
  scoring. Since `score_long` is pure, the outcome is identical, and
  `List.exists buy_candidates ~f:(fun c -> c.ticker = sa.ticker)` is exactly
  `Set.mem (String.Set.of_list (map ticker buy_candidates))`. `build` preserves
  input order via `List.filter_map` and still returns `[]` when
  `buys_active = false`. No semantics smuggled in.

### Default-off correctness at the behavioural level

Provably inert, not merely asserted. `_failed_breakout_levels`
(`screener_admission.ml:34-41`) returns `None` on `tolerance_pct <= 0.0`
**before** either price is destructured, so no comparison executes at `k = 0.0`
and the `<` / `<=` off-by-one the brief flags is structurally unreachable — and
it is pinned by `test_failed_breakout_reason_disabled_at_or_below_zero`, which
feeds the most extreme possible input (close 1.0 vs breakout 100.0) at `k = 0.0`
and requires `is_none`. `count_long_failed_breakouts` inherits the same
short-circuit, so the counter is 0 by construction. Combined with
`test_failed_breakout_default_is_inert` (same collapsed candidate that *is*
dropped when armed) and `test_default_screening_failed_breakout_tolerance_is_zero`,
the "zero goldens move" claim holds. *Advisory:* the exact-boundary case
(`close = breakout * (1-k)`, which the `.mli`'s strict `<` says must be
admitted) is untested — 35.50 sits 0.42 above the 35.0835 floor. Low value
(measure-zero in float), noted only for completeness.

### Interaction with the ≤4-week early-Stage-2 admission window

Composes correctly, and no admission path can skip re-validation:
`is_breakout_candidate` collapses its three arms to a single `bool` before
`_long_candidate` consults it, so no arm identity flows into the gate and the
gate is applied to every admitted name. *Advisory:* the fixture
(`breakout_analysis`, `test_screener.ml:2122-2168`) sets both
`weeks_advancing = 2` **and** `prior_stage = Some (Stage1 …)`, so the
Stage1→Stage2 arm matches first and the pure staleness arm is never the one
exercised. Structurally immaterial for the reason above, but a variant with
`prior_stage = None; weeks_advancing = 4` would pin the compounding factor the
PR body names as the motivation. Not a rework item.

*Advisory on the continuation arm:* when `enable_continuation_buys` and this
gate are armed together, a mature Stage-2 name pulling back to its MA (the
book's continuation setup, §4.6) can close well below the prior-base
`breakout_price` and be dropped. This is defensible — `suggested_entry` is
derived from `breakout_price` for continuation candidates too, so the emitted
entry really would be stale — but the `.mli` scopes its rationale to the
initial-breakout arm and says nothing about it. Both flags are default-off and
continuation buys already carry a REJECT (#1366), so this is a documentation
note for whoever arms `k`, not a defect.

## Quality Score

3 — Implementation, test discrimination, scope honesty and default-off proof are
all exemplary (the code alone would score 5); the score is held down by a
replicated authority-citation defect and two docstring guards that no test pins,
both documentation-level and cheap to fix.

## Verdict

NEEDS_REWORK

## NEEDS_REWORK Items

### W2: Authority citation is not supported by the section cited

- Finding: Five source files, the PR body, and `dev/status/screener.md` all
  attribute to `weinstein-book-reference.md` §Buy Criteria the claim that "a
  close back below the breakout level after the breakout week is a failed
  breakout." **That sentence, and any statement of that rule, does not appear in
  §4 "Individual Stock Buy Criteria" — or anywhere else in the document.** §4.1
  lists exactly three entry requirements (breakout above resistance and above the
  30-week MA; MA no longer declining; no breakout below a declining MA); §4.2 is
  volume; §4.3 resistance grading; §4.4 RS. None concerns re-validating an
  already-admitted candidate against a later close. The nearest genuinely
  related passages point elsewhere, and one points the *other* way: §Stage 2
  detail (Ch. 2) says "After initial rally, usually at least one pullback close
  to the breakout point — **this is a second chance to buy**", and §5.1/§5.2
  handle a breakout that fails via the *initial stop below the prior correction
  low* and the whipsaw re-buy allowance, not by de-listing the candidate. So the
  book, as distilled in the reference doc, treats a post-breakout give-back as a
  stop-management event and a possible second entry — not as a screening
  disqualifier. The mechanism is still defensible (it enforces §4.1 requirement 1
  against current data, and `suggested_entry` is genuinely stale once the close
  collapses), but it is an **engineering adaptation**, not a book-quoted rule,
  and the docstrings present it as the latter. This matters beyond pedantry:
  `weinstein-faithful-core.md` exists to keep the search space disciplined, and a
  future agent sweeping `k` who follows the citation will find a section that
  says the opposite of what the docstring implies. Note qc-structural's W2 row
  passed this claim through by restating it rather than checking it against the
  document.
- Location:
  `trading/analysis/weinstein/screener/lib/screener_admission.mli:53-57`;
  `trading/analysis/weinstein/screener/lib/screener_admission.ml:46-48`;
  `trading/analysis/weinstein/screener/lib/screener.mli:265-270`;
  `trading/analysis/weinstein/screener/lib/screener_watchlist.mli:9-13`;
  `trading/analysis/weinstein/stock_analysis/lib/stock_analysis.mli:119-122`;
  PR #2087 body §"Weinstein authority"; `dev/status/screener.md` (2026-07-25 entry).
- Authority: `docs/design/weinstein-book-reference.md` §4 "Individual Stock Buy
  Criteria (Ch. 3, 4, 5)" — full text of §4.1: "1. Stock breaks out above
  resistance AND above 30-week MA / 2. 30-week MA is no longer declining (flat or
  rising) / 3. Breakout must NOT occur below a declining MA — **this is a trap,
  not a buy**". Counter-pointing passage, §Stage 2 detail (Ch. 2): "After initial
  rally, usually at least one pullback close to the breakout point — this is a
  second chance to buy." Governing rule:
  `.claude/rules/weinstein-faithful-core.md` §W2 — "it must be justified against
  the book, not invented."
- Required fix: one of —
  (a) Re-attribute honestly in all five docstrings, the PR body, and the status
  file: cite §4.1 requirement 1 (read as a condition that must hold at
  *evaluation* time, not only on the breakout bar) plus §4.6 "Greater risk of
  false breakout" and §5.2 "IF whipsaw … acceptable to re-buy", and state
  explicitly that invalidating a stale candidate is an engineering adaptation
  enforcing spine item 3 against current data rather than a book-quoted rule.
  Additionally note that the tolerance `k` is precisely what separates the book's
  "pullback close to the breakout point = second chance to buy" from a genuine
  failure, which is why `k` must not be set small; or
  (b) If Weinstein does state the rule directly, add it to
  `weinstein-book-reference.md` with its chapter/line citation in this PR, so the
  §Buy Criteria reference becomes true.
  No code change is required either way.
- harness_gap: ONGOING_REVIEW — verifying that a cited section actually contains
  the cited claim requires reading the authority document; a linter could at best
  check that a `weinstein-book-reference.md §<name>` reference resolves to an
  existing heading, which would not have caught this (§Buy Criteria exists).

### CP4: Two docstring guard claims have no test exercising them

- Finding: (a) The comment at `test_screener.ml:2277-2278` states "a negative
  value is treated as disabled too (same convention as `min_price`)", and the
  test below it is named `..._reason_disabled_at_or_below_zero`, but the only
  value exercised is `0.0`. The `<= 0.0` branch's negative half is unpinned; a
  regression to `Float.equal tolerance_pct 0.0` would arm the gate for every
  negative `k` with no test failing. (b) `screener.mli:358-361` and
  `screener_cascade_diagnostics.mli:16-22` both claim
  `long_failed_breakout_dropped` is "Always `[0]` … when the macro gate closed
  the long side", implemented by `zero_if long_macro_admitted`
  (`screener_cascade_diagnostics.ml:44-45`). The existing macro-gate diagnostics
  tests assert field-by-field via `field … equal_to` and do not include the new
  field, so removing the `zero_if` wrapper would leave the suite green. This is
  the advertised-but-unpinned class that CP4 exists to catch — both claims read
  as covered and are not.
- Location: `trading/analysis/weinstein/screener/test/test_screener.ml:2277-2284`
  (claim a); `trading/analysis/weinstein/screener/lib/screener.mli:358-361` and
  `trading/analysis/weinstein/screener/lib/screener_cascade_diagnostics.mli:16-22`
  vs `test_screener.ml:1221-1240` (claim b).
- Authority: `.claude/agents/qc-behavioral.md` §Contract Pinning Checklist CP4 —
  "FAIL if the docstring names an edge case but no test covers it."
- Required fix: (a) add a negative-`k` case to
  `test_failed_breakout_reason_disabled_at_or_below_zero` (e.g.
  `~tolerance_pct:(-0.05)` with `breakout_price = Some 100.0`,
  `current_close = Some 1.0`, expect `is_none`) — or drop the negative-value
  claim from the comment; (b) add one screen under `~macro_trend:Bearish` with
  the collapsed `FTH` candidate and `failed_breakout_tolerance_pct = 0.05`,
  asserting `long_failed_breakout_dropped = 0`.
- harness_gap: LINTER_CANDIDATE — both are deterministic single-input assertions
  and would be caught by a golden-scenario test; the general "docstring names an
  edge case with no matching test" check remains ONGOING_REVIEW.

Reviewed SHA: 937ec9356832135c8c5a5412e33ef0be3f3533db

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | Exit 0. Warning about missing dune-project is pre-existing and cosmetic. |
| H2 | dune build | PASS | Exit 0. |
| H3 | dune runtest | PASS | Exit 1 due to nesting_linter pre-existing baseline — identical 49-function violation set on both `origin/main` and this branch; zero new violations introduced. All test executables pass: screener 18/18, strategy 15/15, screener e2e 5/5, strategy smoke 5/5, backtest 3/3, and all other suites. `devtools/checks` (fn_length, magic_numbers, mli_coverage, arch_layer, fmt_check, all other shell linters) exit 0. fn_length_linter exits 0. The nesting_linter dune rule does not use `(exit 0)` so its non-zero exit propagates to the full `dune runtest` — this is a pre-existing infrastructure condition, not a new failure from this PR. |
| P1 | Functions ≤ 50 lines (fn_length_linter) | PASS | fn_length_linter exit 0. Largest new function: `_make_entry_transition` ~42 lines (within limit). `entries_from_candidates` ~24 lines. `_screen_universe` ~40 lines. All within limits. |
| P2 | No magic numbers (linter_magic_numbers.sh) | PASS | linter_magic_numbers.sh exits 0. The dune sandbox run prints `FAIL:` text and flags `weinstein_strategy.ml: 11 in: entries (Weinstein Ch. 11)` — this is a false positive: "11" appears in a docstring chapter reference `(Weinstein Ch. 11)`, not as a numeric literal. No production numeric literals introduced. The linter exits 0 regardless. |
| P3 | All configurable thresholds/periods/weights in config record | PASS | No new numeric thresholds introduced. `_rs_blocks_short` uses variant pattern matching (`Positive_rising | Positive_flat | Bullish_crossover`) — not numeric literals. `_normalised_entry_stop_for_sizing` uses `Float.max`/`Float.min` with no constants. No new tunable values require config fields. |
| P4 | .mli files cover all public symbols (linter_mli_coverage.sh) | PASS | linter_mli_coverage.sh exits 0 (part of devtools/checks exit 0). New public symbol `entries_from_candidates` is exported in `weinstein_strategy.mli` at line 124 with a full docstring. New field `side : Trading_base.Types.position_side` on `scored_candidate` appears in `screener.mli` at line 103 with documentation. |
| P5 | Internal helpers prefixed with _ | PASS | New internal helpers: `_rs_blocks_short` (screener.ml) and `_normalised_entry_stop_for_sizing` (weinstein_strategy.ml) — both correctly prefixed. `entries_from_candidates` is public (in .mli) and correctly unprefixed. |
| P6 | Tests use the matchers library | PASS | Both test files open `Matchers` and use `assert_that` throughout. New test assertions use `elements_are`, `all_of`, `field`, `matching`, `equal_to`, `is_empty` — all consistent with the matchers library pattern. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No modifications to Portfolio, Orders, Position, Engine, or the core Strategy interface. `weinstein_strategy.ml` is the Weinstein-specific strategy implementation, not a core module. |
| A2 | No imports from analysis/ into trading/trading/ | PASS | `weinstein.screener` was already a dependency of `weinstein_trading.strategy` on `origin/main` — not a new import. The screener dune file now imports `trading.base`, which is in `trading/base/lib/` (not `trading/trading/`) — this is a cross-layer-safe dependency (base types library). Architecture layer check exits 0. |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | Changed files: `screener.mli`, `screener.ml`, `weinstein_strategy.mli`, `weinstein_strategy.ml`, their test files, their dune files, and `dev/status/` and `dev/plans/` files. All changes are directly required by the feature scope. No unrelated module modifications. |

## Verdict

APPROVED

All applicable items are PASS. No FAILs. The nesting_linter exit-1 is a pre-existing baseline condition present on `origin/main` with identical violations — zero new violations introduced by this branch. Behavioral QC may proceed.

---

# Behavioral QC — short-side-strategy
Date: 2026-04-18
Reviewer: qc-behavioral

## Behavioral Checklist

| # | Check | Status | Notes (cite authority doc section) |
|---|-------|--------|------------------------------------|
| S1 | Stage 1 definition matches book | NA | Stage classifier not modified in this PR; behavior inherited from main. |
| S2 | Stage 2 definition matches book | NA | Stage classifier not modified in this PR. |
| S3 | Stage 3 definition matches book | NA | Stage classifier not modified in this PR. |
| S4 | Stage 4 definition matches book | NA | Stage classifier not modified in this PR. |
| S5 | Buy criteria: Stage 2 entry on breakout + volume | PASS | `_long_candidate` unchanged — still gated on `is_breakout_candidate` (Stage 1→2 or early Stage 2 + adequate volume + non-negative RS) per stock_analysis.ml:115–138 + screener.ml:307–312; no regression from this PR. |
| S6 | No buy signals in Stage 1/3/4 | PASS | weinstein-book-reference.md §Stage 1, §Stage 3, §Stage 4: no buying. `is_breakout_candidate` only returns true for Stage 2 states (stock_analysis.ml:115–122); screener buy path unchanged. Under Bearish macro, `_evaluate_longs` returns `[]` (screener.ml:358–359). Strategy-level `buy_candidates @ short_candidates` concatenation (weinstein_strategy.ml:_screen_universe) preserves this — no new buy path introduced. |
| L1 | Initial stop below the base (prior correction low) for longs; above resistance ceiling for shorts | PASS | weinstein-book-reference.md §5.1 ("below the significant support floor") and §6.3 (short buy-stop "above prior rally peak"). `_make_entry_transition` now threads `~side:cand.side` into `Weinstein_stops.compute_initial_stop_with_floor` (weinstein_strategy.ml:97–100). Side-aware `Support_floor.find_recent_level` returns correction low for Long and rally high for Short (support_floor.mli:31–49). For Shorts the book calls this the "resistance ceiling" — implementation faithful. |
| L2 | Trailing stop never lowered (longs) / never raised (shorts) | NA | Trailing-stop update logic not modified in this PR; the side-aware ratchet landed in PR #382 (support-floor-stops). `Stops_runner.update` path unchanged. |
| L3 | Stop triggers on weekly close | NA | Stop-trigger semantics unchanged in this PR. |
| L4 | Stop state machine transitions correct | NA | State machine not modified in this PR. |
| C1 | Screener cascade order (macro → sector → individual → ranking) | PASS | eng-design-2-screener-analysis.md. The short-path cascade is: macro gate (`_evaluate_shorts` returns `[]` if Bullish; screener.ml:367–375), sector gate (`_short_candidate` rejects Strong; screener.ml:317), individual scoring (`_score_short`; screener.ml:213–218), ranking (`_top_n max_short_candidates`; screener.ml:373). Same ordering as long cascade. |
| C2 | Bearish macro blocks all buy candidates (macro gate unconditional) | PASS | weinstein-book-reference.md §Macro Analysis. `_evaluate_longs` explicitly returns `[]` under Bearish (screener.ml:358–359). Strategy `_run_screen` no longer short-circuits Bearish — relies on the screener's own gate; `buy_candidates` is empty so the concatenation `buy_candidates @ short_candidates` yields shorts-only. Existing `test_bearish_macro_no_buys` still asserts this. |
| C3 | Sector analysis uses relative strength vs. market (not absolute) | NA | Sector RS logic not modified in this PR. |
| — | **Short-side gate: never short a stock with positive/strong RS (Ch.7 §6.1 rule 5)** | PASS | weinstein-book-reference.md §6.1 ("NEVER short a stock with strong RS, even if it breaks down"). `_rs_blocks_short` (screener.ml:323–328) blocks `Positive_rising | Positive_flat | Bullish_crossover` as a hard gate in `_short_candidate` (screener.ml:322). `Negative_improving` still allowed — faithful to book (rule targets "strong RS", not "improving-from-negative"). Absent RS treated as not-blocking (documented). |
| — | **Short-side gate: never short from a Stage 2 group (Ch.7 §3.1)** | PASS | weinstein-book-reference.md §3.1 ("Never short a stock from a Stage 2 group"). `_short_candidate` rejects when `sector.rating = Strong` (screener.ml:317). Strong sector = Stage 2 uptrending group; faithful proxy. |
| — | **Short-side entry: Stage 4 only (Ch.7 §6.1 rule 4)** | PASS | weinstein-book-reference.md §6.1 rule 4 ("Stock breaks below support AND below 30-week MA → Stage 4 entry"). `is_breakdown_candidate` only returns true for Stage 4 states (stock_analysis.ml:140–145); `_short_candidate` depends on it (screener.ml:318). No Stage 2/3 short entries possible. |
| — | **Short-side macro gate: bearish-or-neutral only (Ch.7 §6.1 rule 1)** | PASS | weinstein-book-reference.md §6.1 rule 1 ("Market trend is bearish"). `_evaluate_shorts` returns `[]` under Bullish (screener.ml:370). Neutral allowed — book is not explicit on this but the Ch.3 "Weight of Evidence" framework makes Neutral reasonable. Strategy-level concatenation yields shorts under Neutral + Bearish, longs under Bullish + Neutral. |
| — | **Side threads end-to-end: screener candidate → strategy entry transition** | PASS | `scored_candidate.side` populated in `_build_candidate` from `is_short` flag (screener.ml:275–280). Consumed in `_make_entry_transition`: `side = cand.side` in `Position.CreateEntering` (weinstein_strategy.ml:116) and `~side:cand.side` in stop computation (weinstein_strategy.ml:98). `order_generator._entry_order_side` maps `Short → Sell` to produce short-sale orders (inherited from main, not modified). |
| — | **Short position sizing: same shares for equivalent entry/stop pair** | PASS | `_normalised_entry_stop_for_sizing` (weinstein_strategy.ml:67–72) uses `Float.max`/`Float.min` so `entry - stop` diff is always positive; `Portfolio_risk.compute_position_size` sees the same absolute risk-per-share on either side. Adapter is correct (preserves sizer contract). Comment at weinstein_strategy.ml:62 documents rationale. |
| T1 | Tests cover all 4 stage transitions | NA | Stage-transition tests not in scope of this PR (covered by stage classifier tests). |
| T2 | Tests include a bearish-macro scenario producing zero buy candidates | PASS | `test_bearish_macro_no_buys` (test_screener.ml:87–96) pre-existing; still passes. Additionally `test_bullish_macro_no_shorts` (test_screener.ml:98–110) is the mirror for the short path. |
| T3 | Stop-loss tests verify trailing behavior | NA | Trailing-stop tests not in scope of this PR. |
| T4 | Tests assert domain outcomes (correct side, correct signal) | PASS | `test_buy_candidates_are_long` and `test_short_candidates_are_short` (test_screener.ml:363–395) assert `.side = Long/Short`. `test_positive_rs_blocks_short` (test_screener.ml:396–424) injects a Stage-4 breakdown candidate with `Positive_rising` RS and asserts `short_candidates is_empty` — faithful test of Ch.11 hard gate. `test_entries_from_candidates_emits_short` and `test_entries_from_candidates_emits_long` (test_weinstein_strategy.ml:427–498) end-to-end assert the `CreateEntering.side` matches the candidate side through the strategy entry pipeline. |

### Notes on scope adherence

- The MVP scope explicitly defers the full short screener cascade (negative-RS weighting, short-side clean-space resistance), the bear-window backtest regression scenario, and borrow/margin modelling to follow-ups. All three are itemised in `dev/status/short-side-strategy.md §Follow-ups`; none leaked into this PR.
- Book's "volume NOT required for valid breakdown" (§6.2) is consistent with `is_breakdown_candidate` which checks only stage transition (no volume gate) — faithful.
- Book's "pullbacks less frequent on short breakdowns" (§6.2) is not currently encoded — neither before nor after this PR. Not a regression; out-of-scope per plan.

## Quality Score

5 — Exemplary vertical slice: book rules (Ch.11 RS hard gate, Stage-4-only entry, Bearish macro short path, side-aware stop placement) land correctly in one coherent commit series. Tests assert real domain outcomes (side round-trips, positive RS blocks short, bearish gate unchanged). Scope discipline is tight — three explicit follow-ups captured in status file, no out-of-scope code leaked in.

## Verdict

APPROVED

---

## Structural + Behavioral Re-verification @ 937ec93

Date: 2026-04-18 (run 4)
Reviewer: lead-orchestrator (deterministic verification — no fresh QC dispatch required)

### Why re-verification (not fresh review)

Branch tip advanced from `26ff33ede0f335bb4732234b1c0ddebcbdaa236c` (prior APPROVED) to `937ec9356832135c8c5a5412e33ef0be3f3533db`. The single new commit on the branch is `937ec93 Merge origin/main into feat/short-side-strategy`.

### OCaml delta

```
git diff --stat 26ff33ede0..937ec93 -- '*.ml' '*.mli'
# (empty — zero OCaml/MLI files changed)
```

No OCaml source or interface file changed between the two tips. The merge brought in only main-side infrastructure commits (orchestrator.yml, dev/ docs, CI workflow tweaks — see PRs #422 #423 #424 #425). None of those files are part of the short-side-strategy feature scope.

### Hard gates on clean checkout of 937ec93

- `dune build @fmt`: exit 0 (PASS)
- `dune build`: exit 0 (PASS)
- `dune runtest trading/`: exit 0 (PASS) — all 3 test_weinstein_backtest tests green; full trading-subtree runtest clean.

### Verdict

**APPROVED — prior structural + behavioral APPROVED verdicts preserved.**

overall_qc: APPROVED
structural_qc: APPROVED (SHA 937ec93 re-verification: zero OCaml delta from 26ff33ede0)
behavioral_qc: APPROVED (SHA 937ec93 re-verification: zero OCaml delta from 26ff33ede0)

---

# Behavioral QC — short_min_price short-entry gate (PR #1551)

Reviewed SHA: ba6c165b
Date: 2026-06-12
Reviewer: qc-behavioral

PR #1551 (`feat/short-side-min-price`) adds a no-op-default `short_min_price : float [@sexp.default 0.0]`
config field + `Short_min_price_gate.filter`, wired at the short-candidate seam in
`weinstein_strategy_screening.ml`. Default `0.0` = identity (all goldens replay unchanged).
This is a short-side eligibility **dial**, not a stage/stop/cascade change.

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | PASS | `short_min_price_gate.mli` claims: (a) "drops short candidates whose `suggested_entry` strictly below `short_min_price`" → `test_threshold_drops_below_and_retains_above` (drops $10, retains $20 at threshold 15.0); (b) "No-op when `short_min_price <= 0.0`: returns candidates unchanged" → `test_zero_threshold_is_noop` (both tickers retained in order); (c) boundary `>=` (at-threshold retained) → `test_threshold_boundary_is_inclusive` ($15 at threshold 15.0 retained). `weinstein_strategy_config.mli` field docstring claims default-off identity + axis-ability → pinned by the no-op test + the variant-matrix axis test below. |
| CP2 | Each PR-body "Test coverage" claim has a corresponding test in the committed test file | PASS | PR body / plan §Acceptance advertise: no-op default (`test_zero_threshold_is_noop` ✓), below dropped / at-above retained (`test_threshold_drops_below_and_retains_above` ✓), boundary inclusive (`test_threshold_boundary_is_inclusive` ✓), longs untouched (`test_gate_does_not_touch_long_list` ✓), axis expands (`test_short_min_price_axis_expands` in test_variant_matrix.ml ✓). All five exist in the committed test files. No advertised test is missing. |
| CP3 | Pass-through / identity tests pin identity, not just size_is | PASS | The no-op (identity) contract is pinned by `test_zero_threshold_is_noop`, which asserts `elements_are [equal_to "LOW"; equal_to "HIGH"]` on the ticker list — membership AND order, not bare `size_is`. The `<= 0.0` branch returns the input list by reference (structural identity); the ticker+order assertion is an adequate observable proxy. Minor: the test asserts ticker identity rather than whole-`scored_candidate` equality, but since the no-op path returns the literal input list unchanged, this faithfully pins the byte-for-byte contract. Not a FAIL. |
| CP4 | Each guard in code docstrings has a test exercising the guarded scenario | PASS | Guard 1: `<= 0.0` short-circuit (no-op) → `test_zero_threshold_is_noop`. Guard 2: strict-below drop with inclusive boundary (`>=`) → `test_threshold_boundary_is_inclusive` pins the exact-at-threshold edge the `>=` guard protects. Both guarded edges have dedicated tests. |

## Behavioral Checklist (Weinstein domain)

| # | Check | Status | Notes (cite authority) |
|---|-------|--------|------------------------|
| A1 | Core module modification is strategy-agnostic | NA | qc-structural did not flag A1. New module `weinstein/strategy/gate/lib/short_min_price_gate.{ml,mli}`; no core (Portfolio/Orders/Position/Strategy-iface/Engine) module modified. |
| S1 | Stage 1 definition matches book | NA | Stage classifier not touched. |
| S2 | Stage 2 definition matches book | NA | Not touched; Stage-2 buy criteria unchanged. |
| S3 | Stage 3 definition matches book | NA | Not touched. |
| S4 | Stage 4 definition matches book | NA | Not touched. |
| S5 | Buy criteria: Stage 2 entry on breakout + volume | NA / PASS | Long path untouched — the gate is applied only to `screen_result.short_candidates`; `buy_candidates` are concatenated unchanged (weinstein_strategy_screening.ml:401–403). No regression to buy criteria. |
| S6 | No buy signals in Stage 1/3/4 | NA | Buy path unchanged. |
| L1 | Initial stop below base (long) / above ceiling (short) | NA | Stop placement not modified. |
| L2 | Trailing stop never lowered/raised | NA | Trailing logic not modified. |
| L3 | Stop triggers on weekly close | NA | Not modified. |
| L4 | Stop state machine transitions correct | NA | Not modified. |
| C1 | Screener cascade order | NA | Cascade not modified. The gate is a post-screener candidate filter at the strategy seam, after `_run_screener`, not a change to cascade order. |
| C2 | Bearish macro blocks all buy candidates | NA | Macro gate not modified. Gate only narrows shorts by price; never adds a short or relaxes any gate. |
| C3 | Sector RS vs market, not absolute | NA | Sector logic not modified. |
| T1 | Tests cover all 4 stage transitions | NA | Not in scope. |
| T2 | Bearish-macro → zero buy candidates test | NA | Macro path unchanged; existing screener tests still pin it. |
| T3 | Stop trailing tests over multiple advances | NA | Not in scope. |
| T4 | Tests assert domain outcomes, not just "no error" | PASS | Gate tests assert concrete domain outcomes: which tickers survive the price floor (`elements_are`), boundary inclusivity (count = 1 at exact threshold), and that the short list empties while the long list is untouched. The axis test asserts the resolved override sexp `((short_min_price 17.0))` and label, not merely "did not raise". |
| W1 | Spine intact (Weinstein faithful core 1–7) | PASS | weinstein-faithful-core.md §spine. The gate filters short *candidates* by an economic price floor. It does not touch: stage classification (1), Stage-2-only buy (2), breakout+volume entry (3), Stage 3/4 sell (4), initial stop below base (5), macro+sector gates (6), or RS selection (7). It can only *remove* short candidates — never adds an entry, never relaxes a gate, never changes a stage decision. Spine untouched. |
| W2 | Adaptation is a dial, config-expressed, with authority | PASS | weinstein-faithful-core.md §dials ("numeric thresholds tuned for the modern regime"). A min-price floor on short eligibility is an economic-viability eligibility threshold — a faithful dial. It is config-expressed as a real `Weinstein_strategy.config` float field (`short_min_price`, not a hardcoded constant), routes through `Overlay_validator`, and cites authority: margin research `dev/notes/long-short-margin-mechanics-2026-06-12.md` (sub-$17 shorts carry 83–362% maintenance margin). The book (§6 Short-Selling Criteria) does not prescribe a price floor, so this is a faithful modern-regime adaptation of a numeric threshold, not a spine change. |
| W3 (R1) | Default-off on merge | PASS | experiment-flag-discipline.md R1. Field carries `[@sexp.default 0.0]`; `default_config` sets `short_min_price = 0.0`; gate short-circuits to identity when `<= 0.0`. Pre-existing behavior preserved bit-for-bit; pinned by `test_zero_threshold_is_noop`. |
| W3 (R2) | Searchable axis the day it lands | PASS | experiment-flag-discipline.md R2. Real top-level `config` float field; `test_short_min_price_axis_expands` proves `((short_min_price ...))` expands as a `Variant_matrix` float axis AND passes `Overlay_validator` validation — `VM.expand` calls `_validate_override` → `Overlay_validator.apply_overrides` (variant_matrix.ml:98–112,140–142), which raises `Failure` on an unknown key-path. The test succeeding proves the field resolves. |
| W3 (R3) | No default-on without ledger ACCEPT | PASS | experiment-flag-discipline.md R3. No default flipped; `enable_short_side` default stays `true` (untouched), `short_min_price` default stays `0.0` (no-op). Not wired into any default config or preset. No ACCEPT cited because none is needed (no promotion). |
| — | Longs untouched (the one real domain risk) | PASS | The seam applies `Short_min_price_gate.filter` exclusively to `screen_result.Screener.short_candidates`; `buy_candidates` is a separate list field (screener.mli:281–282) concatenated untouched (weinstein_strategy_screening.ml:401–403). The whole expression is inside `if config.enable_short_side` — with shorts disabled the field is never read. The gate `filter` is itself side-agnostic (filters purely on `suggested_entry`), so even a hypothetical mis-wire would drop on price not side; but the wiring never routes longs through it. `test_gate_does_not_touch_long_list` documents the invariant (longs held separately survive while gated shorts drop). |

### Notes on scope adherence

- Pure additive change behind a no-op default; no golden/baseline changes (the `<= 0.0` short-circuit returns the input list unchanged).
- `test_gate_does_not_touch_long_list` is closer to a documentation-of-invariant than a strong behavioral pin (it never actually routes a Long through the gate — it asserts a separately-held long list is unaffected). The seam reading confirms the real invariant holds, so this is acceptable, not a FAIL. A stronger end-to-end test would gate a mixed `buy_candidates @ short_candidates` flow and assert longs survive regardless of `short_min_price`; noted as a (minor) optional hardening, not a blocker.

## Quality Score

5 — Textbook experiment-flag-discipline slice: no-op default, real searchable config axis, spine untouched, economic-viability dial with cited authority. Contracts in the `.mli` are each pinned by a focused test asserting the domain outcome; the axis test correctly leans on `Overlay_validator` validation at expansion time. Clean, well-scoped, well-documented.

## Verdict

APPROVED

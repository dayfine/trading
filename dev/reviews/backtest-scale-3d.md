Reviewed SHA: 36311b6dc3d71e68c802b3a3a26e83f2fe99e4b5

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | No format errors in this branch's files |
| H2 | dune build | PASS | Clean build |
| H3 | dune runtest | PASS | All test failures are pre-existing on main@origin (fn_length linter: runner.ml line 193 run_backtest 56 lines; file-length linter: weinstein_strategy.ml 320 lines; magic-number linter: trace.ml:1024 comment, weinstein_strategy.ml:11; nesting linter: analysis/scripts violations; arch-layer linter: weinstein/screener violations). None introduced by this branch. New test_trace_integration.ml: 7 tests pass. |
| P1 | Functions ≤ 50 lines — covered by fn_length_linter (dune runtest) | PASS | No new function in this branch exceeds 50 lines. _maybe_trace: 4 lines; promote: 27 lines; _demote_one: 23 lines; demote: 4 lines. |
| P2 | No magic numbers — covered by linter_magic_numbers.sh (dune runtest) | PASS | No bare numeric literals introduced in lib/ files. Test fixture uses named constant history_days = 420. |
| P3 | All configurable thresholds/periods/weights in config record | PASS | No tunable thresholds introduced. The trace_hook is a callback injection point, not a tunable parameter. |
| P4 | .mli files cover all public symbols — covered by linter_mli_coverage.sh (dune runtest) | PASS | tier_op, trace_hook types fully documented in bar_loader.mli. Promote_summary, Promote_full, Demote variants documented with inline comments in trace.mli. |
| P5 | Internal helpers prefixed with _ | PASS | _maybe_trace is correctly prefixed. All other new let bindings are either type definitions or existing public functions (promote, demote) that already existed in the interface. |
| P6 | Tests use the matchers library (per CLAUDE.md) | PASS | test_trace_integration.ml: open Matchers; uses assert_that, elements_are, equal_to, size_is, ge, match_phase_metrics throughout. test_trace.ml (extended): same pattern. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No modifications to any core trading modules. Changed files: bar_loader.{ml,mli}, lib/trace.{ml,mli}, test/test_trace.ml, test/dune, dev/status/backtest-scale.md. |
| A2 | No imports from analysis/ into trading/trading/ | PASS | No analysis/ imports in any changed file. |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | trace.ml/trace.mli modifications are precisely scoped to add 3 Phase.t variants — this is the stated feature. test_trace.ml sexp round-trip test extended by 3 lines to cover the new variants. All in-scope. |

## Dependency cycle rationale (A2 extension)

The local `tier_op` type in `bar_loader.mli` avoids a future `bar_loader → backtest` dependency that would cycle once 3e makes `backtest → bar_loader`. The test file (`test_trace_integration.ml`) imports both `trading.backtest.bar_loader` and `backtest` — this is correct: tests sit outside the lib dependency graph and serve as the wire site that validates the adapter contract. The `_hook_forwarding_to` adapter in the test mirrors exactly what 3e's runner will implement.

## No-trace path coverage

`test_no_hook_promote_is_silent` exercises all three operations (promote Summary, promote Full, demote) without a registered hook and asserts the separately-owned Trace.t contains zero records. The `_maybe_trace` implementation's `None` branch is a direct `f ()` passthrough with no side effects, satisfying the parity guarantee precondition for 3g.

## Verdict

APPROVED

## Staleness note

Branch is 7 commits behind main@origin by the staleness check formula. This count includes commits that are ancestors of both branches (the formula counts `main@origin ~ ancestors(feat/...)` which includes shared ancestors). Actual divergence point is one commit (main@origin = HEAD~1 of this branch). No rebasing needed.

---

# Behavioral QC — backtest-scale 3d (tracer phases for tier operations)
Date: 2026-04-19
Reviewer: qc-behavioral

## Scope note

3d is infrastructure-only — a tracer hook + three `Phase.t` variants plumbed through `Bar_loader.promote` / `.demote`. No Weinstein trading logic is introduced or modified. No `Bar_history`, `Weinstein_strategy`, `Portfolio`, `Simulator`, or `Screener` changes. Most Weinstein-domain checklist axes are therefore NA. The behavioral review focuses on:
1. **Plan faithfulness** — trace emission rules match the §3d contract in the plan doc.
2. **No-trace silent-path property** — `trace_hook = None` produces observable behaviour identical to the pre-hook version (precondition for the 3g parity gate).
3. **No domain-logic leakage** — the hook payload is an opaque `tier_op` tag + batch size; no strategy-relevant mutation happens inside the callback boundary.

## Behavioral Checklist

| # | Check | Status | Notes (cite authority doc section) |
|---|-------|--------|------------------------------------|
| A1 | Core module modification is strategy-agnostic | NA | qc-structural marked A1 PASS — no core module (Portfolio/Orders/Position/Strategy/Engine) modified; `Bar_loader` and `Backtest.Trace` are already-new infrastructure libraries for this plan. |
| S1 | Stage 1 definition matches book | NA | No stage-classification logic touched. |
| S2 | Stage 2 definition matches book | NA | No stage-classification logic touched. |
| S3 | Stage 3 definition matches book | NA | No stage-classification logic touched. |
| S4 | Stage 4 definition matches book | NA | No stage-classification logic touched. |
| S5 | Buy criteria: Stage 2 entry on breakout with volume | NA | No signal generation touched. |
| S6 | No buy signals in Stage 1/3/4 | NA | No signal generation touched. |
| L1 | Initial stop below base | NA | No stop logic touched. |
| L2 | Trailing stop never lowered | NA | No stop logic touched. |
| L3 | Stop triggers on weekly close | NA | No stop logic touched. |
| L4 | Stop state machine transitions | NA | No stop logic touched. |
| C1 | Screener cascade order | NA | No screener logic touched. |
| C2 | Bearish macro blocks all buys | NA | No macro/screener logic touched. |
| C3 | Sector RS vs. market, not absolute | NA | No sector analysis touched. |
| T1 | Tests cover all 4 stage transitions | NA | Not a stage-classification feature. |
| T2 | Bearish macro → zero buy candidates test | NA | Not a screener feature. |
| T3 | Stop trailing tests | NA | Not a stops feature. |
| T4 | Tests assert domain outcomes, not "no error" | PASS | `test_trace_integration.ml` asserts the exact `Phase.t` variant, batch `symbols_in` count, and insertion order via `elements_are [match_phase_metrics ~phase:... ~symbols_in:...]`. Each test pins the observable contract, not simply that the call returned Ok. |

## Plan-faithfulness checks (3d-specific, supplementing the standard axes)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| PF1 | Plan §3d "Trace emission rules" match implementation | PASS | `bar_loader.ml` `promote` dispatches: `Metadata_tier` → `run_metadata ()` direct (not traced); `Summary_tier` → `_maybe_trace … ~tier_op:Promote_to_summary`; `Full_tier` → `_maybe_trace … ~tier_op:Promote_to_full`. `demote` → `_maybe_trace … ~tier_op:Demote_op ~symbols:(List.length symbols)`. Matches the four bullets in the commit message and plan §3d. |
| PF2 | Metadata promotion stays silent (owned by legacy Load_bars) | PASS | `bar_loader.ml` `promote ~to_:Metadata_tier` calls `run_metadata ()` directly with no `_maybe_trace` wrapper. `test_promote_metadata_is_silent` verifies `snapshot = []` after a Metadata promote with hook attached. Matches plan §3d commit message bullet 1. |
| PF3 | No-hook path is observably silent | PASS | `_maybe_trace`'s `None` branch is a direct `f ()` pass-through with no side effects (`bar_loader.ml` lines 315-318). `test_no_hook_promote_is_silent` exercises Summary-promote + Full-promote + demote with **no** hook attached and asserts a separately-owned `Trace.t` records zero phases. This is the observable-behaviour-equivalence precondition for the 3g parity gate. |
| PF4 | Full promote emits exactly one `Promote_full` phase (internal Metadata/Summary cascade bypasses the outer wrapper) | PASS | `_promote_one_to_full` calls `_promote_one_to_summary` (and transitively `_promote_one_to_metadata`) directly, not through `promote`; only the outer `promote` dispatch enters `_maybe_trace`. `test_promote_full_emits_one_phase` confirms a single `Promote_full` record after Full-tier promotion — no cascading records. |
| PF5 | Demote emits by batch size, not by count of symbols that actually changed tier | PASS | `demote` wraps the entire `List.iter` in one `_maybe_trace` call with `~symbols:(List.length symbols)`. `test_demote_noop_still_emits` confirms a Summary→Summary demote (no-op tier-wise) still emits one `Demote` phase with `symbols_in = Some 1`. Matches plan §3d commit message bullet 4 and .mli documentation. |
| PF6 | Callback boundary keeps `bar_loader` independent of `Backtest.Trace` | PASS | `bar_loader.mli` declares `tier_op = Promote_to_summary | Promote_to_full | Demote_op` distinct from `Trace.Phase.t`. The test's `_hook_forwarding_to` adapter maps `tier_op → Trace.Phase.t`, mirroring the wiring 3e's runner will install. Neither `.ml` nor `.mli` for `bar_loader` imports `Backtest.Trace`. Prevents the future cycle once 3e makes `backtest → bar_loader`. |
| PF7 | Hook is a polymorphic `(unit -> 'a) -> 'a` wrapper matching `Trace.record`'s shape | PASS | `trace_hook.record : 'a. tier_op:tier_op -> symbols:int -> (unit -> 'a) -> 'a` preserves the `Result.t` return of `promote` through the hook (the bar_loader code does `_maybe_trace t ~tier_op ~symbols run_summary` where `run_summary : unit -> (unit, Status.t) Result.t`). Rank-2 polymorphism needed because `demote` returns `unit` and `promote` returns `Result.t`. Correctly typed. |
| PF8 | Tests assert on observable Phase.t mapping via test-matchers (not just call count) | PASS | Each test pins the specific `Phase.t` variant via `equal_to Backtest.Trace.Phase.Promote_summary/Promote_full/Demote` and the `symbols_in` count via `equal_to (Some 1)`. `test_multiple_calls_in_insertion_order` additionally pins the ordered sequence. This is the T4-equivalent domain-outcome assertion for this infrastructure feature. |

## Quality Score

5 — Exemplary for an infrastructure increment. The callback-boundary design is principled (avoids the future `bar_loader ↔ backtest` cycle flagged in the commit message), the no-hook silent-path contract is explicitly tested for all three operations, and the tests pin the exact `Phase.t` → `tier_op` mapping that 3e's runner will depend on. The `_hook_forwarding_to` helper in the test is effectively an executable specification of the 3e wire site. `match_phase_metrics` + `test_matcher` derivation forces the test to be kept in sync with the `phase_metrics` record at compile time.

## Verdict

APPROVED

(All applicable items PASS. No FAILs. All Weinstein-domain axes correctly NA — this increment introduces no trading logic.)

## Domain findings

None. No behavioural change to Weinstein stage analysis, stops, screener, or portfolio logic. The 3g parity gate (next-but-one increment) is the test that will confirm end-to-end behavioural equivalence; 3d contributes the silent no-hook path that makes that gate achievable.

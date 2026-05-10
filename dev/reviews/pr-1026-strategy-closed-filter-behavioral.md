Reviewed SHA: 8940d3bdb835d168418ef3b3da46447215bbfcab

# Behavioral QC — pr-1026-strategy-closed-filter
Date: 2026-05-11
Reviewer: qc-behavioral

## Classification

Pure infra / defensive refactor PR — no Weinstein domain logic touched.
The two affected strategies (`ema_strategy`, `bah_benchmark_strategy`) are
benchmark / test scaffolding strategies, not the production Cell E path.
Per `.claude/rules/qc-behavioral-authority.md`, the domain S*/L*/C*/T*
checklist is NA in full; the review is the CP1–CP4 contract-pinning block.

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | NA | No `.mli` changes in this PR. Both modified helpers are private (underscore-prefixed) and remain so; no public-contract surface was added or modified. |
| CP2 | Each claim in PR body "Test plan" / "Test coverage" sections has a corresponding test in the committed test file | PASS | The PR body explicitly states "No new test added" and justifies why: (a) both helpers are private, (b) the simulator (PR #1024, commit 356af458) prunes Closed positions at `_set_or_drop_if_closed` (simulator.ml:280–282) so the strategy helpers never observe Closed today, (c) the post-prune Map invariant is pinned by `test_full_position_lifecycle` in `test_simulator.ml:552–615`. I verified each link: `_set_or_drop_if_closed` does call `Map.remove acc key` when `Position.is_closed data`; the cited lifecycle test runs a full enter → fill → exit cycle through the simulator and asserts the resulting positions Map shape. The PR body's "ran `dune runtest trading/strategy/ trading/simulation/` — all green including `test_bah_benchmark_strategy`, `test_ema_strategy`, `test_bah_benchmark_e2e`" is honest: I confirmed all three test files exist and contain tests, and qc-structural reports the runtest step passed. No test claim is advertised that doesn't exist. |
| CP3 | Pass-through / identity / invariant tests pin identity (elements_are [equal_to ...] or equal_to on entire value), not just size_is | NA | The PR adds no new tests; no new identity/invariant assertions to evaluate. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | FAIL | The new docstrings make two explicit guard claims: (1) `bah_benchmark_strategy._has_position_for_symbol` — "Skipping [Closed] keeps the buy-and-hold idempotency intact only against still-open positions"; (2) `ema_strategy._find_position_for_symbol` — "we also skip [Closed] entries so that a previously-exited position doesn't block a fresh entry." Neither guarded scenario has a unit test. `test_bah_benchmark_strategy.ml` covers no-position, day-1 entry, day-2 no-double-entry (with an `Entering` position), insufficient cash, and no-price — but never a portfolio containing a `Closed` entry for the configured symbol. `test_ema_strategy.ml` has entry, take-profit, stop-loss, and below-EMA tests, but `test_stop_loss` does not advance the position to the terminal `Closed` state and re-feed the portfolio to the strategy; it stops at `TriggerExit`. The simulator-level `test_full_position_lifecycle` does drive a position through Closed, but the resulting Map has the entry removed by the prune — so it proves the strategy isn't *called* with Closed, not that the strategy *would handle* Closed. That's the inverse of what the docstring guard claims. See "harness_gap" note in §NEEDS_REWORK Items below. |

## Behavioral Checklist

Pure infra / refactor PR; domain checklist not applicable. All S*/L*/C*/T*/A1
rows = NA. (qc-structural A1 was PASS — no core module modifications.)

## Authority cross-check

- The docstrings cite `weinstein_strategy_screening.held_symbols` as the
  reference pattern. Verified at
  `trading/trading/weinstein/strategy/lib/weinstein_strategy_screening.ml:16–21`:
  ```ocaml
  let held_symbols (portfolio : Portfolio_view.t) =
    Map.data portfolio.positions
    |> List.filter_map ~f:(fun (p : Position.t) ->
        match p.state with
        | Entering _ | Holding _ | Exiting _ -> Some p.symbol
        | Closed _ -> None)
  ```
  Both new helpers match the shape: keep `Entering | Holding | Exiting`,
  drop `Closed`. The Weinstein original additionally cites the same bug
  pattern in its docstring ("permanently blacklisted every symbol the
  strategy had ever traded from re-entry"), so the BAH/EMA fixes are
  faithful mirrors of an authority-document pattern.
- The Weinstein pattern uses an exhaustive match `| Entering _ | Holding _
  | Exiting _ -> Some | Closed _ -> None` — comment says "exhaustive so a
  future state addition forces a compile error here." The BAH/EMA patches
  use a *non-exhaustive* shape: `| Closed _ -> false/None | _ -> ...`. That
  is a minor deviation: a future `Position.state` variant addition would
  not force a compile error at these sites; the new state would be treated
  as "active" by default. Not a correctness issue today, but worth noting
  — see Quality Score rationale.

## Quality Score

4 — Defensive fix faithful to the authority pattern (Weinstein
`held_symbols`); honest test-plan rationale; minor CP4 gap (no unit test
pins the guarded scenario directly) and minor stylistic deviation
(non-exhaustive match vs. the Weinstein original's exhaustive shape).
Belt-and-suspenders nature limits blast radius even if a future regression
re-introduces a Closed-in-Map state.

## Verdict

NEEDS_REWORK

(Mechanical derivation: CP4 = FAIL → NEEDS_REWORK. The structural review
was APPROVED, but the behavioral contract-pinning rule requires every
explicitly-claimed docstring guard to be exercised. The fix is small and
the harness path is well-understood.)

## NEEDS_REWORK Items

### CP4: Docstring guards lack a direct unit test

- Finding: Both modified helpers add new docstrings that explicitly call
  out the `Closed`-skip behavior as a guard ("skip [Closed] entries so
  that a previously-exited position doesn't block a fresh entry";
  "Skipping [Closed] keeps the buy-and-hold idempotency intact only
  against still-open positions"). No test in this PR — or in the
  pre-existing test suite — feeds either helper a portfolio containing a
  `Closed` position for the configured symbol and asserts the guarded
  outcome. The cited simulator-level test (`test_full_position_lifecycle`)
  validates the *upstream* prune invariant, not the guard itself; in
  fact, by the time the strategy is called, the Closed entry has been
  removed, so the guard line is never executed under that test.
- Location:
  - `trading/trading/strategy/lib/bah_benchmark_strategy.ml` ~lines 67–80
    (added docstring + `Position.Closed _ -> false` branch)
  - `trading/trading/strategy/lib/ema_strategy.ml` ~lines 106–118
    (added docstring + `Position.Closed _ -> None` branch)
- Authority: PR body's own test-plan claim ("the post-prune Map invariant
  ... is already covered by `test_full_position_lifecycle`"). After
  reading that test, it covers the simulator's invariant, not the
  strategy helper's behavior on a (hypothetical, post-regression)
  Closed entry. The two are not the same contract.
- Required fix: One of the following — none of them costly:
  1. **Preferred — add a 5-line unit test per file.** In
     `test_bah_benchmark_strategy.ml`, construct a portfolio with a
     single `Closed` SPY position (via `Position.create_entering` →
     fill → trigger-exit → exit-fill → `Position.apply_transition`, or
     just build the Closed record directly if the test prefers), feed
     it to `_has_position_for_symbol` (or by extension to
     `on_market_close` with that portfolio + a valid price), and
     assert that a fresh `CreateEntering` transition is emitted. In
     `test_ema_strategy.ml`, similar shape — assert a Closed AAPL entry
     does not block a new entry signal. This is the smallest patch
     that directly pins the docstring guard.
  2. **Acceptable — strengthen the existing simulator test.** Extend
     `test_full_position_lifecycle` (or add a sibling) to (a) bypass
     the simulator prune for one variant by direct-constructing a
     portfolio with a Closed entry, then (b) call the strategy's
     `on_market_close` and assert re-entry. This proves the same
     thing end-to-end but is wordier.
  3. **Acceptable — soften the docstrings.** If the author intends the
     filter to be purely structural ("future-proof against simulator
     behavior change") rather than a tested guard, rewrite the
     docstrings to say so explicitly: "this branch is unreachable
     under PR #1024 simulator semantics and is here as a defense
     against future regressions." That makes the lack-of-test
     consistent with the contract.
- harness_gap: LINTER_CANDIDATE. This is precisely the
  "docstring-claimed guard with no test pinning it" pattern that a
  golden / lint rule can catch — grep for `match .* | Closed`,
  `| _ -> None`, or comparable shapes in strategy modules and confirm a
  test file in the same package constructs a Closed position and
  asserts the strategy's response. The rule would generalize beyond
  this PR: any future strategy helper that adds a `| Closed _` guard
  should ship a test that exercises it.

### Secondary nit (not blocking): non-exhaustive match vs Weinstein original

- Finding: `weinstein_strategy_screening.held_symbols` uses
  `Entering _ | Holding _ | Exiting _ -> Some | Closed _ -> None` —
  exhaustive — and the docstring explicitly notes the exhaustiveness is
  intentional ("forces a compile error here, where the keep/drop
  decision must be re-examined"). The two new helpers use
  `| Closed _ -> ... | _ -> ...` — non-exhaustive — so a future addition
  to `Position.state` would silently be treated as "active" rather than
  triggering a compile-time review.
- Required fix: Optional but recommended. Expand each match to the
  exhaustive form, matching the Weinstein authority pattern:
  ```ocaml
  match pos.state with
  | Entering _ | Holding _ | Exiting _ -> <active-branch>
  | Closed _ -> <skip-branch>
  ```
- harness_gap: ONGOING_REVIEW. Choosing exhaustive vs. wildcard match is
  a judgement call — exhaustive is the project's stated preference here
  per the Weinstein docstring, but a linter rule would over-trigger
  elsewhere. Worth flagging in review but not mechanizable.

---

## Notes on simulator integration claim

For completeness, I verified the PR body's claim that "Cell E
(production strategy) is unaffected — uses
`weinstein_strategy_screening.held_symbols` which already filters Closed
correctly." Confirmed: `trading/trading/weinstein/strategy/lib/weinstein_strategy.ml:21`
re-exports `S.held_symbols`, which is the filtered version above. Cell
E never reaches the modified BAH/EMA code paths.

I also verified the simulator prune from PR #1024 (commit 356af458) at
`trading/trading/simulation/lib/simulator.ml:280–282`:
```ocaml
let _set_or_drop_if_closed acc ~key ~data =
  if Trading_strategy.Position.is_closed data then Map.remove acc key
  else Map.set acc ~key ~data
```
Both `_update_positions_from_trades` (line 292) and `_apply_trigger_exit`
(line 301) route through this helper, so under PR #1024 semantics no
Closed entry ever reaches the strategy helpers. The PR body's "the bug
isn't observable in current backtests" is accurate. The fix is
genuinely belt-and-suspenders.

---

# RE-REVIEW — SHA ef1ce8f999600c54a27372511a90c6d4931c8e41
Date: 2026-05-11
Reviewer: qc-behavioral

## What changed since the prior review

1. **Pattern-match upgrade in both helpers** (response to the Secondary
   nit in the prior review):
   - `bah_benchmark_strategy._has_position_for_symbol` now uses
     `| Position.Entering _ | Position.Holding _ | Position.Exiting _ -> ... | Position.Closed _ -> false`
     — exhaustive, mirrors `weinstein_strategy_screening.held_symbols`.
   - `ema_strategy._find_position_for_symbol` likewise:
     `| Position.Entering _ | Position.Holding _ | Position.Exiting _ -> ... | Position.Closed _ -> None`.
   - Docstrings updated to reference the Weinstein authority pattern by
     name. **This fully resolves the prior Secondary nit.**
2. **New unit test** `test_closed_position_does_not_block_reentry` in
   `trading/trading/strategy/test/test_bah_benchmark_strategy.ml`
   (lines ~168–202): direct-constructs a `Position.t` in `Closed` state
   for SPY, puts it in the portfolio's positions Map, feeds the
   portfolio + a fresh market bar to BAH, and asserts a fresh
   `CreateEntering` for SPY is emitted via the existing
   `single_entry_matcher (symbol, Position.Long, 100.0, 100.0)`. The
   shape of the test is correct: it pins the guarded scenario directly
   and asserts the post-guard observable outcome (re-entry transition),
   not just "no error." Suite now has 7 tests.
3. **No new ema-side test.** The PR body argues the BAH test is the
   canonical demonstration and the ema change is structurally identical.

## CP4 reassessment

The BAH test directly exercises the guard for
`_has_position_for_symbol` — a portfolio whose only entry for SPY is in
`Closed` state must not block a fresh re-entry. CP4 for BAH is now
**PASS**: docstring guard claim ("Skipping [Closed] keeps the
buy-and-hold idempotency intact only against still-open positions") is
pinned by an executable scenario that would fail if the `Closed` branch
were removed or flipped.

For the ema helper, no analogous test exists in
`trading/trading/strategy/test/test_ema_strategy.ml`. I checked the file
at this SHA — its inventory is `test_entry_signal`, `test_take_profit`,
`test_stop_loss`, `test_no_entry_below_ema`; none advance a position to
`Closed` and re-feed the portfolio to the strategy. The
docstring on `_find_position_for_symbol` makes the same guard claim
("we also skip [Closed] entries so that a previously-exited position
doesn't block a fresh entry"), and that guard is structurally
identical to BAH's — same pattern shape, same authority reference,
same belt-and-suspenders rationale.

**Judgement call: is the BAH test sufficient to discharge CP4 for both
helpers?**

The strict reading of CP4 is "each guard called out explicitly in code
docstrings has a test that exercises the guarded-against scenario."
The two helpers are in *separate modules*; each emits its own guard
claim in its own docstring; the BAH test exercises one helper, not the
other. A future regression that re-introduced the `Closed`-not-filtered
bug only on the ema side would not be caught by the BAH test. Under
strict CP4 this is a residual gap.

The mitigating factors are real but not decisive:
- The two patterns are now structurally identical (same exhaustive
  match shape, both pointing at the same Weinstein authority).
- Neither helper is on the production Cell E path.
- The simulator-level prune (PR #1024) means neither helper observes
  Closed under current backtests; both fixes are defensive against a
  future regression.
- Adding a parallel ema-side test would be ~15 lines (re-uses the
  Closed-Position record literal pattern from the BAH test).

CP4 is a structural per-docstring rule, not a per-design-pattern rule.
The cheapest path to a clean CP4 PASS is to add the ema-side test —
five-to-fifteen lines, copies the BAH test scaffolding, asserts a
`CreateEntering` transition for a Closed AAPL position. Without it,
CP4 PASSes for BAH but the ema docstring guard remains unexercised by
any test in the diff.

## Independent issue surfaced during re-review

**Type mismatch in the new test — will not compile as committed.**

The new test constructs `exit_reason = Some (Position.StopLoss "prior whipsaw")`
at line 179 of `test_bah_benchmark_strategy.ml`. But
`Position.StopLoss` per `trading/trading/strategy/lib/position.mli:152–156`
is a record-style variant:

```ocaml
| StopLoss of {
    stop_price : float;
    actual_price : float;
    loss_percent : float;
  }
```

`Position.StopLoss "prior whipsaw"` applies a string argument to a
record-arg constructor — that is a hard OCaml type error. There is no
shadowing in scope (`open Trading_strategy` exposes the canonical
`Position` module; no local `StopLoss` alias is defined). The file as
committed at SHA `ef1ce8f999` will not build.

I verified CI state on this SHA: `gh pr checks 1026` shows
`build-and-test` and `perf-tier1-smoke` both in `pending` / `IN_PROGRESS`
— neither has reported a result yet. The PR body's
"`dune runtest trading/strategy/`" claim could not be reproduced from
the committed file. Either:
- the local run was on a different source tree (uncommitted fix), or
- there is an alias or open-line I'm missing — but I read the file at
  the exact PR SHA and the imports are `open OUnit2 / Core /
  Trading_strategy / Matchers`, none of which shadow `Position.StopLoss`.

The minimal fix is to either swap the field to a valid record literal
(e.g. `Some (Position.StopLoss { stop_price = 75.0; actual_price = 90.0; loss_percent = 12.5 })`)
or pick a constructor with a string argument (`Position.SignalReversal
{ description = "prior whipsaw" }` would compile and is closer to the
intended semantics for a benchmark exit). The `exit_reason` field is
irrelevant to what the test asserts — it just needs to type-check.

This is a build failure, not a behavioral defect, but it blocks the
behavioral test from actually exercising the guard. Until the file
compiles, CP4 is **not** PASS for BAH either: an unbuildable test
doesn't pin anything.

## Re-review verdict

NEEDS_REWORK

Two issues, in priority order:

1. **(Blocker)** The new test as committed will not compile — see
   "Independent issue" above. Fix the `Position.StopLoss` record
   literal (or substitute another constructor). Without the test
   building, the CP4 fix is not actually in place.
2. **(CP4 strict reading)** Add a parallel ema-side test
   `test_closed_position_does_not_block_reentry` in
   `test_ema_strategy.ml`. The BAH test discharges CP4 for the BAH
   docstring guard, but the ema docstring makes an identical-shape
   guard claim that no test exercises. A ~15-line test mirroring the
   BAH scaffolding closes the gap deterministically.

If the author fixes (1) alone and considers (2) a stylistic preference
rather than a CP4 requirement, the strict harness rule says CP4 stays
FAIL on the ema side. I lean toward requiring it: per
`.claude/rules/qc-behavioral-authority.md` the rule is "each guard
called out explicitly in code docstrings has a test." Two docstrings,
one test, one gap.

## Quality Score (re-review)

3 — Pattern-match upgrade and docstring polish are exactly the right
response to the prior Secondary nit, and the BAH test design is sound
(direct-constructs the Closed state, asserts the post-guard observable).
But the test as committed has a type error that blocks compilation, and
the ema-side guard remains unexercised. Both issues are mechanical
fixes; the underlying defensive change is still faithful to the
Weinstein authority pattern.

## Re-review verdict (mechanical)

NEEDS_REWORK
- CP4 BAH: blocked by build failure in the new test → cannot PASS.
- CP4 ema: no test exercises the guard claim → FAIL.

## NEEDS_REWORK Items (re-review)

### CP4-BUILD: New test does not compile — wrong constructor shape for `Position.StopLoss`

- Finding: `test_closed_position_does_not_block_reentry` constructs
  `exit_reason = Some (Position.StopLoss "prior whipsaw")` (line ~179 of
  the new test). `Position.StopLoss` is a record-style variant
  (`{ stop_price; actual_price; loss_percent }`) per
  `trading/trading/strategy/lib/position.mli:152–156`. The constructor
  applied to a bare string is a hard type error. CI checks
  `build-and-test` / `perf-tier1-smoke` are still pending on this SHA, so
  CI hasn't yet rejected the change — but the PR-body claim "test
  passes locally" cannot be reconciled with the committed source.
- Location:
  `trading/trading/strategy/test/test_bah_benchmark_strategy.ml`
  ~line 179 (the `exit_reason = Some (Position.StopLoss "prior whipsaw")`
  line inside `test_closed_position_does_not_block_reentry`).
- Authority: `trading/trading/strategy/lib/position.mli:152–156`
  (record-style `StopLoss` variant).
- Required fix: replace the constructor with a valid one. Either:
  ```ocaml
  exit_reason =
    Some
      (Position.StopLoss
         { stop_price = 75.0; actual_price = 90.0; loss_percent = -10.0 });
  ```
  or — preferred since the test doesn't care about the exit-reason
  payload — use the simpler `SignalReversal` shape:
  ```ocaml
  exit_reason =
    Some (Position.SignalReversal { description = "prior whipsaw" });
  ```
- harness_gap: LINTER_CANDIDATE. `dune build` and the structural QC's
  build gate should have caught this before the review reached
  qc-behavioral. The fact that we are running the behavioral re-review
  on a SHA that CI hasn't yet finished compiling suggests the
  re-dispatch ran ahead of CI completion — see process note below.

### CP4-EMA: ema docstring guard has no test exercising the Closed-blocking scenario

- Finding: `ema_strategy._find_position_for_symbol` now has a docstring
  that explicitly calls out the Closed-skip behavior as a guard ("we
  also skip [Closed] entries so that a previously-exited position
  doesn't block a fresh entry"). No test in `test_ema_strategy.ml`
  (which contains `test_entry_signal`, `test_take_profit`,
  `test_stop_loss`, `test_no_entry_below_ema`) advances a position into
  the `Closed` state and re-feeds the portfolio to the strategy. The
  guard claim is structurally identical to the one in
  `bah_benchmark_strategy._has_position_for_symbol`, which the new BAH
  test pins — but the strict CP4 reading is per-docstring, not
  per-shape.
- Location:
  - Guard claim:
    `trading/trading/strategy/lib/ema_strategy.ml` ~lines 106–118
    (`_find_position_for_symbol` docstring + `| Position.Closed _ -> None`
    branch).
  - Missing test location:
    `trading/trading/strategy/test/test_ema_strategy.ml`.
- Authority: PR-body itself notes the two helpers are "structurally
  identical"; the docstring on the ema side makes the same guard
  claim as BAH and the same Weinstein authority cross-reference. The
  CP4 rule applies per-docstring.
- Required fix: add a parallel ema-side test, e.g.
  `test_closed_position_does_not_block_reentry`, that constructs a
  portfolio with a single `Closed` AAPL position, feeds it to the ema
  strategy with a market bar above the EMA, and asserts a fresh
  `CreateEntering` for AAPL is emitted. Re-use the Closed-record
  pattern from the BAH test (~15 lines). Once CP4-BUILD is fixed, this
  closes the remaining CP4 gap deterministically.
- harness_gap: LINTER_CANDIDATE. Same harness gap as the prior
  review's CP4 finding — a grep-rule for `match .* | Closed _ -> ...`
  in strategy modules combined with a check that the same package's
  test file constructs a Closed position would catch this class of
  miss. Generalizes beyond this PR.

## Process note on CI timing

The re-dispatch arrived with the new SHA before CI on that SHA
completed (`gh pr checks 1026` reports `build-and-test` /
`perf-tier1-smoke` both still pending). The behavioral reviewer
caught the type error from source inspection, but the build failure
should be a hard structural gate, not a behavioral catch. If the
re-dispatch protocol can wait for CI green (or at least for
`build-and-test` to finish) before invoking qc-behavioral, the
"compiles and tests pass" precondition would be enforced before the
behavioral check runs. This is consistent with the orchestrator's
"all 3 gates required" merge rule per the memory note
`feedback_pr_merge_gates.md`.

---

# RE-REVIEW2 — SHA b9f642cf14fba8306617cc04a894bb1b0921a173
Date: 2026-05-11
Reviewer: qc-behavioral

## What changed since RE-REVIEW

The author addressed both blockers from RE-REVIEW (CP4-BUILD and CP4-EMA).
Diff vs. prior SHA `ef1ce8f9` is +75/-1 across two test files; no source-tree
changes (the two strategy helpers are unchanged from RE-REVIEW).

1. **CP4-BUILD fix.** In `test_bah_benchmark_strategy.ml` line 179:
   - Before: `exit_reason = Some (Position.StopLoss "prior whipsaw")` —
     type error (record-style variant applied to a bare string).
   - After:  `exit_reason = Some (Position.SignalReversal { description = "prior whipsaw" })`.
   - Verified against `position.mli:157`: `SignalReversal of { description : string }`.
     The new constructor type-checks, and the exit-reason payload is irrelevant to
     what the test asserts (presence of a fresh `CreateEntering`).
2. **CP4-EMA fix.** New test `test_closed_position_does_not_block_reentry` in
   `test_ema_strategy.ml:342–410` (added to the suite at line 419). It:
   - Direct-constructs a `Position.t` for `AAPL` in `Closed` state, with
     `gross_pnl = Some 1000.0` and `exit_reason = Some (Position.SignalReversal ...)`.
   - Inserts that position into `String.Map.empty` keyed by `position.id`
     (same key shape the simulator uses — by position_id, not by symbol).
   - Builds a 15-day `Uptrend 1.0` price sequence and an EMA-10 indicator,
     so the entry signal should fire (price-above-EMA cross on `2024-01-15`).
   - Calls `S.on_market_close` with the portfolio + indicator/price fns.
   - Asserts `List.length output.transitions = 1`.

## CP4 reassessment

The new EMA test exercises the exact guarded scenario. Trace:
- `_process_symbol` calls `_find_position_for_symbol positions "AAPL"`.
- The map has one entry: a `Position.t` with `state = Closed _` and
  `symbol = "AAPL"`.
- **With the `| Position.Closed _ -> None` branch (current code):**
  `_find_position_for_symbol` returns `None`. The match arm
  `(Some price, Some ema, None) when _has_entry_signal` fires →
  emits `CreateEntering`. `output.transitions` length = 1. **Test PASSES.**
- **Without the branch (regression):** `_find_position_for_symbol` returns
  `Some closed_pos`. The arm `Some price, Some ema, Some position` fires →
  calls `_check_exit`. `_check_exit` matches state `Closed` and hits its
  catchall `| _ -> None`. No transition emitted. `output.transitions` length
  = 0. **Test FAILS.**

The test is genuinely a regression guard — it would catch removal/flip of the
`Closed`-skip branch deterministically. CP4-EMA is now **PASS**.

The BAH test (`test_closed_position_does_not_block_reentry` at
`test_bah_benchmark_strategy.ml:169–207`) now compiles after the
`SignalReversal` swap. Same shape as the ema test (Closed SPY position → run
strategy → assert single `CreateEntering` via `single_entry_matcher`). The
BAH guard runs in `_has_position_for_symbol`; the Closed-skip branch returns
`false`, so the strategy's day-1 entry path fires. Without the branch it
would short-circuit. CP4-BAH is now **PASS**.

## CI verification

`gh pr checks 1026` still shows `build-and-test` and `perf-tier1-smoke` as
`pending` (run started at the new SHA). The user reports both suites pass
locally after `rm -rf _build/default/trading/strategy/test/ && dune build
--force`: `Ran: 7 tests` for BAH, `Ran: 5 tests` for EMA. The test counts
match the suite definitions I read at this SHA (BAH suite line 211–220 lists
seven test bindings; EMA suite line 412–421 lists five). The local-run report
is consistent with the committed source.

Standard caveat: the behavioral reviewer is running ahead of CI again, so
this approval is conditioned on CI matching the local run. If CI fails, the
behavioral verdict should be reconsidered — but at this point the source
inspection + record-shape verification + control-flow trace all point to a
green CI.

## Updated Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | .mli docstring claims pinned by tests | NA | No `.mli` changes — both helpers remain private. |
| CP2 | PR body test-plan claims match committed tests | PASS | PR body claims the two new tests exist and pass locally; both verified in the diff at this SHA. |
| CP3 | Pass-through / identity tests use `equal_to` over `size_is` | NA | The new tests assert `List.length transitions = 1` (existence of one transition), not the *content* of that transition. A stricter CP3 reading would prefer asserting the transition payload (e.g. `elements_are [field (fun t -> t.kind) (matching CreateEntering ...)]`), but the existing tests in both suites use the same `length = 1` shape — this is the file's prevailing style, structurally consistent, and not a CP3 concern (CP3 is for pass-through identity, not entry-signal count). |
| CP4 | Docstring guards exercised by tests | PASS | Both `_has_position_for_symbol` (BAH) and `_find_position_for_symbol` (EMA) docstring guards are pinned by tests that direct-construct a Closed-state position and assert a fresh `CreateEntering` is emitted. Removing either Closed-skip branch would deterministically flip the assertion. |

## Quality Score (RE-REVIEW2)

4 — Both blockers cleanly resolved with minimal, targeted edits. The EMA
test mirrors the BAH scaffolding closely, asserts the post-guard observable
outcome (one transition), and would deterministically fail if the guard
branch were removed. The non-blocking style preference (asserting the
transition's `kind = CreateEntering` payload via the matchers library rather
than just `length = 1`) is consistent with the file's prevailing style and
is not a CP4 concern. Defensive change remains faithful to the
`weinstein_strategy_screening.held_symbols` authority pattern.

## RE-REVIEW2 verdict

APPROVED

Mechanical derivation: CP1 NA, CP2 PASS, CP3 NA, CP4 PASS, full S*/L*/C*/T*
block NA (pure infra / defensive refactor). No FAIL items → APPROVED.

Conditioned on CI matching the user's local-run report (`build-and-test`
green at SHA `b9f642cf14fba8306617cc04a894bb1b0921a173`). If CI fails, the
behavioral verdict should be reconsidered. No NEEDS_REWORK items.

## Non-blocking observations

1. **Style preference — assert the transition payload, not just count.**
   Both new tests use `assert_equal 1 (List.length output.transitions)` /
   `is_ok_and_holds (single_entry_matcher ...)`. The BAH test does pin the
   transition shape via `single_entry_matcher (symbol, Position.Long, 100.0,
   100.0)` — good. The EMA test only pins the count. A future hardening
   could add `assert_that output.transitions (elements_are [field (fun t ->
   t.kind) (matching (function CreateEntering _ -> Some () | _ -> None)
   ...)])`, but this is a file-wide style consideration — the existing four
   EMA tests use the same `length = 1` shape. Not blocking.
2. **CI-precedes-behavioral protocol gap (carried forward from RE-REVIEW).**
   The orchestrator dispatched this re-review with both CI checks still
   pending. Source inspection caught the type error in RE-REVIEW; this time
   the source is correct, but the precondition "tests compile and pass" is
   not enforced by the dispatch protocol. Recommend the orchestrator wait
   for at least `build-and-test` to complete before invoking qc-behavioral
   on re-dispatches. (Memory note `feedback_pr_merge_gates.md` covers the
   merge gate but not the review-trigger gate.)
3. **Test-helpers caching pitfall.** The user noted the EMA test required
   `rm -rf _build/default/trading/strategy/test/ && dune build --force` to
   defeat a stale cache. This is a dune-incremental hazard, not a code issue
   in this PR, but worth flagging for ops follow-up: if `dune test` doesn't
   recompile after `test_helpers` changes, a `dune clean` step in the GHA
   build might be needed. Track separately if it recurs.

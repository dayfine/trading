Reviewed SHA: e6f9207f7a5607c8336586453d90ccee041107b6

## Structural QC — trade-audit external exits (PR #2085, issue #2076)

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | Orchestrator-provided evidence: exit 0 on `e6f9207f`. |
| H2 | dune build | PASS | Orchestrator-provided evidence: exit 0 on `e6f9207f`. |
| H3 | dune runtest | PASS | Orchestrator-provided evidence: full suite (128 test binaries), exit 0, zero `^FAIL:` lines. |
| P1 | Functions ≤ 50 lines (linter) | PASS | H3 clean; new functions in `trade_audit.ml` (`_external_exit_of_transition`, `_fill_in_external_exit`, `_process_transition_for_external_exit`, `record_transitions`) are all small (≤6 lines). |
| P2 | No magic numbers (linter) | PASS | H3 clean; diff-scan of production files (`trade_audit.ml/.mli`, `panel_runner.ml`) for new numeric literals found only `#2076` in a doc comment. No new tunables introduced. |
| P3 | All configurable thresholds/periods/weights in config record | NA | Pure plumbing/capture change — no new threshold, period, or weight introduced. |
| P4 | Public-symbol export hygiene (mli coverage) | PASS | H3 clean; new public symbols (`external_exit_decision`, `record_transitions`, `audit_record.external_exit`) all have `.mli` doc comments (verified by reading the diff — thorough docstrings). |
| P5 | Internal helpers prefixed per convention | PASS | `_external_exit_of_transition`, `_fill_in_external_exit`, `_process_transition_for_external_exit`, `_on_transitions` (panel_runner.ml) all underscore-prefixed. |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | PASS | Sub-rule 1 (`List.exists ... equal_to true/false`): no hits in either new/modified test file. Sub-rule 2 (`let _ = ...on_market_close/.run`, result ignored): no hits. Sub-rule 3 (bare `match ... Ok/Error -> assert_failure` without `assert_that`): `test_trade_audit_external_exits.ml` uses `match create ~config ~deps with | Ok s -> s | Error e -> assert_failure (...)` and `match run sim with | Ok r -> result_ref := Some r | Error err -> assert_failure (...)` inside a setup helper (`_run_and_collect_trade_audit`) to unwrap the simulator run before the real domain assertions happen afterward via `assert_that`/`is_some_and`/`field`. This is a pre-existing, widespread codebase idiom (identical pattern verified in `test_margin_exit_observability.ml` — the file this test explicitly mirrors — plus 7 other files under `simulation/test/` and `backtest/test/`), not new drift introduced by this PR, and every actual test assertion in this file and in `test_trade_audit.ml`'s new tests uses proper `assert_that (... is_some_and / all_of / field ...)` composition. Treated as conformant. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | `git diff --stat` confirms zero touches under `trading/trading/{portfolio,orders,position,strategy,engine}/`. All source changes are under `trading/trading/backtest/lib/` and `trading/trading/backtest/test/` (not core). No FLAG needed. |
| A2 | No new `analysis/` imports into `trading/trading/` outside the backtest exception surface | PASS | Only dune file touched in the diff is `trading/trading/backtest/test/dune`, which adds a module name (`test_trade_audit_external_exits`) to the existing test-executable list — no new library dependency added. `trading/trading/backtest/lib/dune` is untouched. No new `analysis/` import surface introduced. |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS (with note) | File list from `gh pr view 2085 --json files` (18 files) exactly matches `git diff --stat` (18 files) — no ancestry contamination. The 8 non-core test-file touches (`test_screen_record.ml`, `test_release_perf_report.ml`, `test_result_writer.ml`, `test_runner_filter.ml`, `test_trade_audit_html_report.ml`, `test_trade_audit_ratings.ml`, `test_trade_audit_report.ml`, `test_trade_context.ml`) are all mechanically required 1-line-per-site additions of `external_exit = None` to existing `audit_record` literal constructors, forced by the additive record-field change — not scope creep. **Note:** `trading/compile_commands.json` is also touched (1-line diff, opam interpreter path `5.3` → `5.3.0+flambda`) — this is machine-generated build-environment noise unrelated to the feature, not a real source change. It is a pre-existing repo pattern (same file was touched by an unrelated PR #1299) rather than something introduced by this PR's intent; does not affect behavior or build correctness. Flagging for visibility, not failing — this is cosmetic environment churn, not cross-feature drift into logic. |

## PR body / issue-closure convention check

PR body opens with "Partially addresses #2076" (not "Closes #2076"), matches the residual `harvest_rotate` gap called out explicitly in both the PR body and the `.mli` docstring for `record_transitions`. `harvest_rotate` emits `Position.TriggerPartialExit` (confirmed via `harvest_rotate_runner.ml` line 25), not `TriggerExit` — `record_transitions`'s `match trans.kind with | TriggerExit {...} -> ... | _ -> ()` correctly and structurally excludes it. This is a correct exclusion per the type system, not an oversight requiring further verification.

## Scrutiny of the "enriched always wins" ordering invariant

Verified structurally, not just asserted: in `trading/trading/simulation/lib/simulator.ml`, `_process_step_day` (lines 402-419) calls `_call_strategy` (which synchronously drives the strategy's `on_market_close`, and therefore any `Exit_audit_capture`-mediated `record_exit` calls) **before** `Margin_runner.tick` and `_notify_transitions` (which fires `on_transitions` → `Trade_audit.record_transitions`) in the same function body, for the same step. This is a hint about function-body ordering, not a runtime race — the sequence is fixed by straight-line code, not by any concurrency/scheduling assumption. It is not enforced by a type-level or assertion-level invariant (a future refactor that reorders these lines would silently break the guarantee), but it is also directly exercised: `test_trade_audit_external_exits.ml` drives a real `Simulator.run` through the exact production `on_transitions` composition, and `test_trade_audit.ml`'s `test_record_transitions_enriched_exit_wins_no_overwrite` unit-tests the collision resolution at the `Trade_audit` level. Composition in `panel_runner.ml`'s new `_on_transitions` helper (`Stop_log.record_transitions stop_log ts; Trade_audit.record_transitions trade_audit ts`) is a straightforward sequential call of both existing single-argument observers into the one `on_transitions` slot — does not alter `Stop_log`'s existing call signature or behavior (same `stop_log` value, same function), so #2074 is not regressed.

## `[@sexp.option]` backward-compatibility claim

Syntactically and semantically correct usage of `ppx_sexp_conv`'s `[@sexp.option]` attribute (compiles under H1/H2/H3): the generated `t_of_sexp` treats a missing field as `None` and `sexp_of_t` omits a `None` field entirely, so pre-existing `trade_audit.sexp` files (written before this field existed) parse unchanged. This is standard, well-established ppx behavior, not a project-specific claim requiring a bespoke test. No test in this PR directly constructs a legacy sexp literal missing the `external_exit` key and parses it — this is a coverage observation for qc-behavioral's contract-pinning check (CP), not a structural finding.

## Verdict

APPROVED

## CI status (e6f9207f7a5607c8336586453d90ccee041107b6)

- `perf-tier1-smoke`: COMPLETED SUCCESS
- `build-and-test`: COMPLETED SUCCESS

---

Reviewed SHA: e6f9207f7a5607c8336586453d90ccee041107b6

## Behavioral QC — trade-audit external exits (PR #2085, issue #2076)

This is an infrastructure / observability PR (capture-only plumbing in
`trading/trading/backtest/`, no Weinstein domain logic touched). Per
`.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely",
the S*/L*/C*/T* domain rows are marked NA below; CP1–CP4 constitute the
substantive review.

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new `.mli` docstrings has an identified test that pins it | PASS | `external_exit_decision` (reason-only, no macro/stage/RS) → `test_external_exit_decision_sexp_round_trip` + the type definition itself (compiler-enforced field set). `audit_record.external_exit` ("populated only when `exit_` is `None`") → `test_record_transitions_enriched_exit_wins_no_overwrite`. `record_transitions`: no-bucket-dropped → `test_record_transitions_without_entry_is_dropped`; enriched-wins-no-op → `test_record_transitions_enriched_exit_wins_no_overwrite`; fills `external_exit` for `TriggerExit` w/ entry-but-no-`exit_` → `test_record_transitions_captures_margin_call_as_external_exit` + `test_record_transitions_captures_any_strategy_signal_label` (generic-label proof). One claim is under-pinned — see CP4: the docstring's explicit "`TriggerPartialExit` transitions are ignored" line has no test using an actual `TriggerPartialExit` transition (the existing generic-ignore test uses `UpdateRiskParams` instead, a structurally distant variant). Not enough on its own to flip this row, since CP4 is the more precise checklist location for guard-specific gaps — see CP4 below for the actionable finding. |
| CP2 | Each claim in PR body "Test plan" section has a corresponding test in the committed test file | PASS (with note) | All 6 bulleted behaviors under `test_trade_audit.ml` map to real tests (verified 1:1 against the diff): margin-label capture, generic-label capture (extra credit), enriched-wins-no-overwrite, no-entry-drop, non-`TriggerExit` ignored, sexp round-trip. (PR body says "+7 tests" but only 6 are new `let test_... =` functions; the 7th bullet — "existing `audit_record` sexp round-trip unaffected" — describes an *existing* test updated in place, not a new one. Minor miscount, not a missing-test problem; every described behavior is covered.) `test_trade_audit_external_exits.ml`'s 1 test is present and asserts exactly what's claimed (`external_exit` carries `margin_call`, `exit_` stays `None`). **Note on the "EXACT composed `on_transitions` closure Panel_runner wires in production" wording:** `panel_runner.ml`'s `_make_simulator`/`_on_transitions` are not exported in `panel_runner.mli` (only `run`, `fold_start_date_of_opt_in`, `engine_costs_with_overlay` are public), so the test cannot literally call into them — it hand-reconstructs the composition (`Stop_log.record_transitions stop_log ts; Trade_audit.record_transitions trade_audit ts`, same order). I independently verified this reconstruction is byte-for-byte identical (order + content) to production's `_on_transitions` (see panel_runner.ml diff). This is the same pattern the accepted sibling test `test_margin_exit_observability.ml` established for #2074's single-observer case. The claim is functionally true but structurally unenforced: a future edit to `_on_transitions` in `panel_runner.ml` (reorder, add a guard, drop an observer) would NOT be caught by this test, because the test never calls the actual private function — only a hand-copy of it. This is a real, if modest, regression-test gap on the exact question this reviewer was asked to scrutinize hardest; recorded as a note rather than a FAIL because (a) it matches established precedent, (b) the composition is currently verified-identical by direct source read, and (c) `panel_runner`'s privacy of `_make_simulator` is a legitimate, deliberate encapsulation choice, not an oversight — exposing it purely for test call-through would be a bigger design change than this PR's scope. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size | NA | No pass-through/identity semantics in this feature — `record_transitions` enriches a lookup table, it doesn't map an input list to an equal output. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | FAIL | Guard 1 ("no bucket → dropped") → `test_record_transitions_without_entry_is_dropped`. Guard 2 ("bucket has `exit_` already → no-op, enriched wins") → `test_record_transitions_enriched_exit_wins_no_overwrite`. Guard 3 — **`record_transitions`'s `.mli` docstring explicitly states**: "`[TriggerPartialExit]` transitions are ignored — a partial trim (e.g. `[harvest_rotate]`) does not close the position, so it has no round-trip ... to record." No test in the diff passes an actual `Position.TriggerPartialExit` transition into `record_transitions` and asserts it is ignored. `test_record_transitions_ignores_non_trigger_exit_kinds` (the closest existing test) uses `Position.UpdateRiskParams` — a variant with no `exit_reason` field at all, structurally much further from `TriggerExit` than `TriggerPartialExit` is. This is exactly the edge case the PR body itself calls out as "the residual gap behind 'partially addresses'" (claim 6 in the review brief) — the single most novel/important exclusion this PR establishes — yet it is the one guard with no dedicated test. The correctness is guaranteed by the compiler's exhaustive match (`| TriggerExit {...} -> ... | _ -> ()` structurally cannot mis-route `TriggerPartialExit` into the `TriggerExit` arm), so this is a coverage gap, not a suspected logic bug — but per CP4's literal criterion ("FAIL if the docstring names an edge case but no test covers it"), it is a FAIL. |

## Behavioral Checklist (domain — NA, infra PR)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | PASS | qc-structural did not FLAG A1 (confirmed independently: zero touches under `trading/trading/{portfolio,orders,position,strategy,engine}/`). All source changes are in `trading/trading/backtest/lib/` (not a core module) — no generalizability judgment required. |
| S1–S6, L1–L4, C1–C3, T1–T4 | Weinstein domain rows | NA | Pure infra / harness capture-only PR; no stage/macro/RS/stop domain logic touched. Per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely." |

## Additional verification performed

- **Ordering invariant** (claim 3, "enriched always wins is safe by construction"): independently traced `trading/trading/simulation/lib/simulator.ml`'s `_process_step_day` — `_call_strategy` (drives `on_market_close`, and therefore any synchronous `Exit_audit_capture.emit_for_list` → `record_exit` calls inside `Weinstein_strategy._run_stops_pass`) completes via `let%bind` before `Margin_runner.tick` and `_notify_transitions` (→ `on_transitions` → `Trade_audit.record_transitions`) run, in the same straight-line function body. This is a structural (compile-order) guarantee of the current pipeline, not a race — confirmed by direct read, matching qc-structural's independent finding. Documented in three places (the `.mli` docstring, the `_notify_transitions` comment in `simulator.ml`, and the PR body).
- **Backward compatibility** (claim 2): no test constructs a hand-written legacy sexp literal (missing the `external_exit` key) and parses it directly. However, `[@sexp.option]` causes `sexp_of_audit_record` to *omit* the key entirely when the field is `None` — so every existing round-trip test that builds a record with `external_exit = None` (e.g. `test_audit_record_sexp_round_trip`, `test_audit_records_sexp_round_trip_through_top_level_codec`) produces and re-parses a sexp that is, byte-for-byte, shaped like a pre-existing file lacking the key. This is a genuine (if implicit) pin of the backward-compat contract, not merely an assumption about `ppx_sexp_conv` — treated as satisfying the claim.
- **Extra credit / genericity** (claim 5): confirmed `_process_transition_for_external_exit` matches `TriggerExit { exit_reason; _ }` with no filtering on `exit_reason`'s constructor — `Position.exit_reason` has 7 variants (`TakeProfit`, `StopLoss`, `SignalReversal`, `TimeExpired`, `Underperforming`, `PortfolioRebalancing`, `StrategySignal`), none of which the code special-cases. The mechanism is genuinely label/variant-agnostic, matching the claim.
- **`harvest_rotate` exclusion is a type-level correct read** (claim 6): `Harvest_rotate_runner` emits `Position.TriggerPartialExit`, confirmed distinct from `TriggerExit` in `position.mli`; `record_transitions`'s match is exhaustive over `transition.kind` with `TriggerPartialExit` falling into the wildcard `_ -> ()` arm. Correct as a reading of the type — see CP4 above for the missing test coverage of this specific claim.
- **Closing-keyword check**: `closingIssuesReferences` GraphQL query for PR #2085 returned `{"nodes":[]}` — no issue will be auto-closed by this PR's merge, consistent with "Partially addresses #2076" (not "Closes").
- **No regression to #2074** (claim 4): `panel_runner.ml`'s new `_on_transitions` calls `Stop_log.record_transitions stop_log ts` first (unchanged call, unchanged `stop_log` value) then `Trade_audit.record_transitions trade_audit ts` — `Stop_log`'s existing behavior and signature are untouched.
- **Scope claim** (claim 8): confirmed no diff to `trade_audit_report.ml`, `trade_audit_ratings.ml`, or `decision_grading_bin.ml` in `lib/` — only their *test* files were mechanically updated for the new `audit_record.external_exit = None` field literal. Matches "capture-only, not surfaced in rendering/scoring."

## Quality Score

2 — Below standard: NEEDS_REWORK on one fixable, low-cost finding (CP4: the `TriggerPartialExit`-ignored guard, which is also the harvest_rotate-exclusion claim, has no dedicated test). Everything else — docstrings, the ordering-invariant argument, backward-compat mechanics, the extra-credit genericity claim, scope discipline, and issue-closure hygiene — is exemplary and independently verified against source.

## Verdict

NEEDS_REWORK

## NEEDS_REWORK Items

### CP4: `TriggerPartialExit` guard (harvest_rotate exclusion) has no dedicated test
- Finding: `Trade_audit.record_transitions`'s `.mli` docstring explicitly states that `TriggerPartialExit` transitions are ignored ("a partial trim (e.g. `[harvest_rotate]`) does not close the position, so it has no round-trip ... to record"). This is also the PR's own stated residual-gap rationale for "Partially addresses #2076" rather than "Closes". No test in the diff exercises this specific scenario — the closest test, `test_record_transitions_ignores_non_trigger_exit_kinds`, uses `Position.UpdateRiskParams`, a variant structurally far from `TriggerExit` (no `exit_reason` field), not `TriggerPartialExit` (the variant the docstring actually names and the one an inattentive future refactor is most likely to conflate with `TriggerExit`).
- Location: `trading/trading/backtest/lib/trade_audit.mli` (the `record_transitions` docstring, "`[TriggerPartialExit]` transitions are ignored" clause); `trading/trading/backtest/test/test_trade_audit.ml` (missing test).
- Authority: PR body's own "Not done" / residual-gap section + the `record_transitions` `.mli` docstring quoted above.
- Required fix: add a test (mirroring `test_record_transitions_ignores_non_trigger_exit_kinds`'s shape) that constructs a `Position.TriggerPartialExit` transition — ideally with a `harvest_rotate`-flavored `StrategySignal` reason, echoing the PR's own framing — for a position with a recorded `entry`, calls `record_transitions`, and asserts `external_exit` (and `exit_`) both stay `None`. Low cost: ~10–15 lines, directly mirrors the existing `_strategy_signal_trigger_exit` builder pattern with `kind = Position.TriggerPartialExit {...}` instead of `TriggerExit`.
- harness_gap: LINTER_CANDIDATE — this is exactly the class of gap CP4 exists to catch mechanically: grep the `.mli` diff for explicit "ignored" / "excluded" / ambiguous-guard language, then grep the paired test file for a test exercising that specific variant/case by name.

---

## Delta re-review @ `ab48fc14daa8fb61bd93fabffa995ecd27c0ace8`

Structural-only delta review of the one-commit rework that addresses the
prior qc-behavioral CP4 NEEDS_REWORK finding above. Not a full re-run of the
H1-H3/P1-P6/A1-A3 checklist — scope restricted per dispatch to the delta
itself.

### Delta scope

`git diff e6f9207f..ab48fc14 --stat`:

```
trading/trading/backtest/test/test_trade_audit.ml | 39 +++++++++++++++++++++++
1 file changed, 39 insertions(+)
```

Single commit (`fix(review): pin TriggerPartialExit exclusion in
Trade_audit.record_transitions`), test-file only. No production code, no
`.mli`, no `dune` file touched. This is exactly the shape a CP4-only rework
should take.

### Findings

| # | Check | Status | Notes |
|---|-------|--------|-------|
| Scope | Delta touches only the test file | PASS | `git diff --stat` confirms the entire delta is `test_trade_audit.ml`, +39/-0. No production, `.mli`, or `dune` changes. |
| P6-1 | `List.exists ... equal_to (true|false)` | PASS | No hits in the new code. |
| P6-2 | `let _ = ...on_market_close` / `.run` (ignored result) | PASS | No hits in the new code. |
| P6-3 | Bare `Ok`/`Error` match without `assert_that`/`is_ok_and_holds` | PASS | No hits in the new code. |
| Idiom | New builder `_strategy_signal_trigger_partial_exit` follows existing sibling-builder shape | PASS | Structurally identical to `_strategy_signal_trigger_exit` immediately above it (same optional-arg style, same `Position.StrategySignal` exit-reason construction, same default `exit_price = 137.20`), differing only in `kind` (`TriggerPartialExit` + `target_quantity`) — exactly the "structurally adjacent" claim in its own docstring. Doc comment present and non-trivial. |
| Idiom | New test `test_record_transitions_ignores_partial_exit` follows `.claude/rules/test-patterns.md` | PASS | Two `assert_that` calls, each on a distinct value (`_external_exit_of t ...` and `TA.get_audit_records t`) — not nested, matches the codebase's "one `assert_that` per value" rule and the shape of the immediately-preceding sibling test `test_record_transitions_ignores_non_trigger_exit_kinds`. Second assertion uses `elements_are [ field ... is_none ]`, consistent with the matcher-composition conventions. |
| Magic numbers | New literals `137.20` (`exit_price` default) and `50.0` (`target_quantity` default) | PASS | Both are test-fixture defaults mirroring the existing sibling builder's pre-existing `exit_price = 137.20` default (not new production tunables) — no linter-relevant magic number introduced. |
| Function length / nesting | New builder (~19 lines) and new test (~17 lines) | PASS | Well under the 50-line hard limit; no added nesting depth. |
| Test registration | New test wired into `suite` | PASS | `"record_transitions ignores TriggerPartialExit" >:: test_record_transitions_ignores_partial_exit` added to the `suite` list, consistent placement immediately after the sibling non-trigger-exit-kinds test. |
| PR body | "Partially addresses #2076" preserved (not replaced with a closing keyword) | PASS | Confirmed via `GET /repos/dayfine/trading/pulls/2085` — body still opens "Partially addresses #2076 (remaining half of #2057)." No `Closes`/`Fixes`/`Resolves` keyword introduced; `harvest_rotate` residual-gap framing unchanged. |
| PR body | CP2 overclaim softened as described | PASS | Body's `test_trade_audit_external_exits.ml` bullet now reads "...reconstructing the same two-observer composition (`Stop_log.record_transitions` + `Trade_audit.record_transitions`, in the same order) that `Panel_runner._on_transitions` wires in production -- verified identical to the private production closure, matching the precedent set by `test_margin_exit_observability.ml`." No longer claims the test literally calls the "EXACT composed closure." Test-plan bullet count now reads "+8 tests," matching the actual diff (7 new `let test_... =` in the prior commit + this rework's 1 new test = 8; also matches the new `suite` entry count). |

### Verdict

APPROVED (delta). No structural regressions introduced by the rework; the
CP4 gap this delta targets is a qc-behavioral judgment (does the new test
actually pin the guard correctly), not restated here — see the companion
qc-behavioral delta review for that determination.

### CI status (`ab48fc14daa8fb61bd93fabffa995ecd27c0ace8`)

- `build-and-test`: COMPLETED SUCCESS
- `perf-tier1-smoke`: COMPLETED SUCCESS

(Confirmed by lead-orchestrator and independently via the GitHub check-runs
API; both required checks green at the reviewed tip.)

---

Reviewed SHA: ab48fc14daa8fb61bd93fabffa995ecd27c0ace8

## Behavioral re-review @ `ab48fc14`

Delta-only re-review of the rework commit (`ab48fc14`, +39/-0, test-file only:
`trading/trading/backtest/test/test_trade_audit.ml`). Scope restricted to
closing the single prior CP4 finding; not a full CP1–CP4 resweep (prior
findings CP1/CP2/CP3, A1, backward-compat, ordering-invariant, genericity,
closing-keyword hygiene all stand as independently verified in the prior
review pass and are not re-litigated here).

### CP4 — re-verified

Read the diff (`git diff e6f9207f..ab48fc14`) and the current
`_process_transition_for_external_exit` in
`trading/trading/backtest/lib/trade_audit.ml`:

```ocaml
let _process_transition_for_external_exit t
    (trans : Trading_strategy.Position.transition) =
  match trans.kind with
  | Trading_strategy.Position.TriggerExit { exit_reason; _ } -> (
      match Hashtbl.find t.records trans.position_id with
      | None -> ()
      | Some bucket -> _fill_in_external_exit bucket trans ~exit_reason)
  | _ -> ()
```

`TriggerPartialExit` falls through the wildcard `_ -> ()` arm — exactly what
the `.mli` docstring for `record_transitions` claims ("`[TriggerPartialExit]`
transitions are ignored — a partial trim (e.g. `[harvest_rotate]`) does not
close the position...").

The new builder `_strategy_signal_trigger_partial_exit` constructs a genuine
`Position.TriggerPartialExit { exit_reason; exit_price; target_quantity }` —
checked field-for-field against the `transition_kind` variant in
`position.mli` (line 295: `TriggerPartialExit of { exit_reason : exit_reason;
exit_price : float; target_quantity : float }`). It is structurally adjacent
to `_strategy_signal_trigger_exit` (same `exit_reason = StrategySignal
{ label; detail }` shape) — the one dimension of change is `kind`, which is
precisely the axis `record_transitions` branches on. This is materially
different from the old negative test's `UpdateRiskParams`, which has no
`exit_reason` field at all and could not have caught a
`TriggerExit`/`TriggerPartialExit` conflation bug.

`test_record_transitions_ignores_partial_exit`:
1. Records a real `entry` for `"AAPL-wein-1"` (`make_entry ()`, whose default
   `position_id` matches the builder's default — confirmed in
   `make_entry`'s optional-arg list).
2. Calls `record_transitions` with a `harvest_rotate`-labeled
   `TriggerPartialExit`.
3. Asserts `_external_exit_of t ~position_id:"AAPL-wein-1"` is `None`
   (`_external_exit_of` correctly looks up the bucket by `entry.position_id`
   and binds into `r.external_exit`).
4. Additionally asserts, via `elements_are [ field (fun r -> r.exit_) is_none ]`
   over `TA.get_audit_records t`, that the enriched `exit_` field also stays
   untouched — i.e. `record_transitions` genuinely no-ops rather than
   synthesizing anything on either field.

**Discrimination check (the question that matters):** if
`_process_transition_for_external_exit`'s match were changed to treat
`TriggerPartialExit` the same as `TriggerExit` (e.g. `| TriggerExit
{ exit_reason; _ } | TriggerPartialExit { exit_reason; _ } -> ...`), the
`match` would bind `exit_reason` from the partial-exit transition,
`_fill_in_external_exit` would set `bucket.bucket_external_exit <- Some
{ ...exit_trigger = harvest_rotate... }`, and the test's `is_none` assertion
on `_external_exit_of` would fail. There is no path by which the test passes
under that regression. The test genuinely discriminates the guarded
behavior — CP4 is closed.

Both assertions target domain outcomes (no synthesized `external_exit`
record, no synthesized `exit_` record) — consistent with T4 / the "domain
outcome, not just no-error" bar; `record_transitions` returns `unit`, so
there was never an error-path to assert against in the first place.

### Delta scope check

- No `.ml`/`.mli` changes in this commit — confirmed by `git diff --stat`
  (single file, test-only). No new claim introduced that needs its own pin.
- Test suite additions are additive only (`+39/-0`); no existing test
  modified or removed.
- PR body: re-read in full. The CP2 note's overclaim ("EXACT composed
  closure") is now qualified — "reconstructing the same two-observer
  `on_transitions` composition ... verified identical to the private
  production closure, matching the precedent set by
  `test_margin_exit_observability.ml`" — an accurate description matching
  what was independently verified in the prior review pass (production's
  `_on_transitions` is private/unexported; the test hand-reconstructs it).
  No new overclaim introduced. Test count corrected +7 → +8, consistent with
  the actual new `let test_... =` function count in this diff plus the prior
  commit. `Partially addresses #2076` is still the operative phrase (no
  `Closes`/`Fixes` keyword) — consistent with the intentional
  `TriggerPartialExit`/`harvest_rotate` exclusion this PR documents; GraphQL
  `closingIssuesReferences` re-check not re-run this pass (no code/body
  change plausibly affects it; prior pass returned empty `nodes`).

## Contract Pinning Checklist (delta)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP4 | `TriggerPartialExit` guard has a test that exercises the guarded-against scenario | PASS | `test_record_transitions_ignores_partial_exit` + `_strategy_signal_trigger_partial_exit`, see discrimination check above. Closes the prior NEEDS_REWORK finding. |

All other CP1–CP3 rows, the domain checklist (NA — infra PR), A1, and the
"Additional verification performed" items from the prior review pass are
unchanged and still hold; not re-run in this delta pass per the review's
scoping instructions.

## CI status (`ab48fc14daa8fb61bd93fabffa995ecd27c0ace8`)

- `perf-tier1-smoke`: COMPLETED SUCCESS
- `build-and-test`: COMPLETED SUCCESS

## Quality Score

4 — Good: the CP4 gap is closed cleanly and precisely — the new test is
minimal (~40 lines), structurally adjacent to the existing positive-case
builder (maximizing discriminating power), asserts the correct domain
outcome on both fields, and the accompanying commit message and PR-body
edits are accurate with no new overclaims. Held at 4 rather than 5 because
this was a rework cycle rather than a first-pass exemplar (the original PR
needed a review round to reach full CP coverage), and the CP2 hand-reconstruction
gap noted in the prior pass (a future `_on_transitions` reorder would not be
caught by `test_trade_audit_external_exits.ml`) remains a modest, accepted
residual note rather than a blocking issue.

## Verdict

APPROVED

---

Reviewed SHA: 8988ae73087eb2fe056a0eef426dd94a3c37b108

## Behavioral QC — trade-audit PR #2365 (R2 + R4)

### CI status — independently re-checked, NOT inherited from structural

Structural approved while `build-and-test` was `in_progress` and substituted a
scoped local run. I re-polled the check-runs API twice during this review:

- `perf-tier1-smoke`: `completed/success`
- `build-and-test`: **`in_progress/-` — still pending at the time of this review**

My behavioral verdict is on contract correctness and is independent of that
gate, but **the merge gate is not satisfied until `build-and-test` reports
`completed/success`** (`.claude/rules/pr-merge-gates.md`). Do not merge on the
strength of two APPROVED reviews alone.

What I did verify by execution, in my own detached worktree at the PR tip:

```
dune exec trading/backtest/test/test_cancel_reason_closed_list.exe
Ran: 2 tests in: 0.10 seconds.  OK   EXIT=0
```

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new `.mli` docstrings has an identified test that pins it | NA | **No new `.mli` is added.** The two `.mli` files in the diff (`cancel_handler.mli`, `screener.mli`) are docstring-only odoc-ref corrections that introduce no new claim. The load-bearing new contract text is the *module docstring of the new test file*; its claims are evaluated under CP2/CP4 below rather than skipped. |
| CP2 | Each claim in the PR body's "Test plan"/"Test coverage" has a corresponding committed test | PASS | Every falsifiable PR-body claim independently reproduced — see the table below. Nothing advertised is absent from the tree. |
| CP3 | Pass-through/identity/invariant tests pin identity, not just size | PASS | Both tests assert whole-value identity via `equal_to` on the complete `Set.to_list` (and on a tuple of two complete lists), never `size_is`. `grep 'size_is' test_cancel_reason_closed_list.ml` → no hits. A size-only assertion here would have passed under my MUT-D below; the identity assertion does not. |
| CP4 | Each guard called out explicitly in code docstrings has a test exercising the guarded-against scenario | PASS | The module docstring names four guards and disclaims a fifth. I executed all four (MUT-A–D below); each reddens the suite. The disclaimed fifth ("a fourth producer in a third module is NOT caught") is accurate — I confirmed a unit test structurally cannot close it — and is filed as R5 with baseline counts rather than papered over. |

### CP2 — PR-body claims, each re-derived rather than restated

| PR-body claim | Verified how | Result |
|---|---|---|
| `grep -rn 'CancelEntry {' --include=*.ml .` → **11 hits**, split 2 production construction / 1 production match arm / 8 test-file | Re-ran the grep myself and re-classified every hit by hand | **Exact match.** See enumeration below. |
| Grid is 144 `Entry_ticket_ttl` inputs | Read `_ttl_inputs`; 3 position states × 2 `rescreen` × 4 `max_rest_weeks` × 2 `qualifies` × 3 dates | 144 ✓ |
| Grid is 9 `Cancel_handler` inputs | Read `_rejection_transitions`; 3 position maps × 3 trade lists | 9 ✓ |
| Mutation 1 (fourth producer arm) → 2/2 FAILED | Re-ran it (MUT-A) | 2/2 FAILED, exit 1 ✓ |
| Mutation 2 (rename `_ttl_reason`) → 2/2 FAILED | Re-ran it (MUT-B) | 2/2 FAILED, exit 1 ✓ |
| "Non-vacuous in **both** directions — an empty reachable set fails as loudly" | MUT-C (mine, below) | 2/2 FAILED ✓ |
| "A second test pins the decision-vs-accident partition, so a token migrating between the two modules is caught too" | MUT-D (mine, below) | test 1 **PASSES**, test 2 **FAILS** ✓ — the second test is non-redundant and does exactly what it claims |
| `grep -rn '{!Weinstein_trading\.'` returns **zero** | Re-ran over `*.ml` + `*.mli` | **0 hits** ✓ |
| No `weinstein_trading.ml/.mli` exists in the tree | `find` | none ✓ |
| `Weinstein_trading_state` is a different, real library, left alone | `trading/trading/weinstein/trading_state/lib/dune` declares `(name weinstein_trading_state)` | ✓ real; the escaped-dot regex `Weinstein_trading\.` cannot over-match it |
| `dune build` / `dune runtest` / `dune build @fmt` all exit 0 | **Not independently verified** — whole-tree build deliberately not started (container-capacity rule). This is `build-and-test`'s job, and it is still `in_progress`. | **pending on CI** |

### My own `CancelEntry {` enumeration (11 hits, re-derived)

The author force-pushed once specifically to correct this count (first commit
message said "9 in test files"; correct is 8). I re-counted from scratch:

**Production construction sites — 2**
- `trading/trading/weinstein/strategy/lib/entry_ticket_ttl.ml:17` (`_cancel_transition`) → 2 reachable tokens, both **module-private** (`entry_ticket_ttl.mli` exports only `cancellations` and `run` — I checked; no reason token is exported)
- `trading/trading/simulation/lib/cancel_handler.ml:28` (`_cancel_entry_transition`) → 1 reachable token, the exported `portfolio_rejection_reason`

**Production match arm — consumer, not a producer — 1**
- `trading/trading/backtest/lib/trade_audit.ml:242` (`_process_transition`)

**Test files — 8**
- `test_position.ml:300,323` (2), `test_cancel_handler.ml:169,184` (2), `test_trade_audit.ml:535,576` (2), `test_entry_ticket_ttl.ml:105` (1, itself a match arm), `test_gtc_entry_persistence.ml:161` (1)

2 + 1 + 8 = 11. **The closed list is exactly three at this SHA**, and the two
exclusion classes a naive grep gets wrong (the `trade_audit.ml` match arm; the
test-file hits) are both correctly identified in the PR body, the commit
message, and the R5 baseline.

### Is the reachable side genuinely derived, or does it collapse to literals?

**Genuinely derived.** The documented side is 2 literals + 1 symbolic reference
(`Cancel_handler.portfolio_rejection_reason`); the two `Entry_ticket_ttl` tokens
*must* be literals there because they are private to that module — which is
precisely why the reachable side has to run the producer to obtain them. The
reachable side is never written down: it is `_reachable_from`, which runs the
real `Entry_ticket_ttl.cancellations` / `Cancel_handler.transitions_for_rejected_trades`,
pushes each emitted `CancelEntry` through the real `Trade_audit.record_transitions`,
and reads back `ticket_lifecycle.cancel_reason` off the persisted audit record.

The decisive evidence is MUT-C: in a literals-vs-literals test, breaking the
audit's *persistence* would change nothing. Here it reddens both tests.

### Mutation probes — the author's two, reproduced, plus two they did not run

| # | Mutation | Whose | Result |
|---|---|---|---|
| MUT-A | Fourth arm in `_cancel_reason_for` returning `entry_ticket_partial_abandoned`, reachable by the grid | author's #1 | **2 of 2 FAILED**, exit 1 ✓ reproduced |
| MUT-B | `_ttl_reason` value → `entry_ticket_clock_expired` | author's #2 | **2 of 2 FAILED**, exit 1 ✓ reproduced |
| **MUT-C** | **`Trade_audit._record_cancel` silently drops the reason** (`bucket_cancel_reason <- None`) — the producers still emit all three tokens, the audit just stops persisting them | **mine** | **2 of 2 FAILED**, exit 1 — reachable set collapses to empty and the equality fails as loudly as a fourth token. **Non-vacuity confirmed in the direction that is usually broken.** |
| **MUT-D** | **Union-preserving cross-module token leak** — `Entry_ticket_ttl` additionally emits `entry_fill_rejected_by_portfolio`, so the *union* stays exactly the documented three while the decision-vs-accident partition breaks | **mine** | **test 1 PASSES, test 2 FAILS** (`Failures: 1`), exit 1 — the partition test is **not redundant** with the set-equality test and catches precisely the case its docstring claims. |

Reverted after each; final state green (`Ran: 2 tests … OK`, exit 0,
`git status --porcelain` clean).

MUT-D is the one worth dwelling on. It is deliberately constructed so that
set-union equality cannot see it — exactly the shape that let PR #2362's
scenario pass under the very mutation it existed to catch. Here the second test
fires and the first correctly stays green, which is the right behaviour for both
and demonstrates the two tests are testing different things rather than one
being decoration.

### R4 — is the substituted verification method sound?

The author reports that `dune build @…/doc` emits no warning *even with the bad
ref deliberately restored* (exit 0), so odoc is not a discriminating gate, and
substitutes structural evidence. Judging that:

- **Sound for what it claims.** (a) No `weinstein_trading.ml/.mli` exists → the
  old `{!Weinstein_trading.X}` form could never resolve, full stop. (b) The
  target path is compiler-proven by the new test's
  `module Entry_ticket_ttl = Weinstein_strategy.Entry_ticket_ttl`, which
  compiles. I confirmed the underlying diagnosis directly:
  `weinstein_strategy`'s dune carries `(public_name weinstein_trading.strategy)`
  — `Weinstein_trading` is indeed a public-name *prefix*, not a module. Given a
  silent odoc, this is genuinely stronger evidence than a build warning.
- **Non-blocking residual (observation, not a finding).** Neither
  `trading.simulation` (which contains `cancel_handler.mli`) nor
  `weinstein.screener` declares `weinstein_strategy` as a dependency — screener
  is a *dependency of* the strategy, so its ref points up the dependency graph.
  Those two refs may therefore still not resolve under odoc, for a different
  reason than before. **This is not a FAIL:** the PR never claims odoc
  resolution — it explicitly states odoc is not a gate — and naming a real
  module in place of a nonexistent one is a strict improvement either way. Worth
  a follow-up line on the track (cross-library odoc refs may want `{!module:…}`
  or plain `[Entry_ticket_ttl]` prose), not a rework cycle.

### Status-file verification (`dev/status/trade-audit.md`)

- **R2 → `[x]`** (line 116), accurate: names the real test path, the derived-not-literal
  design, both grid sizes, the reproduce command, and the load-bearing mutations.
- **R4 → `[x]`** (line 130), accurate, and correctly records that it was three
  refs rather than the one originally filed.
- **R1 still `[ ]`** (line 104) — confirmed open and untouched, as intended.
- **R5 filed** (line 138) with the full baseline census: 2/1/8 split, both
  exclusion classes named, and the correct rationale for why it belongs in
  `trading/devtools/checks/` rather than a unit test.
- **`dev/status/_index.md` untouched** — confirmed; matches
  `.claude/rules/feat-agent-dispatch.md` §4.

**Line-number citations:** none in any new docstring — the new test's module
docstring cites `dev/notes/ticket-death-on-cash-2026-08-16.md` and
`dev/status/trade-audit.md` symbolically, and the R2 item's old
`entry_ticket_ttl.ml:17` / `_cancel_reason_for:38-50` citations were *removed*.
One nit: the completed R4 item's heading still reads "at `cancel_handler.mli:76`"
— carried-over text from the original filing describing where the defect was, in
a status file rather than a docstring. Harmless; no action required.

### Behavioral Checklist (domain)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | qc-structural did not FLAG A1; no core module touched. |
| S1–S6, L1–L4, C1–C3, T1–T4 | Weinstein stage / stop / cascade / domain-test rows | NA | **Audit-observability plumbing and an odoc-ref docstring fix — no Weinstein decision logic is added or altered.** The new test drives existing producers to enumerate diagnostic reason tokens; it changes no stage rule, entry/exit criterion, stop, or cascade behaviour. Per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely", CP1–CP4 is the review. |

### Rules spot-check

- `.claude/rules/experiment-flag-discipline.md` — NA, no strategy mechanism or config field added.
- `.claude/rules/weinstein-faithful-core.md` W1 — spine untouched; the diff adds a test and corrects three doc refs.
- `.claude/rules/no-python.md` — no `*.py` in the diff.

## Quality Score

5 — Exemplary. This is the reference implementation of the discipline the last
eight rejections were about: the universal ("exactly three tokens") is closed by
*deriving* the reachable side rather than restating it, every enumerated count
re-derives exactly, the coverage limit is stated in the docstring and filed as
R5 with a baseline instead of being papered over, and the author force-pushed to
correct their own miscount rather than leave it in a durable commit message. My
two independent mutations both landed where the docstring says they should —
including a union-preserving cross-module leak that isolates the second test and
proves it is not decoration. The only residual (cross-library odoc refs may still
not resolve) sits outside anything the PR claims and is non-blocking.

## Verdict

APPROVED

Behavioral gate satisfied at `8988ae73`. **Merge remains blocked until
`build-and-test` reports `completed/success` at this SHA** — it was still
`in_progress` throughout this review.

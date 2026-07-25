Reviewed SHA: 1eaa6806229d14df45b92e5f315ebca77b746af1

## Structural QC — margin-realism-exit-labels (PR #2074)

### Hard gates

CI on the reviewed SHA: `build-and-test` = completed/success, `perf-tier1-smoke` = completed/success (re-verified via `GET /commits/{sha}/check-runs`). `build-and-test` runs `dune build @fmt`, `dune build`, `dune runtest` plus the full linter suite (`fn_length_linter`, `nesting_linter`, `linter_magic_numbers.sh`, `file_length_linter`, `linter_mli_coverage.sh`, `status_file_integrity_linter`, `no_python_check.sh`) — strictly stronger than a local build. H1–H3 marked PASS on this evidence per dispatch instructions (dune not run locally in this container — another agent holds the lock).

Branch staleness: `git rev-list --count <sha>..origin/main` = 0. Branch is fully up to date with `main`. No staleness flag.

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | Verified via CI check-run `build-and-test` = success on reviewed SHA |
| H2 | dune build | PASS | Same CI evidence |
| H3 | dune runtest | PASS | Same CI evidence; includes full linter suite (fn_length, nesting, magic-numbers, file-length, mli-coverage, status-file-integrity, no-python) |
| P1 | Functions ≤ 50 lines (linter) | PASS | Covered by H3/CI. Largest new function (`_run_and_collect_stop_log`, `test_stop_log_records_*`) well under limit by inspection |
| P2 | No magic numbers (linter) | PASS | Covered by H3/CI. Test fixture literals (prices, dates) are standard test-data literals, not production thresholds |
| P3 | All configurable thresholds in config record | NA | This PR is pure plumbing (observer hook) — no new tunable threshold/period/weight introduced |
| P4 | Public-symbol export hygiene (.mli coverage) | PASS | Covered by H3/CI (`linter_mli_coverage.sh`). New `on_transitions` field + `?on_transitions` param both fully documented in `simulator.mli` (+26 lines) |
| P5 | Internal helpers prefixed per convention | PASS | All new helpers underscore-prefixed: `_notify_transitions`, `_run_and_collect_stop_log`, `_exit_trigger_for`, `_assert_strategy_signal_label`, `_make_bar`, `_config_for`, `_make_one_shot_strategy`, `_capture_transitions`, `_count_exit_tagged`, `_date`, `_commission`, `_on_config`, `_buyin_only_config`, fixture data (`_aapl_*`). No violations found |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | PASS | See detailed sub-rule analysis below |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | FLAG | `trading/trading/simulation/lib/simulator.ml`/`.mli` modified. Not literally on the enumerated core-module watch-list (portfolio/orders/position/strategy/engine), but `Simulator` is the shared live+backtest pipeline seam per `weinstein-trading-system-v2.md` ("live and simulation share the same pipeline"), so I'm applying A1's spirit per dispatch instructions. See generalizability assessment below — routes to qc-behavioral for final judgment |
| A2 | No new `analysis/` imports into `trading/trading/` outside allow-list | PASS | `backtest/test/dune` diff only adds `test_margin_exit_observability` (exe) and `simulation_test_helpers` (lib) — no `analysis/` references added |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | `$PR_FILES` from the API (7 files) matches exactly what the diff touches; all 7 are load-bearing for this fix (status doc, the 2 simulator files, the 2 test files it pins, panel_runner wiring, and the dune target registration). No drift |

### A1 generalizability assessment (for qc-behavioral)

The new `on_transitions : (Position.transition list -> unit) option` field:
- Is typed purely in terms of `Trading_strategy.Position.transition list -> unit` — no Weinstein-specific or margin-specific type appears in the `Simulator` signature.
- Mirrors the existing `on_trade_fill : (Trading_base.Types.trade -> Trading_base.Types.trade) option` hook exactly in shape (optional field + optional labeled arg on `create_deps`, default `None`).
- Is invoked unconditionally once per step in `_process_step_day`, regardless of which strategy or domain is in use — the call site (`_notify_transitions ~on_transitions:t.deps.on_transitions transitions`) has no knowledge of margin, Weinstein, or `Stop_log`; the coupling to those is entirely at the `Backtest.Panel_runner` call site (`~on_transitions:(Stop_log.record_transitions stop_log)`), one layer up.
- Traced the data flow: `transitions` returned from `Margin_runner.tick` is passed to `_notify_transitions` (which returns `unit`, discarding any return value) and then, unchanged, to `_apply_transitions` and `Order_generator.transitions_to_orders`. The observer cannot mutate, reorder, or filter the list — confirmed by reading `_process_step_day` (lines ~401–420 of `simulator.ml` at this SHA): the same `transitions` binding is used before and after the notify call, and `_notify_transitions`'s only side effect is calling `observe transitions`, whose return value is discarded.

My assessment: the `on_trade_fill`-mirroring argument holds — this is a genuinely strategy-agnostic, side-effect-only observer hook, not domain logic leaking into the simulator. I flag it (not fail it) purely because it touches the shared engine/simulation seam, per this repo's A1 protocol; final generalizability sign-off is qc-behavioral's per authority doc.

### Backward-compatibility check (record field addition)

`dependencies` gained a new field in `.mli`. Verified via `git grep create_deps` at this SHA that every call site across the codebase (panel_runner.ml, and ~15 test files under simulation/test, backtest/test, weinstein/strategy/test) constructs `dependencies` exclusively through the `create_deps` smart constructor, never via a direct record literal outside `simulator.ml` itself. `on_transitions` is `?on_transitions` (optional, default `None`), so every existing call site compiles unchanged. Confirmed no breaking change.

### P6 detail — test-pattern conformance

Applied the three sub-rules to both test files:

**`test_margin_exit_observability.ml` (new, 257 lines):**
- Sub-rule 1 (`List.exists .* equal_to (true|false)`): no matches.
- Sub-rule 2 (`let _ = ... on_market_close/.run` discarding a Result): no matches — `run sim`'s result is always captured.
- Sub-rule 3 (manual match with `Error -> assert_failure` / bare `Ok ->` used as the assertion): found `match create ~config ~deps with | Ok s -> s | Error e -> assert_failure ...` and `match run sim with | Ok r -> result_ref := Some r | Error err -> assert_failure ...` inside the `_run_and_collect_stop_log` **setup helper**. Not a violation: `.claude/rules/test-patterns.md` §"Test Data Builders" explicitly sanctions this exact idiom as the canonical "Domain-Specific Helper" pattern (`apply_trades_exn` worked example: `match ... with | Ok value -> value | Error err -> OUnit2.assert_failure (...)`). The actual test assertions are separate, correctly composed `assert_that` calls (`_assert_strategy_signal_label` using `is_some_and (matching ...)`). PASS.

**`test_margin_runner.ml` (new T8 section, ~lines 869–1012, plus signature-only changes to the pre-existing `_run_with_margin` helper):**
- Sub-rule 1: no matches.
- Sub-rule 2: `let (_ : run_result) = _run_with_margin ... in` discards a plain `run_result` record (not a `Result`/Option needing assertion) — `_run_with_margin` already unwraps and fails fast internally via the same sanctioned helper idiom (pre-existing code, unchanged except added optional params in this PR). The actual assertions are `assert_that (_count_exit_tagged ...) (equal_to 1)` — correct single-`assert_that` composition. PASS.
- Sub-rule 3: the only bare `match` in the new section is `match t.kind with` inside `_count_exit_tagged`, matching a `Position.transition.kind` variant, not a `Result` — out of scope for this sub-rule. PASS.
- All new tests use exactly one `assert_that` per assertion. Conforms to the "One `assert_that` per Value" core rule.

## Verdict

APPROVED

## Notes for qc-behavioral

- A1 FLAGged on `trading/trading/simulation/lib/simulator.ml`/`.mli` — please judge the generalizability claim (summarized above) rather than re-deriving it from scratch; I traced the call site and confirmed the hook is invoked post-dedup, side-effect-only, with its return value discarded before `_apply_transitions` runs on the same unmodified `transitions` binding.
- Behavior-neutrality claim ("no behavior change, same PnL/fills/timing") is structurally consistent with the code (observer never touches `portfolio`/`positions`, return value discarded) — worth confirming via any bit-identical golden/regression assertions in the existing simulator test suite if qc-behavioral wants an independent check beyond CI green.
- The status doc (`dev/status/margin-realism.md`) documents a deliberately deferred scope item (`trade_audit.sexp` still doesn't capture margin exits, consistent with pre-existing behavior for other `StrategySignal` exit types) — this is a scope/authority judgment call for qc-behavioral, not a structural issue.

---

Reviewed SHA: ef6694eea33114da88dea857a2ec0729f0c4a62a

## Behavioral QC — margin-realism-exit-labels (PR #2074)

### Scope classification

Observability/plumbing PR over the margin subsystem — no strategy decision
logic changed (no stage classifier, stops-triggering, screener cascade, or
macro/sector gating). Per `.claude/rules/qc-behavioral-authority.md`, domain
rows S1–S6, C1–C3, and L1–L4 (this PR touches exit-reason *labelling*, not
exit *triggering*) are all NA. Review is CP1–CP4 plus the A1 generalizability
judgment routed by qc-structural.

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new `.mli` docstrings has an identified test that pins it | PASS (caveat) | New claims in `simulator.mli` on `dependencies.on_transitions`: (1) "invoked once per step with the final post-dedup transition list, incl. margin-driven ones" → pinned by `test_on_transitions_observes_margin_call` / `_buyin_stress` / `_maintenance_reduce` (test_margin_runner.ml). (2) "never influences portfolio/positions/fills" → structurally true by code read (`_notify_transitions` discards the observer's return value; `transitions` binding is reused unchanged for `_apply_transitions`), not independently re-verified by a golden/regression test in this PR, but qc-structural already traced this and no golden output changed. (3) "invoked unconditionally every step, including steps where `_should_call_strategy` is false" — this sub-claim is **not exercised by any test**: all three new T8 tests and both new observability tests use `strategy_cadence = Cadence.Daily`, under which the strategy is called every day, so the cadence-independence property is never distinguished from "always called anyway." Minor gap, not blocking — the call site is structurally unconditional (no gate around `_notify_transitions`) — but a weekly-cadence fixture with a Friday-only margin trigger on a non-strategy-call day would close it. |
| CP2 | Each claim in PR body "Test plan"/"Test coverage" sections has a corresponding test in the committed test file | FAIL | The "Which labels are pinned, and where" section's claims are literally true — all 3 labels (`margin_call`/`buyin_stress`/`maintenance_reduce`) × 2 layers (Simulator, Backtest) = 6 tests, all present and passing per the diff. **However** the PR carries `Closes #2057`, and issue #2057's own title is "Margin-driven exit reasons ... do not propagate to **trades.csv / trade_audit.sexp**" (both sinks named). This PR's own "trade_audit.sexp scope note" admits that sink is *not* fixed and is deliberately deferred — and explicitly states the follow-up was "not filed as a new issue (needs its own design first)." That falls short of "honestly documented with a follow-up": the documentation is honest and thorough, but there is no tracked artifact for the remaining half of the named bug, and `Closes #2057` will auto-close an issue that literally names the still-broken sink in its title. This is a process-completeness gap, not a code defect — see Required fix below. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size | NA | No pass-through/identity semantics in this feature (observer hook, not a data transform). |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | FAIL | Both the PR body ("Fix" section) and the `panel_runner.ml` code comment explicitly claim: "on a same-tick collision the later `on_transitions` call correctly overwrites the wrapper's stale strategy-side trigger with the winning margin one (a latent staleness bug the old design had on collision days, fixed as a side effect)." This is a specific, non-trivial, testable guard claim. **No test in the diff exercises it.** The pre-existing `test_e2e_strategy_exit_collides_with_margin_call` (test_margin_runner.ml, unmodified by this PR) drives exactly this scenario — a strategy-side stop-loss AND a margin call both targeting the same position on the same tick — but only asserts the position closed without raising; it does not wire `Stop_log`/`on_transitions` and does not check which label wins. None of the three new `test_margin_exit_observability.ml` tests use a strategy that itself emits a competing `TriggerExit` (they all use the passive `_make_one_shot_strategy`, which never generates an exit) — so the "stale wrapper trigger corrected by the later hook" claim is asserted in prose and comments but has zero test coverage. See Required fix. |

## A1 generalizability judgment (routed by qc-structural)

**PASS — strategy-agnostic.** Independently traced the same call path qc-structural did:

- `on_transitions` is typed `Position.transition list -> unit` in `simulator.mli` — no `Margin_runner`, `Stop_log`, or Weinstein type appears anywhere in the `Simulator` module's new surface.
- It mirrors `on_trade_fill`'s existing shape exactly (optional `dependencies` field + optional labeled arg on `create_deps`, default `None`, zero-overhead no-op when unset).
- The call site (`simulator.ml`, `_notify_transitions ~on_transitions:t.deps.on_transitions transitions`) fires unconditionally in `_process_step_day`, with no branching on strategy identity, margin config, or any domain concept — it is invoked with whatever `transitions` list `_process_step_day` has assembled by that point, regardless of what produced it (a Weinstein strategy, a synthetic test strategy, margin, or in principle any future exit-generating subsystem).
- The domain coupling is entirely one layer up, at `Backtest.Panel_runner._make_simulator`'s `~on_transitions:(Stop_log.record_transitions stop_log)` wiring — which is exactly where domain-specific observers are supposed to live per the existing `on_trade_fill` precedent (also wired from `Panel_runner`, not `Simulator`).
- This is a coherent, reusable observation point: "the final list of transitions this step will apply" is a natural seam for *any* per-step transition observer (audit trails, metrics, future non-margin force-exit mechanisms), not one privileging margin's timing specifically — margin merely happens to be the first consumer that needed a hook the strategy-call-boundary wrapper couldn't see.

No Weinstein/margin-specific logic leaked into the shared `Simulator` module.

## Test quality (CP4 detail, additional review axes)

- **Label-string specificity:** all 6 new tests assert the exact `StrategySignal` label string (`margin_call` / `buyin_stress` / `maintenance_reduce`) via `matching`/`_count_exit_tagged`, not merely "some non-blank exit_trigger appeared." Conforms to `.claude/rules/test-patterns.md` (`List.count` + `equal_to N`, `is_some_and (matching ...)`).
- **`detail` payload:** `Stop_log.exit_trigger.Strategy_signal.detail` is preserved end-to-end structurally (`exit_trigger_of_reason` maps the whole `StrategySignal` record, including `detail`, unconditionally) — but this is pre-existing behavior in `stop_log.ml`/`.mli`, untouched by this PR's diff, and not a claim this PR makes. Not a CP1/CP2 finding for this review; noted for completeness only.
- **Failing-before/passing-after plausibility:** the claim (disable the `_notify_transitions` call site, all 6 new tests fail with `Expected Some but got None`/count mismatches) is plausible and consistent with the code: all 6 assertions depend exclusively on data flowing through `on_transitions`; nothing else in the diff could produce a false pass.

## Behavior-neutrality

Agree with qc-structural's structural finding: `_notify_transitions` discards the observer's return value and the same `transitions` binding flows unchanged into `_apply_transitions`/`Order_generator.transitions_to_orders`. No existing golden/regression fixture was touched or needed to be touched by this diff (confirmed via the PR file list — no golden `.sexp`/CSV fixtures appear), consistent with a pure side-effect addition. I did not find an existing bit-identical simulator golden test in this PR's diff that would have caught a violation if one had been introduced — that class of protection lives in the broader existing golden-scenario suite (out of this PR's diff) and CI already reports green on it at this SHA.

## Quality Score

3 — Clean, well-documented, correctly-scoped fix with genuinely strategy-agnostic design and solid two-layer test coverage for the three headline labels. Held to 3 (not 4) by two concrete, fixable gaps: the collision-overwrite guard claim (the PR's own stated bugfix-as-side-effect) is untested, and `Closes #2057` auto-closes an issue whose title names a sink this PR admits it does not fix, with no tracked follow-up filed.

## Verdict

NEEDS_REWORK

## NEEDS_REWORK Items

### CP4: Collision-overwrite guard claim has no test
- Finding: PR body and `panel_runner.ml` comment claim that on a same-tick strategy/margin collision on the same position, the later `on_transitions` call correctly overwrites the `Strategy_wrapper`'s stale strategy-side trigger with the winning margin label — explicitly framed as a bug fixed "as a side effect." No test in the diff exercises this scenario through the `Stop_log`-recording composition.
- Location: `trading/trading/backtest/lib/panel_runner.ml` (comment above `_make_simulator`); PR body "Fix" section. Untested gap spans `trading/trading/simulation/test/test_margin_runner.ml` (`test_e2e_strategy_exit_collides_with_margin_call`, unmodified, doesn't wire `Stop_log`/`on_transitions`) and `trading/trading/backtest/test/test_margin_exit_observability.ml` (new, but all 3 tests use the passive `_make_one_shot_strategy`, which never emits a competing `TriggerExit`).
- Authority: PR body §Fix: "on a same-tick collision the later `on_transitions` call correctly overwrites the wrapper's stale strategy-side trigger with the winning margin one (a latent staleness bug the old design had on collision days, fixed as a side effect)."
- Required fix: add a test to `test_margin_exit_observability.ml` (or extend `test_margin_runner.ml`) that wires both `Strategy_wrapper.wrap ~stop_log` and `~on_transitions:(Stop_log.record_transitions stop_log)` (the exact `_run_and_collect_stop_log` composition already built in this PR), drives a strategy that itself emits a stop-loss `TriggerExit` on the same position/tick that also breaches margin (reuse the existing `_short_then_stop_strategy` fixture from `test_margin_runner.ml`'s `test_e2e_strategy_exit_collides_with_margin_call`), and asserts `Stop_log.get_stop_infos`'s `exit_trigger` for that position carries the margin label (`margin_call`), not the strategy's stop-loss label.
- harness_gap: LINTER_CANDIDATE — deterministic golden scenario (fixed fixture, fixed expected label) once written.

### CP2: `Closes #2057` auto-closes an issue whose title names an unfixed sink, with no tracked follow-up
- Finding: Issue #2057's title is "Margin-driven exit reasons ... do not propagate to trades.csv / trade_audit.sexp" (both sinks). This PR fixes the `trades.csv`/`Stop_log` sink only; its own "trade_audit.sexp scope note" documents that the `trade_audit.sexp` sink remains unfixed and states the follow-up was deliberately "not filed as a new issue (needs its own design first)." Merging with `Closes #2057` will auto-close the issue, leaving the still-broken half of the originally-reported bug with no open tracking artifact.
- Location: PR body (trailing `Closes #2057` line); `dev/status/margin-realism.md` follow-up bullet (marks `#2057` `[x]` done).
- Authority: issue #2057 title + body ("do not propagate to trades.csv / trade_audit.sexp"; "Impact: the M4 ... deliverable ... cannot be completed from scenario outputs").
- Required fix: either (a) drop `Closes #2057` (use "Addresses #2057" / "Partially fixes #2057") and open a new tracked issue for the `trade_audit.sexp` propagation gap, referencing it from both the PR body and `dev/status/margin-realism.md` in place of the untracked prose note; or (b) narrow #2057 itself (edit title/scope to `trades.csv`-only) before merge and file the new issue for the `trade_audit.sexp` half. Either way the remaining gap needs a real tracked artifact, not just a status-file paragraph.
- harness_gap: ONGOING_REVIEW — this is a process/scope judgment (does closing #2057 as currently titled match what was actually fixed), not something a deterministic test can encode.

---

Reviewed SHA: 1eaa6806229d14df45b92e5f315ebca77b746af1

## Behavioral QC — re-review at 1eaa6806 (rework iteration 1)

### Scope classification

Unchanged from the prior pass: observability/plumbing PR over the margin
subsystem, no strategy decision logic. S1–S6/L1–L4/C1–C3 remain NA. Review is
CP1–CP4 plus the standing A1 judgment.

### Finding 1 (CP2, prior FAIL) — re-verified CLOSED

- Fetched issue **#2076** via the REST API: open, titled `trade_audit.sexp
  does not capture margin-driven exit reasons (remaining half of #2057)`.
  Body correctly names the root cause (`Exit_audit_capture.emit_for_list`
  only ever covers `Stops_runner`-triggered/strategy-emitted exits;
  `Margin_runner` sits outside that path and has no macro/stage/RS context to
  fabricate), states this is pre-existing behavior shared with other
  `StrategySignal` exit types (not margin-specific), and lists two candidate
  fix shapes. This is a real tracked artifact, not a status-file paragraph.
- Checked the current PR body (`GET /pulls/2074`) and every commit message on
  the PR (`GET /pulls/2074/commits`) for GitHub closing-keyword patterns
  (`closes?|closed|fix(es|ed)?|resolves?|resolved` immediately followed by
  `#2057`, case-insensitive). Two literal substring matches exist — one in
  the PR body ("`Closes #2057` would otherwise have auto-closed..."), one in
  commit `d684c471c0`'s message ("change PR body's Closes #2057 to a
  non-closing cross-reference") — but both are backtick-quoted /
  prose-describing-the-removed-keyword, not live directives. Rather than
  trust my own read of GitHub's keyword regex, I queried GitHub's own
  linkage record directly: `POST /graphql`
  `pullRequest(number: 2074) { closingIssuesReferences }` →
  **`{"nodes": []}`** — GitHub itself currently associates **zero** closing
  issue references with this PR. #2057 will not auto-close on merge.
- PR title reads `... (#2057)` — a plain reference, not a closing keyword.
- Verdict: **CLOSED.** #2076 exists, is open, and accurately scopes the
  remaining gap; no live closing-keyword risk to #2057 survives (confirmed
  via GitHub's GraphQL API, not just text inspection).

### Finding 2 (CP4, prior FAIL) — re-verified CLOSED

- Read the new test `test_stop_log_records_margin_call_on_strategy_collision`
  in `trading/trading/backtest/test/test_margin_exit_observability.ml`
  (lines 254–363 at this SHA). It builds `_short_then_stop_strategy`, a
  strategy that enters a short at $50 on day 1 and emits its own
  `TriggerExit { StopLoss }` once price crosses `stop_trigger_price = 60.0`.
  Driven against the `_aapl_rising_50_to_70` fixture (50→52→58→65→68→70→70),
  price crosses 60.0 on day 4 (close $65) — the same bar on which margin's
  maintenance-call trigger fires for a $50 short under the default 50%
  IM/25% MM config (also 60.0). This is a genuine same-tick collision, not a
  vacuous pass on a different-tick exit — confirmed by re-deriving the
  trigger arithmetic independently, not just trusting the comment.
- The assertion (`_assert_strategy_signal_label ~expected_label:"margin_call"`)
  checks the specific `Strategy_signal { label; _ }` string via
  `String.equal label expected_label`, not merely "some non-blank
  exit_trigger" — conforms to `.claude/rules/test-patterns.md`.
- Traced the mechanism myself end to end (not just re-stated the author's
  claim):
  - `Backtest.Strategy_wrapper.wrap` calls `Stop_log.record_transitions
    stop_log transitions` on the *raw* strategy output at `_call_strategy`
    time (`strategy_wrapper.ml:12`) — this records the strategy's `Stop_loss`
    label into the position's mutable `pos_exit_trigger` field
    (`stop_log.ml:107-109`, unconditional overwrite on each `TriggerExit`).
  - `Margin_runner.tick` is called next, computing
    `strategy_transitions @ margin_trans` — but only after routing
    `strategy_transitions` through `dedup_strategy_exits_for_margin`
    (`margin_runner.ml:88-98`, `.mli:80-94`), which drops any `TriggerExit`
    from `strategy_transitions` whose `position_id` collides with a margin
    transition. The `.mli` docstring (pre-existing, unmodified by this PR)
    already documents this exact behavior for exactly this reason ("issue
    #1266 ... margin wins by priority").
  - `_notify_transitions` (`simulator.ml:396-397,419`) fires with this final,
    deduped list — which for the colliding position contains **only**
    margin's `TriggerExit`, never the strategy's — and `_apply_transitions`
    (line 420) is called on that same list right after, so only margin's
    exit is ever actually applied.
  - `on_transitions = Stop_log.record_transitions stop_log`
    (`panel_runner.ml:85`) receives this second, final call and overwrites
    `pos_exit_trigger` a second time with margin's label.
  - Net effect verified structurally: the strategy's `Stop_loss` label is
    always transient (overwritten before any reader ever sees it), and the
    strategy's stop-loss transition is provably never applied to the
    position — so "margin wins" is a deterministic consequence of
    `dedup_strategy_exits_for_margin`'s pre-existing, independently-tested
    contract, not a last-writer-wins race as the original wording implied.
- **Comment correction also verified.** The `panel_runner.ml` comment above
  `_make_simulator` was updated (diff vs `ef6694ee`: `+5/-1` lines) to add:
  "This is the correct outcome, not a race:
  `Margin_runner.dedup_strategy_exits_for_margin` drops the strategy's
  colliding `TriggerExit` before `_apply_transitions` runs, so only margin's
  exit actually executes" plus a citation of the new test. The PR body
  carries the equivalent correction. Neither the code comment nor the PR body
  now states the misleading "overwrites a stale trigger" framing *without*
  the corrective mechanism explanation — the CP4 finding's secondary point
  (misdescribed mechanism) is also resolved, not just the missing-test part.
- Verdict: **CLOSED.**

### Regression check — prior CP1/CP3/A1

- CP1: unaffected; the three-label × two-layer test coverage this row
  evaluated is untouched by the rework (verified `git diff` of
  `test_margin_runner.ml` between `ef6694ee` and `1eaa6806` is empty — no
  changes at all in this iteration). CP1's noted minor gap (cadence-
  independence claim untested) was explicitly flagged "not blocking" last
  round and remains so; still non-blocking, not re-opened.
- CP3: still NA — no pass-through/identity semantics in this feature.
- A1: **re-confirmed PASS.** `git diff ef6694ee 1eaa6806 --
  trading/trading/simulation/lib/simulator.ml
  trading/trading/simulation/lib/simulator.mli` is empty — the rework
  touched zero lines of the core `Simulator` module. The A1 generalizability
  judgment from the prior pass (strategy-agnostic `Position.transition list
  -> unit` hook, mirrors `on_trade_fill`, domain coupling lives entirely at
  `Panel_runner`) stands unchanged since its evidentiary basis (the diff) is
  unchanged.

### Behavior-neutrality — still holds

The rework's only production-code change is the `panel_runner.ml` comment
(prose only, `+5/-1` lines, zero executable-line changes — confirmed via
`git diff`). The new test file and test additions add test-only code. No
production call site, control flow, or ordering changed since the prior
structural APPROVED pass. Exit prices/quantities/fill timing/equity curves
remain bit-identical by construction (same argument as last round: the
observer's return value is discarded and the `transitions` binding flows
unchanged into `_apply_transitions`).

### Merge-commit sanity

Parents of `1eaa6806`: `d684c471c0` (this PR's own tip) and `ddb6255dff`
(main). `git diff d684c471c0 1eaa6806 -- <PR's 7 files>` is **empty** — the
merge did not touch, conflict-mangle, or revert any of this PR's own files.
The merge's only substantive content is `dev/status/tax-lens.md` and
`trading/trading/backtest/tax_lens/**` (merged PR #2073's work) — correctly
out of scope for this review, not evaluated here.

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new `.mli` docstrings has an identified test that pins it | PASS (same caveat as prior pass) | Unchanged since `ef6694ee` — `test_margin_runner.ml` diff between the two SHAs is empty. Minor untested cadence-independence sub-claim remains non-blocking. |
| CP2 | Each claim in PR body "Test plan"/"Test coverage" sections has a corresponding test in the committed test file | PASS | Prior FAIL closed: `Closes #2057` removed from the live-directive position in the PR body (replaced with "Partially addresses #2057"); GitHub's own `closingIssuesReferences` GraphQL field returns empty for PR #2074, confirming no live auto-close association survives. Follow-up issue #2076 filed, open, and accurately scoped. All "Which labels are pinned, and where" claims remain test-backed (6 tests, verified present). |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size | NA | No pass-through semantics in this feature. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PASS | Prior FAIL closed: `test_stop_log_records_margin_call_on_strategy_collision` drives a genuine same-tick strategy/margin collision (independently re-derived, not vacuous) and asserts the specific `margin_call` label. Mechanism independently traced end-to-end (dedup → notify → apply ordering) and confirmed correct; the `panel_runner.ml` comment's mechanism description was also corrected to match ("not a race"), not just backed by a new test. |

## A1 generalizability judgment (standing, re-confirmed)

**PASS — unchanged from prior pass.** Zero diff on `simulator.ml`/`.mli`
between `ef6694ee` and `1eaa6806`; the strategy-agnostic hook design, its
`on_trade_fill`-mirroring shape, and the domain-coupling boundary at
`Panel_runner` are all as previously assessed and re-verified.

## Quality Score

4 — Both prior findings are genuinely closed with real artifacts (a
correctly-scoped tracked issue, a non-vacuous collision test, and a
corrected mechanism explanation), not just paperwork. The rework is
minimal and precisely targeted (test-only + comment-only + status-doc
changes; zero production-code diff beyond prose). Held at 4 rather than 5
because the `Closes #2057`-adjacent phrasing choice (relying on
backtick-quoting to defuse a literal keyword+issue-number adjacency, rather
than restructuring the sentence to avoid the adjacency entirely) was a
slightly fragile way to resolve the finding, even though GitHub's own API
confirms it works as intended here.

## Verdict

APPROVED

---

Reviewed SHA: 1eaa6806229d14df45b92e5f315ebca77b746af1

## Structural QC — delta re-review at 1eaa6806 (rework iteration 1)

Supersedes the structural verdict at `ef6694ee` (APPROVED, above) with a
delta-scoped re-review of the rework addressing qc-behavioral's CP2 and CP4
findings. Prior APPROVE stands for everything unchanged; only the rework
delta is re-checked here.

### Hard gates (re-verified at 1eaa6806)

Polled `GET /commits/1eaa6806.../check-runs` until both required checks
completed (`build-and-test` was `in_progress` for ~13 min of polling before
completing):

- `build-and-test`: completed / **success**
- `perf-tier1-smoke`: completed / **success**

`build-and-test` runs `dune build @fmt`, `dune build`, `dune runtest` plus
the full linter suite — H1–H3 PASS on this evidence.

### Scope of the delta

`git log --oneline ef6694ee..1eaa6806` shows three commits:

1. `d684c471 fix(review): address QC rework iteration 1 — collision-label
   test + trade_audit follow-up` — the author's rework, touching exactly
   `dev/status/margin-realism.md`, `trading/trading/backtest/lib/panel_runner.ml`,
   `trading/trading/backtest/test/test_margin_exit_observability.ml`.
2. `ddb6255d test(tax-lens): pin Loader.load_exn error-path contract (#2066
   CP4 follow-up) (#2073)` — merged PR #2073, brought in via the branch
   update-merge. Touches `dev/status/tax-lens.md`,
   `trading/trading/backtest/tax_lens/lib/loader.ml`,
   `trading/trading/backtest/tax_lens/test/dune`,
   `trading/trading/backtest/tax_lens/test/test_loader.ml`. **Not this PR's
   work** — confirmed against the PR-files API (`/pulls/2074/files`), which
   shows zero net diff for these paths against current `main` (they're
   already on `main` via #2073, so this PR's cumulative diff against `main`
   excludes them entirely). Correctly out of scope for this review, per
   dispatch instructions. `dev/reviews/tax-lens.md` left untouched.
3. `1eaa6806 Merge branch 'main' into feat/margin-realism-exit-labels` — the
   merge commit itself. Verified clean: no `<<<<<<<`/`=======`/`>>>>>>>`
   conflict markers in any of the three author-touched files at the merge
   tip.

### Delta checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| P6 | Test-pattern conformance on new test | PASS | `test_stop_log_records_margin_call_on_strategy_collision` (new, `test_margin_exit_observability.ml`) uses exactly one `assert_that` via the existing `_assert_strategy_signal_label` helper, asserting the specific label `margin_call` via `is_some_and (matching ... (equal_to ()))` — not a generic non-blank check. No sub-rule-1/2/3 violations: no `List.exists .* equal_to (true\|false)`, no discarded `on_market_close`/`.run` result (the pre-existing `_run_and_collect_stop_log` setup helper's `match create/run with Error -> assert_failure` idiom is the same sanctioned "Domain-Specific Helper" pattern already PASSed in the prior review, unchanged by this delta), no bare `Ok ->`/`Error -> assert_failure` used as the test's own assertion. |
| A3 | No scope creep in author's own commits | PASS | Author commit `d684c471` touches exactly the three expected files (`test_margin_exit_observability.ml`, `panel_runner.ml`, `dev/status/margin-realism.md`). No `dev/reviews/*.md` committed by the author, no `dev/status/_index.md` touched. The tax_lens / `dev/status/tax-lens.md` files in the raw `ef6694ee..1eaa6806` diff originate from merged PR #2073 (commit `ddb6255d`), not the author — correctly excluded from A3 scope per dispatch instructions. |
| — | `panel_runner.ml` change is comment-only | PASS | Delta diff is a pure docstring/comment addition above `_make_simulator` (adds a citation to the new test + a two-sentence clarification of *why* the overwrite is correct, not a race). Zero executable-code lines changed (`git diff` shows only `+`/`-` inside the existing comment block). No re-check of P1/nesting/file-length needed; file length unaffected — no limit bump, no `@large-module` marker, consistent with `.claude/rules/code-health-discipline.md`. |
| — | `on_transitions` design unchanged | PASS | `git diff ef6694ee..1eaa6806 -- simulator.ml simulator.mli test_margin_runner.ml backtest/test/dune` is empty — none of these files appear in the delta. The already-reviewed/approved hook design (strategy-agnostic, `on_trade_fill`-mirroring, side-effect-only) is untouched by the rework. |
| A1 | Core-module modification | PASS | No new core-module touch beyond the already-FLAGged (and qc-behavioral PASSed) `simulator.ml`/`.mli`, which is unchanged in this delta. Nothing new to flag. |
| A2 | No new disallowed `analysis/` imports | PASS | No dune-file changes in the author's delta commit; the merged-in tax_lens dune change is pre-existing #2073 scope, already covered by that PR's own review, not re-litigated here. |
| — | Merge-commit sanity | PASS | Clean merge, no conflict markers, no accidental reverts in any of the three author-touched files. |
| — | Follow-up issue #2076 exists and is correctly scoped | PASS | Verified via API: issue #2076 is **open**, titled "trade_audit.sexp does not capture margin-driven exit reasons (remaining half of #2057)" — matches the CP2 rework requirement (a real tracked artifact, not just a status-file paragraph). PR body now reads "Partially addresses #2057" (verified via `/pulls/2074` body text) with #2076 cross-referenced, in place of the prior `Closes #2057`. |

### Verdict

**APPROVED** (delta re-review at `1eaa6806`, superseding the `ef6694ee`
APPROVE). Both rework items (CP2 tracked-follow-up, CP4 collision test) are
structurally sound: the new test is P6-conformant and asserts the specific
label, the `panel_runner.ml` change is comment-only (no re-triggered
code-health checks), and no scope creep occurred in the author's own commits.
The merge-in of PR #2073's tax_lens changes is correctly out of scope for
this PR. This concurs with qc-behavioral's independent delta APPROVED
verdict above.

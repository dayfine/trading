Reviewed SHA: 0f1d11f1178548e2e013f0b5b45dd71025b7eb02

## Structural QC — leverage-dawn (PR #2077, rework iteration 1)

This is the second structural pass on this PR. Prior qc-behavioral NEEDS_REWORK
(quality 2/5) at `1c557186` found B1: the dawn mechanism swapped
`initial_long_margin_req` only on the entry-walk sizing config while the
simulator's funding path (`Panel_runner` -> `Simulator.create_deps` ->
`apply_single_trade_with_long_margin`) stayed pinned at the base req 1.0 and
floor-rejected the levered buy. This review verifies the "permissive-funding
inversion" rework against the diff directly (not on trust).

### H1-H3 (hard gates)

- Main baseline (`46b3a8d0`): `dune build` / `dune runtest` exit 0, zero
  `^FAIL:` lines (orchestrator-recorded).
- PR branch (`0f1d11f1`): `dune build @fmt` exit 0, `dune build` exit 0,
  `dune runtest --force` exit 0 (full suite, ~3m18s), zero `^FAIL:` lines,
  `status_file_integrity.sh` exit 0, `test_leverage_dawn.exe` 23/23 OK
  (implementing-agent-recorded, foreground exit codes).
- GitHub CI on `0f1d11f1`: both required checks GREEN —
  `perf-tier1-smoke completed success`, `build-and-test completed success`.
  (Per coordinator: the earlier `build-and-test` failure on tip `d1416a0e` was
  the documented GHA runner disk-exhaustion flake, not a real linter failure —
  the same tree's linter fixes were already correct and this later CI run on
  `0f1d11f1` confirms it clean.)

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | Implementing-agent foreground run exit 0; confirmed by green CI `build-and-test` on `0f1d11f1`. |
| H2 | dune build | PASS | Exit 0 on both main baseline and PR tip; confirmed by CI. |
| H3 | dune runtest | PASS | Full suite exit 0, zero `^FAIL:` lines; `test_leverage_dawn.exe` 23/23 OK, matches the 23-case suite enumerated in `test_leverage_dawn.ml`; confirmed by CI `build-and-test: success`. |
| P1 | Functions ≤ 50 lines (linter) | PASS | H3/CI clean covers this. Independently spot-checked: `leverage_dawn.ml` functions all ≤17 lines (`dawn_active` longest at 17); `screen_universe` in `weinstein_strategy_screening.ml` now 47 lines (was 53, the prior-review linter FAIL) after extracting `_entries_of_screen_result`. |
| P2 | No magic numbers (linter) | PASS | H3/CI clean covers this. `_cash_account_margin_req = 1.0` and `_flip_search_margin_weeks = 8` are named constants with doc comments, not inline literals. |
| P3 | Config completeness | PASS | All three new tunables (`dawn_leverage_enabled`, `dawn_initial_long_margin_req`, `dawn_max_ma_flip_age_weeks`) are real fields on `Weinstein_strategy_config.config` with `[@sexp.default]` no-ops, not hardcoded. The new permissive-base-req value (0.75) lives only in the WF-spec axis file, not as a code literal. |
| P4 | Public-symbol export hygiene (linter) | PASS | H3/CI clean covers this (`.mli` present for `leverage_dawn.ml`, fully documented; `weinstein_strategy.mli` / `weinstein_strategy_config.mli` updated to match). |
| P5 | Internal helpers prefixed per convention | PASS | All non-exported helpers in `leverage_dawn.ml` and the new `_entries_of_screen_result` in `weinstein_strategy_screening.ml` use the `_` prefix convention. |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | PASS | `test_leverage_dawn.ml` has `open Matchers`. Sub-rule 1 (`List.exists .* equal_to (true\|false)`): zero hits. Sub-rule 2 (`let _ = ... on_market_close`/`.run`): zero hits. Sub-rule 3 (`match ... with` + `Error -> assert_failure` / bare `Ok ->`): one hit, at `debit_after_dawn_entry` (lines ~326-341) — `match apply_single_trade_with_long_margin ... with \| Ok p -> p.long_margin_debit \| Error err -> assert_failure ...`. This is the sanctioned "Domain-Specific Helper" idiom test-patterns.md documents verbatim (`apply_trades_exn`, "build on top of matchers"): a setup helper that unwraps a `Result` to a scalar, whose value is *then* asserted via `assert_that (debit_after_dawn_entry ...) (gt (module Float_ord) 0.0)` / `(float_equal 0.0)` in the actual test bodies. The end-to-end `Portfolio_margin` Result assertion in `test_base_cash_account_req_would_reject` uses `assert_that ... is_error` directly, not a raw match. No test in this file substitutes a raw match for `is_ok_and_holds` at the point of assertion. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | NA | `git diff --stat` confirms zero touches to `trading/trading/portfolio/`, `trading/trading/orders/`, `trading/trading/position/`, `trading/trading/engine/`, `trading/trading/simulation/`. All 9 code/doc files are under `trading/trading/weinstein/strategy/` or are new files (`leverage_dawn.ml/.mli`, test, WF-spec, plan, status). Independently confirmed — not a FLAG. |
| A2 | No new `analysis/` imports into `trading/trading/` outside allow-list | PASS | Zero `analysis` references in any touched `dune` file. |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | File list from `gh pr view 2077 --json files` (via API) matches `git diff --name-only origin/main...0f1d11f1` exactly (12 files, byte-identical set) — no ancestry-walk drift. All modified existing files (`weinstein_strategy.ml/.mli`, `weinstein_strategy_config.ml/.mli`, `weinstein_strategy_screening.ml`, `test/dune`) are directly load-bearing for wiring the new mechanism in; no incidental drive-by edits. |
| Index-hygiene | `dev/status/_index.md` untouched (`.claude/rules/feat-agent-dispatch.md` §4) | PASS | Not in the diff; PR correctly scoped to `dev/status/leverage-dawn.md` only. |

## B1 rework verification (structural read of the fix, not a behavioral re-judgment)

Verified directly against the diff, not taken on trust:

- `Leverage_dawn.validate` gained `_validate_base_at_most_dawn_req`, which
  raises `Failure` when `config.initial_long_margin_req >
  config.dawn_initial_long_margin_req`. It is called **only** inside
  `if config.dawn_leverage_enabled then begin ... end` in `validate` — a
  no-op when the mechanism is off, consistent with R1.
- The permissive base req (`initial_long_margin_req 0.75`) is set **only** in
  `trading/test_data/walk_forward/leverage-dawn-BROAD-2000-2026.sexp` as an
  explicit WF-spec axis (`((key (initial_long_margin_req)) (values (0.75)))`).
  Grepped `initial_long_margin_req` across the full repo (`origin/main` vs PR
  tip): `weinstein_strategy_config.ml`'s `default_config` and the `.ml`
  `[@sexp.default]` still read `1.0` — the base default is untouched, so
  `dawn_leverage_enabled = false` (or omitted) remains an exact no-op (R1
  intact).
- Three new tests (`test_dawn_week_funds_levered_entry`,
  `test_non_dawn_week_no_new_debit`, `test_base_cash_account_req_would_reject`)
  exist exactly as claimed, exercise `Portfolio_margin.apply_single_trade_with_long_margin`
  directly (the funding seam, not just the sizing-config value), and assert
  `long_margin_debit` via `gt`/`float_equal`/`is_error` — this is a materially
  different (and stronger) assertion surface than the pre-rework tests, which
  only checked `dawn_effective_config`'s returned config value.
- `weinstein_strategy.mli`'s config docstrings for `dawn_leverage_enabled` /
  `dawn_initial_long_margin_req` now explicitly describe **two functional
  readers** of `initial_long_margin_req` (entry-walk sizing ceiling + simulator
  fill-funding path) and the `base <= dawn` invariant — the false "sole
  functional reader" claim flagged in the prior review is gone from this file.
  (`leverage_dawn.mli` already carried the corrected framing.)

Whether the *design* (permissive base funding + gated per-week sizing) is the
behaviorally correct fix — e.g., whether raising the entry walk to a cash
account off-dawn actually prevents new borrowing at the simulator's permissive
base req, and whether this composes correctly with existing margin state
carried across weeks — is a domain/contract question for qc-behavioral (T4,
CP1/CP4), not structural. Flagging for their attention: this is exactly the
class of "docstring claim vs. actual code path" issue that tripped B1 the
first time, so a fresh grep-verification (not a re-read of the corrected
prose) on the funding path is warranted.

## Commit-message hygiene note (non-blocking)

The branch carries `b5985f84`, titled `WIP: leverage-dawn B1 rework
(permissive-funding redesign) — agent hit session limit mid-task, state
UNVERIFIED`. The subsequent `0f1d11f1` commit and full green test run (local
+ CI) confirm the state was in fact verified before merge. Since this repo's
merge gate is `gh pr merge --squash`, the WIP/UNVERIFIED commit message will
not become the final commit subject (GitHub uses the PR title by default) but
may appear in the squash commit body's auto-populated commit list unless
edited at merge time. Not a structural FAIL — flagging so the squash-merge
step edits the body to drop the stale "UNVERIFIED" line rather than landing
it verbatim on `main`.

## Verdict

APPROVED

Structural review finds no FAILs. All applicable rows PASS/NA. The B1 rework
is verified present and load-bearing in the diff (not just claimed in prose).
Both required CI checks (`perf-tier1-smoke`, `build-and-test`) are green on
`0f1d11f1`.

---

Reviewed SHA: 0f1d11f1178548e2e013f0b5b45dd71025b7eb02

## Behavioral QC — leverage-dawn (P1b) — RE-REVIEW (iteration 1, prior verdict NEEDS_REWORK at 1c557186)

This re-review verifies the B1 fix against the production seam, not just unit-level
config assertions — per the prior review's central finding that the funding
authority (`Panel_runner` -> `Simulator.create_deps` -> `apply_trades_best_effort`
-> `Portfolio_margin.apply_single_trade_with_long_margin`) was pinned at base req
1.0 while the entry-walk sizing swapped only its own local config copy.

### Confirmed at the code level (not just re-reading corrected prose)

- `panel_runner.ml:62` (`_make_simulator`) is **unchanged** in this rework — it
  still threads `input.config.initial_long_margin_req` (the base field) into
  `Simulator.create_deps`, which is still the sole funding authority for the
  whole run. `simulator.ml`, `portfolio_margin.ml` are untouched (confirmed via
  `git diff --stat origin/main...0f1d11f1`: only `leverage_dawn.{ml,mli}`,
  `weinstein_strategy.{ml,mli}`, `weinstein_strategy_config.{ml,mli}`,
  `weinstein_strategy_screening.ml`, the test file, and the WF spec/status/plan
  docs changed).
- The fix is entirely in what value is *fed into* that unchanged path:
  1. `Leverage_dawn.effective_initial_long_margin_req` now returns
     `_cash_account_margin_req` (1.0) on a non-dawn week when enabled (previously
     it fell through to `config.initial_long_margin_req`, which happened to be
     1.0 only because the base was always 1.0). This is the "gated sizing" half —
     load-bearing precisely because the base is no longer assumed to be 1.0.
  2. `trading/test_data/walk_forward/leverage-dawn-BROAD-2000-2026.sexp` now sets
     `((key (initial_long_margin_req)) (values (0.75)))` — the base is armed
     permissive at the most-restrictive value that still funds every dawn rung
     `{0.90, 0.85, 0.75}` in the sweep. This is the "permissive funding" half.
  3. `Leverage_dawn.validate` gained `_validate_base_at_most_dawn_req`, raising
     `Failure` when `base > dawn`, called (unconditionally on every strategy
     construction) at `Weinstein_strategy.make` — confirmed unchanged call site
     `weinstein_strategy.ml:372` (`Leverage_dawn.validate config;`, present since
     before this rework, still wired).
- **Choke-point check (no bypass):** `panel_strategy_builder.ml`'s `build`
  dispatches to `Weinstein_strategy.make` for `Strategy_choice.Weinstein`, which
  is the strategy the WF spec's `base_scenario`
  (`top3000-2000-2026-record-convention.sexp`, no `strategy_choice` override ->
  default `Weinstein`) exercises. `Sector_rotation_weinstein_strategy.make` and
  `Spy_only_weinstein_strategy.make` do NOT call `Leverage_dawn.validate`, but
  neither of those strategy variants reads `dawn_leverage_enabled` at all (grep
  confirms `Leverage_dawn` is referenced only from `Weinstein_strategy_screening`,
  which only the base `Weinstein_strategy.make` path invokes) — so there is no
  route by which an armed dawn cell reaches a strategy variant that skips
  `validate`. The armed path is protected.
- Code-level defaults are untouched: `weinstein_strategy_config.ml:113,122` still
  default `initial_long_margin_req` and `dawn_initial_long_margin_req` to `1.0`
  (`[@sexp.default 1.0]`); the permissive base only exists in the one WF spec
  file that opts in. Any other scenario/backtest not touching this axis is
  unaffected — R1 holds.
- `test_dawn_week_funds_levered_entry` / `test_non_dawn_week_no_new_debit` /
  `test_base_cash_account_req_would_reject` call
  `Portfolio_margin.apply_single_trade_with_long_margin` directly (not through
  `Panel_runner`/`Simulator`) — this is a unit-level call to the *same function*
  the production seam calls, at the *same* `initial_long_margin_req` argument
  the production seam threads through unmodified code. It is legitimate
  regression coverage for "does funding occur at a permissive base req" and
  "does it reject at the old base req" (root-cause pin), but it does **not**
  exercise `Panel_runner`/`Simulator.create_deps` wiring end-to-end (e.g. via a
  synthetic `test_panel_runner_*`-style scenario). That wiring is itself
  unchanged pre-existing code (confirmed above via the diff-stat and file read),
  so the gap is materially small — but it is a gap: no test in this PR proves the
  WF-spec's `((key (initial_long_margin_req)) (values (0.75)))` axis actually
  lands on `Simulator.create_deps` for an armed cell. That composition (config
  override -> `Overlay_validator` -> `Panel_runner` -> `Simulator.create_deps`)
  is generic pre-existing `Variant_matrix`/`Overlay_validator` machinery
  exercised by many other WF specs' own tests, not dawn-specific, so I do not
  treat this as a fresh B1 recurrence — but it is the one remaining inferential
  step in "B1 is closed," not a directly pinned one.
- **Interest/maintenance pricing:** not re-tested by this PR, and doesn't need to
  be — once a debit is created via `apply_single_trade_with_long_margin` (now
  demonstrated to occur for a dawn week), interest accrual
  (`long_margin_rate_annual_pct`) and maintenance force-reduce
  (`maintenance_long_pct`) are pre-existing, already-tested mechanics
  (`test_margin_accounting.ml`, `test_long_maintenance.ml`,
  `test_margin_runner.ml`) that apply to any funded debit regardless of how it
  was created. The prior review's "unpriced" finding was a *consequence* of B1
  (no debit ever formed to price), not a separate defect; with funding now
  occurring, pricing follows automatically through unmodified code.

**Verdict on the crux question: B1 is closed at the production seam**, with the
caveat above (Panel_runner/Simulator wiring itself is unchanged, well-established
code — the fix is entirely in the values fed into it, and those are verified by
direct grep/read, not just re-reading the corrected prose).

### PR-body staleness (flagged, non-blocking for verdict)

The GitHub PR body (`pulls/2077` current body) was **not updated** for the
rework: it still states "That field's **sole functional reader** is the
entry-walk buying-power ceiling" — the exact false claim that was B1's root
cause — and its Test Plan section still says "19 cases" (now 23) with no mention
of the B1 fix, the `validate` base<=dawn guard, or the three new end-to-end
funding tests. `dev/status/leverage-dawn.md` (the correct authority per this
repo's status-file convention) DOES carry an accurate rework changelog entry
under `## behavioral_qc`; only the PR body prose is stale. This does not
mechanically fail CP2 (every test named in the PR body's Test Plan section does
still exist as a subset of the current 23), but it is a real documentation-drift
risk — the merged PR body will read as if the "sole functional reader" claim is
still true. **Recommend the PR body be refreshed (`gh pr edit`) before or at
merge** to match the corrected `.mli`/status-file framing; not gating this
verdict since the code, `.mli`, and status file are all internally consistent
and correct.

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial `.mli` claim has a pinning test | PASS | `leverage_dawn.mli`'s corrected "two functional readers / base<=dawn" claim is pinned by `test_dawn_week_funds_levered_entry` (dawn -> funded, `long_margin_debit > 0`), `test_non_dawn_week_no_new_debit` (off-dawn -> no new debit), `test_base_cash_account_req_would_reject` (root-cause: base=1.0 floor-rejects). `effective_initial_long_margin_req`'s tri-state (disabled/dawn/off-dawn-raised-to-cash) is pinned by `test_effective_req_dawn_active`, `test_effective_req_not_dawn`, `test_effective_req_disabled_ignores_dawn`. `validate`'s new `base<=dawn` guard is pinned by `test_validate_base_exceeds_dawn_req_raises`. Signal claims (lookahead-free, boundary-inclusive, etc.) unchanged from the pure-refactor and remain pinned per the prior review. |
| CP2 | PR-body "Test plan" claims each have a committed test | PASS | All 19 originally-advertised tests exist as a subset of the current 23. PR body is stale (undercounts at 19, doesn't mention the 4 new tests or the B1 fix) — under-claiming, not over-claiming, so this does not trip the CP2 FAIL condition (advertising a test that doesn't exist). Flagged above as a non-blocking documentation-drift item; recommend refreshing the PR body before merge. |
| CP3 | Pass-through/identity tests pin identity, not size | NA | No pass-through/list-identity semantics in this feature. |
| CP4 | Each guard named in docstrings has a test exercising the guarded scenario | PASS | The `base <= dawn` guard (`.mli` `dawn_leverage_enabled`/`dawn_initial_long_margin_req`/`validate` docstrings) is pinned by `test_validate_base_exceeds_dawn_req_raises`. The effect-isolation guard ("dawn swaps sizing only; funding follows the base req") is now pinned end-to-end by the three new funding tests, closing the prior CP4 FAIL. Pre-existing validation guards (margin-armed requirement, req range) remain pinned. |

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core-module change strategy-agnostic | NA | qc-structural did not flag A1 (re-confirmed: no changes to `portfolio/`, `orders/`, `position/`, `engine/`, or `simulation/` — diff is confined to `weinstein/strategy/lib/`, its test, a WF-spec sexp, and docs). |
| S1-S6 | Stage defs / buy criteria | NA | Stage classification, Stage-2-only buys, breakout+volume entry untouched. |
| L1-L4 | Stop rules / state machine | NA | Stops untouched. |
| C1-C3 | Screener cascade / macro / sector | NA | Cascade, macro gate, sector RS untouched. |
| T1 | 4 stage transitions covered | NA | No stage logic. |
| T2 | Bearish-macro -> zero candidates | NA | No macro logic. |
| T3 | Stop trailing over advances | NA | No stops. |
| T4 | Tests assert domain outcomes, not "no error" | PASS | Reversed from prior FAIL: `test_dawn_week_funds_levered_entry` asserts the actual domain outcome (`long_margin_debit > 0.0`, i.e. a funded, priced levered position), not just the config *value*. `test_non_dawn_week_no_new_debit` asserts the negative domain outcome (`long_margin_debit = 0.0`) on a non-dawn control. `test_base_cash_account_req_would_reject` asserts the domain failure mode (`is_error`) at the old base req, pinning the root cause. |
| W1 | Spine intact | PASS | Unchanged from prior review: only long deployment-intensity is touched; stages/buys/breakout+volume/stops/macro/sector all unchanged. `weinstein-faithful-core.md` spine untouched. Rework did not touch spine-adjacent code. |
| W2 | Adaptation is a config-expressed dial, cited | PASS | Three real `config` fields, `[@sexp.default]` no-ops, cite the P1b memo (`dev/notes/regime-dependency-evaluation-2026-07-24.md`). Prior caveat ("non-functional as wired") is resolved — the dial is now functional end-to-end at the production seam. |
| R1 | Default-off exact no-op | PASS | Re-verified at the code level (not re-reading prose): `weinstein_strategy_config.ml:113,122` still default both `initial_long_margin_req` and `dawn_initial_long_margin_req` to `1.0`; `dawn_effective_config` still short-circuits to `config` unchanged before any fetch when `dawn_leverage_enabled = false`; the permissive base (`0.75`) exists only inside the one armed WF-spec file, not in any code default or any other scenario. `test_defaults_are_noop` + `test_effect_disabled_unchanged` pin this. Merging changes no backtest result outside the one armed spec. |

## Quality Score

4 — B1 is genuinely closed: the fix is architecturally sound (permissive-funding / gated-sizing inversion), verified present in unchanged production code (not just corrected prose), protected by a new `validate` guard at the single strategy-construction choke point, and pinned by domain-outcome-asserting tests (T4 now PASS, reversing the prior FAIL). One point held back for the stale PR body (repeats the exact false "sole functional reader" claim that caused the original NEEDS_REWORK) and for the funding tests calling `Portfolio_margin` directly rather than through a `Panel_runner`/`Simulator` integration test — both non-blocking but worth closing before this pattern repeats on the next mechanism PR.

## Verdict

APPROVED

## Follow-ups (non-blocking, recommended before/at merge)

- Refresh the PR body (`gh pr edit`) to remove the "sole functional reader" claim and describe the permissive-funding/gated-sizing design + the 23-test suite, matching `dev/status/leverage-dawn.md`'s accurate changelog.
- Consider a future integration-level test (through `Panel_runner`/`Simulator.create_deps`, not directly through `Portfolio_margin`) for the next mechanism that swaps a `Simulator.create_deps` input conditionally, to close the one remaining inferential step identified above.

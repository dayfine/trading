Reviewed SHA: f9e3bd46f7d62d0479d407ff4a0babc711d57197

## Structural QC — extension-stop (PR #1934)

### Hard Gates

| Gate | Exit Code | Status | Notes |
|------|-----------|--------|-------|
| H1 (dune build @fmt) | 0 | PASS | |
| H2 (dune build) | 0 | PASS | |
| H3 (dune runtest) | 0 | PASS | 42 tests, 42 passed, 0 failed; all linters clean |

### Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| P1 | Functions ≤ 50 lines (linter) | PASS | fn_length_linter passed as part of H3; all helpers < 20 lines |
| P2 | No magic numbers (linter) | PASS | linter_magic_numbers passed as part of H3 |
| P3 | Config completeness | PASS | `extension_stop_config` has tunable fields (trigger_ratio, trail_pct); defaults to no-op (0.0, 0.0) |
| P4 | Public-symbol export hygiene (linter) | PASS | mli-coverage linter passed as part of H3; all public symbols documented |
| P5 | Internal helpers prefixed per convention | PASS | `_first_trigger`, `_trail_fires` correctly prefixed in extension_stop.ml |
| P6 | Tests conform to test-patterns | PASS | test_extension_stop.ml, test_extension_stop_runner.ml, test_runner_hypothesis_overrides.ml all use `assert_that` with Matchers library; no nested assertions |
| A1 | Core module modifications | PASS | No modifications to Portfolio, Orders, Position, Strategy, or Engine; only new modules in weinstein/stops/ and weinstein/strategy/ |
| A2 | Dependency-direction rules respected | PASS | No new `analysis/` imports into `trading/trading/` (pre-existing `indicators.*` in weinstein/strategy/lib/dune is unchanged) |
| A3 | No unnecessary existing module modifications | PASS | PR files are focused: 2 new pure modules (extension_stop), 1 new runner (extension_stop_runner), 1 integration point (special_exits.ml), 1 config update (weinstein_strategy_config), 5 test files, 3 status/notes docs |

### Experiment-Flag-Discipline Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| R1 | Default-off | PASS | `extension_stop_config` defaults to `Extension_stop.default_config` which has `trigger_ratio = 0.0`, `trail_pct = 0.0` — exact no-op, disables mechanism completely. Merging changes no backtest result. |
| R2 | Searchable axis | PASS | `extension_stop_config` is a real `Weinstein_strategy_config.config` field (line 454); routed through config sexp; can be expressed as `Variant_matrix` axis e.g. `((key (extension_stop_config trigger_ratio)) (values (2.0 2.25)))` (tested in test_runner_hypothesis_overrides.ml lines 546-553) |
| R3 | Promotion needs ledger ACCEPT | PASS | PR does NOT flip any default (mechanism stays default-off). No promotion claim made. |

## Verdict

**APPROVED**

## Summary

PR #1934 adds a tail-insurance extension-stop primitive — a default-off, wide-trail exit for long positions that have run far above their 30-week WMA (parabolic advances). All structural gates pass. The mechanism is:

- **Pure**: The core logic (extension_stop.ml) is a stateless computation over closing/WMA arrays.
- **Configurable**: Fully parameterized via `extension_stop_config.{trigger_ratio, trail_pct}` in the strategy config.
- **Default-off**: Both parameters default to 0.0, producing an exact no-op. Merging changes zero backtest behavior.
- **Integrated cleanly**: Wired through `Extension_stop_runner` as a special-exit channel in `special_exits.ml`, running on Friday ticks only, tighten-only (never lowers a structural stop).
- **Well-tested**: Unit tests pin default-off bit-identity, fire conditions, shakeout survival (width), skip-set collision, LONG-only constraint, and cadence gating. Axis reachability (R2) tested in overlay-validator tests.
- **No scope creep**: No changes to core modules; all PR files are focused on the extension-stop feature and supporting tests.

Architecture rules and experiment-flag-discipline all satisfied.

---

## Behavioral QC — extension-stop (PR #1934) @ f9e3bd46

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial .mli claim has an identified pinning test | PASS | `is_enabled` iff both>0 → `test_default_off_never_fires`/`test_default_off_no_exit`. Trigger (first finite-wma>0 week ≥ ratio) → `test_no_trigger_below_ratio`, `test_nan_wma_warmup_cannot_trigger`. Peak-seed + fire-check-before-update ("new high can never fire") → `test_new_highs_never_fire`. Fire (close ≤ peak·(1−trail)) → `test_collapse_below_trail_fires`. Width (0.25 survives / 0.15 kills) → `test_shakeout_survives_wide_trail` + `test_shakeout_exits_tight_trail`. Runner: LONG-only → `test_short_not_eligible`; Friday cadence → `test_off_cadence_no_op`; TriggerExit label+price → `test_collapse_fires_extension_stop`; default-off → `test_default_off_no_exit`. |
| CP2 | Each PR-body "Test plan" claim has a committed test | PASS | All three advertised suites present with the exact counts claimed: `test_extension_stop.ml` (9 tests, all listed cases present), `test_extension_stop_runner.ml` (6 tests), `test_runner_hypothesis_overrides.ml` (+3: `test_default_extension_stop_config_is_no_op`, `test_override_extension_stop_config`, `test_extension_stop_config_axis_resolves_via_overlay_validator`). No advertised test is missing. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size | PASS | The identity contract here is "disabled ⇒ emits nothing": `test_default_off_no_exit` / `test_shakeout_survives_wide_trail` / `test_skip_set_collision_no_op` / `test_short_not_eligible` / `test_off_cadence_no_op` all assert `List.length result = 0` (empty list fully pins the no-emit semantics). The fire test uses `elements_are [...]` with whole-transition matching (position_id + TriggerExit label + exit_price), not a bare count. Config no-op pinned by whole-value field assertions (`trigger_ratio=0.0` ∧ `trail_pct=0.0`). |
| CP4 | Each explicit code/docstring guard has a scenario test | PASS | NaN-WMA warmup guard → `test_nan_wma_warmup_cannot_trigger`; mismatched-length guard → `test_mismatched_lengths_returns_false`; empty-array guard → `test_empty_series_returns_false`; "new high can never fire" (fire-check precedes peak update) → `test_new_highs_never_fire`; already-exiting skip guard (tighten-only) → `test_skip_set_collision_no_op`; LONG-only guard → `test_short_not_eligible`. |

### Behavioral Checklist (domain — stop mechanism)

| # | Check | Status | Notes (authority) |
|---|-------|--------|-------------------|
| A1 | Core-module change strategy-agnostic | NA | qc-structural did not FLAG A1 — no core-module (Portfolio/Orders/Position/Strategy/Engine) modification; only new modules + config field + special_exits wiring. |
| S1–S6 | Stage definitions / buy criteria | NA | No stage-classification or buy logic touched; this is a held-position exit only. |
| L1 | Initial stop below base | NA | Not an initial-stop mechanism (a post-entry trailing insurance exit). |
| L2 | Trailing stop tighten-only / never moved against position | PASS | The runner only ever ADDS a `TriggerExit`; a position already exiting via any prior channel (stop/force-liq/Stage-3/laggard/liquidity) is skipped via the full same-tick skip-set union in `special_exits.ml`, so an earlier structural exit always wins. Pinned by `test_skip_set_collision_no_op`. (book §5.2/§5.3) |
| L3 | Triggers on weekly close, not intraday | PASS | Fire evaluated on weekly adjusted-closes; runner is Friday-gated (`is_screening_day`) and exits at the current weekly bar's close. `test_off_cadence_no_op` pins the cadence gate; fire tests operate on weekly-close series. (book §Stop-Loss Rules: weekly re-evaluation) |
| L4 | State-machine transitions correct (disarmed → armed-at-trigger → fired-on-trail) | PASS | Disarmed/never-arms → `test_no_trigger_below_ratio`; armed-but-not-fired (peak ratchets over multiple advances) → `test_new_highs_never_fire`; armed→fired-on-collapse → `test_collapse_below_trail_fires` / `test_collapse_fires_extension_stop`. (eng-design-3-portfolio-stops.md) |
| C1–C3 | Screener cascade / macro / sector | NA | No screener/macro/sector logic touched. |
| T1 | 4 stage transitions covered | NA | Not a stage feature. |
| T2 | Bearish-macro → zero buys | NA | No macro-gate logic. |
| T3 | Trailing over multiple price advances | PASS | `test_new_highs_never_fire` ratchets the peak across three successive higher closes (110→130→160) without firing; the shakeout tests cover a dip that holds then resumes to a new high. |
| T4 | Tests assert domain outcomes, not "no error" | PASS | Every test asserts a concrete fire/no-fire outcome plus (on fire) the exit label `extension_stop` and exit price 60.0 — no "runs without crashing" placeholders. |

### Weinstein-faithful guardrail

| # | Check | Status | Notes |
|---|-------|--------|-------|
| W1 | Spine intact | PASS | Only adds one discretionary weekly-close exit trigger for a held LONG. Stage classification, the Stage-2-only buy rule, breakout+volume entry, the macro/sector gate, and relative strength are all unaffected. |
| W2 | Adaptation is a documented dial, config-expressed, cites book | PASS | `extension_stop_config` is a real `Weinstein_strategy.config` field (default no-op), routed through `Overlay_validator.apply_overrides` (axis reachability pinned by `test_extension_stop_config_axis_resolves_via_overlay_validator`). Faithfulness cited to weinstein-book-reference.md §5.3 "Trailing Stop — Trader Method" ("don't wait for MA violation — exit when pattern deviates from plan") and §Stage 3 Ch. 2 ("Traders: exit with profits"); classed as tail-INSURANCE (catastrophic-stop-class, #1695 precedent), not an alpha axis. |

### Acceptance-scope note

This is a **default-off** primitive (experiment-flag-discipline R1/R2): both config
values default to 0.0 = disabled, so `Extension_stop_runner.update` returns `[]` and
every existing golden/baseline replays bit-identically. Per the merge-gate scope, the
armed-vs-off deep-warehouse event-level validation is the LATER promotion step (ledger
ACCEPT, R3), NOT a merge gate — so it is correctly listed as a `[non-blocking]` post-merge
Next Step and is not required to APPROVE. This review verifies the CODE CONTRACTS
(config semantics, weekly-close, tighten-only, arm/peak/fire logic) are pinned by the unit
tests, and the trigger/peak/fire semantics in the tests match the claimed behavior.

## Quality Score

5 — Exemplary: pure stateless core, every documented contract and guard pinned (including NaN-warmup, mismatched-array, and the survives-0.25/kills-0.15 width pair that encodes *why* the build is wide), faithful config-expressed dial with book citation, and axis reachability verified through the real `Overlay_validator`.

## Verdict

APPROVED

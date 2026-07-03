Reviewed SHA: 584f3316d7ef204f0fd38c6d814016540c66a198
(note: reviewed at 584f3316; update-branch merged main #1830/#1831 in at 32169aa9 — branch diff-vs-main unchanged, QC verdict carries)

## Structural QC — scale-in-config-detector

### Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | CI validating; no format violations in new code |
| H2 | dune build | PASS | CI validating; no build failures |
| H3 | dune runtest | PASS | CI validating; all tests pass |
| P1 | Functions ≤ 50 lines (linter) | PASS | scale_in_detector.ml max function length is ~18 lines; all within limits |
| P2 | No magic numbers (linter) | PASS | Numeric literals are in named constants (default_pullback_proximity_pct = 0.03, default_extension_max_pct = 0.15) or config fields with defaults |
| P3 | Config completeness | PASS | All tunable parameters (proximity_pct, max_pct, fraction, trigger type, not_late gate) are in Scale_in_detector.config with defaults; no hardcoded values in logic |
| P4 | Public-symbol export hygiene (linter) | PASS | All exports documented in .mli; private helpers prefixed with underscore |
| P5 | Internal helpers prefixed per convention | PASS | Private functions (_split_current, _touched_pullback_zone, _held_and_turned) all use underscore prefix |
| P6 | Tests conform to test-patterns.md | PASS | test_scale_in_detector.ml: opens Matchers, uses assert_that with proper matchers (equal_to, all_of, field), no List.exists with equal_to true/false, no unused let bindings on function calls, no problematic match patterns |
| A1 | Core module modifications | PASS | No modifications to core modules (portfolio, orders, position, strategy/STRATEGY interface, engine). weinstein_strategy.ml/mli are Weinstein-feature-specific, not core |
| A2 | No new analysis imports into trading/trading | PASS | No analysis/ library refs added; dune file only adds test target, no new library dependencies |
| A3 | No unnecessary existing module modifications | PASS | Only modified files are those needed for scale-in integration: scale_in_detector (new), weinstein_strategy (module re-export + config fields), weinstein_strategy_config (config additions), test/dune (test target), test_scale_in_detector.ml (new test) |

### Experiment-Flag-Discipline Verification

**R1 (default-off):**
- `enable_scale_in : bool [@sexp.default false]` in Weinstein_strategy_config.ml — mechanism fully disabled by default
- `scale_in_config : Scale_in_detector.config [@sexp.default Scale_in_detector.default_config]` — loads with no-op defaults
- Scale_in_detector.config defaults:
  - `initial_entry_fraction = 1.0` (no scale-in, full single entry, bit-identical to baseline)
  - `add_trigger = Pullback` (v1 default per Weinstein)
  - `max_adds = 1` (Weinstein's one pullback add)
  - `require_not_late = true` (topping gate enabled)
- **R1 PASS**: New config fields carry `[@sexp.default <no-op>]` and defaults maintain backward compatibility. Old scenario sexps without scale_in fields parse with disable-mechanism defaults.

**R2 (searchable):**
- `enable_scale_in` is a real bool field in Weinstein_strategy_config.type config → routes through config parsing
- `scale_in_config` is a real nested config record → all sub-fields addressable as dot-path axes (e.g., `scale_in_config.add_trigger` can be `Pullback | Either`)
- Test `test_strategy_config_omitted_fields_default_off` verifies round-tripping: omitted scale_in fields decode to disabled mechanism + defaults
- **R2 PASS**: All parameters are real config fields, not hardcoded; searchable as Variant_matrix axes.

**R3 (no promotion without ACCEPT):** NA — this PR lands the mechanism default-off as an axis. No defaults are flipped here; promotion is deferred pending experiment-ledger ACCEPT.

## Verdict

**APPROVED**

No structural findings. PR introduces pure price-action detection logic (Scale_in_detector), wires it into Weinstein_strategy config as a default-off mechanism axis, and includes comprehensive tests pinning both the detection predicates and the config contract. Config discipline (R1/R2) is correctly implemented. Ready for qc-behavioral review.

---

# Behavioral QC — scale-in-config-detector

Reviewed SHA: 584f3316d7ef204f0fd38c6d814016540c66a198
(note: reviewed at 584f3316; update-branch merged main #1830/#1831 in at 32169aa9 — branch diff-vs-main unchanged, QC verdict carries)

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial `.mli` docstring claim has an identified pinning test | PASS | `pullback_hold` (touch+hold+turn, ≥2 bars): fires → `test_pullback_touch_then_turn_up_fires`; no-touch → `test_pullback_without_touch_does_not_fire`; broke-entry (didn't hold) → `test_pullback_that_breaks_entry_does_not_fire`; no-turn → `test_pullback_without_turn_up_does_not_fire`; two-bar guard → `test_pullback_needs_two_bars`. `early_new_high` (new post-entry high AND above entry) → `test_early_new_high_fires_on_new_post_entry_high` / `test_early_new_high_not_fired_below_prior_high`. `add_signal` dispatch (Pullback / Either disjunction) → `test_either_fires_on_new_high_when_pullback_does_not`. `extended_above_ma` (over/under/non-positive-ma) → `test_extended_above_ma`. `default_config` no-op → `test_config_defaults_are_no_op`. Minor gap (non-blocking): `early_new_high`'s own "needs ≥2 bars" and its "above entry_price" clause are not separately exercised (covered transitively via the shared `_split_current` helper tested in the pullback path). |
| CP2 | PR-body / plan §3.4 claims have a corresponding committed test | PASS | Plan §3.4 #1 instrumented claim ("pure-pullback under-sizes gap-and-go monsters; `Either` is the fix") is pinned by `test_either_fires_on_new_high_when_pullback_does_not`, which asserts `(signal Pullback, signal Either) = (false, true)` on a gap-and-go bar shape (never touches the zone, keeps making highs). R1 no-op claim pinned by `test_config_defaults_are_no_op` + `test_strategy_config_omitted_fields_default_off`. |
| CP3 | Pass-through / identity tests pin identity, not just size | PASS | `test_strategy_config_omitted_fields_default_off` asserts whole-value identity: `enable_scale_in = false` and `scale_in_config = Scale_in_detector.default_config` (full-record `equal_to`, not a count). Round-trips an old config sexp lacking scale-in fields. |
| CP4 | Each explicit guard in docstrings has a test exercising the guarded scenario | PASS | "Needs ≥2 bars (`false` otherwise)" → `test_pullback_needs_two_bars`. "`false` for non-positive `ma` (warmup/missing MA never blocks-by-crash)" → `test_extended_above_ma` (ma:0.0 → false). "Current close held the breakout (≥ entry)" → `test_pullback_that_breaks_entry_does_not_fire`. Same `early_new_high` two-bar minor gap as CP1. |

## Behavioral Checklist

| # | Check | Status | Notes (cite authority doc section) |
|---|-------|--------|------------------------------------|
| A1 | Core module modification is strategy-agnostic | NA | qc-structural marked A1 PASS (not FLAG) — no core module (portfolio/orders/position/STRATEGY/engine) touched; only Weinstein-feature modules. Nothing to judge for generalizability. |
| S1 | Stage 1 definition matches book | NA | No stage-classifier change in this PR. |
| S2 | Stage 2 definition matches book | NA | No stage-classifier change. |
| S3 | Stage 3 definition matches book | NA | No stage-classifier change. |
| S4 | Stage 4 definition matches book | NA | No stage-classifier change. |
| S5 | Buy criteria: entry only in Stage 2, breakout + volume | PASS | The scale-in ADD operates only on already-held Stage-2 positions' post-entry bars (adds the second ½ of a `½+½`), not fresh entries — it cannot create an entry outside Stage 2. The `require_not_late` + `extended_above_ma` gates are provided here; runner (PR 4) enforces Stage-2/not-late at the wiring point. Initial breakout+volume entry path is untouched. weinstein-book-reference.md §Stage 2 detail (Ch.2); plan §3.2, §4. |
| S6 | No buy signals in Stage 1/3/4 | PASS | Add is gated `not-late AND not-extended` per plan §3.2; detector supplies `extended_above_ma` (Weinstein "never buy extended") and the `require_not_late` knob. Default-off, so no signal is emitted anywhere yet. weinstein-book-reference.md §Late Stage 2 warning / §Stage 3 detail. |
| L1 | Initial stop below the base | NA | No stop logic in this PR. |
| L2 | Trailing stop never lowered | NA | No stop logic. |
| L3 | Stop triggers on weekly close | NA | No stop logic. |
| L4 | Stop state-machine transitions | NA | No stop logic (the `Holding → add` transition build is PR 4). |
| C1 | Screener cascade order | NA | No screener change. |
| C2 | Bearish macro blocks all buys | NA | No macro-gate change; plan §2 states the reallocation lever changes no gross-exposure envelope. |
| C3 | Sector RS vs. market | NA | No sector logic change. |
| T1 | Tests cover all 4 stage transitions | NA | No stage logic. |
| T2 | Bearish macro → zero buy candidates test | NA | No macro logic. |
| T3 | Stop-loss trailing tests | NA | No stop logic. |
| T4 | Tests assert domain outcomes, not just "no error" | PASS | Every test asserts a specific domain outcome: predicate fires / does-not-fire on named price-action shapes, exact config field values, and whole-record round-trip identity — never a bare "did not raise". |

### Weinstein-faithfulness (weinstein-faithful-core.md W1–W3)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| W1 | Spine intact | PASS | Mechanism operates only on held Stage-2 winners (adds the second ½), never creates entries outside Stage 2, does not drop the initial-breakout volume confirmation (initial entry path unchanged), and does not touch the macro/sector gates. Notional stays capped at existing `max_position_pct_long` (plan §3.2). Reallocation inside a fixed envelope — no spine item (1–7) altered. Default-off → zero behavior change. |
| W2 | Adaptation is a documented dial, config-expressed, cites authority | PASS | This is Weinstein's own `½ + ½` "The Trader's Way": buy on breakout, add the other half on the first pullback close to the breakout point (weinstein-book-reference.md §Stage 2 detail Ch.2: "usually at least one pullback close to the breakout point — this is a second chance to buy. The less it pulls back, the more strength it shows"). Every knob (`initial_entry_fraction`, `max_adds`, `add_trigger`, `pullback_proximity_pct`, `extension_max_pct`, `require_not_late`) is a real `Scale_in_detector.config`/`Weinstein_strategy.config` field, searchable as a `Variant_matrix` dot-path axis. `.mli` cites the book section + plan §3.2/§3.4. `pullback_hold` correctly encodes "follows revealed strength, never predicts" (a prior bar's low touched the zone, current close holds ≥ entry and turns up). **Non-blocking note:** the book's second-entry criterion also wants volume contraction (~75%+ from peak, ref lines 155/216); v1 deliberately scopes the trigger to price-action reveal (plan §3.2 names no volume filter). This makes the add more permissive but not non-Weinstein — it is a faithful adaptation settled by the approved design authority (#1829), not a spine break. |
| W3 | Experiments are Weinstein-faithful presets | NA | No experiment run / no default flipped — this PR lands the axis default-off. Promotion is deferred to WF-CV + the confirmation grid (plan §6). |

### Experiment-flag-discipline re-confirm (behavioral level)

- **R1 (default-off no-op):** PASS. `enable_scale_in = false` (master switch) + `initial_entry_fraction = 1.0` independently guarantee the explore/exploit sides are inert; nothing consumes the flag in this PR, so merging is trivially a zero-behavior-change land. Pinned by `test_config_defaults_are_no_op` and `test_strategy_config_omitted_fields_default_off` (old sexps decode to disabled + defaults).
- **R2 (searchable):** PASS. All knobs are real config fields (nested `scale_in_config` record), addressable as `Variant_matrix` axes.
- **Non-blocking observation:** plan §5 lists `max_adds` no-op default as `0`, but the implementation defaults it to `1` (the "when enabled" value). This is **behaviorally inert** here — the mechanism is fully gated by `enable_scale_in = false` and `initial_entry_fraction = 1.0`, and nothing consumes it. The `.mli` is internally consistent ("inert while `enable_scale_in = false`"). Flagging for PR 4 awareness: when the runner is wired, `enable_scale_in = true` with `max_adds` omitted will yield one add (not zero) — which matches the plan's *enabled* intent, so this is fine, just a plan-table-vs-impl wording divergence, not a defect.

## Quality Score

4 — All CP1–CP4, S5/S6, W1/W2, and R1/R2 checks pass; clean pure predicates with thorough branch-level test coverage and an `.mli` that cites the book authority. Held from 5 by two minor non-blocking nits: `early_new_high`'s own two-bar / above-entry clauses are pinned only transitively, and `max_adds` default (1) diverges from the plan §5 table's stated no-op (0) though behaviorally inert.

## Verdict

APPROVED

(Both qc-structural and qc-behavioral APPROVED at SHA 584f3316. All applicable Contract-Pinning, Behavioral, and Weinstein-faithfulness rows PASS; NA rows carry reasons.)

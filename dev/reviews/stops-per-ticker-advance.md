Reviewed SHA: c87756f2abadcbf1c6b06051bd5ef7b129ea032f
(note: reviewed at b5d8d5ab; branch was merged-up with main #1830 at c87756f2 — branch diff-vs-main byte-identical, QC verdict carries)

## Structural QC — stops-per-ticker-advance

### Context

PR #1831 fixes a double-advance bug in `Stops_runner.update` when multiple positions hold the same ticker (scale-in shape). Refactors stop-transition logic into a new `Stop_transitions` module. CI (build-and-test + perf-tier1-smoke) passed; read-only structural review follows.

### Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | CI build-and-test GREEN |
| H2 | dune build | PASS | CI build-and-test GREEN |
| H3 | dune runtest | PASS | CI build-and-test GREEN |
| P1 | Functions ≤ 50 lines — covered by language-specific linter | PASS | fn_length_linter passed (H3) |
| P2 | No magic numbers — covered by language-specific linter | PASS | linter_magic_numbers.sh passed (H3) |
| P3 | All configurable thresholds/periods/weights in config record | PASS | No new hardcoded tunable values introduced |
| P4 | Public-symbol export hygiene — covered by language-specific linter | PASS | mli_coverage linter passed (H3) |
| P5 | Internal helpers prefixed per project convention | PASS | All internal helpers in stops_runner.ml prefixed with `_` (_is_weekly_close, _default_stage_and_ma_for_side, _compute_ma_and_stage, _advance_machine, _advance_ticker_once, _handle_stop_full, _catastrophic_hit, _catastrophic_exit, _handle_stop, _process_stop) |
| P6 | Tests conform to `.claude/rules/test-patterns.md` (presence + conformance) | PASS | test_stops_runner.ml: (1) no `List.exists ... equal_to (true\|false)`, (2) no unasserted `let _ = .*\.run\b`, (3) no bare match with `Error → assert_failure`; file opens Matchers and uses `assert_that` consistently |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) — FLAG if any found | PASS | Files under `trading/trading/weinstein/strategy/` (feature code); no core modules touched |
| A2 | No new `analysis/` imports into `trading/trading/` outside allow-listed exceptions | PASS | dune files: no analysis/ library dependencies added |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | Canonical file list: 2 new (stop_transitions.ml/.mli) + 2 modified (stops_runner.ml, test_stops_runner.ml) all within weinstein/strategy/ |

### Branch staleness

main is 1 commit ahead of this branch → no FLAG needed.

## Verdict

**APPROVED**

All structural checks pass. Code conforms to project conventions, test patterns, and architecture rules. No blockers for behavioral review.

---

## Behavioral QC — stops-per-ticker-advance

Reviewed SHA: c87756f2abadcbf1c6b06051bd5ef7b129ea032f
(note: reviewed at b5d8d5ab; branch was merged-up with main #1830 at c87756f2 — branch diff-vs-main byte-identical, QC verdict carries)

### Context

Correctness fix for the scale-in shape (sibling positions on one ticker). `Stops_runner.update` folds over positions; each position previously advanced the shared per-ticker Weinstein stop state machine. With one position per ticker that is one advance/tick (bit-identical), but two Holding positions on one ticker (original + add) double-advanced the machine, violating `Weinstein_stops.update`'s one-call-per-period contract, double-stepping correction bookkeeping, double-aging `weeks_advancing`, and leaving the second sibling's risk params stale on a raise. Fix: a per-`update` memo `ticker → (pre_advance_state, event)`; first position advances, siblings replay the memoized event.

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new `.mli` docstrings has an identified test | PASS | `stop_transitions.mli`: `of_stop_event` (Stop_hit→exit at pre-advance level; Stop_raised→adjust to new level) pinned by `test_sibling_positions_stop_hit_exits_both` + `test_sibling_positions_raise_adjusts_both`; `handle_trigger_only` (no state advance, trigger-only) pinned by `test_weekly_cadence_no_state_advance_when_only_midweek` / `test_weekly_cadence_trigger_fires_on_midweek_bar`; `trigger_fill_price` worst-case fill (bar low long / high short / close on `on_close`) pinned by existing exit + G1 short-fill tests. |
| CP2 | Each PR-body "Test plan" claim has a corresponding committed test | PASS | PR body advertises exactly 3 new tests — (1) "sibling stop-hit exits both" → `test_sibling_positions_stop_hit_exits_both`; (2) "sibling raise adjusts both at one level" → `test_sibling_positions_raise_adjusts_both`; (3) "shared state after a two-sibling update equals the single-position run" → `test_sibling_positions_advance_state_once`. All three present in `test_stops_runner.ml`. |
| CP3 | Pass-through / identity / invariant tests pin identity (`equal_to` on whole value), not just size | PASS | Claim 1 ("bit-identical today"): `test_sibling_positions_advance_state_once` asserts `sibling (equal_to single)` on the full persisted `stop_state` — whole-value identity, not a size check. Transition sets pinned via `equal_to [ "AAPL-add"; "AAPL-orig" ]` on sorted ids. |
| CP4 | Each guard called out in code docstrings has a test exercising the guarded scenario | PASS | `_advance_machine` docstring guards against "a second call per tick" (double-advance → double-aged `weeks_advancing`, stale second-sibling risk params). Guarded scenario is exercised: `test_sibling_positions_advance_state_once` proves single-advance (final `stop_states` equals the one-position run — a double-advance from `_raise_ready_trailing` would diverge), and `test_sibling_positions_raise_adjusts_both` proves the second sibling is NOT left stale (both carry the same raised level). Minor: the `prior_stages` `weeks_advancing` symptom is not independently asserted (the tests use `Bar_reader.empty` → warmup default, which never touches `prior_stages`), but the memo makes `_advance_machine` — the sole writer of `prior_stages` — run exactly once, so pinning stop_states-once covers it. |

### Behavioral Checklist

| # | Check | Status | Notes (authority) |
|---|-------|--------|-------------------|
| A1 | Core module modification is strategy-agnostic | NA | qc-structural did not FLAG A1 — files under `trading/trading/weinstein/strategy/`, no core module touched. |
| S1 | Stage 1 definition matches book | NA | No stage-classification change; `_compute_ma_and_stage` relocated but logic unchanged. |
| S2 | Stage 2 definition matches book | NA | " |
| S3 | Stage 3 definition matches book | NA | " |
| S4 | Stage 4 definition matches book | NA | " |
| S5 | Buy criteria: Stage-2 breakout + volume | NA | Stops pass; no entry logic. |
| S6 | No buys in Stage 1/3/4 | NA | " |
| L1 | Initial stop below the base | NA | Stop placement (`Weinstein_stops`) untouched; this PR only fixes per-ticker advance multiplicity. |
| L2 | Trailing stop never lowered | NA | Trailing rule unchanged; refactor preserves it (weinstein-book-reference §Stop-Loss Rules). |
| L3 | Stop triggers on weekly close (not intraday) | NA | `trigger_on_weekly_close` / `on_close` threaded through unchanged; no semantic change. |
| L4 | Stop state machine transitions correct (INITIAL→TRAILING→TRIGGERED) | PASS | The PR's core contract: machine advances exactly once/ticker/tick so transitions match the pre-PR single-position machine — pinned by `test_sibling_positions_advance_state_once` (eng-design-3-portfolio-stops.md; weinstein-book-reference §Stop-Loss Rules). |
| C1 | Screener cascade order | NA | No screener change. |
| C2 | Bearish macro blocks buys | NA | " |
| C3 | Sector RS vs market | NA | " |
| T1 | Tests cover 4 stage transitions | NA | Not a stage feature. |
| T2 | Bearish-macro → zero-buy test | NA | Not a screener feature. |
| T3 | Stop tests verify trailing over price advance | PASS | `test_sibling_positions_raise_adjusts_both` drives a completed ≥8% correction + recovery bar into a `Stop_raised` and asserts the raised level (>80) on both siblings; existing trailing tests unchanged. |
| T4 | Tests assert domain outcomes, not just "no error" | PASS | New tests assert specific position-id sets, identical raised stop levels, and full stop_state equality — domain outcomes, not smoke. |

### Weinstein-faithful spine (weinstein-faithful-core.md)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| W1 | Spine intact (no change to stages/buy-only-Stage2/volume/exit/stop/macro/RS) | PASS | Pure stops-pass multiplicity fix; the trailing-stop discipline (spine item 5) is preserved bit-identically for the existing one-position-per-ticker case. |
| W2 | Adaptation is a documented dial, config-expressed | NA | No new mechanism/dial introduced — no new `config` field, bit-identical today (experiment-flag-discipline R1–R3 not triggered); this is correctness plumbing for the future scale-in runner (PR 3–4 of the build). |
| W3 | Experiments are Weinstein-faithful presets | NA | No experiment/axis added. |

## Quality Score

4 — All checks pass; the advance-once contract is pinned precisely via full-state equality against the single-position baseline, docstrings are excellent. Minor: the `prior_stages` `weeks_advancing` double-age symptom named in the guard docstring isn't independently asserted (tests run through the warmup default that skips `prior_stages`), though single-advance of its sole writer is proven.

## Verdict

APPROVED

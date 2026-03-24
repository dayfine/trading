# Review: screener
Date: 2026-03-24
Status: NEEDS_REWORK

## Build / Test
- dune build: UNKNOWN — Docker daemon unavailable in this review environment; build could not be verified
- dune runtest: UNKNOWN — same constraint; see note below

Note: The worktree code was reviewed directly at
`/home/user/trading/.claude/worktrees/agent-a1940117/trading/analysis/weinstein/`.
The code compiles cleanly by inspection (types align across module boundaries,
dune library dependencies are correct, no obvious type errors). Docker
verification must be performed before final merge approval.

## Summary

The screener feature delivers the complete Weinstein analysis pipeline: shared
types, SMA/WMA indicators, stage classifier, relative strength, volume
confirmation, overhead resistance, sector analysis, stock analysis aggregator,
and the cascade screener. Module structure is clean, all modules have `.mli`
files with comprehensive documentation, all analysis functions are pure
(same input → same output), and the stage classifier faithfully encodes
Weinstein's four-stage framework. Tests cover happy paths and most edge cases
across all eight sub-modules.

However, the feature has four blocker-level violations of the "all parameters in
config, never hardcoded" requirement: hardcoded entry/stop buffer percentages in
the screener, no configurable short scoring weights, a hardcoded RS slope
threshold, and hardcoded sector stage inference thresholds. Additionally, all
tests use raw OUnit2 assertions rather than the Matchers library required by
CLAUDE.md.

## Findings

### Blockers (must fix before merge)

**B1 — Hardcoded entry/stop buffer percentages (screener.ml lines 191, 194, 293, 295)**

`_suggested_entry` multiplies by `1.01` and `_suggested_stop` multiplies by
`0.97`. The short candidate entry uses `0.99` and stop uses `1.03`. All four
multipliers are hardcoded in function bodies rather than drawn from config.
Design requirement: "All parameters in config, never hardcoded." These buffers
directly affect trade execution and must be tunable.

Fix: Add `entry_buffer_pct` and `stop_buffer_pct` fields to `screener.config`
and thread them through `_suggested_entry`, `_suggested_stop`, and
`_build_short_candidate`.

**B2 — Short scoring uses hardcoded integer weights (_build_short_candidate, lines 272–290)**

The buy scoring path uses a configurable `scoring_weights` record for every
component. The short scoring path uses hardcoded integers: `30` for fresh
breakdown, `15` for continuation, `20` for negative RS, `5` for improving RS,
`10` for weak sector, `-20` for strong sector. These are not connected to any
config structure, making short-side scoring impossible to tune in backtesting.

Fix: Add a `short_scoring_weights` record to the screener config (mirroring
`scoring_weights`) and replace all hardcoded integers in `_build_short_candidate`.

**B3 — Hardcoded RS slope threshold (rs.ml line 59)**

`_classify_rs_trend` uses `Float.(s > 0.001)` to distinguish `Positive_rising`
from `Positive_flat`. This threshold is not in `Rs.config` and cannot be tuned.

Fix: Add a `positive_rising_slope_threshold` field to `Rs.config` (default
`0.001`) and use it in `_classify_rs_trend`.

**B4 — Hardcoded sector stage inference thresholds (sector.ml lines 42–46)**

`_infer_sector_stage` uses hardcoded values `0.5`, `0.4`, and `0.3` to determine
the sector stage (Stage2, Stage4, Stage1, Stage3). The first two match
`config.strong_stage2_pct` and `config.weak_stage4_pct`, but they are not
actually read from the config — the literals are used directly. The third
threshold (`0.3` for Stage1 vs Stage3) is entirely off-config.

Fix: Pass or use `config.strong_stage2_pct` and `config.weak_stage4_pct` inside
`_infer_sector_stage`. Add a third threshold (e.g., `stage1_min_stage2_pct`) to
`Sector.config` for the Stage1/Stage3 disambiguation.

### Should Fix (important but not a merge blocker)

**S1 — Tests do not use the Matchers library**

All 57 test cases across all eight test files use raw OUnit2 assertions
(`assert_equal`, `assert_bool`, `match ... | None -> assert_failure ...`).
CLAUDE.md explicitly requires the Matchers library (`is_ok_and_holds`,
`is_some_and`, `elements_are`, `float_equal`, etc.). The Matchers library is not
listed as a dependency in any of the weinstein test `dune` files.

Fix: Update all test `dune` files to depend on `matchers`, then migrate
assertions to use matchers patterns (particularly for `Option` unwrapping and
float comparisons).

**S2 — Wrong comment on `_macro_gate` Bearish arm (screener.ml line 321)**

The comment says `(* Bearish market: no longs; only A+ shorts allowed *)` but
the code returns `(false, true)` which allows ALL shorts in a Bearish market —
which is the correct behavior per the design spec. The comment was copy-pasted
from the Bullish case. This is misleading and should read something like
"Bearish market: no longs; all shorts allowed."

**S3 — Redundant guard in `_classify_stage` Declining arm (stage.ml lines 118–119)**

```ocaml
| Declining when majority_below -> Stage4 { weeks_declining = weeks }
| Declining -> Stage4 { weeks_declining = weeks }
```

Both arms produce identical output. The `when majority_below` guard is dead
code. The design algorithm specifies "MA Declining + mostly below → Stage4"
implying a distinction exists; the current code makes MA Declining alone
sufficient. Either collapse the two arms into one, or implement the intended
distinction (e.g., MA Declining + mostly above could be an early Stage3→Stage4
transition worth tracking).

**S4 — `screen` function uses mutable refs internally (screener.ml lines 337–369)**

The `screen` function accumulates candidates via `ref []` and `List.iter`
mutation. The function is externally pure (same inputs → same output), but the
CLAUDE.md functional idioms section prefers functional patterns (`filter_map`,
`fold`). This is consistent with the overall codebase style.

### Suggestions (optional)

**Suggestion 1 — `stock_analysis.ml` always calls `analyze_breakout` on the latest bar**

`Volume.analyze_breakout` is called on the full bar list unconditionally.
This means every stock is evaluated for "breakout volume" regardless of whether
it is actually at a breakout. Consider only calling this when the stock shows a
Stage1→Stage2 transition, or documenting the intent explicitly in `stock_analysis.mli`.

**Suggestion 2 — Late Stage2 detection skipped in `_infer_stage_no_prior` path**

When `prior_stage = None` and the stock is inferred as Stage2, the late-stage
detection is not applied (it only runs in the `Some _` branch). This is a minor
inconsistency — fresh classification without history cannot produce `late = true`
even if MA deceleration is present.

**Suggestion 3 — Macro analyzer noted as "Future"**

The design doc specifies a `Macro.analyze` function that the screener's `screen`
signature currently replaces with a bare `macro_regime` parameter. This is a
reasonable M1 simplification (the status doc calls it "Future"). Ensure the
macro analyzer is tracked in a follow-up feature.

## Checklist

**Correctness**
- [x] All interfaces specified in the design doc are implemented (stage, RS, volume, resistance, sector, screener; macro noted as future)
- [ ] No placeholder / TODO code in non-trivial paths — hardcoded multipliers and short scoring integers are placeholder behavior
- [x] Pure functions are actually pure (no hidden state, no side effects)
- [ ] All parameters in config, nothing hardcoded — four violations (B1–B4)

**Tests**
- [x] Tests exist for all public functions
- [x] Happy path covered
- [x] Edge cases covered (empty inputs, boundary values, insufficient data)
- [ ] Tests use the matchers library (per CLAUDE.md patterns) — S1

**Code quality**
- [x] `dune fmt` clean (formatting appears consistent, no obvious drift by inspection)
- [x] `.mli` files document all exported symbols
- [ ] No magic numbers — four violations (B1–B4) plus RS slope threshold (B3)
- [x] Functions under ~35 lines, modules under ~5 public methods
- [x] Internal helpers prefixed with `_`
- [x] No unnecessary modifications to existing modules

**Design adherence**
- [x] Matches the architecture described in the design doc
- [x] Data flows match the component contracts in the system design doc

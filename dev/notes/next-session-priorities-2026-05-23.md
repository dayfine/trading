# Next-session priorities (post 2026-05-23)

Supersedes `next-session-priorities-2026-05-22-pm.md`. Written at end of
session that landed 8 PRs + tested V8 random-restart winners against new
3-gate panel.

## This session's outcomes

**8 PRs landed:**

| PR | Theme |
|---|---|
| #1255 | Promote gate extension: MaxDD ≤ baseline + 5pp + N_trades within 2x; + smoke test in `trading/devtools/checks/` |
| #1256 | V8 random-restart analysis writeup + QC reviews for #1255 |
| #1257 | First promote-tooling fix: `git diff` vs `git diff-index` (wrong fix — strictly more permissive but didn't address the root cause; superseded by #1259) |
| #1258 | tuner: `Grid_search.cell_to_overrides ?int_keys` + 4 unit tests (lib-side BO int-knob rounding capability) |
| #1259 | Real promote-tooling fix: `git diff --diff-filter=M` skips intent-to-add markers |
| #1260 | Cost-model wiring Phase 1: `scenario.cost_model : Cost_model.t option` field + simulator `on_trade_fill : (trade -> trade) option` hook + 3 new test cases |
| #1261 | `int_keys` plumbing through `bayesian_runner_spec.ml` → 6 BO-runner call sites of `cell_to_overrides` (unblocks 11-knob BO sweep relaunch) |
| #1262 | Margin Phase 3 bear-window validation sweep (6 scenarios + report) |

**V8 random-restart verdict — both REFUSED by new 3-gate panel:**

| Seed | Mode | sp500-2019-2023 MaxDD vs cell-E | Gate verdict |
|---|---|---|---|
| V3 (live) | low-exposure (0.47) | 30.58 vs 21.56 = **+9.02pp** | Would FAIL today (+9 > +5) |
| V8 seed 2027 | high-exposure (0.85) | 30.45 vs 21.56 = **+8.89pp** | FAIL |
| V8 seed 2028 | low-exposure (0.45) | 27.04 vs 21.56 = **+5.48pp** | FAIL (just barely) |

**Conclusion:** the 4-knob BO surface is exhausted vs the tightened MaxDD gate.
No knob combination found that passes all 3 gates. Tighter stops on seed 2028
reduced MaxDD by ~3.4pp vs seed 2027 but still couldn't clear +5pp.

**V3 winner stays live** — it's the best we have. The gate is advisory until
a candidate emerges that passes; treat the V3 live config as grandfathered
under the pre-#1255 single-Sharpe gate.

## Open background jobs at session end

None — all merged.

## P0 — 11-knob BO sweep relaunch (now unblocked)

Both prerequisites landed today:
- #1258: tuner library `?int_keys` capability + rounding
- #1261: `bayesian_runner_spec` plumbing — `int_keys` flows from spec sexp through to `cell_to_overrides` at all 6 call sites

Action:
1. Restore `dev/experiments/bayesian-production-sweep-2026-05-18/spec_prod_11knob_v1.sexp` (currently sitting on un-tracked jj commit `rtpoyuvv` or via `jj file show -r rtpoyuvv ...`). Annotate int-typed knobs with `(int)` marker per `dev/notes/bayesian-11knob-int-knob-crash-2026-05-22.md`:
   - `stage3_force_exit_config.hysteresis_weeks`
   - `screening_config.weights.w_positive_rs`
   - any other int-typed knobs in the spec
2. Launch with parallel=4, budget=60. ETA ~12-15h wall.
3. When done, run `dev/scripts/promote_config.sh` on the winner. If MaxDD-gate fails on sp500-2019-2023 → confirms structural limit; if passes → first config that survives the full panel.

**Why this is P0:** 11-knob surface adds sector cap + 6 more knobs to the BO surface. The 4-knob result confirms that knob-tuning on a 4-D surface can't escape the MaxDD trap; the 11-D surface might.

## P1 — Component-decomposition objective (the strategic-value experiment)

Per `dev/plans/tuning-methodology-redesign-2026-05-22.md` §2.8 + #1237 §5 P6.
Composite objective is global P&L-derived. Decompose into:
`score = w1×screener + w2×portfolio + w3×orders + w4×stops`

BO can then target the weak component instead of the global. ~200-400 LOC
implementation + 12-20h CPU.

Worth doing AFTER P0 11-knob result lands — that tells us whether the 4-D
plateau is escaped by adding more knobs OR whether we need a different
search objective altogether.

## P2 — Cost-model items 3 + 4 (after items 1+2 landed today)

`dev/status/cost-model.md` next-tasks:
- **Item 3:** ADV plumbing for `apply_market_impact`. Engine surface change. ~150 LOC. **Deferred until empirical evidence impact ≫ spread** per status file.
- **Item 4:** re-pin Cell E + smaller scenarios under the cost overlay (forces sweep). After items 1+2 (now landed), this is the obvious next step. ~50 LOC plus a re-pin sweep run.

Per priorities-2026-05-22-pm §P3 the original intent was wiring → ADV → re-pin. We're at the "ready for re-pin" gate.

## P3 — Phase 2 margin transition bug fix

Discovered in #1262: dotcom-2000-2002 margin-on scenario CRASHES with
`Invalid transition Position.TriggerExit` when a margin_call fires on a
position already targeted by the stop-loss runner on the same tick.

Locations (from #1262 report):
- `trading/trading/simulation/lib/margin_runner.ml:56-67` (`margin_call_transitions` — needs dedup against `strategy_transitions` in `tick`)
- `trading/trading/strategy/lib/position.ml:172` (transition validator: `Holding _ → TriggerExit` only)

**Should file an issue** referencing #1262 + the failing scenario before
dispatching the fix. Blocks any re-enable of margin in long-short mode.

## P4 — M6.6 live cycle implementation (was P4 in prior priorities; user decisions pending)

5-session sequence per `dev/plans/m6-6-live-cycle-scoping-2026-05-22.md`. Start
with **S1 — `weekly_cycle.exe` entrypoint** (~300 LOC, new module). End-to-end
test against the most recent Friday using real EODHD data.

**User decisions still needed (carried forward):**
- Email service (SendGrid recommended)
- Trading-state private repo name (`dayfine/trading-state` proposed)
- Cron timing (Friday 13:30 PT proposed)
- Gate on V3 winner vs wait for 11-knob / V8 result

## P5 — int-knob follow-up items (qc-behavioral non-blocking)

From `dev/reviews/feat-bo-int-keys-spec-plumbing-behavioral.md`. Land before
next BO sweep relies on the explicit-field or merge-semantics paths:
1. `bayesian_runner_spec.mli:192` doc bug — example uses bare atom `int` instead of `(int)` (will not parse as written)
2. No test for non-empty `int_keys` round-trip (`t_of_sexp ∘ sexp_of_t = id`)
3. No test for explicit `(int_keys ...)` field + merge semantics with per-binding markers
4. No test for malformed marker rejection (`(int extra)`, `(int_alias)`, etc.) — `_is_int_marker` claims rejection, untested

~50 LOC of tests + 1-line doc fix. Land as one batched cleanup PR.

## Lower-priority follow-ups carried from prior sessions

| Item | State |
|---|---|
| Two qc-structural `[info]` items (H3 false-positive, review-file persistence gap, carried 8+ weeks) | Need patch OR explicit acceptance in `dev/decisions.md`. Not addressed this session. |
| shares-outstanding fundamentals source decision | Vendor decision needed (EODHD Fundamentals tier upgrade vs paid scraper API vs Sharadar). Blocked on user. |
| Cross-scenario validation track decision (new track vs fold into `tuning`) | Per track-pacer recommendation 1 — needs maintainer call. |
| `walk_forward_runner.ml:23` hardcodes `cost_model = None;` while inheriting `slippage_bps = base.slippage_bps;` | Non-blocking observation from qc-behavioral on #1260. Becomes a real bug when cost-model item 4 (Cell E retail/institutional overlay) intersects walk-forward. |

## Open PRs at session end

**None.** All 8 PRs landed.

## Hiccups this session (codified in memory)

1. **`promote_config.sh` had 2 more fix-forward bugs in 24h** (#1257 wrong; #1259 real). Total 5 fix-forwards in 48h. Memory `feedback_promote_config_3_bugs_one_week.md` was the warning sign — should have been more aggressive about smoke-testing before shipping #1257.
2. **qc-behavioral correctly flagged #1257 as not-actually-fixing the bug** (1-line `git diff` vs `git diff-index` distinction doesn't hold for intent-to-add markers). The reviewer's empirical-reproduction-across-7-scenarios was load-bearing. **Lesson:** when a fix is "obvious" but doesn't have a test pinning the fix's mechanism, dispatch with skepticism.
3. **feat-backtest agent for int_keys plumbing (P1.1) TIMED OUT** mid-flight (API Error: Stream idle timeout). Work was preserved in agent worktree; picked up + finished by main thread. **Lesson:** for large multi-file agents, build in checkpoints (push partial work as you go).
4. **Cost-model agent (#1260) shipped without wiring the on_trade_fill hook into `_apply_trades_best_effort`** — the test that should have caught this (`per_trade=1.50 subtracts exact delta`) actually did, but the agent's PR body claimed "all 6 new tests pass" without running them. **Lesson:** trust-but-verify agent self-reports of test results; run `dune runtest` in the dispatcher to confirm.
5. **ScheduleWakeup silently drops outside `/loop` mode** (per `feedback_schedulewakeup_loop_only.md`). I forgot during a long polling window and went silent until user pinged. Use inline `until` polls for CI waits ≤15min.

## Session totals

- 8 PRs merged
- 2 V8 winners promote-tested + REFUSED (4-knob surface verdict locked)
- 5 fix-forwards on `promote_config.sh` over 48h (closing on it being stable)
- 1 Phase 2 margin bug discovered (issue not yet filed)
- 1 follow-up issue for `walk_forward_runner` cost_model inheritance
- 4 background subagents dispatched + harvested (1 timed out, 3 completed)
- 6 QC dispatches (4 APPROVED, 2 NEEDS_REWORK both reworked + approved)

## Files

- This doc: `dev/notes/next-session-priorities-2026-05-23.md`
- V8 analysis (prior session): `dev/notes/v8-random-restart-analysis-2026-05-23.md`
- Margin Phase 3 report: `dev/notes/margin-phase3-bear-windows-2026-05-23.md`
- 11-knob crash diagnosis: `dev/notes/bayesian-11knob-int-knob-crash-2026-05-22.md`
- Bayesian sweep plan: `dev/plans/bayesian-production-sweep-2026-05-18.md`
- Tuning methodology: `dev/plans/tuning-methodology-redesign-2026-05-22.md`
- M6.6 plan: `dev/plans/m6-6-live-cycle-scoping-2026-05-22.md`
- Margin spec: `dev/plans/short-side-margin-2026-05-13.md`
- trading-parameters repo: https://github.com/dayfine/trading-parameters (live = V3 winner `bbd84ce` unchanged)

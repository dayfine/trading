# Next-session priorities (post 2026-05-22 marathon)

Written end of 2026-05-22 session after V3-V7 sweep stack converged + methodology redesign landed. Supersedes `next-session-priorities-2026-05-21-pm.md`.

## This session's outcomes

15 PRs landed across 2 days (2026-05-21 + 2026-05-22):

| PR | Theme |
|---|---|
| #1224 | BO checkpoint (resume after crash) |
| #1225 | V3 sweep specs |
| #1226 | V3 smoke spec + QC reviews |
| #1227 | Rules promotion (QC docker + isolation, merge gates, session rampup, code-health) |
| #1228 | Gitignore Bayesian sweep output dirs |
| #1229 | Soft gate penalty (spec.gate_penalty_value field) + V4 spec |
| #1232 | V3 result writeup + axis-3 gate-fitness proposal (Option E) |
| #1234 | promote_config.sh + tuning methodology design doc |
| #1235 | Drop name field from symbol_types + delisted sexp (-5.8 MB) |
| #1236 | V5 result + V6 specs |
| #1237 | Methodology redesign (8 gaps + P0-P7 experiment order) |
| #1238 | Status refresh (5 stale files) |
| #1239 | Docs-only PR exception for merge gates |
| #1240 | P1 cross-scenario validation in promote_config.sh |
| #1241 | Fix-forward: route promote_config.sh dune-build through docker (in QC) |

**Sweep series V3-V7 finished:**
- V3: completed 60/60 iters. Winner = iter-1 random sample, mean Sharpe 0.81 vs cell-E 0.56. REJECT under strict axis-3, PASS under proposed Option E.
- V4 (soft gate penalty): killed iter-19. Confirmed penalty value not binding.
- V5 (wider bounds): killed iter-18. Confirmed bounds-too-tight not binding.
- V6 (worst_delta 0.50): killed iter-14. Confirmed worst_delta not binding.
- V7 (m=14 wins): killed iter-6. Confirmed m-of-N wins not binding.
- **All four hypotheses rejected.** 4-knob parameter space is fundamentally narrow.

**Optimal-strategy quality refreshed:** numbers believable on 16y SP500 (Cell-E full-period Sharpe 0.71 / +307% return / -19.92% MaxDD). Caveat: Constrained variant under-fills capital (185% < Actual 307%); not a true upper bound. Usable as sanity-check column, not strict efficiency normalization.

**trading-parameters repo seeded** (`ab8427f` + `45fdb63`): cell-E baseline at live/current.sexp + V3 winner staged.

## P0 — Complete the V3 promotion E2E test (post-#1241 merge)

Once #1241 merges, exercise the cross-scenario validation gate end-to-end:

```sh
TRADING_PARAMS_DIR=/Users/difan/Projects/trading-parameters \
PROMOTE_SHARPE_REGRESSION_THRESHOLD=0.10 \
dev/scripts/promote_config.sh \
  2026-05-22-bayesian-v3-winner \
  dev/experiments/bayesian-production-sweep-2026-05-18/output-v3-parallel4/best.sexp \
  dev/experiments/bayesian-production-sweep-2026-05-18/output-v3-parallel4 \
  dev/experiments/bayesian-production-sweep-2026-05-18/spec_prod_v3.sexp \
  dev/experiments/bayesian-production-sweep-2026-05-18/walk_forward_v2_baseline.sexp
```

Expected wall: ~20-30 min (2 scenarios × 10-15 min each, in parallel).

Outcomes:
- **PASS gate** → V3 winner promoted to live/current.sexp; first real Promotable Config in the system.
- **FAIL gate** → see which scenario regressed; this is the cross-scenario validation actually working.

## P1 — Update `bayesian-production-sweep-2026-05-18.md` §6 to reflect Option E

Tiny follow-up to #1232. The codified 5-axis gate spec still has strict axis-3 ("OOS Sharpe ≥ 0.50 every fold"). Update to Option E ("OOS Sharpe ≥ baseline - 0.10 every fold") per the redesign decision in #1237 §10.

~10 LOC docs-only diff. No-QC per #1239.

## P2 — M6.6 live cycle scoping (per user 2026-05-22)

User explicitly green-lit ("we could start setting it up with param and code version pinned"). Scope:
1. **`live` DATA_SOURCE** — does not exist yet. The existing DATA_SOURCE abstraction supports `historical` (cache) + `synthetic`; need to add a `live` variant that calls EODHD live endpoints.
2. **Cron / scheduler integration** — Weekly Friday-close trigger.
3. **Alert dispatch** — email / push notification of new trade signals.
4. **Trading-state durability** — persist position state across sessions (currently held in memory).
5. **Parameter pin** — coupled with P0 above (promote V3 winner via promote_config.sh).

This is a substantial new track (~3-5 weeks of work). Recommend starting with a plan doc + scoping next session.

## P3 — Next BO experiment: 11-knob multi-param sweep (P4 in #1237)

Existing fixture: `trading/test_data/walk_forward/bayesian-multi-param-2026-05-16.sexp` (tested algorithmically, never run in production). Adds 7 more knobs:
- 4 screener stop/entry knobs
- 1 risk-per-trade knob
- 2 screener weights

Per #1237 §5, this is the next-priority sweep. Tests whether more dimensions escape the 4-D plateau. ~12-15h CPU wall.

**Stopping rule** (per #1237 §4): if first 15 iters all score within composite_delta 0.4±0.1 (i.e. same plateau as V3-V7), kill the sweep. 11-knob is also a plateau means the search-space-topology hypothesis is dead; need strategy-mechanic changes (M8+).

## P4 — Component-decomposition scoring (P6 in #1237)

The "highest strategic value" experiment per the methodology doc. Decompose the Composite objective into screener / portfolio / orders / stops components, so the BO can target the weak component instead of optimizing globally.

Cost: ~12-20h dev + 12h CPU. Biggest commitment in #1237 §5.

Worth doing AFTER P3 reads, since P3 tells us whether more dimensions help at all (cheaper experiment first).

## P5 — Random-restart V8 (P3 in #1237)

V3 spec, but with 3 different seeds (2026 + 2027 + 2028). Pick best across them. ~33h CPU total but can run in background overnight.

Cheap insurance: confirms V3 winner is the global optimum, not a seed-locked random sample. Useful if V3 winner makes it through the cross-scenario gate.

## P6 — Carry-overs from track-pacer 2026-05-22

| Item | Action |
|---|---|
| qc-structural H3 false-positive (carried 7+ weeks) | Escalate to maintainer or patch agent |
| qc-structural review-file persistence gap (carried 7+ weeks) | Escalate to maintainer or patch agent |
| `cleanup` track 4 `[~]` items dated 2026-05-07/08 | Dispatch code-health or close |
| orchestrator-automation Phase 2 no dispatch since 2026-05-04 | Wrap or commit to Phase 2 work |
| shares-outstanding fundamentals source decision | Vendor decision needed |

Lower-priority but accumulating.

## Open PRs at session end

- **#1241** (in QC) — fix-forward for promote_config.sh docker routing. Should land first thing next session.

## Hiccups to NOT repeat (codified in memory this session)

1. **`feedback_jj_workflow_for_concurrent_writes.md`** — always `jj diff --stat` BEFORE any `jj new <rev>` to verify your new files are in @. Cost me 5× in one session.
2. **`feedback_docker_vs_host_dune.md`** — scripts MUST route `dune build` through `docker exec trading-1-dev`. Host opam is intentionally minimal. Caught only at first real-bars E2E of #1240; fixed in #1241.
3. **`feedback_pkill_narrow_pattern.md`** — `pkill -f <short-string>` matches incidental command-line references (cleanup sidecars, watchers). Always `pgrep -af` first to inspect, then narrow.
4. **`feedback_schedulewakeup_loop_only.md`** (codified earlier) — ScheduleWakeup only fires inside `/loop`. Use CronCreate or inline Bash polls instead for interactive sessions.

## Session totals

- 15 PRs merged + 1 closed
- 2 sweep series complete (V3 + diminishing returns confirmed on V4/V5/V6/V7)
- Methodology redesigned + codified in #1237
- Cross-scenario validation gate shipped + fix-forward in QC
- Optimal-strategy quality verified
- 4 new memories codified for hiccups
- Status reconcile + track-pacer audit landed

## Files

- This doc: `dev/notes/next-session-priorities-2026-05-22.md`
- Methodology: `dev/plans/tuning-methodology-redesign-2026-05-22.md`
- V3 result: `dev/notes/bayesian-prod-v3-result-2026-05-21.md`
- V5 result: `dev/notes/bayesian-prod-v5-result-2026-05-22.md`
- Axis-3 fitness: `dev/notes/axis-3-gate-fitness-2026-05-21.md`
- Track-pacer: `dev/reviews/track-pacer-2026-05-22.md`
- trading-parameters repo: https://github.com/dayfine/trading-parameters

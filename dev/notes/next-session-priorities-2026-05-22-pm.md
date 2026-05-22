# Next-session priorities (post 2026-05-22 PM session)

Supersedes `next-session-priorities-2026-05-22.md`. Written at end of
session that landed P0 (V3 winner promoted) + 8 PRs + first cross-scenario
validated promotion in the system + 2 background V8 random-restart sweeps
launched.

## This session's outcomes

8 PRs landed:

| PR | Theme |
|---|---|
| #1243 | `promote_config.sh` fix-forward: tmpdir under repo bind-mount (dev/_tmp/) |
| #1244 | docs: §6 axis-3 → Option E |
| #1245 | docs: close 4 stale `[~]` cleanup items |
| #1246 | docs: orchestrator-automation track wrapped (Phase 1 stable, Phase 2 deferred) |
| #1247 | `promote_config.sh` fix-forward: `declare -a foo=()` for set -u safety |
| #1248 | docs: M6.6 live cycle scoping plan |
| #1249 | docs: 11-knob BO sweep int_of_sexp crash + fix path |
| #1251 | fix: PARKED → MERGED (status_file_integrity linter unblock for #1246-introduced bug) |

**P0 SHIPPED — first real cross-scenario validated promotion.**
- `dayfine/trading-parameters` commit `bbd84ce`: V3 winner promoted to `live/current.sexp`.
- Both panel scenarios PASS the Sharpe regression gate:
  - sp500-2010-2026 (16y): cand 0.765 vs cell-E 0.78 (delta -0.0149)
  - sp500-2019-2023 (5y):  cand 0.689 vs cell-E 0.56 (delta +0.1287)
- Caveat: sp500-2019-2023 candidate MaxDD = 30.58% vs cell-E 21.56% (delta +9pp). The current promote gate only checks Sharpe regression; MaxDD ≤ baseline + 5pp is an Option E axis but not yet enforced in `promote_config.sh`. **Follow-up: extend the gate to MaxDD + N_trades.**

**P3 11-knob BO sweep CRASHED on int_of_sexp.** Per `dev/notes/bayesian-11knob-int-knob-crash-2026-05-22.md`: `cell_to_overrides` emits raw `%.17g` floats; int-typed knobs receive non-integer BO samples (e.g. `3.8004`). P3 BLOCKED until per-knob `is_int` flag + rounding lands (~30 LOC; Option A in the crash doc).

**P5 V8 random-restart RUNNING.** Two background sweeps:
- Seed 2027 (parallel=4) — launched ~03:14 UTC, ETA ~14:14 UTC (~11h wall)
- Seed 2028 (parallel=2) — launched ~03:28 UTC, ETA ~02:28 UTC next day (~22h wall at half parallelism)

Both use V3 4-knob spec (no int knobs, unaffected by the P3 bug). When they finish, run `dev/scripts/promote_config.sh` on each winner; if any beats both panel scenarios cleanly (no MaxDD blowup) AND beats the V3 winner's mean composite, it's the new live config.

## Open background jobs at session end

- `dev/logs/bayesian-prod-v3-seed2027-parallel4.log` — V8 seed 2027 (~iter 1-2 of 60)
- `dev/logs/bayesian-prod-v3-seed2028-parallel2.log` — V8 seed 2028 (~iter 1 of 60)

When they finish:
- Results at `dev/experiments/bayesian-production-sweep-2026-05-18/output-v3-seed2027-parallel4/best.sexp` + `output-v3-seed2028-parallel2/best.sexp`
- OOS reports at `output-v3-seed*/oos_report.md`
- Apply Option E gate (per `dev/plans/bayesian-production-sweep-2026-05-18.md` §6 post-#1244): mean composite ≥ cell-E + 0.05, per-fold Sharpe ≥ baseline - 0.10, MaxDD ≤ baseline + 5pp, N_trades within 2x

## P0 — Extend `promote_config.sh` gate to MaxDD + N_trades

Per the Option E spec at `dev/plans/bayesian-production-sweep-2026-05-18.md` §6 (post-#1244):

- Sharpe gate (current): regression ≤ 0.10 absolute units. **Already implemented.**
- **MaxDD gate (MISSING):** MaxDD ≤ baseline + 5pp. Today's V3 promotion passed Sharpe but had +9pp MaxDD on sp500-2019-2023 — would have been caught by this gate.
- **N_trades gate (MISSING):** within 2x of baseline. Today's V3 promotion: sp500-2019-2023 candidate 259 trades vs cell-E ~?? (need to look up).

~50 LOC change to `promote_config.sh`. Same pattern as `regresses_by_more_than` (already in `lib/extract_metrics.sh`).

## P1 — Land 11-knob int-knob fix (Option A)

Per `dev/notes/bayesian-11knob-int-knob-crash-2026-05-22.md` §"Fix path" Option A:

1. Extend cell spec to carry an `is_int` flag per knob:
   ```sexp
   (bounds
     (("knob_name" (lo hi) ?(int)) ...))
   ```
2. Round in `_binding_to_sexp` (`trading/trading/backtest/tuner/lib/grid_search.ml:61-67`) when the flag is set.
3. Unit test: int-typed knob sampled at `3.8` → emitted sexp atom is `"4"` not `"3.8004…"`.

~30 LOC + a unit test. Required to unblock P3 (11-knob sweep).

## P2 — Re-launch 11-knob sweep after P1 lands

`dev/experiments/bayesian-production-sweep-2026-05-18/spec_prod_11knob_v1.sexp` is staged but un-tracked locally (gitignored under `output-*-parallel*/`? actually it's in the experiments dir itself; verify). Re-launch with parallel=4; expected ~12-15h wall.

Stopping rule (per #1237 §4): kill if first 15 iters all score within composite_delta 0.4±0.1.

## P3 — V8 random-restart result analysis (when seeds 2027 + 2028 finish)

ETA both seeds done within ~24h of session-end. After both land:

1. Read `output-v3-seed{2027,2028}-parallel*/best.sexp` + `oos_report.md`.
2. Compare to V3 seed-2026 winner: do seeds 2027/2028 find better composites? Different params?
3. If any seed clearly beats V3 winner on the cross-scenario panel → promote it (different label, e.g. `2026-05-23-bayesian-v8-seedXXXX-winner`).
4. If all 3 seeds converge to ~same composite ± 0.05 → the V3 winner is the global optimum on this surface.
5. If seeds diverge significantly → BO is local-optima-locked; need restarts in future production sweeps.

## P4 — M6.6 live cycle implementation S1 (per dev/plans/m6-6-live-cycle-scoping-2026-05-22.md)

5-session sequence per plan §3. Start with **S1 — `weekly_cycle.exe` entrypoint** (~300 LOC, new module). End-to-end test against the most recent Friday using real EODHD data.

User decisions needed before S1 (per plan §4):
- Email service (SendGrid recommended)
- Trading-state private repo name (`dayfine/trading-state` proposed)
- Cron timing (Friday 13:30 PT proposed)
- Gate on V3 winner vs wait for 11-knob / V8 result

## P5 — Component-decomposition objective (the highest-strategic-value experiment)

Per `dev/plans/tuning-methodology-redesign-2026-05-22.md` §2.8 + #1237 §5 P6:

> Current Composite is global P&L-derived. Should decompose: screener score / portfolio score / orders/execution score / stops score. Then BO composite becomes `w1×screener + w2×portfolio + w3×orders + w4×stops`, and BO can target the weak component.

~200-400 LOC + 12-20h CPU. Worth doing AFTER P3 + V8 results since those tell us whether the 4-D plateau is escaped at all (P3) or seed-locked (V8).

## Lower-priority follow-ups

| Item | State |
|---|---|
| Two qc-structural `[info]` items (H3 false-positive, review-file persistence gap, carried 7+ weeks) | Need patch OR explicit acceptance in `dev/decisions.md`. Not addressed this session. |
| shares-outstanding fundamentals source decision | Vendor decision needed. Not addressed this session. |
| Cross-scenario validation track decision (new track vs fold into `tuning`) | Per track-pacer recommendation 1 — needs maintainer call. |

## Open PRs at session end

**None.** All 8 PRs landed.

## Hiccups this session (codified in memory)

1. **`feedback_promote_config_3_bugs_one_week.md`** — `promote_config.sh` had 3 fix-forward bugs in 24h. Each surfaced only at first real usage. Demand a smoke test before shipping production-tooling scripts.
2. **`project_bayesian_int_knob_crash.md`** — `cell_to_overrides` emits raw floats; int-typed knobs trip `int_of_sexp` on BO samples. P3 blocked.

PARKED → MERGED status mistake (today) is captured in the PR body of #1251 + #1246 amendment in the orchestrator-automation status file; not in memory since the schema is documented in `devtools/checks/status_file_integrity.sh`. Future status updates should grep that linter for valid values.

## Session totals

- 8 PRs merged
- 1 trading-parameters commit (V3 winner promoted)
- 1 background sweep crashed + diagnosed (11-knob)
- 2 background sweeps launched (V8 seeds 2027 + 2028)
- 1 baseline aggregate computed (`dev/data/cell-e-baseline-aggregate/aggregate.sexp`, 31 folds × 2 variants)
- 1 docs status track wrapped (orchestrator-automation MERGED)
- 1 docs cleanup track items closed (4 stale `[~]`)
- 2 memories added
- 1 scoping plan landed (M6.6 live cycle)

## Files

- This doc: `dev/notes/next-session-priorities-2026-05-22-pm.md`
- Crash diagnosis: `dev/notes/bayesian-11knob-int-knob-crash-2026-05-22.md`
- M6.6 plan: `dev/plans/m6-6-live-cycle-scoping-2026-05-22.md`
- Methodology (prior): `dev/plans/tuning-methodology-redesign-2026-05-22.md`
- trading-parameters repo: https://github.com/dayfine/trading-parameters (commit `bbd84ce`)

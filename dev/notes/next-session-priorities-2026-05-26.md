# Next-session priorities (2026-05-26)

Supersedes `dev/notes/next-session-priorities-2026-05-25.md`.

## Session ramp-up

Per `.claude/rules/session-rampup.md`:

1. **Check main CI is green:** `gh run list --branch main --limit 3 --json conclusion,name,headSha,status`. If red, fix first.
2. **Read this doc** (you're here). It points at the active roadmap docs.

## Active roadmaps — two parallel programs

### Program A — Tuning research-driven program (5-7 sessions)

**Master plan:** `dev/plans/tuning-research-driven-program-v2-2026-05-25.md`

Settles the 11-knob plateau verdict by attacking the noise floor + meta-overfit + hand-tuned-scalar problems all at once, per the 2026-05-25 frontier-BBO research triage.

4 milestones + 1 sweep + 1 Phase-2 stretch:

| Milestone | What |
|---|---|
| **M1 (PR-1)** | Multi-fidelity (fold-COUNT tiers: 6→12→26 folds × 12m + Ambitious 8-10 × 36m) + Common Random Numbers fold pairing |
| M2 (PR-2) | qNEHVI multi-objective with multi-baseline constraint (Sharpe, MaxDD, pass-vs-BRK + SPY-pass as hard constraint) |
| M3 (PR-3) | Deflated Sharpe Ratio + outer-holdout enforcement |
| **M4 (PR-4)** | 1998-2026 + top-3000 (delisted-aware) primary sweep — the canonical experiment |
| Phase 2 stretch | True PIT Russell 3000 membership (data engineering; deferred) |

**Start M1.** Task list at the top of the plan doc.

### Program B — Sweep + QC architecture improvements (3-4 sessions)

**Master plan:** `dev/plans/sweep-and-qc-architecture-2026-05-26.md`

Harness improvements that compound across all future sessions. **Parallel to Program A — neither blocks the other.**

5 small PRs:

| PR | What |
|---|---|
| **PR-A** | `dev/scripts/launch_sweep.sh` — mandatory entry point; refuses to launch if preconditions fail (disk, bind-mount, etc.) |
| PR-B | `bayesian_runner.exe` refuses non-`/tmp/sweeps/` output paths |
| PR-C | `dev/scripts/sweep_disk_watcher.sh` — autonomous abort on disk/Docker.raw thresholds |
| PR-D | QC agents post via `gh pr review --comment` instead of writing `dev/reviews/<feature>.md` files |
| PR-E | QC agents use plain `git worktree` instead of `jj edit` (fixes the shared-jj-backend race) |

**Why this parallel work:** today's session lost ~16h of sweep wall-time to disk-fill recovery + multiple jj contamination incidents. The sweep-hygiene rule exists but isn't mechanically enforced — these PRs add the enforcement layer.

## Order recommendation

**Open PR-A first** (launch wrapper). Single highest-leverage change in either program. Once mechanically-safe sweep launches are in place, the rest of Program A's wall-time risk drops dramatically. Then choose freely between A and B based on bandwidth.

## Operational reminders (carried forward from 2026-05-25)

Documented in `.claude/rules/sweep-hygiene.md`. Will become enforced once Program B PR-A lands. Until then, observe manually:

- **Sweep output to `/tmp/sweeps/<name>/`** (bind-mounted to host)
- **`df -h /` every ~2h** of an active sweep
- **No concurrent agent dispatches during a sweep** (share container's writable layer)
- **`rm -rf .claude/worktrees/<agent-id>/`** after each agent's task-notification

## Open follow-ups (carried forward; deferred)

- 2 qc-structural `[info]` items (H3 false-positive, review-file persistence gap, carried 8+ weeks)
- shares-outstanding fundamentals vendor decision (blocked on user)
- Cross-scenario validation track decision (per track-pacer)
- Sweep ↔ QC container contention — still real after Program B PR-A-E; needs separate-containers or sweep-runs-natively fix (out of current scope)

## State at session end (2026-05-25)

- Main green
- No open PRs, no open issues
- Docker container `trading-1-dev` healthy; bind-mount in place; Docker.raw < 30 GB
- 22+ PRs merged today across the day's session
- `.sweep-output/` exists as bind-mount target on host

## References

- `dev/plans/tuning-research-driven-program-v2-2026-05-25.md` — Program A master plan
- `dev/plans/sweep-and-qc-architecture-2026-05-26.md` — Program B master plan
- `.claude/rules/sweep-hygiene.md` — operational rules
- `.claude/rules/session-rampup.md` — the ramp-up protocol itself
- `dev/notes/v6-random-baseline-verdict-2026-05-24.md` — the empirical evidence both programs respond to

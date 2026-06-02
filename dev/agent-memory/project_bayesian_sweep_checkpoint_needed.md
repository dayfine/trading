---
name: project-bayesian-sweep-checkpoint-needed
description: V2 sweep lost ~5h of work to power-loss-induced restart (2026-05-20). User flagged checkpointing as a needed improvement for future frequent sweeps.
metadata: 
  node_type: memory
  type: project
  originSessionId: b503ea26-7990-436d-9061-8f8bf18ced02
---

V2 production sweep (2026-05-20) was interrupted by a power loss ~5h
into the planned 11.5h run. The current `bayesian_runner.exe` has no
checkpoint mechanism — it auto-restarted from scratch (effective wall
cost: 2× planned).

**Why:** User flagged this directly at end of 2026-05-20 session: "might
be worth making the checkpointing of the whole thing a bit more robust
if we need to run this frequently in the future". Production sweeps
will become frequent (V2, V3, P5-cadence-aware) — each costs 11h+.

**How to apply:** When picking up next-session work, this is a
candidate P1 item, especially if a V3 cadence-aware sweep is planned.
Design surface: persist `bo_log.csv` incrementally after each BO
iter (currently only written at end); persist BO state (GP posterior
+ next-acquisition state) so a restart can resume from last-completed
iter rather than scratch. Plumbing is in
`trading/trading/backtest/tuner/bin/bayesian_runner_runner.ml`
(orchestrates `Bayesian_opt.suggest_next` ↔ `evaluator` cycles).

Related: `dev/plans/parallelise-walk-forward-executor-2026-05-18.md`
shipped fork-per-fold (fixes leak), but doesn't address resume.
Checkpoint plan would be a fourth pillar of the tuner robustness
work alongside the leak fix + fork-pool + composite scorer.

Linked work: [[project_2026-05-13_session]], [[feedback_no_silent_ci_waits]].

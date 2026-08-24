# Next-session priorities — 2026-08-24 EOD (~16:00 PT)

Supersedes `next-session-priorities-2026-08-24.md`. The 08-22 research pair is
**fully delivered** (#2486/#2489/#2490 all answered with committed artifacts),
the P1 regression scare (#2503) resolved as baseline-provenance, and a full
issue-backlog burn-down ran 08-24 (user-directed 8-10h session).

## Delivered 08-24 (on top of the overnight instrumented-run program)

- **#2490 monster funnel — ANSWERED (v2, book-faithful)**: 1,303 episodes ≥100%
  fwd run; 51% die at the production breakout gate, 36% at top-N, grade+RS drop
  ZERO, 3.5% admitted, 0.6% held ≥13wk. Funding/stop levers sit below the leak.
  `project_monster_funnel_top_of_funnel`; artifacts PRs #2520/#2522;
  tool = `monster_scan` (PR #2519, book defaults, guards pinned via 2 QC
  rework cycles incl. a live zero-volume-guard catch).
- **Backlog closed**: #2429 (auto-merge poll, PR #2517 — behavioral caught a
  subshell set-u abort the first fix shipped), #2508 (A2 rule rewritten from
  measurement, PR #2516), #2509 (audit verdict inversion, PR #2518 — behavioral
  caught a 20-file combined-review regression in the first fix), #2506 deps,
  #2505 (cron's stops differential pin — relocated for A2). #2382 measured:
  exposure caps bind ZERO times in 26y → docs-only, downgraded P4. #2521 filed
  (shellcheck-over-workflow-run-blocks LINTER_CANDIDATE).
- Salvage evaluation #2466 dispatched EOD (verdicts may still be landing —
  check `gh pr list` + issue comments).

## Decision queue (user)

1. **#2486 §2.1** — `initial_stop_buffer` flip + `reset_anchor_on_stalled_cycle`
   promotion path. All evidence on the issue: freeze real (9% vs 49% ratchet),
   unfreeze per-trade ~nil, +138pp arm delta = CLS lottery.
2. **#2503 re-basis ack** — declare instr-null (params committed) the pinned
   record baseline. Evidence complete; issue open only for the ack.
3. **#2404** — picks artifact: stop suppressing past-band picks, show
   "will not fill at current price" instead (one rule, two views). Changes the
   weekly artifact the user reads → user call; full analysis in the issue.
4. **#2489 §2.2 (arc trade)** — representative-trade audit says realized
   population ≠ book population BECAUSE of stop mechanics, not selection;
   feeds the same §2.1/§2.2 decisions.

## P1/P2 work queue (agent-runnable next session)

- **#2403** goldens-track-live (P1, size L) — head of the correctness chain
  (#2404 decision → #2403 → fill-model flip → #2405). Needs the #2404 decision
  first for its worst-instance field.
- **#2440** record_qc_audit_test scenario 22 CI-vs-local (P1) — diagnosability
  landed via cron PR #2504; next step is the actual divergence fix.
- **#2489 pending dims** — base length + fill-week ratio per entry via
  `monster_scan -pairs` (tool merged; pairs from trades.csv/tickets tables in
  `dev/experiments/instrumented-record-2026-08-23/results/`).
- **#2490 follow-up axis** — per-drop sub-reason inside `Dropped_at_breakout`
  (candidates.sexp G3 extension) to decompose gate-strictness sub-causes.
- #2408 stop surface stays PARKED behind the correctness chain (its own note).

## Operational notes

- **Preserve `.claude/worktrees/sweep-instr-0823`** (candidates.sexp 519MB/arm
  + trade_audit.sexp per arm) until #2489 pending dims + any funnel re-cuts are
  done. `mscan-run` worktree can be deleted (tool now on main).
- Container zombies ~290 (PID clutter only). Two dune-wedge incidents 08-24 —
  pattern: kill + relaunch detached with file log (`feedback_docker_exec_dune_wedge`).
- QC loop stats today: 6 NEEDS_REWORK verdicts, every one a real catch
  (dead-code subshell stub, 20-file regression, lookahead-unpinned, non-book
  volume basis, unguarded widest-window crash, zero-volume junk). The gates
  are earning their cost.
- Memory snapshot exported (139 memories → dev/agent-memory/).

---

## Amendment (~16:00 PT) — afternoon completions

- **#2489 FULLY delivered** (PR #2526): fill-week vol ratio med 1.20× vs book
  2× — resting StopLimit tickets decouple confirmation from execution, which
  mechanically explains the arc's 72% §4.2 ejection rate. base_weeks med
  24-35wk; p25=0 for a quarter of executed entries. Adds a third leg to the
  §2.2 decision: the faithful gate ejects the NORMAL consequence of resting
  tickets, not unusually bad entries.
- **#2466 closed** (PR #2525): both salvage guards landed — incl. a mirror
  defect the issue didn't name (rejected exit could spend a long ticket's
  retry budget AND re-submit the exit order). Mutation-verified both gates.
  #2524 filed (simulator.ml headroom trigger).
- **#2440 fixed-and-monitoring** (PR #2527, P1→P3): scenario 22 was passing
  by ACCIDENT (ls directory-header word-split); find-based enumeration fixes
  it + a silent directory-drop. Grep-on-directory image variance remains the
  one open intermittency candidate; per-conjunct diagnostics will name it on
  recurrence.
- Day totals: **13 PRs merged**, 6 issues closed (+2 filed: #2521, #2524),
  2 downgraded on measurement (#2382, #2440). All six QC NEEDS_REWORK
  verdicts today were genuine catches.

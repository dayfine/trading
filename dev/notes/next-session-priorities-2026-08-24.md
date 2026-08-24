# Next-session priorities — 2026-08-24 (~05:15 PT)

Supersedes `next-session-priorities-2026-08-22-eod.md`. The 08-22 "opening
move" (one instrumented run, three analyses) is **run + first analysis DONE**;
a P1 regression was found in the process.

## What happened this session (08-23 00:40 → 08-24 05:15)

- **Instrumentation shipped through full gates**: #2496 (max_stop/n_stop_raises
  on trades.csv), #2500 (G1 candidates.sexp — zero-funded Fridays kept),
  #2501 (G2 per-candidate cascade-stage outcomes), #2497 (design doc),
  #2498 (book write-back: freeze = artifact, Ch. 6 XYZ walk-through).
- **Paired 26y run complete** (`dev/experiments/instrumented-record-2026-08-23/`,
  PR **#2511** open with artifacts): instr-null 243.06%/1182 trades vs
  instr-unfreeze 381.46%/1178.
- **#2486 ANSWERED on real data**: fallback = 88.7% of entries; ratchet 9% vs
  49% (≥13wk); 85% of fallback trades die at initial ~2% width. Unfreeze
  per-trade effect ~nil (937/949 paired identical); +138pp = CLS lottery.
  Memory: `project_ratchet_freeze_real_data`.
- **⚠ P1 REGRESSION FOUND — issue #2503**: identical grid1-null config gives
  305%→243% between 08-22 main and 2b11c60dd, diverging from week one.
  Suspects #2492 (floor_stop refactor, prime) / #2500 / #2501. Memory:
  `project_record_basis_divergence_0823`. **No absolute cross-era comparisons
  until bisected.**
- Issues filed: #2502 (streaming trades.csv, P3), #2503 (P1).

## P0 for next session

1. **#2503 bisect** — container free. 6-month probes (2000-01-01→06-30,
   instr-null spec truncated) at builds `e64f8655` (control), `4141beda5`
   (post-#2492), `b128b1d9e` (post-#2500). Divergence visible by 2000-01-29 so
   6mo discriminates. If control ≠ recorded baseline early trades, re-examine
   baseline provenance instead. If #2492's refactor is the culprit: it's a
   behavior change that passed all gates — needs either revert-of-refactor or
   acceptance + re-basis of the record (user decision), plus a harness answer
   to "broad armed scenarios are invisible to PR gates" (third instance).
2. **Merge #2511** (experiment artifacts; CI + gates as applicable).

## P1 queue after that

- **#2489 representative-trade audit** + **#2490 monster capture funnel** —
  ALL inputs on disk: `candidates.sexp` (519MB/arm, per-week per-candidate
  cascade outcomes) + `trade_audit.sexp` (13MB/arm) in the pinned worktree
  `.claude/worktrees/sweep-instr-0823/trading/dev/backtest/scenarios-2026-08-24-013206/`.
  **DO NOT delete that worktree** until these analyses are done (the sweep
  script skips locked worktrees but it is not locked — recreate from
  run_chain.sh + spec if lost; costs ~9h).
- #2486 decision items (§2.1 initial_stop_buffer flip; unfreeze promotion
  path) — all evidence now on record in the issue.
- #2408, #2403, #2440 (carried P1s).

## Standing cautions

- Cron merged 5+ PRs during this session's 00:17/05:17 slots (#2492 included).
  Fence comments on issues do not stop runs already started — check
  `git log origin/main` at session start.
- Session-limit outage cost 8.5h on 08-23 (03:15–11:48); salvage-commit agent
  work to wip/* branches when it happens (this worked — zero loss).
- Container zombies ~290 (PID clutter only, `tail -f` PID 1 doesn't reap).

---
name: project_d1d2_default_flip_in_flight
description: "MERGED 2026-09-03 (b3cac3672) — PR #2648 flipped sim_exit_fill_next_open + stop_skip_entry_bar default ON with 27 paired golden cells (14 re-pinned); every post-09-03 backtest runs on the fixed exit basis; pre-09-03 exit-lever verdicts must be re-measured"
metadata: 
  node_type: memory
  type: project
  originSessionId: c7c971d0-92c7-4c65-a853-b1c877ee64fa
  modified: 2026-09-03T08:10:00.357Z
---

**2026-09-03 (user: "yes - work autonomously" on P0):** the D1/D2 exit-basis
correctness flip is PR #2648 (`feat/d1d2-default-flip`, flip commit
`398f57111` + paired-goldens commit `d0806bcf` + rework-1 commit `66fcae44`:
default pins + bool .mli drift guard in test_runner_hypothesis_overrides.ml,
three docstrings, count fixes). **Chain DONE 03:44 PDT**: 27 cells, 14
goldens re-pinned, 13 wide-band kept; `paired-run-done` applied,
`do-not-merge` removed. Both gates APPROVED at 66fcae44; **MERGED 2026-09-03 ~06:00 PDT as b3cac3672**.
Pinned worktree removed. Remaining: then `git worktree remove --force
.claude/worktrees/sweep-d1d2` and re-run the exit levers on the fixed basis.

- **Ledger:** `dev/experiments/_ledger/2026-09-03-exit-basis-d1d2-correctness.sexp`
  (verdict Inconclusive = human-gated R3 override, same convention as the
  2026-08-24 stops-basis entry).
- **Chain:** `/tmp/d1d2-run/chain.sh` (host, nohup), log
  `/tmp/d1d2-run/chain.log`, pinned worktree `.claude/worktrees/sweep-d1d2`
  @ 398f57111, artifacts `.sweep-output/d1d2g/<family>--<name>-{new,old}-*`.
  Old-arm specs staged at `/tmp/d1d2-run/specs/<family>/<name>-old.sexp`
  (both knobs pinned false, prepended to config_overrides; deep-merge keeps
  the golden's own stops_config fields).
- **Old-arm provenance:** the 12 cells #2587 ran at 5dc61da07
  (`dev/experiments/clock-surface-2026-08-27/results/goldens/*-actual.sexp`)
  ARE the current-main old arm by R1 (every merge since was default-off or
  docs); validated by one direct re-run (armed-stoplimit-old). All other
  cells (armed-e, goldens-small, smoke tier-2, perf-sweep 1y/3y, goldens-broad
  tier-4) run both arms.
- **Phases:** 1 postsubmit 5y → 2 tagged historical → 3 tier-2 → 4 tier-3
  perf-sweep → 5 untagged historical (26y) → 6 tier-4 broad. ~14h total.
  Skipped on purpose: goldens-hybrid-tier-experiment (no CI consumer),
  sp500-30y-capacity-1996 (untagged), Bah_benchmark cells (no strategy).
- **runtest goldens already regenerated in the flip commit:**
  `panel_goldens/{panel-golden-2019-full,tiered-loader-parity}.sexp`
  (their exits were Saturday-dated).

**Why:** every golden that exits a position moves; postsubmit goldens go red
on main if the flip merges before the re-pins. `goldens-affected` FAILs with
the affects-all shape by design until `paired-run-done` is applied.

**How to apply:** when resuming, read `/tmp/d1d2-run/chain.log` for
`RESULT` lines (never the chain.out), build the paired table from
`.sweep-output/d1d2g/*-actual.sexp`, re-pin each moved golden's `expected`
at ±15% around the NEW-arm actuals (existing convention), commit as a second
commit on `feat/d1d2-default-flip`, apply `paired-run-done`, remove
`do-not-merge`, run QC. No agents while phases 5–6 (26y / top-3000) run.
Related: [[project_lever_reads_invert_on_fixed_sim]],
[[project_saturday_stale_fill_defect]].

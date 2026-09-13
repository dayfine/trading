# Next-session priorities — 2026-09-13 (supersedes 2026-09-10)

Written 09:41 PT 2026-09-13 by the autonomous session that ran 00:17 → 09:41 PT while the user was away.
The 09-10 handoff's queue items 1–3 are resolved; item 4 is running; item 5–6 untouched.

## Merged this session

- **#2767** `fix(devtools)`: per-pid fixture root for `test_walk_failure_reporting` — closes #2760 (the concurrent-runtest `/tmp` race that produced the spurious H3 on #2758). Both QC gates; the behavioral pass drove the race deterministically (pre-fix 6/6 failures, post-fix 0/6).
- **#2758** `feat(snapshot_pipeline)`: `-cut-prefix-misscale` (default-off) — queue item 2 (#2732). Structural re-run cleared the stale H3; behavioral rework iteration 1 added the deep-prefix `.weekly` side-table pin (probe e now fails 2 arms, control passes).
- **#2759** `feat(strategy)`: `deteriorating_blocks_longs` (default-off) — queue item 3 (#2755). Behavioral rework iteration 1 threaded `~macro_trend` into `Screener_macro_gate.longs_admitted_by_breadth` (flag-off bit-identical by construction; the first pass found a flag-off behaviour change when `neutral_blocks_longs` was also on) and added the strategy-level fresh-candidate pin (two severing mutations had been green).
- **#2768** pre-registration, **#2776** the verdict (below) — docs, admin-merged on green.

## The result that changes what comes next

**Item 3 is settled: `deteriorating_blocks_longs` = REJECT-do-not-revive** (`dev/experiments/deteriorating-gate-2026-09-13/`,
ledger `2026-09-13-deteriorating-breadth-long-gate`, `memory/project_deteriorating_gate_reject`). Three salts on `_v10dedup`
vs the a0-v10 band, V6 = 0 on all six cells: realised **−$1.70M / −$0.82M / −$1.25M** (0 of 3), maxDD worse / worse /
better (1 of 3; the win is on the null's $3.84M open-MTM cell). `Deteriorating` fires inside recoveries and chop
(52 weeks: 6 in 2020, 20 in 2022–23) and removes NVDA 2020-04-06 and UTHR 2020-12-02 at every salt, BBWI 2020-08-08 at
two; ~300 later fills re-draw per salt; the exit mix shifts toward stops. **Regime labels applied to admission are
anti-predictive** — the label turns over inside the moves the edge comes from. That closes the state-conditioning line
from the 09-04 yearly review (item 3 stop-width-by-state = REJECT-as-default/keep-axis on 09-09; the admission gate =
REJECT-do-not-revive today). Flag stays default-off; Rule-4 retirement candidate after three sessions.

## Live (check first)

- **Item 4 — 12% initial stop × weekly trail cadence on `_v10dedup`** (`dev/experiments/cadence-12w-v10-2026-09-13/`,
  arm `a4-cadence-12w` = a0 + `initial_stop_buffer 0.9167` + `stop_update_cadence Weekly`; same build/worktree/warehouse as
  item 3; same pre-registered binary rule). Lanes: B2 = salts 0 then 1 (started 06:32 / ~09:30), A2 = salt 2 (started 09:16).
  **Salt 0 landed 09:40: 751.67% / 851 / Sharpe 0.578 / maxDD 29.99 vs the null 382.74 / 710 / 37.60 — realised +$2.59M, maxDD −7.6pp, V6 = 0: CLEARS both criteria at one salt** (CLS/NOVT/KTOS/BPT = $2.92M of the arm-only P&L — concentration caveat; see the README). Salt 2 (A2) due ~12:15 PT, salt 1 (B2) due ~12:45 PT. If ≥ 1 more salt clears both, the candidate passes the pre-registered bar and moves to the promotion-confirmation grid (`promotion-confirmation.md`: ≥ 3 cells incl. a broad-vs-broad second universe — the 2009 / 2019 `_v10dedup` vintages exist) before any default flip; #2672-family delisting exposure of wide arms must be re-checked first.
  Read each cell with `ARM=a4-cadence-12w sh dev/experiments/deteriorating-gate-2026-09-13/read.sh <salt> .sweep-output/detgate`
  and gate with `validator_diff -check V6` against `stop-width-by-state-2026-09-08/results/a0-breadth-on-null-s<salt>-v10-validator.sexp.sexp`.
  Artifacts land in `.sweep-output/detgate/a4-cadence-12w-s<salt>-v10-*`; copy to `cadence-12w-v10-2026-09-13/results/`
  (exclude `trade_audit.sexp`, 9 MB) and write the ledger entry either way.
- Pinned worktree `.claude/worktrees/sweep-detgate` (31e4bb9c3) stays until item 4's cells finish; then
  `git worktree remove --force .claude/worktrees/sweep-detgate`.

## Queue (in order)

1. **Finish item 4** (above): three-salt read, ledger entry, memory, this doc's amendment. If it does not clear
   realised AND maxDD at ≥ 2 of 3, retire it as the 09-05 record already anticipated (width is regime-dependent).
2. **Orchestrator summary push (D2)** — carried from 09-10 item 5: step 8 sets git identity but jj reads its own and `@` is
   never described. Harness PR on `.github/workflows/`, full gates, idle container.
3. **Follow-ups carried:** #2753 (publisher 422-guard unpinned, 53/53); #2729 residuals; the `stop_loss` label hiding
   the `Per_position` breaker; `_v9gap` 2009 has no 5y spec (write it against `_v10dedup` 2009).
4. **Rule-4 retirement worklist:** `deteriorating_blocks_longs` becomes removable after three sessions (this is session 1);
   `initial_stop_buffer_by_macro_state` stays (keep-as-axis).

## Ops notes

- **Docker daemon was down at session start** (container `Exited (255)`); `open -a Docker` recovered it in ~5 s. Docker.raw
  had already been recompacted (32 → 26 GB). Superseded warehouses deleted from container `/tmp` (`_v9gap` ×2, plain 2009,
  `_v8ctl`, `dedup_v5thin_adj`, `1998_2026`; −6 GB); `_v7mark` and `_v10dedup` kept.
- **Host free fell 81 → 27 GB with Docker.raw shrinking: macOS Time Machine local snapshots** were pinning the deleted
  agent worktrees. `tmutil thinlocalsnapshots / 40000000000 3` → 65 GB in seconds. `memory/feedback_tm_local_snapshots_pin_deleted_worktrees`.
- 23 local jj bookmarks pointing at merged PRs forgotten; `trading-1-side` worktree (Feb checkout) left alone.
- `pr_gate_status.sh` reads `unclear` when a superseded-SHA NEEDS_REWORK and a later same-SHA APPROVED coexist, even after
  the tip moves; adjudicated by hand (both at the current tip were clean single APPROVEDs) and recorded as a PR comment.
- Strict required checks: after #2767 merged, both feature PRs were BEHIND and `gh pr merge` refused; `gh pr update-branch`
  + 25-min CI each. #2759 was then merged `--admin` seconds after #2758 (disjoint files, both green vs the same main);
  main CI on 31e4bb9c3 green.
- Waits: `Monitor` tails on chain logs for RESULT lines; `run_in_background` until-loops for CI/merge and lane waiters
  (a `nohup … &` inside a tool call did not survive — use `run_in_background`).
- Agents: 10 dispatches (5 structural, 4 behavioral, 2 reworks), all `isolation: worktree`, all via the wrapper.sh fallback;
  every worktree removed on completion. One behavioral agent paused on a background monitor and needed a `SendMessage` kick.

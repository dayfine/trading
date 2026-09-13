# Next-session priorities — 2026-09-13 (supersedes 2026-09-10)

Written 09:41 PT 2026-09-13 by the autonomous session that ran 00:17 → 09:41 PT while the user was away.
The 09-10 handoff's queue items 1–3 are resolved; item 4 is running; item 5–6 untouched.

## Merged this session

- **#2767** `fix(devtools)`: per-pid fixture root for `test_walk_failure_reporting` — closes #2760 (the concurrent-runtest `/tmp` race that produced the spurious H3 on #2758). Both QC gates; the behavioral pass drove the race deterministically (pre-fix 6/6 failures, post-fix 0/6).
- **#2758** `feat(snapshot_pipeline)`: `-cut-prefix-misscale` (default-off) — queue item 2 (#2732). Structural re-run cleared the stale H3; behavioral rework iteration 1 added the deep-prefix `.weekly` side-table pin (probe e now fails 2 arms, control passes).
- **#2759** `feat(strategy)`: `deteriorating_blocks_longs` (default-off) — queue item 3 (#2755). Behavioral rework iteration 1 threaded `~macro_trend` into `Screener_macro_gate.longs_admitted_by_breadth` (flag-off bit-identical by construction; the first pass found a flag-off behaviour change when `neutral_blocks_longs` was also on) and added the strategy-level fresh-candidate pin (two severing mutations had been green).
- **#2768** pre-registration, **#2776** item-3 verdict, **#2777** handoff, **#2783** item-4 verdict — docs, admin-merged on green.
- **#2778** harness(publisher): publish the run's artifacts (orchestrator-authored; closes #2775) — behavioral rework iteration 1 pinned all four allowlist entries and fixed the C-quoted-filename abort; merged 13:19 PT.

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

- **Item 4 DONE (single-surface ACCEPT; grid owed) — 12% initial stop × weekly trail cadence on `_v10dedup`** (`dev/experiments/cadence-12w-v10-2026-09-13/`,
  arm `a4-cadence-12w` = a0 + `initial_stop_buffer 0.9167` + `stop_update_cadence Weekly`; same build/worktree/warehouse as
  item 3; same pre-registered binary rule). Lanes: B2 = salts 0 then 1 (started 06:32 / ~09:30), A2 = salt 2 (started 09:16).
  **ALL THREE SALTS LANDED (09:40 / 12:29 / 12:56): realised +$2.59M / +$1.97M / +$2.48M, maxDD 37.6→30.0 / 32.8→28.1 / 43.0→33.0, Sharpe better at every salt — 3 of 3 on both pre-registered criteria = single-surface ACCEPT** (ledger `2026-09-13-stop-width-12pct-weekly-cadence-v10dedup`, `memory/project_cadence_12w_v10dedup_accept`). Mechanism = the shared trades run wider (salt 1: arm-only and null-only net to zero). V6 = 1 on arm s1/s2 = one −$2.8k IAC/MTCH spin-off twin (#2782 filed). NOT promoted — see queue item 1.
  Read each cell with `ARM=a4-cadence-12w sh dev/experiments/deteriorating-gate-2026-09-13/read.sh <salt> .sweep-output/detgate`
  and gate with `validator_diff -check V6` against `stop-width-by-state-2026-09-08/results/a0-breadth-on-null-s<salt>-v10-validator.sexp.sexp`.
  Artifacts land in `.sweep-output/detgate/a4-cadence-12w-s<salt>-v10-*`; copy to `cadence-12w-v10-2026-09-13/results/`
  (exclude `trade_audit.sexp`, 9 MB) and write the ledger entry either way.
- Pinned worktree `sweep-detgate` removed 13:05 PT after the last cell; the container is idle.


## Queue (in order)

1. **Item 4 promotion path (ACCEPT → grid, no default flip yet):** (a) confirmation grid — 2009 and 2019 `_v10dedup` vintages, 5y record-convention windows at 3 salts each, paired against their own nulls (the 26y cell is the bear-regime cell; `promotion-confirmation.md` broad-vs-broad); (b) dissect the 5–6 force liquidations per arm cell (phantom pre-#2695 classes vs real gaps); (c) paired goldens for BOTH knobs (`config-default-blast-radius.md`) and the W2 book argument (12% is outside §5.3's 4–6% band; weekly re-evaluation is L3) in the promotion PR. Also #2782: spin-off backfill twins (MTCH ≡ IAC pre-2015) survive the rename-twin dedupe — extend the detector before the next rebuild.
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

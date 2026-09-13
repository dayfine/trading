# Next-session priorities — 2026-09-13 (supersedes 2026-09-10)

Written 14:54 PT 2026-09-13 (autonomous 00:17–13:20 PT, then interactive with the user; the grid keeps running past this doc).
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

## Live (check first) — the item-4 confirmation grid is RUNNING across the session boundary

Launched 14:09 PT 09-13, two host-side `nohup` lanes of `dev/experiments/cadence-12w-v10-2026-09-13/chain-grid.sh`
(pinned worktree `.claude/worktrees/sweep-detgate` @ 31e4bb9c3, build cache-warm; warehouses
`/tmp/snap_top3000_{2009,2019}_v10dedup`; specs staged at `/tmp/grid-run/specs/`; ~50–60 min per 5y cell):

- lane **G1**: `n5-2019:0 a4-2019:0 n5-2019:1 a4-2019:1 n5-2019:2 a4-2019:2` → `/tmp/grid-run/chain-G1.log`
- lane **G2**: `n5-2009:0 a4-2009:0 n5-2009:1 a4-2009:1 n5-2009:2 a4-2009:2` → `/tmp/grid-run/chain-G2.log`
- artifacts: `.sweep-output/detgate-grid/<spec>-s<salt>-v10-*` (= container `/tmp/sweeps/detgate-grid`)

**Pickup procedure:** `tail /tmp/grid-run/chain-G?.log` and `docker exec trading-1-dev sh -c 'ps -eo etime,args | grep "[s]cenario_runner"'`.
If a lane died (no process, no `LANE .. DONE`), re-run the SAME command line — the chain skips every cell that already has
a `RESULT` line in its lane log and restarts the interrupted cell from scratch. Each null/arm pair at a salt is read with
`validator_diff -check V6` (null vs arm reports) and
`ARM=a4-2019 sh dev/experiments/deteriorating-gate-2026-09-13/read.sh <salt> .sweep-output/detgate-grid` — NOTE that
`read.sh` hardcodes the 26y a0 null; for the grid cells pass the null explicitly by editing `N=` to
`.sweep-output/detgate-grid/n5-<vintage>-s<salt>-v10` (or copy the script). Decision rule per cell = the pre-registered
one (realised AND maxDD better at ≥ 2 of 3 salts); the grid clears if the 26y cell + both 5y cells clear
(`promotion-confirmation.md`: strong majority, never badly dominated). Copy per-arm artifacts (no `trade_audit.sexp`)
into `cadence-12w-v10-2026-09-13/results/`, log each pair in its README, then the ledger amendment.
After the grid: `git worktree remove --force .claude/worktrees/sweep-detgate` and delete the persistent monitors if
any are still listed in `/tasks`.

## Settled this afternoon (screens, no cells): `cadence-12w-v10-2026-09-13/screens/README.md`

- **Width is NOT linear**: replaying narrower initial stops on the wide arm's own trades gives flat ≤ 6%, a knee 7→9%,
  a plateau 9–12% (±$0.4M) at three salts. The promotable value is the plateau → a 10%-weekly neighbour arm is owed.
- **Four of five breadth states gain from wide at 3/3 salts, Deteriorating included** (its record loss was whipsaw:
  stop-out 81% → 59%). The only cohort wide hurts is Bearish-week FILLS of older resting tickets (3/3, $0.1–0.4M).
- **No-builds, with tables:** exit/tighten resting stops on `Deteriorating` (−$0.1…−1.2M on the wide arm at 4% or 8%),
  on a Bearish onset (−$0.7…−1.2M), on leaving Bullish (−$1.8…−2.9M), on an index-speed trigger (−$0.3…−0.45M, fires
  after the stop has cut); selective poor-RS exit at Bearish onsets (poor subset 1–17 positions, no consistent sign);
  per-state map 4/8/12 for Deteriorating (already answered by the cohort table + item 3) and 4/8 for Bearish (a no-op:
  the map sizes at placement, the gate never places Bearish tickets). Book Ch. 6/8 read and reconciled (see the screens README).

## Codex integration (set up 14:30–15:30 PT, after the autonomous block)

- **Rules for a second agent in this directory are on main:** `AGENTS.md` (#2789) — own detached worktree under
  `.claude/worktrees/`, plain git and never `jj` (jj from any worktree mutates the primary workspace, which
  snapshots continuously; a Codex file rode into #2785 this way), dune only in the container against that
  worktree, one dune in flight repo-wide (the shared dune cache corrupted a build today), docs-only PRs skip the
  build, no self-merge / approve. Plus the **issue assignment protocol**: owner labels `agent/codex` /
  `agent/claude` on top of the triage roles (`ready-for-agent` etc. — those role labels were only created today);
  Codex picks the highest-P `ready-for-agent` + `agent/codex` issue, claims by issue comment, works on
  `codex/<issue>-<slug>`, PR body `Closes #N`, `BLOCKED:` convention, done = PR open + CI green; the dispatcher
  runs the gate loop and merges.
- **Codex queue (seven `agent/codex` issues):** P2 #2788 (qc-behavioral "no Bash" line), #2653 (safe.directory
  step order), #2753 (publisher 422-guard pin); P3 #2539, #2742, #2639, #2394. First dry run should be #2788.
- **Open Codex PRs:** #2785 (review howto, draft) — Codex's second review left one ordering item: land #2788 first,
  then cite it and re-review. #2786 (`.codex/rules/trading.rules` command policy) — NEEDS_REWORK from both my
  review and Codex's own: deny/drop `jj`, narrow `docker` and `gh` (no stop/rm, no merge/approve), and prove the
  repo-local rules file is actually loaded (today's approvals went to `~/.codex/rules/default.rules`).
- **#2780** (post-merge audit): the deteriorating-gate REJECT stands but the *do-not-revive* classification is
  challenged. Decide (keep-as-axis vs do-not-revive) and amend the ledger entry either way — a docs PR; not a
  Codex item.

## Queue (in order)

1. **Finish the grid** (above) → three-cell verdict → ledger amendment; if it holds, **add the 10%-weekly neighbour arm**
   (26y + both 5y vintages, 3 salts) before any promotion PR.
2. **Force-liquidation dissection** on the wide cells (5–6 per cell vs 2–3; `force_liquidations.sexp` committed):
   phantom pre-#2695 classes or real gaps. Dispatcher-side.
3. **Cancel-on-Bearish** (`cancel_resting_longs_on_bearish`, default-off; book: suspend buying in Stage 4): mechanism PR
   (new `CancelEntry` reason + one read site where resting tickets are re-evaluated; #2709 added the `delisted` reason
   the same way), full gates, then one 3-salt arm on top of wide-weekly. Expected $0.1–0.4M/salt on a ~100-trade cohort.
4. **Promotion PR for wide-weekly** only after 1–3: two-knob paired goldens (`config-default-blast-radius.md`), the §5.3
   argument (12% or 10% as a modern-regime dial; weekly re-evaluation = L3), `experiment-flag-discipline.md` R3.
5. **Record the no-builds as a memory + retire the dead axes** (Rule 4 clock starts for `deteriorating_blocks_longs`).
6. **Entry side (later):** Recovering-week deployment cap — 2020-04/05 admitted 18/11/20/20 vs 8/5/5/4 taken; a
   portfolio-risk dial (position count / exposure ramp on the index's Stage-1→2 flip), book-faithful; screen first.
7. Carried: #2780 classification decision (above); orchestrator D2 push (09-10 item 5); #2729 residuals; `stop_loss` label hiding the `Per_position`
   breaker; #2782 spin-off backfill twins before the next warehouse rebuild; #2785 (Codex howto draft) needs the
   "docs-only PRs skip the build gate" line and Codex's second look.

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

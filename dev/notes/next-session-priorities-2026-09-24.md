# Next-session priorities — 2026-09-24 (supersedes 2026-09-23)

Written ~17:55 PT 2026-09-22; **refreshed 08:05 PT 2026-09-23 after lane A finished** (session ran 13:32 PT 09-22 →
08:05 PT 09-23). Main green at `ed1262997`. **Container IDLE** (lane A done 07:36 PT; `sweep-grid` worktree and
`/tmp/grid-run` removed; `/tmp/sweeps/top-n-grid` 83 MB kept). Open PR: **#2931** (results-only, the cell-2 verdict +
ledger amendment) → `dispatch qc-results` when CI is green, `--admin` merge on APPROVED.

## State in one paragraph

**P1 #1 of the 09-23 doc was retracted before running.** The proposed "slot-fill ordering dial (score → RS → volume
ratio)" is `Screener.config.candidate_ranking = Quality` (#1786), REJECTED twice in the 06-29 ledger with a 06-30
noise-floor grid concluding no tiebreak beats unbiased sampling and that the productive direction is capacity /
concentration as a variance reducer — which is exactly #2900's one robust property (tighter salt band). Memory
`feedback_check_ledger_before_proposing_a_dial`; README §"Why this and not P1 #1" in
`dev/experiments/top-n-grid-2026-09-22/`. **P1 #2 (the top-N confirmation grid) was pre-registered (#2917, qc-results
APPROVED) and its sub-window lane launched 17:43 PT.** Harness: #2918 (fastexit selector, #2887 — one rework, one
dash-only CI fix), #2919 (perf FAIL-row visibility, #2891 — one rework), #2920 (local PIT smoke cell, #2896: cap 256
2,629 s vs cap 12,000 480 s, byte-identical) all merged through the three gates. Filed #2921 (tier-4 wrapper passes
`--snapshot-mode`, which `scenario_runner.exe` rejects) and **#2922 (token-usage tracking for Claude + Codex — user
request, design in the issue)**.

## Lane — top-N grid cell 2: DONE 09-23 07:36 PT (12/12 cells, V6 = 0 on all nine pairs)

**Verdict (pre-registered dispersion rule, README §Verdict, PR #2931):** null ranges 80.9 pp / 4.9 pt (means 32.1 % /
Calmar 0.084). Cap 40: 37.4 pp / 3.3 pt, means 63.9 % / 0.160 → **tightens, not dominated → 2 of 3 grid cells reached
(26y + sub-window); cell 3 pending; default stays 20, no promotion PR.** Cap 30: 109.7 pp → does not tighten. Cap 60:
66.9 pp / 2.1 pt but means 21.6 % / 0.050 and the maxDD band above the null (47.9–50.0 vs 43.4–48.3) → tightens AND
dominated — the dial is bounded above (cap 60 s2 arm-only 99 trades −$335 k = stale breadth). ADMA 2023-12-19 tops
the arm-only cohort at cap 40 on all three salts, at 30/60 on one salt each. Ledger `2026-09-22-top-of-funnel-capacity`
amended in place. Memory `project_top_n_grid_lane_2026_09_22`. The paragraphs below are the launch-time record.

### Launch-time record (superseded by the verdict above)

`EXPECT_HEAD=ad5a9e04e sh /tmp/grid-run/chain-grid.sh A a0-pit-null-sub:{0,1,2} t1-topn-40-sub:{0,1,2} t1-topn-30-sub:{0,1,2}
t1-topn-60-sub:{0,1,2}` from `sweep-grid` @ `ad5a9e04e` (cell 1's exact build; runner md5 `683b4885…`), cap 12,000,
guard 14,400 s. Log `/tmp/grid-run/chain-A.log` (`RESULT <tag> => …` per cell), artifacts `/tmp/sweeps/top-n-grid/`
(container). Projection ~80 min/cell → null+40 done ~01:40 PT 09-23, all 12 ~10:00 PT; **re-size the guard from the
first cell's wall (≥ 1.5×) if a later relaunch is needed** — the chain is resumable (RESULT line = SKIP).

Read per the README §Decision rule: per value, the 3-salt ranges of realised return AND maxDD vs the null's; "tightens"
= both narrower; promote-eligible only at ≥ 2 of 3 grid cells (cell 1 = 26y, cap 40 tightens) and never dominated
(lower mean realised AND lower mean Calmar). Per-salt cohort read: `sh paired.sh <null-trades.csv> <arm-trades.csv>`.
V6 diff exit 0 required per pair (`<tag>.v6diff.log` in the artifact dir once #2923 merges — the running chain copy
already does this). Commit per-cell raw artifacts to `results/` (`feedback_commit_raw_per_arm_artifacts`), the writeup
as an AMENDMENT to `_ledger/2026-09-22-top-of-funnel-capacity.sexp` (no new ACCEPT), then remove the worktree
(`git worktree remove --force .claude/worktrees/sweep-grid`) and `/tmp/grid-run`. Results PR = results-only lane.

**Cell 3 (top-1000 schedule) is not runnable yet:** yearly `top-1000-YYYY.sexp` exist under
`trading/test_data/goldens-custom-universe/composition/`, but the pit-v11 top-3000 lists drop ~333 names/year that are
absent from the warehouse (2019: 58 of the top-1000). Build step: per year, goldens top-1000 ∩ pit-v11 top-3000 symbol
set (lists are sorted by `avg_dollar_volume` desc, 0 violations), re-weighted; then a `universe_schedule` of those.

## P0 — nothing blocking.

## P1 — next work, in order

1. **Merge #2931** (qc-results, no dune), then **build and run grid cell 3** — the confirmation for cap 40: per year,
   goldens `top-1000-YYYY.sexp` ∩ pit-v11 `top-3000-YYYY.sexp` symbol set (lists sorted by `avg_dollar_volume` desc),
   re-weighted 1/N, written as `pit-v11/composition/top-1000-YYYY.sexp` + a `universe_schedule` spec on the 26y window
   (same build `ad5a9e04e` or a fresh pin with a tripwire), null + cap 40 × 3 salts first (30/60 optional, both lost
   cell 2). Pre-register the cell in the same README before launching. Cells should run faster than the top-3000
   ones (fewer members; the union warehouse is unchanged). If cap 40 tightens cell 3 without domination → the
   paired-golden table (`config-default-blast-radius.md`) and a promotion PR citing the README + ledger amendment.
2. **#2922 token-usage tracking** (user request 09-22): `dev/scripts/token_usage_report.sh` over the local transcripts
   (`message.usage`, the 09-08 audit's jq as seed) + `codex exec --json` usage probe + `dev/budget/local-<date>.json`
   sink + a weekly §Usage review. The 09-22 numbers in the issue are the first dataset (≈ 2.4 M subagent tokens for
   three shell-only PRs; stall→resume replays and QC tree rebuilds dominate). Harness-maintainer, after the lane.
3. **Perf weekly** (`perf-review-weekly.md`, Monday 09-28): read the `perf-weekly` table — the 15y sp500 cells should
   read ~364–408 s post-#2894; FAIL rows now surface as annotations (#2919) with artifacts; **close #2895 on PASS**; run
   `dev/scripts/perf_pit_smoke.sh` (#2920) and log both in `dev/status/backtest-perf.md`.
4. **#2921** tier-4 wrapper `--snapshot-mode` (size S, harness) and **#2876** file-length linter scope (two-parter,
   judgement on nine files) — Codex candidates.
5. **#2915** (SPY bars end 2026-05-01) — queued for Codex, unchanged.

## Ops notes — read these

- **Agent stalls, 5 of 7 dispatches today** (`feedback_agents_background_wait_stall` 09-22 entry): briefs that
  prohibit waiting are not enough; put the poll recipe in ("block on the container pid with a foreground
  `while kill -0 <pid>; do sleep 30; done`"), tell agents the dune lock is per-worktree, and take over from the
  dispatcher side after the second stall (verify gates in the agent worktree → commit → push → PR). #2891 was finished
  that way; #2896 finished itself on the third nudge. Two wedged dunes (0 % CPU for 24 min and 1.5 h) and one orphan
  `dune runtest` in the PARENT tree (ppid 0) were killed — check `pgrep -x dune` + `/proc/<pid>/cwd` when
  `docker stats` looks high with nothing dispatched.
- **Dash-only defects:** #2918 went red on GNU `stat -f %m` succeeding with filesystem output; #2919's guard grepped a
  comment. Verify shell findings under `dash` in the container before posting (`feedback_qc_false_positive_needs_tip_move`).
- **Disk:** host free 54 G → 15 G in one session from ~12 agent worktrees with builds; Docker.raw unchanged (31 G); the
  space was in 22 Time Machine local snapshots. `tmutil thinlocalsnapshots / 40000000000 3` → 64 G in seconds. Check
  before every chain launch (`feedback_tm_local_snapshots_pin_deleted_worktrees`).
- **BEHIND-main merges:** every PR today was BEHIND by disjoint files after the first merge; plain `--squash` is
  refused, `--admin` used with all three gates green at the tip (`feedback_admin_merge_qc_comment_prs`). Codex sampling
  (`codex_review.sh`) was NOT run on today's merges — no `review/codex-*` label, and the NEXT-ACTION showed no advisory
  hint; the A/B row (`codex_agreement_row.sh`) therefore has no new rows.
- **Open PR #2923** (results-only: chain tripwire + launch log) → `dispatch qc-results` when CI is green; `--admin`
  merge on APPROVED (it will be BEHIND).
- **jj working copy:** `@` is a fresh commit on `main@origin` after this doc; the chain-tweak commit is on
  `exp/top-n-grid-chain-launch` (#2923). Two stale bookmarks `harness/2887-…`, `harness/2891-…`, `harness/2896-…`
  were created by jj's git import of agent branches (all merged/deleted on origin) — `jj bookmark forget` them if noisy.

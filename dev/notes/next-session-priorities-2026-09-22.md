# Next-session priorities — 2026-09-22 (supersedes 2026-09-21)

Written 13:40 PT 2026-09-21 mid-session, after the QC wave cleared and the chain launched. Main green. **Container is
NOT free: chain lane A (top-of-funnel) is running since 13:25 PT, ~16 h → done ≈ 05:30 PT 2026-09-22.** No agent
dispatches, no builds in the container until `LANE A DONE` appears in `/tmp/funnel-run/chain-A.log`
(`container-capacity-scheduling.md` rule 1). Open PR: **#2900** (`exp/top-of-funnel-results`, `.sh` + README → full
three gates; QC waits for the container).

## State in one paragraph

Three merges today. **#2894** — the first real weekly perf review found that every perf tier script omitted
`--no-emit-all-eligible`, so the opt-out all-eligible diagnostic ran inside every tier cell (and inside the measured
wall since #2616): the tier-3 15y cells read 4,738 s / 716 MB vs 364 s / 550 MB on the daily golden path with the same
binary, ~92 % diagnostic; the 3,600 s band FAILed on it for three weeks with no readable cause (no artefacts). Fixed in
all five scripts, artefact upload added to `perf-nightly.yml` / `perf-weekly.yml`, and tier-3 discovery now includes
`goldens-custom-universe-scenarios` (broad top-3000 / top-500 5y cells). Tickets #2895 (FAIL rows, close when next
weekly PASSes), #2896 (PIT-warehouse smoke cell, local-only), #2899 (devtools check pinning the flag — LINTER_CANDIDATE
from QC). **#2897** — pre-registered the top-N capacity arm `t1-topn-40` (`screening_config.max_buy_candidates` 20→40,
3 salts vs the PIT null band) plus `d0-funnel-diag` (null s0 with `--emit-candidates`, trades md5 tripwire
`c1352be6…`); rationale: the 26y funnel kills 36 % of monsters at the top-N cut, ranking has no skill, and every
faithful breakout-gate *width* dial is already a settled REJECT, so capacity is the one open top-of-funnel lever.
**#2889** — weekly deps snapshot (uucp/uuseg 18). Memory: `project_perf_tiers_timed_all_eligible_diagnostic`,
`project_top_of_funnel_arm_in_flight`.

## P0 — read lane A (`dev/experiments/top-of-funnel-2026-09-21/`)

1. `cat /tmp/funnel-run/chain-A.log` — four `RESULT` lines expected (`d0-funnel-diag-s0-v11`, `t1-topn-40-s{0,1,2}-v11`),
   each with `v6diff:exit=0`, peak RSS and the cache line. **d0 must read `tripwire:MATCH`**; a MISMATCH means build
   drift 3a20f4987 → ad5a9e04e (#2888 telemetry is the suspect) — stop, dissect, do not read the arm.
2. If the lane is still running: dispatcher-side work only (steps 3–4 can be prepared, not run in the container).
3. Archive per cell: copy `/tmp/sweeps/top-of-funnel/<tag>-{actual.sexp,trades.csv,params.sexp,summary.sexp,
   trade_audit.sexp,open_positions.csv,force_liquidations.sexp,equity_curve.csv,macro_trend.sexp,validator.sexp.*,
   .rss,.log}` into `results/` (**not** `candidates.sexp`, ~500 MB — derive from it instead). The README's §Log gets
   one line per cell (`feedback_commit_raw_per_arm_artifacts`: numbers from `actual.sexp`, never the chain line).
4. Reads, in order: (a) d0 → the PIT-band funnel decomposition per year — counts by `outcome` and by `breakout_gate`
   sub-reason, and the share of screening weeks with `Dropped_at_top_n > 0` (cap-bound weeks); write it as
   `results/d0-funnel-decomposition.md` (awk over `candidates.sexp` in the container; no Python). (b) per salt
   `sh paired.sh <null-trades> <arm-trades>`; the pre-registered rule (realised AND Calmar at ≥ 2/3 salts) and the
   arm-only cohort by entry-year (≥ 80 % losers every salt ⇒ stale-entry breadth ⇒ REJECT with that why). (c) ledger
   `dev/experiments/_ledger/2026-09-2x-top-of-funnel-capacity.sexp` (baseline `record-pit-null-v11pit`, window
   `top3000-pit-1999-2025-record-26y-3salt`), README §Verdict, memory update. Second commit on **#2900**, then the
   three gates.
5. After archiving: `git worktree remove --force .claude/worktrees/sweep-funnel`; `rm -rf /tmp/funnel-run` on the host
   and in the container (`docker exec trading-1-dev rm -rf /tmp/funnel-run`).

## P1 — after P0 (container free)

1. **#2900 QC** (structural → behavioral → merge) — it is the results PR, so it goes through once P0's second commit is on it.
2. **Perf follow-through:** read the 05:00 UTC `perf-nightly` table (first run with the flag) — expect ~10× lower walls
   and ~25 % lower RSS on every non-trivial cell; log two lines in `dev/status/backtest-perf.md` §Weekly review and
   cite #2895/#2896 there (the merged entry predates the tickets by a minute). Treat golden-path walls as a band
   (88–145 s on the same SHA in one day). Close #2895 after Monday's `perf-weekly` shows both 15y cells PASS.
3. **#2899** (devtools check pinning `--no-emit-all-eligible` on the six scripts) — size S, feat-backtest or
   harness-maintainer; fixture-driven RED/GREEN like `gnu_time_rss_smoke.sh`.
4. **#2896** PIT-warehouse smoke cell (local, snapshot mode, cap 256 vs 12,000) — the one workload shape no tier
   times; pairs with the weekly review.
5. **PIT warehouse rebuild with #2862's twin guards** (`-twin-require-direct-match -twin-max-group-size 4`) — operational,
   container-exclusive (hours); the record band stays on `_v11pit` until a rebuild is paired.
6. **Veto follow-on only if asked:** faster re-admission keyed off MA *levelling* (book §2.1 "Resolved 2026-09-16"),
   never a close above a still-falling MA.

## Codex queue

Nothing `ready-for-agent` for Codex. Candidate unchanged: `build_snapshots -twin-only`.

## Ops notes

- **Chain hygiene held today:** specs + chain script staged under `/tmp/funnel-run/` (outside VCS), pinned worktree
  `sweep-funnel` @ `ad5a9e04e`, `CELL_TIMEOUT=60000` sized from the measured veto arm, GNU-time peak RSS per cell.
- `jj new` produced a commit with an **empty committer** twice today (push refused: "no author and/or committer set");
  `jj describe --reset-author --no-edit` fixes it. Cause not chased — likely the git-import race with agent worktrees.
- Under zsh, `echo ====` fails (`=foo` is equals-expansion) — use `echo '---'` in one-liners.
- QC agents at 3 concurrent pushed the container to 5.6 GB; fine with no backtest, never with one.
- Full local `dune runtest` needs `TRADING_DATA_DIR=$PWD/test_data`; 58 stale `worktree-agent-*` git branches were
  pruned to 0 today as agents finished. Host free ~33 GB; Docker.raw 30 G.

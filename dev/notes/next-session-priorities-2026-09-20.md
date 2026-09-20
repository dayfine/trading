# Next-session priorities — 2026-09-20 (supersedes 2026-09-17)

Written 02:45 PT 2026-09-20 mid-session (the 09-16 → 09-20 session: rate-limit gap 09-16 19:35 → 09-20 00:00).

**Read the 15:00 PT addendum at the bottom FIRST** — it supersedes the timing line in Step 0 (salt 0 landed 11:08, 8h33m), carries the salt-0 read and the resume protocol, and inserts #2878 → #2839 (snapshot-cache tracking, then the handle-cap knob) ahead of the P1 list.
Main `b6696f84b`, green. **A backtest chain is LIVE in the container** — read §Ops before dispatching anything.

## State in one paragraph

The index-stage veto (P0 #1 of the 09-17 doc) went from book check to running arm in one session: tier-2 answer
written back to `weinstein-book-reference.md` §2.1 (#2861 + the §2.1 bullet fix in #2870 — Stage 4 = unconditional
buying suspension, Stage 3 = caution only); mechanism `index_stage_veto_blocks_longs` merged default-off (#2863, two
commits — the rework pins the fresh-candidate wiring after qc-behavioral proved the M2/M3 mutations survived); #2823
twin-detector guards merged default-off (#2862). The pre-registered arm `v1-index-veto` (README + spec + chain on
branch `exp/index-stage-veto`, pushed before any cell ran) is running: lane A, salts 0 → 1 → 2, ~6.3 h each, on the
pinned worktree `sweep-veto` @ `5577d418a`, pairing against the committed `a0-pit-null-s{0,1,2}-v11`.

## Step 0 — the chain (`/tmp/veto-run/launch-A.log`; artifacts `/tmp/sweeps/index-veto/` = host `.sweep-output/index-veto/`)

- Started 02:34 PT 09-20. Expected: s0 ≈ 09:00, s1 ≈ 15:30, s2 ≈ 22:00 PT (single worker, 5.5–6.5 GB).
- Per cell as it lands (`RESULT <tag> => …` line, but **read numbers from the artifacts, never the log**):
  1. copy `/tmp/sweeps/index-veto/<tag>-{actual,summary,params,force_liquidations}.sexp`, `-trades.csv`,
     `-open_positions.csv`, `-validator.sexp.{sexp,md}` into `dev/experiments/index-stage-veto-2026-09-16/results/`
     (branch `exp/index-stage-veto`), keep `equity_curve.csv` / `macro_trend.sexp` / `trade_audit.sexp` on the host;
  2. `validator_diff -check V6` exit 0 (the chain prints `v6diff:exit=N`; re-run by hand if unclear);
  3. `sh dev/experiments/index-stage-veto-2026-09-16/paired.sh <null-trades.csv> <arm-trades.csv>` — shared /
     null-only / arm-only, per-year, the four re-entry episodes, the 2022 cohort removed; append to README §Log.
- Decision rule (pre-registered): realised AND Calmar better than the null at ≥ 2 of 3 salts → ACCEPT(mechanism)
  on this base (promotion still needs the grid + paired goldens); else REJECT-as-default, flag stays an axis unless
  the mechanism read says do-not-revive. The mechanism read is the paired 2022 cohort AND the 2003 / 2009 / 2020
  re-entry episodes (a 2022 win bought with a slower 2009 / 2020 re-entry is the fat-tail tax).
- Close-out: ledger entry `dev/experiments/_ledger/2026-09-2x-index-stage-veto.sexp` (+ `index.sexp`), README
  §Verdict, memory `project_index_stage_veto_verdict`, PR from `exp/index-stage-veto` (code-free but not docs-only:
  `.sh`/`.sexp` — full three gates), then `git worktree remove --force .claude/worktrees/sweep-veto`.

## P1 — after the verdict

1. **#2839 PIT cell cost** — bit-identical only; profile first (the 1999 warmup year alone is ~18 min of weekly
   classification over 9,915 symbols; membership pruning rejected 09-15).
2. **Top-of-funnel screen** (breakout-gate width, top-N) — read with the 2022–25 regime in mind (≥ +20 % winners
   fell 10 % → 2 %).
3. **PIT warehouse rebuild with #2862's guards armed** (`-twin-require-direct-match -twin-max-group-size 4`) — a
   separate operational step; the record band stays on the current `_v11pit` until a rebuild is paired.

## Codex queue

Nothing `ready-for-agent` for Codex at write time; #2823 closed by #2862. Candidate: the `-twin-only` (closes-only)
mode of `build_snapshots` (`memory/project_pit_chunked_twin_miss`).

## Ops notes

- **Container-exclusive while the chain runs** — no agent dispatches, no `dune` in the parent tree
  (`container-capacity-scheduling.md` rule 1). Dispatcher-side work only. A Monitor on the launch log fires per
  `RESULT` / `ABORT` / `LANE A DONE` line in the live session; after a `/clear`, poll the log instead.
- Cold `dune build` through a foreground `docker exec` that the harness backgrounds at 600 s HANGS (futex, 0 % CPU)
  — launch long container jobs detached (`docker exec -d … nohup … ; echo exit=$? >> log`) and poll the log
  (`memory/feedback_backgrounded_docker_build_hangs`).
- `gh pr merge` from the repo root fails on the detached jj checkout ("not on any branch") — run it from `/tmp`
  with `--repo dayfine/trading --admin` (QC verdicts are COMMENTED reviews; branch protection needs `--admin`).
- The weekly rate limit reset 09-20 00:00 PT; a subagent killed mid-task leaves its work in
  `.claude/worktrees/agent-*` — the #2863 rework was recovered from disk, verified and pushed dispatcher-side.
- Codex worktrees under `.claude/worktrees/codex-*` are Codex's to remove; leave them. `sweep-pit` (null build)
  can go once the veto arm has paired cleanly against the committed null artifacts.

## Addendum 15:00 PT 2026-09-20 (session wrapped here; chain keeps running)

- **Salt 0 landed 11:08 PT** (wall 8h33m): level 457.0 → 344.7, realised $3.85M → $2.77M (**fails**), maxDD 40.6 → 33.5,
  Calmar 0.165 → 0.173 (**clears**). Join: trade-identical 2000 → 2018-11; 2022 cohort 19 entries removed, −$818k →
  −$282k (the predicted save); 2020 re-entry cost ≈ nil (10 blocked entries net −$3k) but the 2020 monster funding
  diverged (−$516k, lottery); 2025 −$1.15M is ECHO skipped `Insufficient_cash` (not the veto). MTM: the maxDD gain is
  half a lower peak ($5.32M vs $5.94M; same $3.54M trough on 2023-10-27), half real 2022–24 protection (+$0.48M at the
  null's 2024-08 trough). Full read: `dev/experiments/index-stage-veto-2026-09-16/README.md` §Log (branch
  `exp/index-stage-veto`, pushed; `results/v1-index-veto-s0-v11-*` committed; `paired.sh` recovered and committed).
- **Salt 1 started 11:07 PT**, salt 2 follows (~6–8.5 h each). Artifacts land in `.sweep-output/index-veto/` (host)
  regardless of the session; the Monitor dies with the session, so on resume: `tail /tmp/veto-run/launch-A.log`, then
  per cell copy the eight artifacts into `results/`, check `v6diff:exit=0`, run `paired.sh` vs
  `pit-universe-2026-09-14/step4/results/a0-pit-null-s<salt>-v11-trades.csv`, append the read. Verdict after salt 2 by
  the pre-registered rule; judge Calmar on the peak/trough decomposition, not the ratio.
- **Runtime finding (README §"Runtime read", #2839 comments, memory `project_snapshot_cache_handle_cap_thrash`):**
  every 26y cell re-decodes each symbol ~450×/sim-year because the v2 warehouse binds on the hard-coded 256 mmap-handle
  cap in `daily_panels.ml`, not on `SNAPSHOT_CACHE_MB`. Misses identical on null and arm; wall variance is per-miss cost.
  **Order after the lane: #2878 (occupancy/heap tracking, `ready-for-agent`) → #2839 knob `SNAPSHOT_MAX_MMAP_HANDLES`
  ≥ n_symbols → smoke at 256 vs 12,000 → chain default.** Both bit-identical; both need the container, so after salt 2.
- Keep `.claude/worktrees/sweep-veto` until the lane is done and the results PR is open; `sweep-pit` can go now that the
  arm pairs cleanly against the committed null artifacts (V6 diff exit 0 at salt 0).

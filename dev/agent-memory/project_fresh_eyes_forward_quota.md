---
name: project_fresh_eyes_forward_quota
description: Fresh-eyes forward pass drained the WEEKLY quota at ~$424 (24 of 100 symbols, paused 10-18); user said work with what we have; reading in PR #3317 (stage starts at MA turn vs book range break)
metadata:
  type: project
---
Forward pass (`dev/experiments/fresh-eyes-2026-10-13/scripts/forward.sh`, branch experiment/fresh-eyes-forward 5f86d1af6, worktree .claude/worktrees/fe-forward) ran 10-14 05:16Z to 10-17; hit the seven_day plan limit 10-17 04:04Z. State at pause (10-18 00:05 PT): 24 symbols done (4,645 calls), 36 partial (752 calls), 40 not started, $424 notional, 238 trade rows. 32 symbols exited 6 ("still limited after 24 pauses"), state kept; restartable per symbol.

**Why:** a full 100-symbol pass ≈ 3+ weeks of the user's entire weekly quota, which also blocks every other session. Paused by the dispatcher, no user decision yet.

**How to apply:** do not relaunch at 4 jobs unasked. Options parked for the user: analyse the 24 done (+ finish 36 partials), throttle to 1 job, or cut checkpoints/cadence. See [[feedback_autonomous_take_recommended]].

**Reading (PR #3317, 10-18, 24 symbols):** stage agreement 65.9 % (reader self-agreement 96 %): our Stage 2/4 start at the MA turn, a median 8/5 weeks before a book reader's range break; a replica of our classifier with SMA ±1 % + a range break reaches 75 %. A documented dial plus a definition gap, not a bug. Reader trades: no edge (long mean +1.3 % excess = one open VIAV trade; median −6.2 %); shorts consistent with the #3286 no-build (one unreplicated draw). The 13 sample names that reached our weekly top-20 were all skipped as No_structural_stop (53 decision-list entries per salt), never cash — see [[project_recovery_reentry_gap]]. Next options parked for the user (11:00 batch).

**User decision 2026-10-18 11:00: STOP at the reading.** No further model runs (no staged pilot). Free follow-ups only: add the 8 partial symbols from state already paid for, replay our screener on the 24 for admissibility, fix compare.sh's week join, and a doc note (stage.mli / reference §1) that our classifier stage starts at the MA turn and the breakout is checked separately. Any future resume uses the staged plan plus pilot (batch-model-run skill).

**Redirect 2026-10-18 (user, after the stop decision):** next step is DATED PICKS, not a full simulation: 24 stratified dates 2000–2024; the reader picks on each date (market → groups → contact sheets → close look, with our top 20 blinded into the pool) and manages to the exit, capped at 2 y; compared with the record's picks and handling, including the 2×2 picks × management cells. Plan PR #3326; pilot $6–10, full $75–115.

**Dated picks done 10-18 (#3328):** 32 date-runs, 928 calls, $65.74; the reading found no gap, and the 0 shared trades are explained by the floor scan ([[project_fresh_eyes_dated_picks]]).

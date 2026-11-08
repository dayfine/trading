# Track Pacer Report — 2026-11-08

## Summary
- Tracks audited: 50 index rows. Cadence was run on the 25 non-MERGED rows (24 IN_PROGRESS, plus `tuning-methods`, which is PENDING). The 25 MERGED rows are exempt. No row changed status this week.
- Active (≥1 PR last 7d): 8
- Slowing (7–30d since last PR): 5
- Stalled (>30d): 12. `arc-readiness` moved from slowing to stalled. `post-run-validation` came back to active (#3500).
- `[info]` items needing decision: 6, each carried 6 or more reconciles. 2 were resolved this week (#3500 rework, #3512 merge).
- Capability gaps flagged: 9 (1 new, 8 carried). 2 resolved.

**Headline 1: throughput fell, and the work went into making backtests run in the cloud.**
- 51 PRs merged 11-01 → 11-08 (`21461890..8ee1ed79`), down from 70 the week before.
- 18 of the 51 are `ops` (daily summaries, budget records, health scan, sweep). That leaves 33 PRs of real work.
- The largest programme was **#3477 / #3476 / #3535, resumable backtests on the cloud**:
  - PRs 5–7 of #3477: #3504, #3517, #3521.
  - Follow-ups: #3524, #3529, #3536.
  - R2 bar and warehouse transport: #3499, #3539, #3540, #3542, #3543.
  - Warehouse path fix: #3547, merged 11-08.
- #3476 closed 11-05: a 26y kill-and-resume on the cloud matched all four artifacts (handoff 11-05).
- Orchestrator spend 11-01 → 11-07 was 14 runs, **$108.43**, against $95.30. One run (11-04, `41858023237`) cost $40.28.

**Headline 2: a new correctness cluster, split basis, now has a measured cost. It has no owner.**
- The split corpus (#2973: #3527, #3530, #3545) registered **5 open `guard none` findings** in `dev/findings/registry.sexp`. In each, raw and split-adjusted prices are mixed:
  - the prior-base scan is blind after an ex-date;
  - the split-week weekly bar mixes bases;
  - the resistance/support grade reads raw highs across a split;
  - the MA-fallback entry anchor reads the adjusted MA;
  - intraday path noise is in absolute dollars.
- The decision walkthrough #3546 (11-07) found that the trailing stop's MA term reads the adjusted basis against raw prices (#2982). That mix decides **390 of 550 (71 %)** of stalled ratchet cycles.
  - The first-order same-basis fix costs **16–22 % of realised P&L in all five record seeds**, carried by the shared monsters.
  - #2982's fix exists only behind a flag (`status fixed-behind-flag`).
- The daily summaries asked where to file the #3527 findings in **6 consecutive reconciles** (11-04 → 11-06-run2). Nothing has been decided.

**Headline 3: last week's docs-reconcile recommendation was mostly done, by the orchestrator, on 11-01.**
- `a3db9887` (#3496) cleared every item named in last week's recommendation 3 except the four listed below:
  - all five stale `screener.md` tokens;
  - the `tax-lens` and `post-run-validation` heading mismatches;
  - the `backtest-infra` and `backtest-perf` index rows;
  - a #3477 booking in `simulation.md`.
- Correction to last week's report: #2503's differential landed as **#2507** (`90455866`), not #2505.
- Still open:
  - `rename-twin-dedup` (close it);
  - `support-floor-stops` ("next: UNSET");
  - the `short-side-strategy` index row;
  - `simulation.md`, which has fallen behind again (P2).

## Active tracks (≥1 PR last 7d)
- **simulation** — 12 PRs: #3504, #3517, #3521 (#3477 PRs 5–7); #3524, #3529 (checkpoint follow-ups); #3536 (halt exit 75 reported as HALTED, closes #3534); #3512 (stop trigger float-noise epsilon, an A1 change to `engine/lib` and `base/lib`); and #3539, #3540, #3542, #3543, #3547 (R2 warehouse push/pull and the #3535 path fix, booked to this row by the index).
  - Theme: resumable backtests, then making cloud backtests the default.
- **harness** — 2 PRs of its own: #3501 (`cleanup_merged_worktrees.sh` keeps locked worktrees) and #3508 (SessionStart brief and PreCompact hooks). The four `harness(r2)` PRs are counted under simulation.
- **data-foundations** — 2 PRs: #3499 (`r2_bars.sh`, bar store to and from R2, #3476) and #3510 (uppercase shard letters, #3506).
- **backtest-infra** — 3 PRs: #3495, #3497 (stream `trades.csv` from `backtest_runner.exe` and pin the wiring) and #3503 (skip stop-closed positions in force-liquidation, plus a review-pack fill-vs-open detector, #3424).
- **trade-audit** — 1 PR: #3526 (cancel pair carried as one value, R1 of #2357). `trade-audit.md` was refreshed 11-04.
- **short-side-strategy** — 1 PR: #3502 (laggard rotation: split-adjusted returns and streak clear, both default-off; closes #3426). The file was refreshed 11-02.
- **post-run-validation** — 1 PR: #3500 (V12/V13 basis and delisting defects, budgeted cash rejection, #3420). It took one extra rework decision (11-02 summary Q1).
- **backtest-perf** — 1 PR: #3520 (weekly perf and issue review, 11-02).

**Exempt rows with work this week:**
- `decision-audit` (MERGED): #3546, the decision-tree walkthrough on the record seed k0.
- `cost-tracking` (MERGED): #3518 (cloud runs added to the usage review) and #3519 (local budget record).

## Slowing tracks (7–30d since last PR)
- **screener** — last PR #3478 was 10 days ago (10-29); theme: seed-band pins for the tier-4 goldens. Its next step, the top-of-funnel screen, is LOCAL. Recommendation: KEEP_AS_INFO.
- **cleanup** — last PR #3458 was 11 days ago (10-28); theme: test pins. The only remaining item, the `linter_coverage` policy, is decision-gated (P3). Recommendation: ESCALATE_TO_MAINTAINER, via P3.
- **rename-twin-dedup** — last PR #3490 was 8 days ago (10-31); theme: registry row for the pit-v12 twins. The work is done (#3475, #3480, #3489, #3490), and the orchestrator asked to close the track in 10 reconciles. Recommendation: ESCALATE_TO_MAINTAINER (close it).
- **support-floor-stops** — last PR #3446 was 13 days ago (10-26); theme: floor-nearest SM, LIVE but INCONCLUSIVE. The index row still reads "next: UNSET". Recommendation: KEEP_AS_INFO, and fix the row.
- **orchestrator-automation** — last booked PR #3226 was 30 days ago (10-09). The file is dated 09-04. Orchestrator-process work lands as `harness:` PRs or as daily-summary questions instead. **It stalls next week.** Recommendation: KEEP_AS_INFO.

## Stalled tracks (>30d since last PR)
- **arc-readiness [NEW]** — last PR #3142 at 2026-10-05 (34 days); reason: A2-4 (picks chart) was never dispatched, and the file is dated 09-26. Recommendation: ESCALATE_TO_MAINTAINER; decide whether A2-4 is still wanted.
- **weekly-snapshot** — last PR #2453 at 2026-08-20 (80 days); reason: the M6.4-class split work now lands under #2973 with no track. Recommendation: ESCALATE_TO_MAINTAINER (9th ask; see P7 gap 1).
- **stage-accuracy** — last PR #2450 at 2026-08-20 (80 days); reason: the broad-universe WF-CV is data-gated and needs K ≥ 5. Recommendation: KEEP_AS_INFO.
- **resistance-v2** — last PR #2145 at 2026-07-28 (103 days); reason: WF-CV vs w30 is LOCAL. #3527 now adds a resistance-grade basis defect (122 of 168 post-split decisions differ). Recommendation: ESCALATE_TO_MAINTAINER (13th cycle).
- **tuning** — last PR #2113 at 2026-07-27 (104 days); reason: the M2 enable-commit (#1327, filed 2026-05-26, **166 days** ago). Recommendation: ESCALATE_TO_MAINTAINER (16th ask).
- **extension-stop** — last PR #1960 at 2026-07-14 (117 days); reason: the R3 flip is human-gated. Recommendation: KEEP_AS_INFO.
- **floor-quality** — last PR #1913 at 2026-07-10 (121 days); reason: deep-warehouse, LOCAL. Recommendation: KEEP_AS_INFO.
- **rolling-start-lens** — last PR ~#1648 at 2026-06-18 (143 days); reason: LOCAL / data-gated. Recommendation: KEEP_AS_INFO.
- **cash-floor-correctness** — last PR #1582 at 2026-06-14 (147 days); reason: NS2 is human-gated and NS4 is data-gated. Recommendation: KEEP_AS_INFO.
- **sweep-perf** — last PR #1574 at 2026-06-13 (148 days); reason: the manual ghcr.io flambda rebuild. Recommendation: ESCALATE_TO_MAINTAINER (15th ask).
- **spy-only-reference** — last PR #1438 at 2026-06-03 (158 days); reason: item 1 is an open question that was never dispatched. Recommendation: ESCALATE_TO_MAINTAINER (9th ask), to close or re-home.
- **tuning-methods** (PENDING) — no PR ever; file last updated 2026-05-24 (168 days). Recommendation: ESCALATE_TO_MAINTAINER (9th ask), to close or re-scope.

## Next Steps staleness (P2)
- **simulation [NEW this cycle]** — dated 11-02. Its last entry says "Remaining: PRs 5–6 … then `scenario_runner --checkpoint-every N / --resume`". All of that has merged: #3504, #3517, #3521, #3524, #3529, #3536.
  - #3476 and #3477 are closed (handoff 11-05).
  - The R2 warehouse work (#3539–#3543, #3547) is not booked.
  - The index row (11-06) is current; the file is not. Recommend refreshing the status file.
- **backtest-infra** — the first Next Step is "[2026-09-14] PIT top-3000 universe migration — in flight locally … four-chunk build running". The index header records steps 1–6 as merged (#2808, #2809, #2816, #2843, #2846).
  - The file was touched 11-01 (#3495, #3497), but the list was not reconciled.
  - Recommend refreshing it.
- **data-foundations** — the first Next Step is "the paired 26y read … runs after merge". It ran and was read in #3489 (10-31). #3499 and #3510 are not booked.
- **rename-twin-dedup** — dated 09-16, and its first step was overtaken by #3475, #3480 and #3489. 6th cycle. Asked in 10 reconciles.
- **support-floor-stops** — dated 10-02. The index row reads "next: UNSET" (7th cycle). Floor-nearest SN/SM (#3423, #3446) are not recorded.
- **short-side-strategy (index row only)** — the file was refreshed 11-02, and its next step is now "paired off/on surface on the record preset" (#3502). The index row still reads "next: short-leg regime-P&L decomposition (LOCAL)", which was overtaken by #3265–#3294.
- **post-run-validation** — the index row cites #3500. The file does not, and its status comment still names `Series_level` arming as the only open item.
- **backtest-perf** — the file header is still `Last updated: 2026-09-22`, though §Weekly review has 10-29 and 11-02 entries.

Carried unchanged, with files untouched for 30+ days: `cash-floor-correctness`, `tuning`, `extension-stop`, `tuning-methods`, `spy-only-reference`, `weekly-snapshot`, `floor-quality`, `rolling-start-lens`, `sweep-perf`, `stage-accuracy`, `orchestrator-automation`, `arc-readiness`, `resistance-v2`.

**Resolved since last cycle (orchestrator reconcile `a3db9887`, 11-01):**
- `screener.md`: all five stale tokens. #3425, #2685, #2563 and #3067 are now marked MERGED, and the #2503 entry is marked MERGED as #2507.
- The `tax-lens` and `post-run-validation` headings.
- The `backtest-infra` and `backtest-perf` index rows.
- #3477 booked in `simulation.md`.

## [info] items needing decision (P3)

`_index.md` carries no `[info]` tags. The items below come from the daily summaries' "Questions for You" sections, 10 summaries from 11-01 to 11-06-run2. There is no 11-03 or 11-07 summary (see Stats).

- **Same-SHA verdict ranking (H-GATE-TWO-VERDICTS-ONE-SHA).** Open since **2026-09-28** and asked in all 10 reconciles this week. It is still the index's harness next task. Recommended action: ESCALATE_TO_MAINTAINER.
- **`linter_coverage` test-file policy.** Asked in every summary since 10-20, ≥21 reconciles. It is the last cleanup item. Recommended action: ESCALATE_TO_MAINTAINER.
- **Close `rename-twin-dedup`?** 10 reconciles (11-01 → 11-06-run2). This is a one-line docs PR. Recommended action: ESCALATE_TO_MAINTAINER.
- **Where do the #3527 split-basis findings 1–3 go: one issue, folded into #2973, or fixed directly?** 6 reconciles (11-04 → 11-06-run2). The open-issue cap (20) is the stated constraint. See P7 gap 1. Recommended action: ESCALATE_TO_MAINTAINER.
- **Add "publish the summary before any background wait / never end the turn with live subagents" to `lead-orchestrator.md`?** 6 reconciles (11-04 → 11-06-run2). It renews the codification question carried since 10-21.
  - Both 11-03 runs lost their summaries this way (`A-FASTEXIT-VACUOUS`, 11-04 summary).
  - The orchestrator cannot write `.claude/agents/**`.
  - Recommended action: ESCALATE_TO_MAINTAINER. It is a one-edit local change.
- **An automation-readable "owned by a session" signal for PRs** (asked 11-01 ×2, then re-asked 11-06-run2 as "add a label so the orchestrator skips QC on PRs whose authoring session drives its own gates"). Carried since 10-30, ≥6 reconciles. Recommended action: ESCALATE_TO_MAINTAINER.
- **Close #2973 as done and track the delisted window separately?** 2 reconciles (11-06 ×2). #3545 then landed the delisted GMCR window (11-07). Its body says "remaining: volume basis column, the #2982 `Stops_runner` production-path column, the QC rule, and the #3527 findings". The close question has changed shape, and it folds into the #3527 item above. KEEP_AS_INFO.
- **Resolved this week:** #3500's third rework iteration (11-02; merged 11-02), and the #3512 merge with its engine change (11-02-run2; merged 11-02).

## Tracks without owner (P4)
- No track was created in the last 14 days, and every non-MERGED row has an owner. PASS.
- Programmes with work this week and no index row:
  - **#2973 split corpus.** 4 PRs this week (#3527, #3530, #3532, #3545) and 5 open registry findings. It is mentioned only in passing in `backtest-perf.md` (the issue audit) and `harness.md`. **[NEW]** Recommend: RECOMMEND_NEW_TRACK (see P7 gap 1).
  - **Decision-tree walkthrough (#3546).** Its results sit under `decision-audit`, which is MERGED, and the forward guidance is in memory only. KEEP_AS_INFO.
  - **Codex/Jules delegation lanes** (board #3330) and the **fresh-eyes study**: carried. KEEP_AS_INFO.
- **Resolved:** #3477 is now booked under `simulation` (11-01 reconcile), and has closed.

## Recurring discussion topics (P5)

`dev/decisions.md` has 0 entries in 30 days and was last modified 2026-05-15 (**177 days**). P5 cannot run as specified. Recommend: ESCALATE_TO_MAINTAINER (9th ask: retire it or revive it). Read instead from the daily summaries, the registry, the handoffs and the results PRs:

- **[NEW] Raw vs split-adjusted basis mixing.** It appears in 6 places this week:
  - #3527 (11-04), #3530 (11-05) and #3545 (11-07): corpus columns, five `guard none` registry rows;
  - #3502 (11-02): laggard returns were read raw, so a split read as a loss;
  - #3546 (11-07): #2982's stop raise decides 71 % of stalled cycles, and fixing it costs 16–22 % of realised P&L first-order;
  - 6 summary questions (P3).

  An earlier instance is `findings/registry.sexp` "split basis keeps recurring (audit close raw vs MA adjusted)". There is no resolution: the fixes are default-off (#2982, #3502) or unfiled (#3527). Recommend: RECOMMEND_NEW_TRACK.
- **Orchestrator vs session ownership of PRs.** Carried since 10-30 (P3). Recommend: KEEP_AS_INFO until P3 is decided.
- **Orchestrator summary loss.**
  - 11-03: both runs ran about 30 min, ended "success" and published nothing.
  - 11-04: one run cost $40.28.
  - 11-07: both budget records read **$0.0000**, and no `dev/daily/2026-11-07*.md` exists.

  This is the standing "green run indistinguishable from a productive one" class in the index header. Recommend: KEEP_AS_INFO. Check the two 11-07 runs, and decide the P3 codification item.
- **Cloud backtests as the default.** #3476 closed 11-05. #3547 (11-08) fixes #3535's warehouse path. Verifying that a cloud cell pulls the warehouse is still pending (simulation index row). RESOLVED in mechanism; verification pending.
- **Record of record.** `dev/backtest/DEEP_RESULTS.md` was last touched 2026-07-29 (**102 days**). The record is the K-seed band (`2026-10-28-record-kseed`). Recommend: KEEP_AS_INFO.

## Diminishing returns (P6)

**Mechanical heuristic: 0 flags.**
- `simulation`, last 5 (#3547, #3543, #3542, #3540, #3539): 0 hits.
- `harness`, last 5 (#3543, #3542, #3540, #3539, #3508): 0 hits.
- `cleanup`: no PR this week; last 5 unchanged, 0 hits.
- PASS.

**Qualitative flag: KEEP_AS_INFO.**
- Every one of the 10 summaries reports `UNDER_TARGET`, "all-work-done" or "no eligible work exists".
- What the GHA orchestrator dispatched this week, per the summaries: #3505 (→ #3512), and the cloud-eligible #2973 items on 11-04.
- 18 of 51 merged PRs are `ops` records.
- The GHA lane is idle for want of maintainer answers (P3), not for want of capacity. The cleanup and harness queues are both decision-gated.

## Capability gaps (P7)
- **[NEW] Split-basis correctness has no owner.**
  - #2973's corpus has 9 windows. Its open items:
    - 5 registry findings with `guard none`;
    - #2982's same-basis stop fix, default-off (`fixed-behind-flag`), which #3546 measures as deciding 71 % of stalled ratchet cycles at a first-order cost of 16–22 % of realised P&L;
    - #3502's two laggard flags, default-off, awaiting a paired surface.
  - Milestone: M6 (this is the M6.4 split/dividend verification gap, carried 8 cycles as "no owning track"; the harness half now exists, the fixes do not).
  - Mentioned in: `short-side-strategy`, `post-run-validation` (#3500 V12/V13 basis), `resistance-v2` (grade finding), `weekly-snapshot` (M6.4), and the registry.
  - A same-basis default flip is a config-default change: it needs the K ≥ 5 paired run (`config-default-blast-radius.md`, record band SD 0.2254).
  - Recommend: ESCALATE_TO_MAINTAINER.
- **Weekly live-picks run: 86 days stale, 12 Fridays missed** (08-21 … 11-06).
  - The newest record is `dev/weekly-picks/f88c277d5/2026-08-14.sexp`, produced on a config two defaults old.
  - Milestone: M6. Mentioned in `weekly-snapshot`, `arc-readiness` and `decision-audit`.
  - Recommend: ESCALATE_TO_MAINTAINER (12th cycle).
- **The promoted resistance bundle (#2047, default-on) is not certified on the K = 5 record band.** #3527 adds that the grade reads raw highs across splits.
  - Mentioned in: `resistance-v2` and `simulation`.
  - Recommend: ESCALATE_TO_MAINTAINER (15th cycle).
- **Shorts close-out decision (a) vs (c), and Rule 4 for the short-only flags.** 4th cycle. The 11-02 issue audit calls the track "parked", with #3145 and #3109 `verify/pending` waiting on it.
  - Milestone: M7.
  - Recommend: ESCALATE_TO_MAINTAINER.
- **`tuning` M2 enable-commit (#1327): 166 days.** Milestone: M7. Recommend: ESCALATE_TO_MAINTAINER (16th ask).
- **`sweep-perf` ghcr.io flambda rebuild: 148 days.** Recommend: ESCALATE_TO_MAINTAINER (15th ask).
- **Weekly perf and usage review: partly resolved.**
  - The 11-02 read ran (#3520). All 12 perf-weekly cells PASS, but wall time is **+29 % to +41 % on every non-trivial cell** (`sp500-2010-2026` went from 304 s to 405 s). Runner variance is suspected, and no ticket was opened because the runner CPU is not logged.
  - The two SLOWER 10y cap-256 shapes are still not re-checked (2nd week).
  - `cost-tracking.md` §Usage review **still has no row**. The 10-28 to 10-31 backfill failed (`token_usage_report.sh` exit 4).
  - Recommend: ESCALATE_TO_MAINTAINER for the usage half. KEEP_AS_INFO for the wall-time move until a second week confirms it.
- **Cloud warehouse verification (#3535).** #3539–#3543 and #3547 merged. Still pending: verify that a cloud cell pulls the warehouse rather than rebuilding it (5.5 h, and a different construction: 9,181 vs 9,364 symbols). The Docker VM shrink waits on it (handoff §4). Recommend: KEEP_AS_INFO; LOCAL.
- **`arc-readiness` A2-4** (picks chart): now stalled. Recommend: KEEP_AS_INFO; it folds into the weekly-picks gap.

**Resolved since last report:**
- **#3477 resumable backtests:** booked, PRs 5–7 merged, issue closed. #3476 closed on 26y cloud kill-and-resume parity. RESOLVED.
- **Decision-tree walkthrough** (handoff queue item 1): run and read in #3546. RESOLVED. Its finding feeds gap 1.

Follow-up accumulation: **47** open `- [ ]` items in `dev/status/` (50 last week). KEEP_AS_INFO.

## Recommendations
1. **Give the split-basis cluster an owner and a plan.**
   - Decide where the #3527 findings go (6 reconciles).
   - Decide whether #2982's same-basis stop fix gets a K ≥ 5 paired surface toward an R3 flip. #3546 prices it at −16 to −22 % of realised P&L first-order, and it decides 71 % of stalled cycles.
   - Book #2973 under a track, or a new row.
2. **Answer the orchestrator questions in one pass:**
   - the same-SHA ranking rule (since 09-28);
   - the `linter_coverage` policy (≥21 reconciles);
   - the `lead-orchestrator.md` rule "publish before any background wait; never end the turn with live subagents" (the 11-03 summaries were lost);
   - a session-owned PR label;
   - closing `rename-twin-dedup`.

   The GHA lane reports no eligible work until these are answered.
3. **File one docs-only reconcile PR** (7th report to ask). Last week's was largely done on 11-01. What remains:
   - `simulation.md`: #3477 PRs 5–7, #3536, R2 and #3547;
   - `backtest-infra` and `data-foundations` first Next Steps;
   - `support-floor-stops` "UNSET";
   - the `short-side-strategy` index row;
   - booking #3500 in `post-run-validation.md`;
   - the `backtest-perf` header date;
   - closing `rename-twin-dedup`.
4. **Decide the shorts close-out (a) or (c)** (4th cycle). Two `verify/pending` issues wait on it.
5. **Look at the two 11-07 orchestrator runs**: they recorded $0.0000 and published no summary. Also look at the $40.28 run on 11-04.
6. **In the 11-09 weekly read:**
   - re-check the two SLOWER 10y shapes and the +29–41 % perf-weekly wall move on a quiet host;
   - write the first §Usage review row;
   - retry the 10-28..10-31 budget backfill.
7. **Verify a cloud cell pulls the R2 warehouse (#3535)**, then make the cloud the default for backtests.
8. **Decide the weekly-picks cadence on the record config.** It is 86 days and 12 Fridays behind; `arc-readiness` A2-4 depends on it.
9. **Unblock the one-action human gates:** `tuning` #1327 (166 days) and the `sweep-perf` flambda rebuild (148 days). Close or re-scope `tuning-methods` (168 days) and `spy-only-reference` (158 days).
10. **Retire or revive `dev/decisions.md`** (177 days), and point `DEEP_RESULTS.md` at the `2026-10-28-record-kseed` ledger entry.

## Stats
- **51 PRs merged in last 7d** (11-01 → 11-08; `21461890..8ee1ed79`; main at `8ee1ed79`).
  - By prefix: 18 `ops`, 9 `fix`, 7 `docs`, 6 `harness`, 4 `feat`, 3 `test`, 3 `backtest`, 1 `results`.
  - This includes last week's pacer (#3494).
- **286 PRs merged in last 30d.**
- 8 tracks active / 5 slowing / 12 stalled, out of 25 non-MERGED rows (10 / 3 / 12 last cycle).
- 6 `[info]` items carried ≥3 reconciles:
  - same-SHA ranking (since 09-28);
  - `linter_coverage` (≥21);
  - close `rename-twin-dedup` (10);
  - #3527 findings (6);
  - `lead-orchestrator.md` rule (6);
  - session-ownership label (≥6).

  2 resolved: #3500 and #3512.
- 9 capability gaps flagged (1 new: split-basis ownership). 2 resolved: #3477, and the walkthrough.
- **Orchestrator spend 11-01 … 11-07:** 14 runs, **$108.43** total; the largest was $40.28 (11-04). No daily summary exists for 11-03 (both lost) or 11-07 (both $0). Every published summary reports UNDER_TARGET.
- Ledger: 0 new entries this week; the newest is `2026-10-28-record-kseed`.
- Open issues: 17 at the 11-02 audit, 15 at the 11-05 handoff (cap 20).
- Stale artifacts:
  - newest `dev/weekly-picks/` record: **86 days**;
  - `DEEP_RESULTS.md`: **102 days**;
  - `dev/decisions.md`: **177 days**;
  - newest local spend record: `local-2026-11-02.json`, **6 days**.
- **47** open `- [ ]` follow-ups in `dev/status/`.
- **Method note:** `gh` was not used. PR facts come from merge-commit subjects and bodies on `main`, from `dev/daily/` summaries, the 11-05 handoff, `dev/budget/` and `dev/findings/registry.sexp`.
  - Track attribution is by subject keyword and the index row's citations, so it is approximate for cross-cutting work.
  - The `harness(r2)` PRs are counted under `simulation`, because the index books #3535 there.
  - The split-corpus PRs are counted under no track.

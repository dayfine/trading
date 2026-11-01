# Track Pacer Report — 2026-11-01

## Summary
- Tracks audited: 50 index rows. Cadence was run on the 25 non-MERGED rows (24 IN_PROGRESS, 1 PENDING). The 25 MERGED rows are exempt. No row changed status this week.
- Active (≥1 PR last 7d): 10
- Slowing (7–30d since last PR): 3
- Stalled (>30d): 12 (11 IN_PROGRESS, plus `tuning-methods`, which is PENDING and parked). `post-run-validation` moved from slowing to stalled.
- `[info]` items needing decision: 4. All four are orchestrator-process questions, each carried 3–11 reconciles. Three items were resolved this week.
- Capability gaps flagged: 9 (1 new, 8 carried). 1 resolved; 1 partly resolved.

**Headline 1: feature work came back, almost all of it from local and cloud sessions.**
- 70 PRs merged 10-25 → 11-01, against 79 last week. 14 of the 70 are daily summaries or budget records.
- More of the work this week was feature or experiment work. Four programmes moved:
  - **Seeded default and K-seed record re-baseline:** #3425, #3456, #3467, #3474, #3478.
  - **Rename-twin dedupe**, with its 26y read: #3475, #3480, #3489, #3490.
  - **Floor-nearest screens S and SM**, with monthly universe lists: #3418, #3423, #3427–#3430, #3435, #3436, #3446.
  - **#3477 resumable-backtest checkpoints**, PRs 0–4: #3479, #3482, #3483, #3485, #3486.
- The GHA orchestrator contributed only harness and cleanup work. Every one of its 9 daily summaries reports `UNDER_TARGET, all-work-done`. From 10-30 on it says "every PR action belongs to the human or the local session". Spend was 12 runs, **$95.30**, down from $159.29.

**Headline 2: the record is now a band, and that changes the cost of every pending verdict.**
- #3467 (ledger `2026-10-28-record-kseed`) replaced the single-run 26y record with a K = 5 seed band: median ln(1+R) 2.7819, SD 0.2254.
- Its own README: "a single 26y cell cannot resolve a lever under about 0.45 log, and 26y verdicts need K ≥ 5 paired per seed".
- Three other reads this week landed inside that noise: #3419 path stability, #3446 floor-nearest SM (INCONCLUSIVE), and #3489 twin dedupe (0.10 band SD).
- Every carried verification gap that needs a 26y run now costs about 5× the container time it did last week. That includes resistance-v2 WF-CV, the M6.4 split/dividend harness and stage-accuracy. P7 is re-costed on that basis.

**Headline 3: none of last week's recommendations 1, 2, 4 or 8–10 was acted on.**
- The shorts close-out is undecided (3rd cycle).
- No docs reconcile PR landed (5th report to recommend one).
- `screener.md` now carries **five** stale state tokens, one of them written this week (#3425).
- Recommendations 3, 5 (in part) and 6 were done: #3412 merged 10-25, the perf review resumed 10-29, and the path-stability chain ran (#3419).

## Active tracks (≥1 PR last 7d)
- **harness** — 14 PRs: #3412, #3433, #3451, #3453, #3455, #3459, #3461, #3462, #3463, #3464, #3468, #3469, #3470, #3472.
  - Themes:
    - check_06 hardening and pins (#3451, #3455, #3461);
    - `.git` sentinel walk-up pins (#3463, #3464);
    - CancelEntry census (#3459, #3462);
    - review-pack seed sets and partial-trade detector (#3468, #3469);
    - `pr_gate_status` fails closed on an incomplete file list (#3470, which closes #3421);
    - `wait_for.sh` curl backend (#3472).
- **screener** — 6 PRs: #3425 (Seeded is the default `candidate_ranking`, user-approved 10-25), #3419 (path-stability results), #3456/#3467 (K-seed record pre-registration and results), and #3474/#3478 (tier-4 goldens re-pinned for Seeded and given seed bands).
- **data-foundations** — 5 PRs: #3427, #3429, #3430 and #3435 (monthly top-3000 lists and the twin-scan cache), plus #3493 (a hash-manifest tool for the bar store, #3476). `data-foundations.md` was refreshed 10-30.
- **rename-twin-dedup** — 4 PRs: #3475 (full rename-twin dedupe of pit-v12 plus the paired 26y pre-registration, #3388), #3480 (monthly builder applies twin drops per window), #3489 (results: the record moves 0.10 band SD; Verifies #3388) and #3490 (findings registry row). All of it is booked in `data-foundations.md`, none in `rename-twin-dedup.md` (P2).
- **simulation** (#3477 resumable backtests, no track row) — 5 PRs: #3479 (state inventory), #3482 (sexp round-trip types), #3483 (`orders`: fill active orders in insertion order), #3486 (Weinstein strategy state as a capturable record) and #3485 (simulator checkpoint capture/restore).
  - #3483 is a core-module change (A1 watch-list). It carried a `do-not-merge` hold until its paired golden table cleared on 10-31/11-01.
  - PRs 5–6 remain.
- **support-floor-stops** (floor-nearest screens) — 5 PRs: #3418 (pre-registration: Nearest floor under `require_structural_stop`), #3423 (SN NOT LIVE as screened), #3428 (ledger entry and SM amendment), #3436 (arm SM chain), #3446 (arm SM: LIVE, INCONCLUSIVE).
  - Experiment-only work; no code change on the track.
  - None of it is recorded in `support-floor-stops.md` (dated 10-02).
- **cleanup** — 5 PRs: #3434 (runner test for `decision_grading_bin.exe`), #3440, #3450 (`sidetable_migrator.ml` under 300 lines, exception dropped), #3454, #3458.
- **trade-audit** — 2 PRs: #3441 (row side falls back to `trade.side`, #3437) and #3460 (doc residuals). The CancelEntry census (#3459, #3462) is booked here too. `trade-audit.md` was refreshed 10-28.
- **backtest-perf** — 4 PRs: #3447 and #3466 (ledger rows), #3448 (review-pack / `perf_long_cells` fix), #3481 (`perf_long_cells` resolves `-k<N>` seed tags). The §Weekly review resumed on 10-29 (see P7).
- **backtest-infra** — 1 PR: #3441, which updated `backtest-infra.md`.

## Slowing tracks (7–30d since last PR)
- **arc-readiness** — last PR #3142 was 27 days ago (10-05); theme: macro-suspend. The file is dated 09-26. A2-4 has still not been dispatched. **It stalls next week.** Recommendation: KEEP_AS_INFO; decide whether A2-4 is still wanted.
- **orchestrator-automation** — last booked PR #3226 was 23 days ago (10-09). The file is dated 09-04. Orchestrator-process work keeps landing as `harness:` or `docs:` instead: #3470, #3472, #3488 (cloud session setup). Recommendation: KEEP_AS_INFO.
- **short-side-strategy** — last PR #3294 was 19 days ago (10-13): wide-top screen, CLOSE. The close-out decision is pending (P7). Recommendation: ESCALATE_TO_MAINTAINER (3rd cycle).

## Stalled tracks (>30d since last PR)
- **post-run-validation [NEW]** — last PR #3051 at 2026-09-30 (32 days). Reason: `Series_level` is waiting to be armed on the next rebuild. Two rebuilds happened this week (#3475, #3480) without arming it. The file heading reads `READY_FOR_REVIEW` while the index reads `IN_PROGRESS` (5th cycle). Recommendation: ESCALATE_TO_MAINTAINER; arm it on the next pit-v12 monthly re-pin, or close the track.
- **weekly-snapshot** — last PR #2453 at 2026-08-20 (73 days). Reason: M6.4-class split and dividend work keeps landing on other tracks. Recommendation: ESCALATE_TO_MAINTAINER (8th ask).
- **stage-accuracy** — last PR #2450 at 2026-08-20 (73 days); reason: broad-universe WF-CV is data-gated, and the K ≥ 5 requirement now applies to it; recommendation: KEEP_AS_INFO.
- **resistance-v2** — last PR #2145 at 2026-07-28 (96 days); reason: WF-CV vs w30 is LOCAL. The default-on bundle has never been certified on the record, which is now a K = 5 band. Recommendation: ESCALATE_TO_MAINTAINER (12th cycle).
- **tuning** — last PR #2113 at 2026-07-27 (97 days); reason: the M2 enable-commit (#1327, filed 2026-05-26, **159 days** ago); recommendation: ESCALATE_TO_MAINTAINER (15th ask).
- **extension-stop** — last PR #1960 at 2026-07-14 (110 days); reason: the R3 flip is human-gated; recommendation: KEEP_AS_INFO.
- **floor-quality** — last PR #1913 at 2026-07-10 (114 days); reason: deep-warehouse, LOCAL; recommendation: KEEP_AS_INFO.
- **rolling-start-lens** — last PR ~#1648 at 2026-06-18 (136 days); reason: LOCAL / data-gated; recommendation: KEEP_AS_INFO.
- **cash-floor-correctness** — last PR #1582 at 2026-06-14 (140 days); reason: NS2 is human-gated and NS4 is data-gated; recommendation: KEEP_AS_INFO.
- **sweep-perf** — last PR #1574 at 2026-06-13 (141 days); reason: the manual ghcr.io flambda rebuild; recommendation: ESCALATE_TO_MAINTAINER (14th ask).
- **spy-only-reference** — last PR #1438 at 2026-06-03 (151 days); reason: item 1 is an open question that was never dispatched; recommendation: ESCALATE_TO_MAINTAINER (8th ask), to close or re-home.
- **tuning-methods** (PENDING) — no PR ever; file last updated 2026-05-24 (161 days); recommendation: ESCALATE_TO_MAINTAINER (8th ask), to close or re-scope.

## Next Steps staleness (P2)
- **screener** (2nd cycle, worse) — dated 10-25. Its own `PR OPEN` tripwire now fails on **five** entries:
  - #3425 marked **PR OPEN** (line 30), merged 10-25 as `cae75ca2`. It was written this week.
  - #2685 marked **PR OPEN** (line 36), merged as `2732ef95`.
  - #2563 marked **PR OPEN** (line 42), merged as `1180aa6d`.
  - The #3056 entry (line 34) is marked **NOT SUBMITTED**, but landed as #3067 (`f86d38f5`).
  - The #2503 differential entry (line 80) is marked **NOT SUBMITTED**. It appears to have landed as #2505 (`6e465e5f`); verify.

  The index row still says "next: top-of-funnel screen (LOCAL)". It does not mention the Seeded default (#3425), the K-seed band (#3467), or the open #3404 item.
- **simulation** — `Last updated: 2026-09-02`, "next: none queued". Since then:
  - total-return default-on (#3184, #3222), #3282 and #3283;
  - the record moved rb1 → N → the K-seed band;
  - and now five #3477 checkpoint PRs, one of them a core-module change.

  **6th cycle.**
- **rename-twin-dedup** — dated 09-16. Its first Next Step, "rebuild the PIT union warehouse with `-twin-require-direct-match`", is overtaken by #3475, #3480 and #3489, which completed the dedupe and its 26y read. The track looks done; recommend closing it. 5th cycle.
- **support-floor-stops** — dated 10-02, and the index row still says "next: UNSET" (6th cycle). The floor-nearest SN and SM reads (#3423, #3446; ledger entries 10-25 and 10-26) are not recorded.
- **short-side-strategy** — dated 10-06. The next task, "short-leg regime-P&L decomposition", was overtaken by #3265, #3273, #3286 and #3294. 4th cycle.
- **Index rows naming shipped work** (6th cycle):
  - `backtest-infra`: "#2984 open", though it was closed by #3121 on 10-04;
  - `backtest-perf`: names #2899 and #2896, both shipped. The file header still reads 2026-09-22 although §Weekly review has a 10-29 entry.
- **Status mismatches:** `tax-lens` (file `READY_FOR_REVIEW`, index `MERGED`) and `post-run-validation` (file `READY_FOR_REVIEW`, index `IN_PROGRESS`).

Carried unchanged, with files untouched for 30+ days: `cash-floor-correctness`, `tuning`, `extension-stop`, `tuning-methods`, `spy-only-reference`, `weekly-snapshot`, `floor-quality`, `rolling-start-lens`, `sweep-perf`, `stage-accuracy`, `orchestrator-automation`, `arc-readiness`.

**Resolved since last cycle:**
- `trade-audit`: refreshed 10-28, and its heading now reads `IN_PROGRESS`.
- `data-foundations`: refreshed 10-30, and it records #3339, #3343, #3427–#3435, #3475 and #3480.

## [info] items needing decision (P3)

`_index.md` carries no `[info]` tags. The items below come from the daily summaries' "Questions for You" sections (10-26 … 10-31-run2, 9 summaries).

- **Same-SHA verdict ranking (H-GATE-TWO-VERDICTS-ONE-SHA): may the orchestrator apply "the latest verdict at the same SHA wins"?**
  - Open since **2026-09-28**. It returned to the list on 10-29 and was asked in 4 of this week's reconciles (10-29, 10-30, 10-31, 10-31-run2).
  - The orchestrator calls it "the top harness item, and nothing else in harness is dispatchable".
  - Live case on 10-30: #3482.
  - Recommended action: ESCALATE_TO_MAINTAINER.
- **`linter_coverage` test-file policy.** Asked in every summary since 10-20, ≥11 reconciles. It is the last dispatchable cleanup item. Recommended action: ESCALATE_TO_MAINTAINER.
- **Codify "interim summary before dispatch, foreground agents, flock-serialized dune, at most 2 built worktrees" in `lead-orchestrator.md`?**
  - Carried since **2026-10-21**, ≥10 reconciles. This week it was asked on 10-26, 10-27, 10-28 and 10-29; 10-27 also asked separately about the worktree cap.
  - It dropped off the list after 10-29 with no answer recorded.
  - The practice held every run this week. A summary was lost on 10-26 run 2, when the practice was not followed.
  - The orchestrator cannot make the edit itself (`.claude/agents/**` writes are refused).
  - Recommended action: ESCALATE_TO_MAINTAINER. It is a one-edit local change.
- **[NEW] Should the orchestrator skip PRs that a local or cloud session is actively gating, and what signal marks them?**
  - Asked in 3 reconciles (10-30, 10-31, 10-31-run2).
  - Live case: on 10-31 run 1 the orchestrator merged #3490, which a session had QC'd 1.5 h earlier and deliberately left unmerged. Run 2 skipped #3483 on judgment alone.
  - Per `pr-merge-gates.md` Rule 0, the answer has to be a label or check, not prose. `do-not-merge` covers holds, but there is no "owned elsewhere" signal.
  - Recommended action: ESCALATE_TO_MAINTAINER.
- **Harness T1 queue is empty: pull T3-C or T3-H?** Asked through 10-26 (8 reconciles since 10-20), then dropped off unanswered. Every summary since still says harness has "no non-nit item". Recommended action: KEEP_AS_INFO; it is folded into P6.
- **Resolved this week:**
  - #3421 hand-off to Codex (10-26 → 10-28): the orchestrator took it as #3470, merged 10-29.
  - #3483 `do-not-merge` hold (10-31 ×2): cleared; #3483 and #3485 merged 11-01.
  - #3412 rework cap (last week's item): merged 10-25.
- **Low stakes, 1 reconcile:** delete or keep `dev/agent-memory/project_rest_time_pnl_is_cell_specific.md` (10-28). KEEP_AS_INFO.

## Tracks without owner (P4)
- No track was created in the last 14 days, and every non-MERGED row has an owner. PASS.
- Programmes with work this week and no index row:
  - **#3477 resumable backtests:** 5 PRs, including core-module changes to `orders`, the simulator and the strategy, with PRs 5–6 pending. **[NEW]**
  - **Path stability / K-seed record (#3404):** only the mechanism is booked, in `screener.md`.
  - **Codex/Jules delegation lanes.**
  - **Fresh-eyes study:** 3rd cycle.

  Recommended action: KEEP_AS_INFO. Book #3477 first; it touches the A1 core modules, and the reconciler cannot see its next step.

## Recurring discussion topics (P5)

`dev/decisions.md` has 0 entries in 30 days and was last modified 2026-05-15 (**170 days**), so P5 cannot run as specified. Recommend: ESCALATE_TO_MAINTAINER (8th ask: retire it or revive it). Read instead from the daily summaries, the ledger and the results PRs:

- **Seed noise dominates 26y reads.** It appears in 4 ledger entries in 5 days:
  - `2026-10-24-path-stability`: Seeded tie order shows 12.6× the noise of the alphabetical yardstick;
  - `2026-10-25-floor-nearest`;
  - `2026-10-26-floor-refresh-sm`: INCONCLUSIVE, with "70 % of the NAV gap is which arm's cash caught a handful of tail names";
  - `2026-10-28-record-kseed`: SD 0.2254, so K ≥ 5 is needed.

  #3489 adds a fifth read inside the band. The method is RESOLVED: the band is the new baseline. The consequence is not: no plan yet states how the ~5× cost per 26y verdict is budgeted. Recommend: KEEP_AS_INFO, and size the next priorities doc against it.
- **Orchestrator vs. local/cloud session ownership of PRs.** This appears on 10-30, 10-31 and 10-31-run2 (P3 item 4), with the #3490 merge and #3482 as live cases. #3488 (cloud session setup) shows that a third concurrent actor is now routine. Recommend: KEEP_AS_INFO until P3 item 4 is decided.
- **Monthly universe refresh and twins.** #3427, #3429, #3430, #3435, #3475 and #3480 landed. #3489 settled the twin effect at 0.10 band SD, and #3446 found SM LIVE but INCONCLUSIVE. RESOLVED (landed).
- **Record of record.** `dev/backtest/DEEP_RESULTS.md` was last touched 2026-07-29 (**95 days**). The record has since moved twice: to N, then to the K-seed band in #3467. Recommend: KEEP_AS_INFO; point it at `2026-10-28-record-kseed` or retire it.

## Diminishing returns (P6)

**Mechanical heuristic: 0 flags.**
- `harness`, last 5 (#3472, #3470, #3469, #3468, #3464): 0 hits.
- `cleanup`, last 5 (#3458, #3454, #3450, #3440, #3434): 0 hits.
- `screener`, last 5 (#3478, #3474, #3467, #3456, #3425): 2 hits (`golden`, `re-pin`), below the threshold of 3.
- PASS.

**Qualitative flag: KEEP_AS_INFO.**
- **cleanup** has run out of dispatchable work. #3434 closed one of the two items left last week. The other, the `linter_coverage` policy, is decision-gated (P3). The daily summaries say the same: "every remaining harness and cleanup item is decision-gated or scope-blocked" (10-29).
- **harness:** 5 of its 14 PRs this week are single-arm pins (#3451, #3455, #3461, #3463, #3464).
- Both GHA lanes are idle for want of maintainer answers, not for want of capacity.

## Capability gaps (P7)
- **Shorts close-out decision (a) vs (c), and Rule 4 for the four short-only flags.** Third cycle with no movement. Milestone: M7. Mentioned in: `short-side-strategy` and the 10-13 handoff §3. Recommend: ESCALATE_TO_MAINTAINER.
- **Weekly live-picks run: 79 days stale, 11 Fridays missed** (08-21 … 10-30).
  - The newest record is `dev/weekly-picks/f88c277d5/2026-08-14.sexp`. The default config changed again this week (Seeded, #3425), so the last picks were produced on a config two defaults old.
  - Mentioned in: `weekly-snapshot`, `arc-readiness`, `decision-audit`. Milestone: M6.
  - Recommend: ESCALATE_TO_MAINTAINER (11th cycle).
- **Promoted resistance bundle (#2047, default-on) not certified on the record.** The record is now the K = 5 band, so certifying it needs a K ≥ 5 paired run. Mentioned in: `resistance-v2` and `simulation`. Recommend: ESCALATE_TO_MAINTAINER (14th cycle).
- **M6.4 split/dividend verification harness**: no owning track. Milestone: M6. Recommend: ESCALATE_TO_MAINTAINER (8th cycle).
- **`tuning` M2 enable-commit (#1327), 159 days.** Milestone: M7. Recommend: ESCALATE_TO_MAINTAINER (15th ask).
- **`sweep-perf` ghcr.io flambda rebuild, 141 days.** Recommend: ESCALATE_TO_MAINTAINER (14th ask). With 26y verdicts now costing about 5×, the wall-time win from this rebuild matters more than it did.
- **[NEW] The #3477 resumable-backtest programme has no track.**
  - PRs 0–4 merged; PRs 5–6 are pending per `dev/notes/resumable-backtest-state-inventory.md`.
  - It touches A1 core modules: `orders/lib/manager.ml` (#3483), the simulator (#3485) and the strategy state (#3486).
  - Checkpoint resume is the long-standing ask in `sweep-hygiene.md` ("the sweep does NOT resume from checkpoint today").
  - Recommend: KEEP_AS_INFO; book it under `simulation` or a new row, so that PRs 5–6 and the A1 review trail are visible.
- **Weekly perf and usage review: partly resolved.**
  - The perf §Weekly review resumed on 10-29.
  - That entry flags two 10y shapes as SLOWER (`top-3000-2014|10y|cap256` +89 %, `top-1000-2014|10y|cap256` +125 %) with host load as the suspect. They are still to be re-checked on a quiet host.
  - `cost-tracking.md` §Usage review **has never had a row**; the table is a header only.
  - The newest local spend record is still `dev/budget/local-2026-10-13.json`, 19 days old.

  Recommend: ESCALATE_TO_MAINTAINER for the usage half.
- **`arc-readiness` A2-4** (picks chart): dispatchable, and stalls next week. Recommend: KEEP_AS_INFO.

**Resolved since last report:**
- **Path-stability Step 2 chain (#3408):** run and read in #3419. The Seeded default (#3425) and the K-seed record (#3467) followed. RESOLVED.

Follow-up accumulation: **50** open `- [ ]` items in `dev/status/` (60 last week). KEEP_AS_INFO.

## Recommendations
1. **Decide the shorts close-out (a) or (c).** This is the 3rd cycle. The track has had no PR in 19 days and nothing else can move it.
2. **Answer the four orchestrator-process questions in one pass:**
   - the same-SHA ranking rule (open since 09-28; the top harness item);
   - the `linter_coverage` policy (the last cleanup item);
   - the `lead-orchestrator.md` codification (≥10 reconciles);
   - an automation-readable "owned by a session" signal, such as a label, after the #3490 merge.

   Both GHA lanes are idle until these are answered.
3. **File one docs-only reconcile PR** (6th report to recommend it). It should cover:
   - `screener.md`'s five stale tokens (#3425, #2685, #2563, #3067, #2503 → #2505?);
   - `simulation`, booking the #3477 PRs;
   - closing `rename-twin-dedup` (#3475, #3480, #3489);
   - `support-floor-stops`: record floor-nearest SN and SM and replace "next: UNSET";
   - `short-side-strategy`;
   - `post-run-validation` and `tax-lens` heading mismatches;
   - the `backtest-infra` and `backtest-perf` index rows;
   - rows for #3477 and path stability.
4. **Re-plan pending 26y verifications against the K ≥ 5 cost.**
   - Pending: the resistance bundle certification, the M6.4 harness, and stage-accuracy WF-CV.
   - Pick which to run, and check that the container budget covers ~5 cells per arm.
5. **Arm `Series_level` on the next pit-v12 monthly re-pin** (`post-run-validation`), or close the track.
6. **Re-check the two SLOWER 10y perf shapes on a quiet host.** Write the first §Usage review row, and backfill `budget_local_record.sh --date` from 10-14.
7. **Decide the weekly-picks cadence on the Seeded record config:** automate it, or de-scope M6.6. It is 79 days and 11 Fridays behind.
8. **Unblock the one-action human gates:** `tuning` #1327 (159 days) and the `sweep-perf` flambda rebuild (141 days).
9. **Assign M6.4 an owner** (8th ask), and close or re-scope `tuning-methods` (161 days) and `spy-only-reference` (151 days).
10. **Retire or revive `dev/decisions.md`** (170 days), and point `DEEP_RESULTS.md` at the `2026-10-28-record-kseed` ledger entry.

## Stats
- **70 PRs merged in last 7d** (10-25 → 11-01; main at `21461890`).
  - By prefix: 17 `ops` (14 daily summaries or budget records), 14 `harness`, 7 `exp`/`experiment`, 5 `feat`, 4 `test`, 4 `fix`, 4 `docs`, 3 `cleanup`, 2 `results`, 2 `perf`, 2 `data`, and 1 each of `simulator`, `orders`, `checkpoint`, `refactor`, `findings`, `chore`.
  - This includes last week's pacer (#3416).
- **343 PRs merged in last 30d.**
- 10 tracks active / 3 slowing / 12 stalled, out of 25 non-MERGED rows (7 / 7 / 11 last cycle).
- 4 `[info]` items carried ≥3 reconciles: same-SHA ranking (since 09-28), `linter_coverage` (≥11), `lead-orchestrator.md` codification (≥10), session-ownership signal (3). 3 resolved: #3421, the #3483 hold, #3412.
- 9 capability gaps flagged (1 new); 1 resolved (path-stability Step 2).
- **Orchestrator spend 10-25 … 10-31:** 12 runs, **$95.30** total. The largest run was $15.95 (10-26). All 9 daily summaries report UNDER_TARGET / all-work-done.
- Ledger: 4 new entries (`2026-10-24-path-stability`, `2026-10-25-floor-nearest`, `2026-10-26-floor-refresh-sm`, `2026-10-28-record-kseed`).
- Weekly deep health scan, prune-candidates and the BAH SPY sweep all ran on 10-26 (#3443, #3444, #3442) and merged 10-27.
- The newest `dev/weekly-picks/` record is **79 days** old; `DEEP_RESULTS.md` is **95 days** old; `dev/decisions.md` is **170 days** old; the newest local spend record is **19 days** old.
- **50** open `- [ ]` follow-ups in `dev/status/`.
- **Method note:** `gh` was not used. PR facts come from merge-commit subjects and bodies on `main`, and from `dev/daily/` summaries.
  - Track attribution is by subject keyword and is approximate for cross-cutting work.
  - Floor-nearest is counted under `support-floor-stops`, #3477 under `simulation`, the twin dedupe under `rename-twin-dedup`, and the review pack under `harness`.

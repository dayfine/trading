# Track Pacer Report — 2026-10-25

## Summary
- Tracks audited: 50 index rows. Cadence was run on the 25 non-MERGED rows (24 IN_PROGRESS, 1 PENDING). The 25 MERGED rows are exempt. No row changed status this week.
- Active (≥1 PR last 7d): 7
- Slowing (7–30d since last PR): 7
- Stalled (>30d): 11 (10 IN_PROGRESS, plus `tuning-methods`, which is PENDING and parked)
- `[info]` items needing decision: 4 (two orchestrator-process questions carried 6–7 reconciles, the `linter_coverage` policy, and the same-SHA verdict rule, which dropped off the question list unanswered and recurred on 10-23)
- Capability gaps flagged: 8 (2 new, 6 carried; 1 resolved since last report)

**Headline 1: throughput came back, and almost all of it went to harness and cleanup.**
- 79 PRs merged 10-18 → 10-24, against 70 last week. The quota outage did not repeat. Fourteen orchestrator runs cost **$159.29**; last week's seven quota-blocked runs recorded $0.
- About 30 of the 79 were harness or cleanup. Feature-track progress was narrow: the 26y verify chain (#3383, #3397), the CMN/CMD twin drop (#3391), six review-pack cards and fixes, and one screener mechanism (#3406).
- The orchestrator says this itself. Every daily summary since 10-20 reports UNDER_TARGET and "feature tracks are fenced", and the harness T1 queue has been empty since 10-20 (P3 item 1). The GHA lane has run out of work it is allowed to pick up, so the only remaining lever is maintainer decisions.

**Headline 2: last week's recommendations 1–3 were not acted on.**
- The shorts close-out (a) vs (c) is still undecided. No shorts PR has merged since #3294 (10-13), and `short-side-strategy.md` is still dated 10-06 (3rd cycle).
- The QC same-SHA question dropped off the daily "Questions for You" list after 10-18 without an answer. The hazard then **recurred on 10-23**: there were three verdicts at `4dd45cf7` on #3398 (`dev/daily/2026-10-23.md`).
- No reconcile PR landed. Only `harness.md`, `cleanup.md` and `screener.md` were touched this week. `screener.md` now carries **four stale state tokens**, the exact failure its own header warns about (P2).

**Headline 3: two new programmes have no track row.**
- **Path stability (#3404).** It has a plan (#3405, amended in #3407), a pre-registered Step 2 chain (#3408) and its step-1 mechanism (#3406). Only the mechanism is booked, in `screener.md`.
- **Codex/Jules delegation lanes.** About 9 PRs this week: #3331, #3332, #3334, #3335, #3336, #3338, #3367, #3378, #3380. No track books them.
- The fresh-eyes study (#3326, #3328) is still unbooked (2nd cycle).

## Active tracks (≥1 PR last 7d)
- **harness** — ~16 PRs: #3321, #3323, #3332, #3337, #3346, #3350, #3358, #3360, #3364, #3367, #3370, #3377, #3378, #3380, #3385, #3389, #3398, #3401. #3412 is open and has hit the rework cap.
  - Themes:
    - report_conjuncts slices 4–8, with the item closed in #3364;
    - the async lane board and the Codex quota pacer (#3332, #3367, #3378, #3380);
    - deep-scan verdict-parser fixes (#3370, #3385, #3389);
    - gitignore-negation checks (#3398, #3401);
    - devcontainer zombie reaping (#3346).
- **cleanup** — ~14 PRs: #3322, #3349, #3356, #3359, #3361, #3363, #3371, #3373, #3379, #3386, #3390, #3399, #3402, #3411, #3414.
  - Theme: pinning config threads and dropping expired adapter exceptions (#3371, #3373, #3386, #3390, #3399, #3402, #3411); file-length and #2876 splits (#3322, #3349, #3359, #3361, #3379); dead code (#3414).
- **trade-audit (review pack)** — 6 PRs: #3347, #3357, #3368, #3369, #3395, #3410.
  - Theme: new cards (missed winners, P&L anatomy, faithfulness grades, an eight-dimension career scorecard) and signal fixes (chain V signals, concentrated gains at intermediate NAV peaks, #3409).
  - None of these are recorded in `trade-audit.md` (dated 10-03).
- **data-foundations** — 5 PRs: #3339 (A-D fixture calendar check, #3263), #3343 (dollar-volume gate-flip measurement on v12, #3136), and the 26y verify chain #3342/#3383 with the #3266 rerun #3393/#3397.
  - Outcome: #3263, #3173 and #3266 satisfied; #3138 refuted; #3174 read as an axis. "N stays the record."
  - None of this is recorded in `data-foundations.md` (dated 10-11).
- **rename-twin-dedup** — #3391: the CMN/CMD twin was dropped from pit-v12 by a whole-universe twin scan. #3397 then confirmed #3266 satisfied. This is the first real track progress in 4 cycles, but `rename-twin-dedup.md` is still dated 09-16.
- **screener** — #3406 (Seeded tiebreak ranking and `tiebreak_seed`, default-off), plus path-stability plan and pre-registration PRs #3405, #3407 and #3408.
- **backtest-perf** — 2 docs PRs (#3382, #3396: perf ledger rows for chain V and the #3266 rerun). This is ledger upkeep only; the last code PR is #2965 (09-25). The §Weekly review was last written **2026-10-05**, so the 10-12 and 10-19 weeks were both skipped.

## Slowing tracks (7–30d since last PR)
- **arc-readiness** — last PR #3142 was 20 days ago (10-05); theme: macro-suspend. The file is dated 09-26. A2-4 has still not been dispatched. Recommendation: KEEP_AS_INFO.
- **post-run-validation** — last PR #3051 was 25 days ago (09-30). The file heading reads `READY_FOR_REVIEW` while the index reads `IN_PROGRESS` (4th cycle). This track becomes stalled next week. Recommendation: ESCALATE_TO_MAINTAINER. Arm `Series_level` on the next rebuild, or close the track.
- **support-floor-stops** — last PR #3193 was 17 days ago (10-08). The index row still says "next: UNSET" (5th cycle). Recommendation: KEEP_AS_INFO; set a next task or close.
- **orchestrator-automation** — last booked PR #3226 was 16 days ago (10-09). The file is dated 09-04. Orchestrator-process work (lanes, quota pacing, #3348's autonomous-decision record) keeps landing as `harness:` or `docs(agents)`. Recommendation: KEEP_AS_INFO.
- **short-side-strategy** — last PR #3294 was 12 days ago (10-13): wide-top screen, CLOSE. The decision is pending (see P7). Recommendation: ESCALATE_TO_MAINTAINER.
- **simulation** — last PRs #3282 and #3283 were 12 days ago (10-13). Recommendation: KEEP_AS_INFO; the file is very stale (P2).
- **backtest-infra** — last PR #3293 was 12 days ago (10-13; nightly and local golden coverage, #2650). Recommendation: KEEP_AS_INFO.

## Stalled tracks (>30d since last PR)
- **weekly-snapshot** — last PR #2453 at 2026-08-20 (66 days). Reason: M6.4-class split and dividend work keeps landing on other tracks. Recommendation: ESCALATE_TO_MAINTAINER (7th ask).
- **stage-accuracy** — last PR #2450 at 2026-08-20 (66 days); reason: broad-universe WF-CV is data-gated; recommendation: KEEP_AS_INFO.
- **resistance-v2** — last PR #2145 at 2026-07-28 (89 days); reason: WF-CV vs w30 is LOCAL. #3397 re-confirmed record N, and the default-on bundle has never been certified on it. Recommendation: ESCALATE_TO_MAINTAINER (11th cycle).
- **tuning** — last PR #2113 at 2026-07-27 (90 days); reason: the M2 enable-commit (#1327, filed 2026-05-26, **152 days** ago); recommendation: ESCALATE_TO_MAINTAINER (14th ask).
- **extension-stop** — last PR #1960 at 2026-07-14 (103 days); reason: the R3 flip is human-gated; recommendation: KEEP_AS_INFO.
- **floor-quality** — last PR #1913 at 2026-07-10 (107 days); reason: deep-warehouse, LOCAL; recommendation: KEEP_AS_INFO.
- **rolling-start-lens** — last PR ~#1648 at 2026-06-18 (129 days); reason: LOCAL / data-gated; recommendation: KEEP_AS_INFO.
- **cash-floor-correctness** — last PR #1582 at 2026-06-14 (133 days); reason: NS2 is human-gated and NS4 is data-gated; recommendation: KEEP_AS_INFO.
- **sweep-perf** — last PR #1574 at 2026-06-13 (134 days); reason: the manual ghcr.io flambda rebuild; recommendation: ESCALATE_TO_MAINTAINER (13th ask).
- **spy-only-reference** — last PR #1438 at 2026-06-03 (144 days); reason: item 1 is an open question that was never dispatched; recommendation: ESCALATE_TO_MAINTAINER (7th ask), to close or re-home.
- **tuning-methods** (PENDING) — no PR ever; file last updated 2026-05-24 (154 days); recommendation: ESCALATE_TO_MAINTAINER (7th ask), to close or re-scope.

## Next Steps staleness (P2)
- **screener [NEW]** — `screener.md` is dated 10-23, but its own `PR OPEN` tripwire fails on every entry:
  - #3406 is marked **PR OPEN** but merged 10-23 (`3db869d3`);
  - #2685 is marked **PR OPEN** but merged (`2732ef95`);
  - #2563 is marked **PR OPEN** but merged (`1180aa6d`);
  - the #3056 entry is marked **NOT SUBMITTED** but landed as #3067 (`f86d38f5`).

  The index row's next task, "top-of-funnel screen (LOCAL)", does not mention the #3404 path-stability Step 2 chain that is now pending.
- **short-side-strategy** — the file is dated 10-06, and the next task, "short-leg regime-P&L decomposition", was overtaken by #3265, #3273, #3286 and #3294. 3rd cycle.
- **simulation** — `Last updated: 2026-09-02`, with "next: none queued". Since then: total-return default-on (#3184, #3222), #3282, #3283, and the record moves rb1 → N (#3261, re-confirmed by #3397). **5th cycle.**
- **data-foundations** — dated 10-11. #3261, #3280, #3297 and #3301 (last cycle) and #3339 and #3343 (this cycle) are not recorded. 2nd cycle.
- **trade-audit** — dated 10-03, with the heading at `READY_FOR_REVIEW`. #3296 and six review-pack PRs this week are not recorded. 3rd cycle.
- **rename-twin-dedup** — dated 09-16. Its first Next Step, "Rebuild the PIT union warehouse with `-twin-require-direct-match`", is partly overtaken by #3391's whole-universe twin scan on pit-v12. 4th cycle.
- **Index rows naming shipped work, 5th cycle:**
  - `backtest-infra`: "#2984 open", though it was closed by #3121 on 10-04;
  - `support-floor-stops`: "next: UNSET";
  - `backtest-perf`: names #2899 and #2896, both shipped.
- **Status mismatches:** `tax-lens` (file `READY_FOR_REVIEW`, index `MERGED`), `post-run-validation` and `trade-audit`.

Carried unchanged, with files untouched for 30+ days: `cash-floor-correctness`, `tuning`, `extension-stop`, `tuning-methods`, `spy-only-reference`, `weekly-snapshot`, `floor-quality`, `rolling-start-lens`, `sweep-perf`, `stage-accuracy`, `orchestrator-automation`.

Resolved since last cycle: none.

## [info] items needing decision (P3)

`_index.md` carries no `[info]` tags. The items below come from the daily summaries' "Questions for You" sections (10-18 … 10-24, 9 summaries).

- **Harness T1 queue is empty: should the orchestrator pull T3-C or T3-H, or stay finding-driven?**
  - Carried since **2026-10-20** across **7 reconciles** (10-20-run2, 10-21, 10-22, 10-22-run2, 10-23, 10-23-run2, 10-24).
  - Every run since is UNDER_TARGET.
  - Recommended action: ESCALATE_TO_MAINTAINER.
- **Codify "write the summary skeleton before dispatch, dispatch in the foreground, publish via trap" in `lead-orchestrator.md` Step 4/8?**
  - Carried since **2026-10-21** across **6 reconciles**.
  - The orchestrator cannot make the edit itself (`.claude/agents/**` writes are refused).
  - Urgency rose on 10-24: run 40092257921 lost its summary, and the Daily orchestrator workflow went RED. That is the second RED this week, after 10-21.
  - Recommended action: ESCALATE_TO_MAINTAINER.
- **`linter_coverage` test-file policy.** Listed as "needs a decision" in the cleanup Next Steps in every summary since 10-20 (≥7 reconciles). It is one of the only two items left in the cleanup queue. Recommended action: ESCALATE_TO_MAINTAINER.
- **Same-SHA verdict ranking (H-GATE-TWO-VERDICTS-ONE-SHA) and QC carryover across a merge-from-main tip.**
  - Open since **2026-09-28**.
  - After 10-18 it stopped appearing in "Questions for You", but no answer is recorded and the `harness.md` item is still `[ ]`.
  - It recurred on 10-23 (#3398: three verdicts at `4dd45cf7`).
  - Recommended action: ESCALATE_TO_MAINTAINER.
- **New, 1 reconcile: #3412 hit the rework cap on a test-only finding.** The ~8-line fixture is already written and verified in review 5639196887. The choice is to apply it locally or allow a third iteration. Recommended action: KEEP_AS_INFO; this is a 5-minute local fix.
- **Resolved:** whether to merge the weekly ops PRs (#3351–#3353, 10-20 Q1). All three merged 10-20.

## Tracks without owner (P4)
- No track was created in the last 14 days, and every non-MERGED row has an owner. PASS.
- Three active programmes have no index row: path stability (#3404), Codex/Jules delegation lanes, and the fresh-eyes study. Recommend booking each under a row so the reconciler sees its next step. Recommended action: KEEP_AS_INFO (fresh-eyes: 2nd cycle).

## Recurring discussion topics (P5)

`dev/decisions.md` has 0 entries in 30 days and was last modified 2026-05-15 (**163 days**), so P5 cannot run as specified. Recommend: ESCALATE_TO_MAINTAINER (7th ask: retire it or revive it). Read instead from the daily summaries, plans and ledger:

- **Delegation lanes / external agents.** This is the 2nd week running (#3316 last week). This week:
  - plans #3331 and #3338;
  - agent rules #3335 and #3336;
  - CI setup #3334;
  - lane board #3332 and #3367;
  - Codex quota #3378 and #3380.

  Codex hand-offs are still blocked on the #3324 environment trial (`async-lanes.md`). Recommend: RECOMMEND_NEW_TRACK, or home it under `orchestrator-automation`.
- **Orchestrator summary silent loss.** The defect class from `_index.md` (#2741 … #2850) recurred on 10-24 (run 40092257921), and the Daily orchestrator was RED on 10-21 too. The process fix is P3 item 2. Recommend: KEEP_AS_INFO until that is decided.
- **Record of record.** #3397 settled it: "N stays the record". `dev/backtest/DEEP_RESULTS.md` was last touched 2026-07-29 (**88 days**). Recommend: KEEP_AS_INFO; point it at the ledger entry or retire it.
- **Split / dividend correctness.** No new PRs this week; the theme is quiet after four straight weeks. Recommend: KEEP_AS_INFO (the M6.4 gap stays in P7).

## Diminishing returns (P6)

**Mechanical heuristic: 0 flags.**
- `cleanup`, last 5 (#3414, #3411, #3402, #3399, #3390): 0 hits on the listed keywords.
- `harness`, last 5 (#3401, #3398, #3389, #3385, #3380): 0 hits.
- `trade-audit`, last 5: 0 hits.
- PASS.

**Qualitative flag: KEEP_AS_INFO.**
- **cleanup:** all five of its last PRs follow one template, "pin a config thread; drop an expired adapter exception". Only two items remain: the `decision_grading_bin.exe` runner test and the `linter_coverage` decision.
- **harness:** its last five are parser nits, word-boundary pins and gitignore negation forms. The orchestrator itself reports the T1 queue as empty.

Both lanes are close to winding down. Their dispatch slots would do more if the maintainer un-fenced a feature item, or answered P3 item 1, than if they kept generating small follow-ups.

## Capability gaps (P7)
- **Shorts close-out decision (a) vs (c), and Rule 4 for the four short-only flags.** Second cycle with no movement. Milestone: M7. Mentioned in: `short-side-strategy` and the 10-13 handoff §3. Recommend: ESCALATE_TO_MAINTAINER.
- **Weekly live-picks run: 72 days stale, 10 Fridays missed** (08-21 … 10-23).
  - The newest record is `dev/weekly-picks/f88c277d5/2026-08-14.sexp`.
  - Mentioned in: `weekly-snapshot`, `arc-readiness`, `decision-audit`. Milestone: M6.
  - Recommend: ESCALATE_TO_MAINTAINER (10th cycle).
- **Promoted resistance bundle (#2047, default-on) not certified on record N** (re-confirmed by #3397). Recommend: ESCALATE_TO_MAINTAINER (13th cycle).
- **M6.4 split/dividend verification harness**: no owning track. Milestone: M6. Recommend: ESCALATE_TO_MAINTAINER (7th cycle).
- **`tuning` M2 enable-commit (#1327), 152 days.** Milestone: M7. Recommend: ESCALATE_TO_MAINTAINER (14th ask).
- **`sweep-perf` ghcr.io flambda rebuild, 134 days.** Recommend: ESCALATE_TO_MAINTAINER (13th ask).
- **[NEW] Weekly perf and usage review lapsed.**
  - `backtest-perf.md` §Weekly review was last written **2026-10-05**, so two weeks have been missed.
  - `cost-tracking.md` has no §Usage review row for October.
  - The newest local spend record is `dev/budget/local-2026-10-13.json`, so local sessions since 10-13 are not recorded (`session-rampup.md` §Maintenance).
  - Required by `perf-review-weekly.md` and `issue-hygiene.md` C. Recommend: ESCALATE_TO_MAINTAINER.
- **[NEW] Path-stability Step 2 chain (#3404).** It is pre-registered (#3408) and needs a local 26y run. Its decision rule ends in a user promotion decision. Recommend: KEEP_AS_INFO; schedule it in the next local session.
- **`arc-readiness` A2-4** (picks chart): dispatchable, ~65 days behind plan. Recommend: KEEP_AS_INFO.

Resolved since last report:
- **Combined verify chain (last week's recommendation 4):** run as chain V (#3342 → #3383) plus the #3266 rerun (#3393 → #3397). #3174 was read, and #3263, #3173 and #3266 were satisfied. RESOLVED in part: #3183 and #3206 were not in chain V's scope and remain open.

Follow-up accumulation: **60** open `- [ ]` items in `dev/status/` (63 last week). KEEP_AS_INFO.

## Recommendations
1. **Decide the shorts close-out (a) or (c).** This is the 2nd cycle. The track has had no PR in 12 days and nothing else can move it.
2. **Answer the orchestrator-process questions in one pass:** the T3-C/T3-H pull (7 reconciles), the summary-skeleton codification in `lead-orchestrator.md` (6 reconciles; it lost a summary on 10-24), the `linter_coverage` policy, and the same-SHA ranking rule (it recurred on 10-23). These four answers are what stand between the GHA lane and useful work.
3. **Apply the 8-line fixture to #3412 locally** (review 5639196887) and merge it after re-QC. It closes the 10-23 run-numbering collision.
4. **File one docs-only reconcile PR.** It should cover:
   - `screener.md`'s four stale state tokens (#3406, #2685, #2563, #3067);
   - `simulation` (5th cycle);
   - `short-side-strategy`;
   - `data-foundations`;
   - `trade-audit`, including the review-pack PRs;
   - `rename-twin-dedup` (#3391);
   - `post-run-validation`;
   - the three stale index rows and three status mismatches;
   - rows for path stability, delegation lanes and fresh-eyes.

   This is the 4th report to recommend it.
5. **Do the weekly perf/usage review** (2 weeks lapsed), and backfill `budget_local_record.sh --date` for local sessions since 10-13.
6. **Run the path-stability Step 2 chain (#3408) locally**, along with #3183 and #3206 if they fit in the same container window.
7. **Unblock the one-action human gates:** `tuning` #1327 (152 days) and the `sweep-perf` flambda rebuild (134 days).
8. **Decide the weekly-picks cadence** on the record-N config: automate it, or de-scope M6.6. It is 72 days and 10 Fridays behind.
9. **Assign M6.4 an owner** (7th ask), and close or re-scope `tuning-methods` (154 days) and `spy-only-reference` (144 days).
10. **Retire or revive `dev/decisions.md`** (163 days), and point `DEEP_RESULTS.md` at the record-N ledger entry.

## Stats
- **79 PRs merged in last 7d** (commits after `3e61cc48`, 10-18 → 10-24; main at `f9bec08b`).
  - By prefix: 18 `ops`, 14 `harness`, 11 `docs`, 6 `test`, 6 `fix`, 6 `feat`, 5 `refactor`, 5 `cleanup`, 4 `experiment`/`exp`, 2 `results`, 1 `data`, 1 `chore`.
  - This includes last week's pacer (#3319).
- **359 PRs merged in last 30d.**
- 7 tracks active / 7 slowing / 11 stalled, out of 25 non-MERGED rows (10 / 4 / 11 last cycle).
- 4 `[info]` items carried ≥3 reconciles: the T3 pull (7), summary-skeleton codification (6), `linter_coverage` (≥7), same-SHA ranking (since 09-28).
- 8 capability gaps flagged (2 new); 1 resolved in part (verify chain V).
- **Orchestrator spend 10-18 … 10-24:** 14 runs, **$159.29** total; the largest run was $24.52 (10-20). There were two RED orchestrator days (10-21, and 10-24 run 40092257921, which lost its summary).
- Ledger: no new `_ledger/` entry this week. The newest entries are from 10-13. Chain V and the #3266 rerun landed as results PRs (#3383, #3397).
- Weekly deep health scan, prune-candidates and the BAH SPY sweep all ran 10-19 (#3352, #3353, #3351), merged 10-20.
- The newest `dev/weekly-picks/` record is **72 days** old; `DEEP_RESULTS.md` is **88 days** old; `dev/decisions.md` is **163 days** old; the perf §Weekly review is **20 days** old.
- **60** open `- [ ]` follow-ups in `dev/status/`.
- **Method note:** `gh` was not used. PR facts come from merge-commit subjects on `main`. Track attribution is by subject keyword and is approximate for cross-cutting work (review pack under trade-audit, verify chain under data-foundations, lanes under harness).

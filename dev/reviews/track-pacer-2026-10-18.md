# Track Pacer Report — 2026-10-18

## Summary
- Tracks audited: 50 index rows. Cadence was run on the 25 non-MERGED rows (24 IN_PROGRESS, 1 PENDING). The 25 MERGED rows are exempt. No row changed status this week.
- Active (≥1 PR last 7d): 10
- Slowing (7–30d since last PR): 4
- Stalled (>30d): 11 (10 IN_PROGRESS, plus `tuning-methods`, which is PENDING and parked)
- `[info]` items needing decision: 1 (may QC verdicts carry across a merge-from-main-only tip change, and may "latest verdict at the same SHA wins" be applied mechanically? Carried since 09-28)
- Capability gaps flagged: 7 (1 new, 6 carried; 2 resolved since last report)

**Headline 1: the week had two halves, and the second was a quota outage.**
- 10-11 → 10-13: 61 PRs merged.
- 10-14 → 10-17: no code PR merged. Main got only `ops(budget)` records (#3308–#3315), and seven of the eight orchestrator runs record `total_cost_usd: 0`.
- Cause, from #3316 and `dev/plans/delegation-lanes-2026-10-18.md`: the fresh-eyes forward pass used up the weekly plan quota in under a day (10-14/15). The 10-17 orchestrator run failed, and every session was blocked until the 10-18 reset.
- After 10-13 there is no `dev/daily/` summary, and `_index.md` is still dated 10-13.
- #3316 (10-18) shipped the fix: a quota tracker, a 15 % management reserve, `--guard` for batch jobs, and a `where_is_work.sh` dashboard. This is the first week that throughput was bound by quota rather than by container capacity or gating.

**Headline 2: the shorts programme has finished its evidence, and the track has not been closed.**
- Four no-build or close results landed this week:
  - #3265, index hedge: 0 of 9 cells escalate.
  - #3273, score threshold: a stricter score does not help.
  - #3286, short setup map: no edge over 45,599 breakdowns.
  - #3294, wide-top screen: CLOSE by its pre-registered rule.
- #3294 was option (b) of the 10-13 handoff §3, so (b) is used up. What remains is (a) close or (c) idle.
- `short-side-strategy.md` was last updated **10-06**, and its index row still reads "next: short-leg regime-P&L decomposition (LOCAL)". This is the 2nd cycle.

**Headline 3: the status layer is still not reconciled.**
- Recommendation 1 of the last two reports, a single reconcile PR, has not been acted on.
- This week only `harness.md`, `cleanup.md` and `data-foundations.md` (#3252) were touched.
- None of this week's feature PRs (#3252, #3254, #3256, #3261, #3280, #3282, #3283, #3286, #3294, #3296, #3297, #3301) is cited by number in any `dev/status/*.md` file.

## Active tracks (≥1 PR last 7d)
- **harness** — 14 PRs, 3 of them review-pack PRs also listed under trade-audit.
  - PRs: #3236, #3246, #3248, #3253, #3255, #3258, #3268, #3279, #3281, #3285, #3289, #3300, #3303, #3316.
  - Theme: audit-test trap pins (#3236, #3246, #3248, #3258); the report_conjuncts slices 1–3 (#3268, #3289, #3303); standing rules moved into agent definitions (#3285); issue-hygiene tooling (#3279); the `wait_for.sh` background wait (#3300, #2738); quota and lane tooling (#3316).
- **cleanup** — 6 PRs (#3235, #3247, #3249, #3269, #3304, #3307), plus twin and shiller test pins booked in `cleanup.md` (#3257, #3288, #3290).
  - Theme: tests for the tuner CLI helpers, the shiller chart MA label, and a file-length split (#3307).
- **short-side-strategy** — 4 results PRs (#3265, #3273, #3286, #3294) and 4 pre-registration PRs (#3251, #3274, #3278, #3299).
  - Theme: every screen came back no-build or close. The programme is at a terminal decision point (see P2 and P7).
- **data-foundations** — 5 PRs (#3252, #3261, #3280, #3297, #3301).
  - Theme:
    - the full NYSE A-D breadth fixture and interior-gap fill (#3252);
    - the record rerun on that fixture, where N replaces rb1 (#3261);
    - a default-off symbol-class filter (#3280);
    - rejecting unconfirmed split factors (#3297);
    - true-dollar dollar-ADV, default-off (#3301).
  - The file was touched by #3252 (10-11); #3261, #3280, #3297 and #3301 are not recorded.
- **trade-audit** — 5 PRs (#3296, plus review-pack #3253, #3255, #3281, #3295).
  - Theme: `No_structural_stop` rows carry the floor kind and distance (#3296), and the review pack gained signal cards and the #3262 fixes.
- **simulation** — 2 PRs (#3282, #3283).
  - Theme: a stop beats a same-day margin cover, behind a default-off flag (#3282, #3206); weekly bars are keyed on the ISO week-year (#3283, #3266). #3283 merged 10-13 after carrying `do-not-merge` earlier that day.
- **backtest-infra** — 3 PRs (#3256, #3292, #3293).
  - Theme: an explicit split event keeps the `trades.csv` stop columns on one basis (#3256); income flag defaults pinned (#3292); nightly and local golden scenarios covered (#3293, #2650).
- **rename-twin-dedup** — 2 test PRs (#3257, #3288), both booked under `cleanup.md`. No track-level progress: the "arm the guards on a PIT rebuild" item is still open.
- **screener** — 1 PR (#3254: holiday-Friday weeks screened on their last trading day, default-off, #3139).
- **backtest-perf** — 1 docs PR (#3264, perf ledger in the 10-12 handoff). This is ledger upkeep only; the last code PR is #2965 (09-25). The weekly perf/usage review was not done this week (10-13 handoff §2.2).

## Slowing tracks (7–30d since last PR)
- **support-floor-stops** — last PR #3193 was 10 days ago (10-08); theme: the dividend stop adjustment. #3296 (audit floor kind) is adjacent work. The index row still says "next: UNSET" (4th cycle). Recommendation: KEEP_AS_INFO; set a next task or close.
- **arc-readiness** — last PR #3142 was 13 days ago (10-05); theme: macro-suspend (dilutes, no phase 2). The file is dated 09-26 and does not record #3123, #3128 or #3142. A2-4 has not been dispatched. Recommendation: KEEP_AS_INFO.
- **orchestrator-automation** — last PR #3226 was 9 days ago (10-09); theme: summary-date strictness. The file is dated 09-04. This week's orchestrator work (#3285, #3300, #3316) was booked to harness. Recommendation: KEEP_AS_INFO.
- **post-run-validation** — last PR #3051 was 18 days ago (09-30). The file's heading reads `READY_FOR_REVIEW` while the index reads `IN_PROGRESS` (3rd cycle). Recommendation: KEEP_AS_INFO; refresh the file.

## Stalled tracks (>30d since last PR)
- **weekly-snapshot** — last booked PR #2453 at 2026-08-20 (59 days). Last week this was listed as slowing; it is reclassified here by its booking date.
  - Reason: M6.4-class split work keeps landing on other tracks. This week: #3256, #3283, #3297.
  - Recommendation: ESCALATE_TO_MAINTAINER (6th ask).
- **stage-accuracy** — last PR #2450 at 2026-08-20 (59 days); reason: broad-universe WF-CV is data-gated; recommendation: KEEP_AS_INFO.
- **resistance-v2** — last PR #2145 at 2026-07-28 (82 days); reason: WF-CV vs w30 is LOCAL.
  - The record basis moved again this week (#3261: N replaces rb1, on the full breadth fixture). The default-on bundle has still never been certified on it.
  - Recommendation: ESCALATE_TO_MAINTAINER (10th cycle).
- **tuning** — last PR #2113 at 2026-07-27 (83 days); reason: the M2 enable-commit (#1327, filed 2026-05-26, **145 days** ago); recommendation: ESCALATE_TO_MAINTAINER (13th ask).
- **extension-stop** — last PR #1960 at 2026-07-13 (97 days); reason: the R3 flip is human-gated; recommendation: KEEP_AS_INFO.
- **floor-quality** — last PR #1913 at 2026-07-10 (100 days); reason: deep-warehouse, LOCAL; recommendation: KEEP_AS_INFO.
- **rolling-start-lens** — last PR ~#1648 at 2026-06-18 (122 days); reason: LOCAL / data-gated; recommendation: KEEP_AS_INFO.
- **cash-floor-correctness** — last PR #1582 at 2026-06-14 (126 days); reason: NS2 is human-gated and NS4 is data-gated; recommendation: KEEP_AS_INFO.
- **sweep-perf** — last PR #1574 at 2026-06-13 (127 days); reason: the manual ghcr.io flambda rebuild; recommendation: ESCALATE_TO_MAINTAINER (12th ask).
- **spy-only-reference** — last booked PR #1438 at 2026-06-03 (137 days); reason: item 1 is an open question that was never dispatched; recommendation: ESCALATE_TO_MAINTAINER (6th ask). Close the track, or re-home #3130 as the benchmark record.
- **tuning-methods** (PENDING) — no PR ever; file last updated 2026-05-24 (147 days); recommendation: ESCALATE_TO_MAINTAINER — close or re-scope (6th ask).

## Next Steps staleness (P2)
- **short-side-strategy** — the file is dated 10-06. The index row's next task, "short-leg regime-P&L decomposition (LOCAL)", has been overtaken by #3237, #3265, #3273, #3286 and #3294 (all Reject, no-build or close). 2nd cycle. Recommend refreshing it, or recording the (a)/(c) decision once the maintainer makes it.
- **simulation** — `Last updated: 2026-09-02`, with the row reading "next: none queued". Since then: total-return default-on (#3184, #3222), #3282 and #3283 this week, and the record moving rb1 → N (#3261). **4th cycle.**
- **data-foundations** — `Last updated: 2026-10-11`. #3261, #3280, #3297 and #3301 are not recorded. The row's next task is still "arm ATB.curated … + General::Type enrichment"; #3280's symbol-class filter overlaps it.
- **trade-audit** — `Last updated: 2026-10-03`. The file heading reads `READY_FOR_REVIEW` while the index reads `IN_PROGRESS`. #3195–#3207 (last cycle) and #3296 (this cycle) are not recorded. 2nd cycle.
- **rename-twin-dedup** — `Last updated: 2026-09-16`; the first Next Step is "Rebuild the PIT union warehouse with `-twin-require-direct-match`". The file does not record whether the v12 build armed it. 3rd cycle.
- **Index rows naming shipped work, 4th cycle:**
  - `backtest-infra`: "#2984 open"; it was closed by #3121 on 10-04.
  - `support-floor-stops`: "next: UNSET".
  - `backtest-perf`: names #2899 and #2896, both shipped.
- **Status mismatches:** `tax-lens` (file `READY_FOR_REVIEW`, index `MERGED`), `post-run-validation` and `trade-audit`.

Carried unchanged, with files untouched for 30+ days: `cash-floor-correctness`, `tuning`, `extension-stop`, `tuning-methods`, `spy-only-reference`, `weekly-snapshot`, `floor-quality`, `rolling-start-lens`, `sweep-perf`, `stage-accuracy`, `orchestrator-automation`.

Resolved since last cycle: none.

## [info] items needing decision (P3)

`_index.md` itself carries no `[info]` or `[critical]` tags. The item below comes from the daily summaries' "Questions for You" sections.

- **May QC verdicts carry across a merge-from-main-only (or rebase-only) tip change? And may "latest verdict at the same SHA wins" be applied mechanically (H-GATE-TWO-VERDICTS-ONE-SHA)?**
  - Carried since **2026-09-28**. It was re-raised in `dev/daily/2026-10-11.md` Q1, `2026-10-11-run2.md` Q1 and `2026-10-12.md` Q1, after 10-06, 10-08 and 10-09 last week. That is ≥6 reconciles.
  - 10-11-run2 records that this question now blocks the top harness item. The orchestrator stopped filling harness work because "the remaining harness items need a maintainer decision".
  - The cost is ~210k tokens per re-QC instance, and a week like this one has no quota to spare for that.
  - Recommended action: ESCALATE_TO_MAINTAINER.
- **Resolved:** #3283 `do-not-merge` (10-13 Q1). It merged the same day.
- **Resolved:** #3259 opam weekly bump, which needed a human merge (10-12). It merged 10-13.
- **Not verifiable, KEEP_AS_INFO:** orchestrator summary loss. There are no 10-14 … 10-17 summaries, but #3316 attributes that window to quota exhaustion, not to the defect class in `_index.md`. Check that the next run writes its summary.

## Tracks without owner (P4)
- No track was created in the last 14 days, and every non-MERGED row has an owner. PASS.
- Note: the **fresh-eyes Weinstein study** is a new programme with no index row. It has had 6 PRs since 10-13: plan #3298, steps #3302 and #3306, forward pass #3317, staged plan `dev/plans/fresh-eyes-staged-2026-10-18.md`, and the tooling in #3316. It is the workload that drained the quota. Recommend adding a row or booking it under an existing track, so its next stage is visible to the reconciler. Recommended action: KEEP_AS_INFO.

## Recurring discussion topics (P5)

`dev/decisions.md` has 0 entries in 30 days and was last modified 2026-05-15 (**156 days**), so P5 cannot run as specified. Recommend: ESCALATE_TO_MAINTAINER (6th ask: retire it or revive it). Read instead from the handoffs, the ledger and the daily summaries:

- **Record of record.** In two weeks the record went rb1 (#3219) → N on the full A-D fixture (#3261, ledger `2026-10-12-breadth-fix-rb1-record-baseline`). `dev/backtest/DEEP_RESULTS.md` was last touched 2026-07-29 (**81 days**). Recommend: KEEP_AS_INFO. Point `DEEP_RESULTS.md` at the ledger entry, or retire it.
- **Split / dividend correctness.** This is the 4th week running. This week: #3256, #3283, #3297 (and #3278, dividend splits in the setup map). Previous weeks: #3181, #3191, #3193, #3222, #2987, #3071, #3105, #3108, #3143. Recommend: RECOMMEND_NEW_TRACK, or re-home it under `weekly-snapshot` M6.4 (5th ask).
- **Quota and delegation lanes.** New this week: #3316 and `delegation-lanes-2026-10-18.md`, which proposes a Codex cloud spike and options for running Claude via an API key in GHA. It is a single episode so far. Recommend: KEEP_AS_INFO. If the lanes work continues, it belongs under `orchestrator-automation` or `cost-tracking`.

## Diminishing returns (P6)

**Mechanical heuristic: 0 flags.**
- `harness`, last 5 (#3316, #3303, #3300, #3289, #3285): 0 hits.
- `cleanup`, last 5 (#3307, #3304, #3290, #3288, #3269): 1 hit (#3290, "golden stdout test").
- `short-side-strategy`, last 5: 0 hits.
- PASS.

Last week's qualitative concern about the harness flag-drift and audit-20d pin chain has eased. This week's harness work includes new surface: `wait_for.sh`, standing rules, issue-hygiene tooling and the quota tooling. The report_conjuncts slices 1–3 (#3268, #3289, #3303) are test-assertion refactors; they are worth capping once slice 3's scenarios are done. Recommended action: KEEP_AS_INFO.

## Capability gaps (P7)
- **[NEW] Shorts close-out decision (a) vs (c), and Rule 4 for the short flags.**
  - Option (b) was used up by #3294.
  - If (a): a ledger amendment marks the single-name short book REJECT-do-not-revive. The four short-only flags then become Rule-4 retirement candidates after 3 unused sessions: `short_min_price_on_order_price`, `share_class_gate_covers_shorts`, `margin_config.short_maintenance_finra`, `short_tightened_ratchet_follows_decline`. `enable_short_side`, which is default true and drives the live "Short candidates", needs its own R3 default-flip PR.
  - Milestone: M7. Mentioned in: `short-side-strategy` and handoff §3.
  - Recommend: ESCALATE_TO_MAINTAINER.
- **M6.4 split/dividend verification harness** — no owning track; 6th cycle (see P5). Milestone: M6. Recommend: ESCALATE_TO_MAINTAINER.
- **Weekly live-picks run — 65 days stale, 9 Fridays missed** (08-21 … 10-16).
  - The newest record is `dev/weekly-picks/f88c277d5/2026-08-14.sexp`.
  - Mentioned in: `weekly-snapshot`, `arc-readiness`, `decision-audit`. Milestone: M6.
  - The record config has changed twice since then (total return; full breadth, record N).
  - Recommend: ESCALATE_TO_MAINTAINER (9th cycle).
- **Promoted resistance bundle (#2047, default-on) not certified on the current record (N, #3261).** Recommend: ESCALATE_TO_MAINTAINER (12th cycle).
- **`tuning` M2 enable-commit (#1327), 145 days.** Milestone: M7. Recommend: ESCALATE_TO_MAINTAINER (13th ask).
- **`sweep-perf` ghcr.io flambda rebuild, 127 days.** Recommend: ESCALATE_TO_MAINTAINER (12th ask).
- **`arc-readiness` A2-4** (picks chart) — dispatchable and ~58 days behind plan. Recommend: KEEP_AS_INFO.

Resolved since last report:
- **A-D breadth 2000–2016 (#3238):** fixed by #3252 (10-11). The paired record read is #3261 (10-12): "N replaces rb1". RESOLVED.
- **Shorts index-hedge screen (handoff §3, option (a) of 10-11):** run as #3265, a no-build. RESOLVED; superseded by the new item above.

Verify/pending items waiting on local runs (10-13 handoff §2.3): #3183 (#3280 membership effect), #3206 (#3282 paired record run) and #3174 (26y TR axis read). They are candidates for one combined chain. KEEP_AS_INFO.

Follow-up accumulation: **63** open `- [ ]` items in `dev/status/` (70 last week). KEEP_AS_INFO.

## Recommendations
1. **Decide the shorts close-out (a) or (c).** Option (b) was run and closed (#3294). Then record the ledger amendment and update `short-side-strategy.md` and its row.
2. **Answer the QC-carryover and same-SHA questions** (open since 09-28, ≥6 reconciles). They now block the top harness item, and each re-QC costs ~210k tokens in a quota-bound week.
3. **File one docs-only reconcile PR.** It should cover:
   - `simulation` (4th cycle);
   - `short-side-strategy`;
   - `data-foundations` (#3261, #3280, #3297, #3301);
   - `trade-audit`;
   - `rename-twin-dedup`;
   - `post-run-validation`;
   - the three stale index rows (4th cycle) and three status mismatches;
   - a row for the fresh-eyes study.

   This was recommendation 1 in the last two reports and has not been acted on.
4. **Run the combined verify/pending chain** (#3183, #3206, #3174) locally under the new quota guard. Then close or comment on the issues per `issue-hygiene.md` B.
5. **Do the weekly perf/usage review.** It was skipped this week. Add the quota log from #3316 to §Usage review, since quota was this week's binding constraint.
6. **Assign M6.4 an owner** and link the split/dividend PRs (#3256, #3283, #3297 plus earlier ones). This is the 6th ask.
7. **Unblock the two one-action human gates**: `tuning` #1327 (145 days) and the `sweep-perf` flambda rebuild (127 days).
8. **Decide the weekly-picks cadence** on the record-N config: automate it, or de-scope M6.6. It is 65 days and 9 Fridays behind.
9. **Close or re-scope the parked tracks**: `tuning-methods` (147 days, never shipped) and `spy-only-reference` (137 days).
10. **Point `DEEP_RESULTS.md` at the record-N ledger entry, or retire it; retire or revive `dev/decisions.md`** (156 days).

## Stats
- **70 PRs merged in last 7d** (69 excluding last week's pacer, #3244).
  - By prefix: 18 `ops` (8 of them $0 or quota-window budget records), 14 `harness`, 8 `experiment(s)`, 6 `fix`, 6 `cleanup`, 5 `feat`, 5 `plan(s)`, 4 `test`, 2 `docs`, 1 `rules`, 1 `chore`.
  - 61 merged 10-11 … 10-13; 3 merged 10-18; 10-14 … 10-17 had budget records only.
- **353 PRs merged in last 30d.**
- 10 tracks active / 4 slowing / 11 stalled, out of 25 non-MERGED rows (13 / 2 / 10 last cycle).
- 1 `[info]` item carried ≥3 reconciles (QC carryover / same-SHA verdicts, since 09-28).
- 7 capability gaps flagged (1 new); 2 resolved (#3238 breadth, index-hedge screen).
- **Orchestrator budget records 10-11 … 10-17:** 10-12 $4.31, 10-13 $8.70, 10-14 $5.80, then seven runs at $0.00 (10-14 … 10-17, quota-blocked per #3316). The newest `dev/daily/` summary is 10-13; `_index.md` was last updated 10-13.
- Ledger entries this week: breadth-fix record N (#3261), index-hedge screen (#3265), short setup map (#3286), short wide-top (#3294).
- Weekly deep health scan and prune-candidates ran 10-12 (#3270, #3271). Weekly-start sweep: #3267 (10-13).
- The newest `dev/weekly-picks/` record is **65 days** old; `DEEP_RESULTS.md` is **81 days** old; `dev/decisions.md` is **156 days** old.
- **63** open `- [ ]` follow-ups in `dev/status/`.
- **Method note:** `gh` was not used. PR facts come from merge-commit subjects on `main` (window 2026-10-11 10:40 → 2026-10-18, main at `3e61cc48`). Track attribution is by subject keyword and is approximate for cross-cutting work (review pack, split/dividend, harness vs orchestrator).

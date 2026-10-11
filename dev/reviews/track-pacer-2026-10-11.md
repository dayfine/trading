# Track Pacer Report — 2026-10-11

## Summary
- Tracks audited: 50 index rows. Cadence was run on the 25 non-MERGED rows (24 IN_PROGRESS, 1 PENDING). The 25 MERGED rows are exempt.
- Active (≥1 PR last 7d): 13
- Slowing (7–30d since last PR): 2
- Stalled (>30d): 10 (9 IN_PROGRESS, plus `tuning-methods`, which is PENDING and parked)
- `[info]` items needing decision: 1 (may QC verdicts carry across a rebase-only tip change? Carried since 09-28)
- Capability gaps flagged: 8 (2 new, 6 carried; 2 of last week's resolved)

**Headline 1: two programmes ended this week, and the status layer recorded neither.**
- **Total-return accounting is now the record basis.** It shipped as cash yield (#3156, default-on via #3184), dividend crediting (#3160, default-on via #3222), the dividend stop adjustment (#3193), dividends in `trades.csv` (#3197), and the 26y re-baseline rb1 (#3219: "rb1 … is the record").
- **Single-name shorts are stopped.** #3237 (10-11): "round 1 fails; stop single-name shorts". Ledger entry `2026-10-10-shorts-phase-b-round1.sexp` has verdict Reject.
- Gaps in the status layer:
  - `short-side-strategy.md` still ends with "Next: Phase B v0 arm sets all three flags on".
  - Its index row still reads "next: short-leg regime-P&L decomposition (LOCAL)".
  - `simulation.md`, where the total-return work belongs, was last touched **2026-09-02**. Its row reads "next: none queued". This is the 3rd cycle.

**Headline 2: the reconciler only reconciles two rows.**
- Every orchestrator run this week (10-04, 10-06 ×2, 10-08, 10-09 ×2) rewrote the `harness` and `cleanup` rows and nothing else.
- The rows already flagged stale last week are unchanged: `backtest-infra` still says "#2984 open" (closed by #3121, 10-04), `support-floor-stops` still says "next: UNSET", and `backtest-perf` still names shipped #2899/#2896. This is the 3rd cycle for all three.
- Recommendation 1 of the last report (one reconcile PR) was not acted on.

**Headline 3: throughput held at 93 PRs, and work shifted from feature tracks to infrastructure and data.**
- 51 PRs (55 %) were code-bearing.
- The new work clustered on four subjects:
  - income accounting (#3137)
  - the true-dollar-volume PIT v12 universe (#3136, #3164, #3182, #3198)
  - shorts Phase B
  - the review pack (6 PRs)
- None of the five long-running human gates moved:
  - tuning #1327
  - sweep-perf flambda
  - weekly picks
  - `dev/decisions.md`
  - `DEEP_RESULTS.md`

## Active tracks (≥1 PR last 7d)
- **harness** — 14 PRs (#3113, #3116, #3117, #3122, #3162, #3163, #3167, #3169, #3210, #3211, #3226, #3229, #3231, #3232).
  - Theme: usage telemetry by model (#3113, #3117, #3163); flag-drift linter region pins (#3162, #3167, #3211, #3231); audit-script pins (#3169, #3210, #3229); summary-date strictness (#3226, #3232).
  - Branch `harness/audit-test-trap-and-20d-alias` (10-10) is on origin and was not merged in this window.
- **short-side-strategy** — ~9 PRs (#3133, #3135, #3157, #3159, #3166, #3201, #3220, #3221, #3237).
  - Theme: Phase A liveness, Phase B v0 fixes behind default-off flags, the book write-back on the short buy-stop trail (#3166), FINRA short margin (#3201), the v1 macro-cancel (#3221), and the round-1 result.
  - **The track reached a terminal verdict (Reject) on 10-11.**
- **simulation** (total return / income) — 7 PRs (#3156, #3160, #3184, #3191, #3193, #3202, #3222), plus the rb1 results chain (#3178, #3188, #3189, #3219, #3223).
  - Theme: cash yield and dividend crediting were built default-off, then flipped default-on.
  - The flips were recorded in `backtest-infra.md`. **`simulation.md` was not touched** (P2).
- **data-foundations** — 6 PRs (#3158, #3164, #3181, #3182, #3198, #3227).
  - Theme: an EODHD dividends and splits bulk fetcher, split-only dollar volume, PIT v12 lists, rejecting "splits" that are really cash dividends, and grouping `-WS` share classes.
  - Status file refreshed 10-07.
- **trade-audit** — 5 PRs (#3195, #3197, #3200, #3204, #3207), plus 6 review-pack PRs (#3134, #3192, #3196, #3199, #3203, #3205).
  - Theme: at-fill cash rejections recorded, a weekly decision record per top-N name, executed exit prices in stop audits (#3207, a Codex-authored PR), and a P&L-anatomy card in the review pack.
  - Status file last updated 10-03 (P2).
- **cleanup** — 4 `cleanup` PRs + 2 `refactor` PRs (#3115, #3161, #3168, #3212, #3228, #3233).
  - Theme: six file-length splits, each removing its linter exception rather than re-dating it.
  - Branch `cleanup/bayes-cli-dead-labels` (10-10) is on origin.
- **backtest-infra** — 3 PRs (#3121, #3143, #3190).
  - Theme: the live order path syncs broker stops (#2984 closed), and `entry_stop` is restated after a split.
- **arc-readiness** (macro-suspend) — 3 PRs (#3123, #3128, #3142).
  - Theme: the macro-suspend investor arm dilutes in 5d and 5r (no phase 2); a second read confirmed it; one fix for stashed tickets.
- **rename-twin-dedup** — 2 PRs (#3208, #3198), plus #3228 counted under cleanup.
  - Theme: clearing stale twin scans, and the v12 twin alias delta.
  - Status file not updated (P2).
- **support-floor-stops** (stops) — 2 PRs (#3120, #3193).
  - Theme: catastrophic exits carry their own reason, and the stop is reduced by the dividend on the ex-date.
- **screener** — 1 PR (#3133: short tickets anchored at the breakdown).
- **orchestrator-automation** — 1 PR (#3226: `verify` rejects a 1-day-stale summary, H-ORCH-SUMMARY-SILENT-LOSS a).
- **backtest-perf** — 2 ledger PRs (#3224, #3240).
  - Ledger upkeep after every chain, as `perf-review-weekly.md` asks. No code PR since #2965 (09-25).

## Slowing tracks (7–30d since last PR)
- **post-run-validation** — last validator PR was #3051 (~10 days ago, V19–V23 wave). The file is dated `2026-09-20` and its status heading reads `READY_FOR_REVIEW` while the index row reads `IN_PROGRESS`. Recommendation: KEEP_AS_INFO; refresh the file (2nd cycle).
- **weekly-snapshot** — last booked PR is #2453 (08-20, 52 days). M6.4-class split/dividend work keeps landing outside the track: this week #3181 (dividends mistaken for splits), #3191 (split guard forwarding), #3222 (`split_dividend_guard` default-on); last week #2987, #3071, #3105, #3108. Recommendation: ESCALATE_TO_MAINTAINER — book M6.4 to an owner (5th ask).

## Stalled tracks (>30d since last PR)
- **stage-accuracy** — last PR #2450 at 2026-08-20 (52 days); reason: broad-universe WF-CV is data-gated; recommendation: KEEP_AS_INFO.
- **resistance-v2** — last PR #2145 at 2026-07-28 (75 days); reason: WF-CV vs w30 is LOCAL. 10-04 the file recorded that the promoted bundle is live in `_v11pit` runs, so rb1 includes it. Recommendation: ESCALATE_TO_MAINTAINER (9th cycle): the default-on bundle has never been certified against the new total-return record.
- **tuning** — last PR #2113 at 2026-07-27 (76 days); reason: M2 qNEHVI is waiting on the maintainer enable-commit per #1327 (filed 2026-05-26, **138 days** ago); recommendation: ESCALATE_TO_MAINTAINER (12th ask).
- **extension-stop** — last PR #1960 at 2026-07-13 (90 days); reason: the R3 flip is human-gated, and its insurance-ACCEPT predates both the #2996 stop flags and the income accounting; recommendation: KEEP_AS_INFO.
- **floor-quality** — last PR #1913 at 2026-07-10 (93 days); reason: deep-warehouse, LOCAL; recommendation: KEEP_AS_INFO.
- **rolling-start-lens** — last PR #1645/#1648 at 2026-06-18 (115 days); reason: LOCAL / data-gated; recommendation: KEEP_AS_INFO.
- **cash-floor-correctness** — last PR #1582 at 2026-06-14 (119 days); reason: NS2 is human-gated and NS4 is data-gated. The cash-yield work (#3156/#3184) now earns interest on the same cash this track floors, but NS2 was not revisited. Recommendation: KEEP_AS_INFO.
- **sweep-perf** — last PR #1574 at 2026-06-13 (120 days); reason: the manual ghcr.io flambda rebuild; recommendation: ESCALATE_TO_MAINTAINER (11th ask).
- **spy-only-reference** — last booked PR #1438 at 2026-06-03 (130 days). #3130 (10-04, SPY 30-week MA + buy-and-hold on the 26y window) is adjacent work but was not booked here; item 1 is still "(Open question, not dispatched)". Recommendation: ESCALATE_TO_MAINTAINER (5th ask). Either close the track and re-home #3130 as the benchmark record, or decide item 1.
- **tuning-methods** (PENDING) — no PR ever; file last updated 2026-05-24 (140 days); recommendation: ESCALATE_TO_MAINTAINER — close or re-scope (5th ask).

## Next Steps staleness (P2)

Resolved since last cycle:
- `margin-realism` and `experiment-platform` were both closed to MERGED by #3129 (10-04), as recommended.
- `resistance-v2` was refreshed 10-04 (liveness on `_v11pit`).
- `short-side-strategy` was refreshed 10-06 (since overtaken; see below).
- `data-foundations` was refreshed 10-07.

Still stale:
- **short-side-strategy** — the file's last entry says "Next: Phase B v0 arm sets all three flags on". Both v0 and v1 ran, and #3237 (10-11) records a Reject and "stop single-name shorts". The index row still says "next: short-leg regime-P&L decomposition (LOCAL)". Recommend refreshing the file and row, and recording the Rule 4 question that the 10-11 handoff §2.1 raises (`enable_short_side` plus the four short-fix flags: index-hedge plumbing, or retire?).
- **simulation** — `Last updated: 2026-09-02`. Since then: #2963, #2967, #3022, #3108 (last cycle), plus #3156, #3160, #3184, #3193, #3222 and rb1 #3219 this week. The row says "next: none queued". **3rd cycle.**
- **trade-audit** — `Last updated: 2026-10-03`; #3195, #3197, #3200, #3204, #3207 merged since. The file heading reads `READY_FOR_REVIEW` while the index row reads `IN_PROGRESS`.
- **rename-twin-dedup** — `Last updated: 2026-09-16`. `## Next task` opens with "Rebuild the PIT union warehouse with `-twin-require-direct-match`". The PIT v12 build (#3182, #3198) and #3208 shipped without the file recording whether the guards were armed. 2nd cycle.
- **post-run-validation** — `Last updated: 2026-09-20`; 2nd cycle (see Slowing).
- **Index rows naming shipped work, 3rd cycle:**
  - `backtest-infra` says "#2984 open … next #2839". #2984 was closed by #3121 (10-04), and the file's top Next Step is still the 09-14 PIT migration, which shipped (#2808 … #2846, plus v12).
  - `support-floor-stops` says "next: UNSET".
  - `backtest-perf` names #2899 and #2896, both shipped.
- **Status mismatches:** `tax-lens` file `READY_FOR_REVIEW` vs index `MERGED`, plus the two above.
- **cleanup** — header still `Last updated: 2026-08-30` (content current). KEEP_AS_INFO.

Carried unchanged (files untouched): `cash-floor-correctness`, `tuning`, `extension-stop`, `tuning-methods`, `spy-only-reference`, `weekly-snapshot`, `arc-readiness` (file dated 09-26; macro-suspend #3123/#3128 not recorded). Recommend refreshing status files; this is the 5th cycle for the first six.

## [info] items needing decision (P3)

`dev/status/_index.md` carries zero `[info]` / `[critical]` tags. The items below come from the week's daily summaries.

- **May QC verdicts carry across a rebase-only or merge-from-main-only tip change?** Status: ESCALATE_TO_MAINTAINER.
  - Carried since **2026-09-28** as "Question 1". Re-raised 10-06, 10-08 (#3211, ~210k tokens re-QC), 10-09 (#3229, ~218k tokens, "test script was byte-identical") and 10-09-run2. That is ≥4 reconciles.
  - Each instance costs ~210k tokens. `pr-gate-loop.md` says "a rework commit invalidates every prior verdict" but is silent on rebase-only changes.
  - This needs one human answer, which the orchestrator then encodes.
- **Orchestrator summary loss** (last cycle's P3 item). Status: FLAG, ESCALATE_TO_MAINTAINER (verify run 38057014961).
  - 10-03 is still unexplained.
  - #3226 (10-09) hardened `verify` against stale-dated summaries.
  - **But run `38057014961` (10-10, $9.47) has a budget record (#3241) and no `dev/daily/2026-10-10*.md`**, while it left two unmerged branches on origin (`harness/audit-test-trap-and-20d-alias`, `cleanup/bayes-cli-dead-labels`). This could be an 8th instance, now after #3226.
  - The other no-summary days this week (10-05 $3.50, 10-07 $3.41/$2.54, 10-08 run 1 $2.72) are consistent with fast-exit costs.
- **qc-structural I1 false FAILs** (10-04 #3115, 10-06 #3160): the agent reads the commit message, not the PR body. Two reconciles; KEEP_AS_INFO.
- **REST PR-creation snippet in `lead-orchestrator.md` breaks on the image's python3** (10-06): one reconcile; KEEP_AS_INFO. Note that `.claude/rules/no-python.md` makes a python3 snippet in an agent definition questionable on its own.

## Tracks without owner (P4)

None. No track was created in the last 14 days, and every non-MERGED row has an owner. PASS.

Note: shorts Phase B, total-return accounting and PIT v12 were each real programmes this week, and none has its own row. They were booked against existing tracks (`short-side-strategy`, `backtest-infra`, `data-foundations`), which is acceptable. See P5 for the one that is not.

## Recurring discussion topics (P5)

`dev/decisions.md` has 0 entries in 30 days and was last modified 2026-05-15 (**149 days**), so P5 cannot run as specified. Recommend: ESCALATE_TO_MAINTAINER (5th ask: retire it or revive it). Scanning the live channels instead (handoffs, ledger, results PRs):

- **Record of record** — rb1 (#3219, v12, total return) is now declared the record. The topic is converging, but `dev/backtest/DEEP_RESULTS.md` was last touched 2026-07-29 (**74 days**) and does not carry it. Recommend: KEEP_AS_INFO (downgraded from RECOMMEND_NEW_TRACK). Either point `DEEP_RESULTS.md` at the rb1 ledger entry or retire the file.
- **Split / dividend correctness** — this is the 3rd week it has been the busiest unowned topic: #3181, #3191, #3193, #3222 this week; #2987, #3071, #3105, #3108, #3143 before that. It is spread over five tracks. Recommend: RECOMMEND_NEW_TRACK or re-home under `weekly-snapshot` M6.4 (4th ask).
- **Short side → index hedge** — Phase A (#3135), Phase B (#3220, #3237), and the 10-11 parked decision (index short when the macro gate is Bearish and SPY is in Stage 4). This is a programme decision, not a loop. Recommend: KEEP_AS_INFO until the maintainer answers handoff §3.
- **A-D breadth gap 2000–2016 (#3238)** — named the "highest-value next fix" in the 10-11 handoff. It affects the long record and the macro gate. It is a single new issue, so it is not recurring yet. Tracked under P7.

## Diminishing returns (P6)

**Mechanical heuristic: 0 flags.**
- `harness` last 5 (#3232, #3231, #3229, #3226, #3211): 0 hits on `chore|fix(linter)|golden|repin|fmt|format|ocamlformat`.
- `cleanup` last 5 (#3233, #3228, #3212, #3168, #3161): 0 hits.
- `short-side-strategy` last 5: 0 hits.
- PASS.

Qualitative flag on **harness** (KEEP_AS_INFO):
- 4 of its last 5 PRs pin regions of the **same two detectors**, `flag-drift` and the audit `20d` scenario.
- The index-row chain this week reads H-FLAG-DRIFT-REGION-PINS → USAGE-PIN → USAGE-SPECIFIC and H-AUDIT-RM-THEN-MV → 20D-ALIAS-PATHS → 20D-ONELINE-FN-ALIAS. Each PR closes a mutant the previous one left open.
- This is mutation-hardening of test scaffolding. It is cheap per item but has no new feature surface.
- Consider capping it, or batching the remaining pins, before it takes the bulk of the GHA harness budget.

## Capability gaps (P7)

- **[NEW] A-D breadth is missing for 2000–2016 in 26y runs (#3238).**
  - Mentioned in: 10-11 handoff §2.2, rb1, and the shorts index-hedge question (the macro gate keys on breadth).
  - Milestone: M7 (backtest validity).
  - Status: not started.
  - It affects the declared record (rb1) and every 26y verdict since the PIT migration.
  - recommend: ESCALATE_TO_MAINTAINER — fix it before any further 26y verdict run, then run a paired rb1 rerun.
- **[NEW] Shorts: index-hedge decision parked.**
  - Single-name shorts are Reject (#3237). The index-hedge screen is option (a) of the 10-11 handoff §3.
  - Open, rule-driven follow-up: Rule 4 retirement eligibility for `enable_short_side` plus the four Phase B flags (#3157, #3221).
  - Milestone: M7 (bear-market behaviour).
  - recommend: ESCALATE_TO_MAINTAINER — answer §3; if (c), sequence it behind #3238.
- **M6.4 split/dividend verification harness** — no owning track; 5th cycle (see P5). Milestone: M6. ESCALATE_TO_MAINTAINER.
- **Weekly live-picks run — 58 days stale, 8 consecutive Fridays missed** (08-21 … 10-09). The newest record is `dev/weekly-picks/f88c277d5/2026-08-14.sexp`. Mentioned in: `weekly-snapshot`, `arc-readiness`, `decision-audit`. Milestone: M6. ESCALATE_TO_MAINTAINER (8th cycle). The record basis also changed this week (total return, v12), so any resumed picks run needs the new config.
- **Promoted resistance bundle (#2047, default-on) not certified on the new record basis.** `DEEP_RESULTS.md` is 74 days old. ESCALATE_TO_MAINTAINER (11th cycle).
- **`tuning` M2 enable-commit (#1327) — 138 days.** Milestone: M7. ESCALATE_TO_MAINTAINER (12th ask).
- **`sweep-perf` ghcr.io flambda rebuild — 120 days.** `-O3` is still a silent no-op in CI. ESCALATE_TO_MAINTAINER (11th ask).
- **`arc-readiness` A2-4** (picks chart, plan #2453) — dispatchable and ~51 days behind plan. KEEP_AS_INFO.

Resolved since last report:
- **`short-side-strategy` liveness question:** decided by #3237 (Reject; single-name shorts stopped).
- **Index/status reconcile path:** partly resolved. #3129 closed two tracks, but rows are still not reconciled (see Recs).

Follow-up accumulation: **70** open `- [ ]` items in `dev/status/` (69 last week). KEEP_AS_INFO.

## Recommendations
1. **File one docs-only reconcile PR.**
   - Refresh `short-side-strategy` (Reject + Rule 4 note), `simulation` (total-return programme; 3rd cycle), `trade-audit`, `rename-twin-dedup` and `post-run-validation`.
   - Fix the three stale index rows (`backtest-infra`, `support-floor-stops`, `backtest-perf`; 3rd cycle) and the three status mismatches.
   - Recommendation 1 of the last report was not acted on, and the orchestrator reconciles only `harness` and `cleanup`.
2. **Answer the QC-carryover question** (rebase-only or merge-from-main-only tip changes). It has been open since 09-28 and costs ~210k tokens per instance; it was hit twice this week (#3211, #3229).
3. **Fix #3238 (A-D breadth 2000–2016) before the next 26y verdict run.** It affects the newly declared record.
4. **Decide the shorts follow-up** (handoff §3: index-hedge screen / close / defer behind #3238). Record which short flags stay as plumbing or retire under Rule 4.
5. **Check orchestrator run 38057014961 (10-10, $9.47)**: why it has no daily summary and two unmerged branches, after #3226.
6. **Assign M6.4 an owner** and link the split/dividend PRs (#3181, #3191, #3193, #3222 + earlier). 5th ask.
7. **Unblock the two one-action human gates**: `tuning` #1327 (138 days) and the `sweep-perf` flambda rebuild (120 days).
8. **Decide the weekly-picks cadence** under the new record config: automate it, or de-scope M6.6. 58 days, 8 Fridays missed.
9. **Close or re-scope the parked tracks**: `tuning-methods` (140 days, never shipped) and `spy-only-reference` (130 days; consider re-homing #3130 as the benchmark record).
10. **Point `DEEP_RESULTS.md` at rb1 or retire it; retire or revive `dev/decisions.md`** (149 days).
11. **Cap the harness pin chain** (flag-drift / audit-20d mutant pins) or batch what remains.

## Stats
- **93 PRs merged in last 7d**: 17 `ops`, 14 `harness`, 13 `feat`, 12 `docs`, 10 `fix`, 10 `experiment(s)`, 5 `review_pack`, 4 `cleanup`, 3 `test`, 3 `data`, 2 `refactor`. **51 (55 %) are code-bearing**, down from 60 %.
- **371 PRs merged in last 30d.**
- 13 tracks active / 2 slowing / 10 stalled, out of 25 non-MERGED rows (14 / 2 / 11 out of 27 last cycle; `margin-realism` and `experiment-platform` were closed to MERGED by #3129).
- 1 `[info]` item carried ≥3 reconciles (QC verdict carryover across rebase-only tip changes).
- **13 orchestrator budget records 10-04 … 10-10, $109.02 total** (vs $197.12 last week). There are 6 `dev/daily/` summaries; run 38057014961 ($9.47, 10-10) has none.
- Weekly deep health scan ran 2026-10-05 (#3154). Prune-candidates ran 10-05 (#3155). Weekly-start sweep ran 10-05 (#3153). The weekly issue-fix audit ran for the first time (#3132).
- Experiment ledger: macro-suspend (#3123/#3128), rebaseline-v12 rb1 (#3219), shorts Phase B round 1 (#3237, Reject). Results PRs: #3123, #3128, #3130, #3135, #3178, #3219, #3237.
- The newest `dev/weekly-picks/` record is **58 days** old; `DEEP_RESULTS.md` is **74 days** old; `dev/decisions.md` is **149 days** old.
- **70** open `- [ ]` follow-ups in `dev/status/`.
- 8 capability gaps flagged (2 new); 2 resolved.
- **Method note:** `gh` is unavailable in this environment. PR facts come from merge-commit subjects on `main`, and open-branch facts from `origin/*` refs and the 10-11 handoff. The window is 2026-10-04 → 2026-10-11 (main at `f0f830d1`). Track attribution of PRs is by subject keyword and is approximate for cross-cutting work (review pack, split/dividend).

# Track Pacer Report — 2026-11-15

## Summary
- Tracks audited: 50 index rows. Cadence was run on the 25 non-MERGED rows (24 IN_PROGRESS, plus `tuning-methods`, which is PENDING). The 25 MERGED rows are exempt. No row changed status this week.
- Active (≥1 PR last 7d): 7
- Slowing (7–30d since last PR): 6
- Stalled (>30d): 12
- `[info]` items needing decision: 4 carried ≥3 reconciles (the oldest is from 09-28). 5 of last week's questions were resolved or dropped (see P3).
- Capability gaps flagged: 9 (2 new, 7 carried). 2 resolved.

**Headline 1: a full week of screens on the entry and screener axis produced no lever.**
- 16 of this week's 77 PRs belong to the screener programme:
  - price-band tiebreak: #3587, #3588, #3595, #3597–#3599, #3602, #3610, #3615;
  - stale-E cap: #3604, #3608, #3609, #3621;
  - entry-timing screen: #3594;
  - gate funnel: #3628, #3631.
- **9 new ledger entries (11-12 → 11-15): 6 Reject, 3 Inconclusive, 0 Accept.**
  - entry-timing, post-stop-reentry and prebreakout-floor: Reject;
  - stale-E cap screen: Inconclusive; stale-E cap K=5: Reject (#3621, NEITHER PASSES);
  - price-band tiebreak: Inconclusive; price-band binding and confirm: Reject (#3602 CLOSE-AXIS, #3610 NO-BUILD);
  - gate-funnel P1: Inconclusive (#3631, Rule 1 PARK, Rule 2 NO RANKING LEVER).
- Every mechanism stays default-off. The plan for next steps is the axis observatory (#3622). Its P2 (`obs_read.sh`, D(t) curves) has not started, and the observatory has no status row (P4).

**Headline 2: the handoff queue is moving fast, but the status files are not keeping up.**
- Handoff 11-14 queue items 1, 3 and 4 merged within a day:
  - gate-funnel read: #3631;
  - `screener.ml` extraction: #3630;
  - `float_equal` NaN fix (#3627): #3632.
- `screener.md` (dated 11-13) has **none** of #3594, #3602, #3604, #3609, #3610, #3621 or #3631. Its index row still says "next: read the K=5 cloud runs (#3608)", and that read merged as #3621.
- The `simulation` row's next task, "#3535 verify a cloud cell pulls it", appears done:
  - chain-w ran in the cloud on the R2 warehouse `v12wk-9236` (#3571, #3584: "The warehouse has 9,236 entries");
  - the gate funnel ran in the cloud as well (#3631).
- The split-basis disposition question has now been asked in **every one of the 9 daily summaries this week**, 15 reconciles in a row since 11-04.

**Headline 3: orchestrator spend halved, and the orchestrator now asks for work.**
- 13 runs from 11-08 to 11-14 cost **$56.79**, down from $108.43. The largest run cost $11.54.
- From 11-11 these are real API dollars (#3576, #3581).
- The 11-14 summary Q3 asks whether the orchestrator may take small, fully specified items from the local priorities queue. Runs sit at about 4 % of budget because no status-file track is eligible.

## Active tracks (≥1 PR last 7d)
- **screener** — 16 PRs (listed in Headline 1). Theme: price-band tiebreak (closed), stale-E cap (closed), entry-timing screen, gate funnel (PARK). All verdict-bearing, no builds.
- **harness** — 14 PRs:
  - #3572 review-pack signals;
  - #3577, #3578: CI is the build of record; CI pending stops the reviewer;
  - #3582, #3583: rules load on demand from `dev/rules/`;
  - #3592: `.tsv` counts as results-only;
  - #3603: `pr_gate_status` pagination;
  - #3606, #3607: perf long-cell ledger;
  - #3616: goldens check skips brand-new fields;
  - #3619, #3620: build agents run tests on CI;
  - #3632: NaN-safe `float_equal`;
  - #3633: rules for chains that publish.

  Theme: process rules and gate tooling.
- **backtest-infra** — 2 PRs: #3625 (pure `Entry_stop_check.evaluate` plus a walk report) and #3626 (`candidates.sexp` rank, walk and shadow fields). Theme: instrumentation for the gate funnel. The file was updated 11-14.
- **cleanup** — 2 PRs: #3574 (nine dead executables deleted) and #3630 (`screener_candidate_eval` extracted; `screener.ml` was at 498/500 lines). The file was updated 11-15.
- **simulation** — 3 PRs, all docs, all 11-08: #3554, #3556, #3557 (#3535 corporate-action staging from R2 for cloud backtests). #3558 (container limits; long runs go to the cloud) is adjacent. Theme: cloud as the default for backtests.
- **backtest-perf** — 1 PR: #3567 (weekly perf, issue and usage read, 11-09).
- **orchestrator-automation** — 1 PR: #3576 (the `ANTHROPIC_API_KEY` secret in `orchestrator.yml`, `health-deep-weekly.yml` and `track-pacer-weekly.yml`, 11-11).
  - It was landed from a local session, which avoids the "`workflow` scope blocked" constraint.
  - This keeps the track out of the stalled bucket. Its status file is still dated 09-04.

**Exempt or unbooked work this week:**
- `strategy-wiring` (MERGED): #3623, the Friday pipeline demo. The file was updated 11-14.
- `cost-tracking` (MERGED): #3581, plus budget records.
- **#2973 split corpus** (no track): #3551, #3559, #3561.
- **Decision-walk gap D3** (no live track; `decision-audit` is MERGED): #3573, which records the tighten trigger in `trade_audit.sexp`.
- **chain-w** (#3136, #3183, #3109; no track): #3571, #3584, #3601, #3605.
  - #3136 decided: no rebuild is needed for the gate basis.
  - #3109 did not run (`PREREQ_MISSING`).

## Slowing tracks (7–30d since last PR)
- **trade-audit** — last PR #3526 was 11 days ago (11-04); theme: R1 cancel-pair invariant. Its next step is the ratings `position_id` join. Recommendation: KEEP_AS_INFO.
- **post-run-validation** — last PR #3500 was 13 days ago (11-02); theme: V12/V13 basis and delisting. What remains is #3420's `[after-merge]` verify items. The file header is still dated 09-20. Recommendation: KEEP_AS_INFO.
- **short-side-strategy** — last PR #3502 was 13 days ago (11-02); theme: laggard split-adjusted returns, default-off. The paired surface and the shorts close-out (a)/(c) wait on the maintainer. Recommendation: ESCALATE_TO_MAINTAINER (5th cycle, P7).
- **data-foundations** — last PR #3510 was 13 days ago (11-02); theme: R2 bar store and shard case. Recommendation: KEEP_AS_INFO.
- **rename-twin-dedup** — last PR #3490 was 15 days ago (10-31). The work is done. The close question was asked in 11 reconciles (through 11-08) and then dropped from the summaries without being answered. Recommendation: ESCALATE_TO_MAINTAINER (close it).
- **support-floor-stops** — last PR #3446 was 20 days ago (10-26); theme: floor-nearest SM, INCONCLUSIVE. The index row still reads "next: UNSET" (8th cycle). **It stalls next week.** Recommendation: ESCALATE_TO_MAINTAINER (close it or set a next step).

## Stalled tracks (>30d since last PR)
- **arc-readiness** — last PR #3142 at 2026-10-05 (41 days); reason: A2-4 (picks chart) was never dispatched, and the file is dated 09-26. Recommendation: ESCALATE_TO_MAINTAINER.
- **weekly-snapshot** — last PR #2453 at 2026-08-20 (87 days); reason: no next step queued, and the split work lands under #2973 with no track. Recommendation: ESCALATE_TO_MAINTAINER (10th ask).
- **stage-accuracy** — last PR #2450 at 2026-08-20 (87 days); reason: the broad-universe WF-CV is data-gated. Recommendation: KEEP_AS_INFO.
- **resistance-v2** — last PR #2145 at 2026-07-28 (110 days); reason: WF-CV vs w30 is LOCAL, and the #3527 grade-basis defect is open. Recommendation: ESCALATE_TO_MAINTAINER (14th cycle).
- **tuning** — last PR #2113 at 2026-07-27 (111 days); reason: the M2 enable-commit (#1327, filed 2026-05-26, **173 days** ago). Recommendation: ESCALATE_TO_MAINTAINER (17th ask).
- **extension-stop** — last PR #1960 at 2026-07-14 (124 days); reason: the R3 flip is human-gated. Recommendation: KEEP_AS_INFO.
- **floor-quality** — last PR #1913 at 2026-07-10 (128 days); reason: deep-warehouse, LOCAL. Recommendation: KEEP_AS_INFO.
- **rolling-start-lens** — last PR ~#1648 at 2026-06-18 (150 days); reason: LOCAL / data-gated. Recommendation: KEEP_AS_INFO.
- **cash-floor-correctness** — last PR #1582 at 2026-06-14 (154 days); reason: NS2 is human-gated and NS4 is data-gated. Recommendation: KEEP_AS_INFO.
- **sweep-perf** — last PR #1574 at 2026-06-13 (155 days); reason: the manual ghcr.io flambda rebuild. Recommendation: ESCALATE_TO_MAINTAINER (16th ask).
- **spy-only-reference** — last PR #1438 at 2026-06-03 (165 days); reason: never dispatched. Recommendation: ESCALATE_TO_MAINTAINER (10th ask), to close or re-home.
- **tuning-methods** (PENDING) — no PR ever; file dated 2026-05-24 (175 days). Recommendation: ESCALATE_TO_MAINTAINER (10th ask), to close or re-scope.

## Next Steps staleness (P2)
- **screener [NEW]** — `screener.md` (11-13) records none of #3594, #3602, #3604, #3609, #3610, #3621, #3631. Its `## In Progress` section still describes PR #718 from April.
  - The index next task ("read the K=5 cloud runs (#3608)") was done by #3621 (11-14).
  - The gate-funnel PARK (#3631) and the observatory plan (#3622) are not recorded.
  - Recommend refreshing both the status file and the index row.
- **simulation** — the file is still dated 11-02 (2nd cycle). It does not record #3477 PRs 5–7, #3536, the R2 warehouse PRs or #3547.
  - The index row's next task, "#3535 verify a cloud cell pulls it", appears done: chain-w pulled warehouse `v12wk-9236` in the cloud (#3584), and so did the gate funnel (#3631).
  - Recommend refreshing it.
- **backtest-infra** — the first Next Step is still "[2026-09-14] PIT top-3000 universe migration — in flight locally … four-chunk build running". The index header records steps 1–6 as merged. The file was touched 11-14 (#3626), but the list was not reconciled (3rd cycle).
- **data-foundations** — the first Next Step is still "the paired 26y read … runs after merge". It was read in #3489 (10-31). #3499 and #3510 are not booked (3rd cycle).
- **support-floor-stops** — the index row reads "next: UNSET" (8th cycle).
- **rename-twin-dedup** — dated 09-16, and overtaken by #3475, #3480, #3489 and #3490 (7th cycle).
- **short-side-strategy (index row only)** — still "next: short-leg regime-P&L decomposition (LOCAL)". The file (11-02) says "paired off/on surface on the record preset" (2nd cycle).
- **post-run-validation** — the header is dated 09-20, and #3500 is cited only in the index row (2nd cycle).
- **backtest-perf** — the header is still `Last updated: 2026-09-22`, though it has 11-09 entries (#3567) (2nd cycle).
- **orchestrator-automation** — the file is dated 09-04. Its index row says `workflow` scope is blocked on every route, and #3576 then changed three workflow files from a local session. Recommend noting the local route.

Carried unchanged, with files untouched for 30+ days: `arc-readiness`, `cash-floor-correctness`, `extension-stop`, `floor-quality`, `resistance-v2`, `rolling-start-lens`, `spy-only-reference`, `stage-accuracy`, `sweep-perf`, `tuning`, `tuning-methods`, `weekly-snapshot`.

## [info] items needing decision (P3)

`_index.md` carries no `[info]` tags. The items below come from "Questions for You" in the 9 daily summaries from 11-08 to 11-14.

- **Where do the #3527 split-basis findings go, and when does #2973 close?** 15 reconciles (11-04 → 11-14), and in all 9 summaries this week. Recommended action: ESCALATE_TO_MAINTAINER.
- **H-GATE-TWO-VERDICTS-ONE-SHA (same-SHA verdict ranking).** Open since **2026-09-28**, and in all 9 summaries this week. It is still the index's harness next task. Recommended action: ESCALATE_TO_MAINTAINER.
- **`linter_coverage` test-file policy.** In every summary since 10-20 (≥30 reconciles). It is the last open cleanup item. Recommended action: ESCALATE_TO_MAINTAINER.
- **Deep-scan R1/R3 scope** (`arch_layer_test.sh` coverage of `data_panel` / `backtest` imports; `weinstein/strategy` → `simulation.cash_yield`). 7 reconciles (11-10 → 11-14). Recommended action: ESCALATE_TO_MAINTAINER.
- **[NEW, 1 reconcile] May the orchestrator take small, fully specified items from the local priorities queue?** (11-14 Q3; runs sit at about 4 % of budget.) KEEP_AS_INFO this week. It becomes an escalation if it carries.
- **[NEW, 1 reconcile + handoff §4] Committed artifacts vs EODHD terms**: option A recommended (leave the frozen pre-registration text as is). KEEP_AS_INFO; it is parked for 11:00 PT under the quiet-hours rule.

**Resolved this week:**
- #3584's gate class (`.tsv` lane): fixed by #3592.
- #3571 rule A or B: chain-w ran and was read (#3605).
- Pushing the entry-timing screen: #3594 merged.

**Dropped from the summaries without a recorded answer:**
- closing `rename-twin-dedup` (last asked 11-08);
- narrowing P6 sub-rule 3 (last asked 11-10);
- the `harness-census-multiline` rework streak (last asked 11-11);
- the GMCR volume basis (last asked 11-09-run2).

Last week's "skeleton summary early" question (11-08 Q4, #2803) and the session-ownership label were not re-asked either. Recommend that the next reconcile record a disposition for each, so they do not drop silently.

## Tracks without owner (P4)
- No index row was created in the last 14 days, and every non-MERGED row has an owner. PASS on the check as written.
- Programmes with work this week and no index row:
  - **Axis observatory [NEW]** (`dev/plans/axis-observatory-2026-11-14.md`, #3622). P1 is done (#3628, #3631), P2 is queued in the handoff, and it is the stated direction of the programme. Recommend: RECOMMEND_NEW_TRACK (owner: dayfine LOCAL).
  - **#2973 split corpus** (#3551, #3559, #3561 this week). Asked last week. Recommend: RECOMMEND_NEW_TRACK, carried (see P7 gap 1).
  - **chain-w follow-ups**:
    - #3109's default-off prerequisite PR (`split_raw_confirm_min_share` is not on main);
    - the td-full shadowing defect: committed short `data.csv` files shadow the full store for 650 symbols (#3605). It is also in handoff queue 6 as "D1 td-full shadowing fix".

    KEEP_AS_INFO; it folds into the split-basis gap.

## Recurring discussion topics (P5)

`dev/decisions.md` was last modified 2026-05-15 (**184 days**) and has 0 entries in 30 days, so P5 cannot run as specified. Recommend: ESCALATE_TO_MAINTAINER (10th ask: retire it or revive it). Read instead from the daily summaries, the handoffs, the ledger and the results PRs:

- **Raw vs split-adjusted basis mixing** (carried). Where it appears:
  - #3527 findings, still 5 open `guard none` rows in `dev/findings/registry.sexp`;
  - #3559 and #3561 (11-09), with the GMCR volume basis left unresolved;
  - #3571 and #3605: #3109's raw-confirm knob is not on main, so its 6 cells were skipped;
  - all 9 summaries this week.

  No resolution. Recommend: RECOMMEND_NEW_TRACK.
- **[NEW] The entry and screener axis keeps returning no lever.** In 4 days: 9 ledger entries, 6 Reject and 3 Inconclusive. The gate funnel's reading (#3631) is that the gap is "the empty book after a gate block", not candidate supply or ranking, which matches the 09-22 top-N result. KEEP_AS_INFO. The observatory plan already redirects to the dial queue; the open question is whether entry-axis screens should pause until P2 orders that queue.
- **[NEW] Data terms and where price-bearing artifacts live.** Where it appears:
  - #3621's note 5;
  - the 11-14 handoff §4;
  - the 11-14 summary Q2;
  - #3631, whose prices are in `dayfine/trading-results` a3a2dadc2;
  - #3633's "Chains that publish" rule.

  The mechanism landed. One decision (A/B) is parked. KEEP_AS_INFO.
- **The orchestrator has no eligible work.** Where it appears: the 11-14 Q3; the index header ("no dispatchable track work"); `cleanup.md`'s "NO dispatchable work"; and spend down to $56.79. This is a renewal of last week's qualitative P6 flag. KEEP_AS_INFO, and it hinges on the P3 answer.
- **Record of record.** `dev/backtest/DEEP_RESULTS.md` was last touched 2026-07-29 (**109 days**). KEEP_AS_INFO.

## Diminishing returns (P6)

**Mechanical heuristic: 0 flags. PASS.**
- `screener`, last 5 (#3631, #3628, #3621, #3615, #3610): 0 hits.
- `harness`, last 5 (#3633, #3632, #3620, #3619, #3616): 0 hits.
- `cleanup`, last 2 this week (#3630, #3574): `cleanup`-prefixed, which is not in the keyword list. The track exists for this kind of work, so no flag.

**Qualitative note (KEEP_AS_INFO):**
- The screener track is the opposite of diminishing activity: 16 PRs in a week. Its return per PR on the strategy is nil (0 Accept in 9).
- That is a programme-level signal for the maintainer, not a maintenance-drift flag.

## Capability gaps (P7)
- **Split-basis correctness has no owner** (carried, 2nd cycle).
  - Open items:
    - 5 registry findings with `guard none` from #3527;
    - #2982's same-basis stop fix, default-off (`fixed-behind-flag`), which #3546 priced at −16 to −22 % of realised P&L first-order;
    - #3502's two laggard flags, default-off;
    - #3109's prerequisite knob, not on main;
    - the td-full shadowing defect (650 symbols, #3605).
  - Milestone: M6 (M6.4 verification).
  - Mentioned in: `short-side-strategy`, `post-run-validation`, `resistance-v2`, `weekly-snapshot`, the registry, and chain-w.
  - Recommend: ESCALATE_TO_MAINTAINER.
- **[NEW] Axis observatory P2 has not started and has no track.** It covers `obs_read.sh` (D(t) curves, yearly increments, step attribution), `surface.tsv`, the curves page and the baseline-drift lane. It orders the P3 dial queue that the gate funnel deferred to.
  - Milestone: M7 (parameter optimisation and surface reading).
  - Mentioned in the 11-14 handoff queue item 2, #3622 and #3631.
  - Recommend: KEEP_AS_INFO, with the P4 new-track recommendation. This is the next lever named by the programme.
- **Weekly live-picks run: 93 days stale, 13 Fridays missed** (08-21 … 11-13). The newest record is `dev/weekly-picks/f88c277d5/2026-08-14.sexp`.
  - #3623's Friday pipeline demo now traces one synthetic Friday stage by stage. A real Friday run on the record config is still missing.
  - Milestone: M6. Mentioned in `weekly-snapshot`, `arc-readiness` and `decision-audit`.
  - Recommend: ESCALATE_TO_MAINTAINER (13th cycle).
- **The promoted resistance bundle (#2047, default-on) is not certified on the K = 5 record band**, and the #3527 grade-basis finding is open. Recommend: ESCALATE_TO_MAINTAINER (16th cycle).
- **Shorts close-out (a) vs (c), and Rule 4 for the short-only flags.** 5th cycle. #3145 and #3109 are `verify/pending`. Milestone: M7. Recommend: ESCALATE_TO_MAINTAINER.
- **`tuning` M2 enable-commit (#1327): 173 days.** Milestone: M7. Recommend: ESCALATE_TO_MAINTAINER (17th ask).
- **`sweep-perf` ghcr.io flambda rebuild: 155 days.** Recommend: ESCALATE_TO_MAINTAINER (16th ask).
- **Weekly perf and usage review.** The 11-09 read ran (#3567) and wrote to `cost-tracking.md`. Whether the two SLOWER 10y cap-256 shapes were re-checked on a quiet host is not visible in the index row ("10-29 weekly review: re-check …" is unchanged). KEEP_AS_INFO; recommend that the next read state it explicitly.
- **`arc-readiness` A2-4** (picks chart): it folds into the weekly-picks gap. KEEP_AS_INFO.

**Resolved since last report:**
- **Cloud warehouse verification (#3535):** chain-w (#3584) and the gate funnel (#3631) both ran in the cloud on the R2 warehouse. RESOLVED in practice; the simulation status file has not recorded it (P2).
- **Decision-walk gap D3** (tighten trigger not recorded): #3573. RESOLVED.

Follow-up accumulation: **47** open `- [ ]` items in `dev/status/`, unchanged from last week. KEEP_AS_INFO.

## Recommendations
1. **Answer the four carried orchestrator questions in one pass:**
   - the #3527/#2973 split-basis disposition (15 reconciles);
   - H-GATE-TWO-VERDICTS-ONE-SHA (since 09-28);
   - `linter_coverage` (≥30 reconciles);
   - deep-scan R1/R3 scope (7 reconciles).

   Also decide 11-14 Q3, whether the orchestrator may take small, fully specified items from the local queue. The GHA lane runs at about 4 % of budget for want of these answers.
2. **Give the split-basis cluster an owner and an index row.** That includes the #3109 prerequisite knob and the td-full shadowing fix, which any flag-on run must fix first (#3605).
3. **Open an index row for the axis observatory** and start P2 (`obs_read.sh`) before more entry-axis screens. The last 9 ledger entries returned 0 Accept, and #3631 already points the programme at the P3 dial queue.
4. **File one docs-only reconcile PR** (8th report to ask). It should cover:
   - `screener.md` and its index row (7 PRs missing; next task done);
   - `simulation.md` and its row (#3535 verified in practice);
   - the first Next Steps in `backtest-infra` and `data-foundations`;
   - `support-floor-stops` "UNSET";
   - the `short-side-strategy` index row;
   - the `post-run-validation` and `backtest-perf` headers;
   - closing `rename-twin-dedup`;
   - noting #3576's local workflow route in `orchestrator-automation.md`.
5. **Record a disposition for the questions that dropped out of the summaries unanswered:** `rename-twin-dedup` close, P6 sub-rule 3, `harness-census-multiline`, the GMCR volume basis, the skeleton summary (#2803), and the session-ownership label.
6. **Decide the shorts close-out (a) or (c)** (5th cycle).
7. **Decide the weekly-picks cadence on the record config**: 93 days and 13 Fridays behind. #3623's demo is the nearest piece.
8. **Unblock the one-action human gates:** `tuning` #1327 (173 days) and the `sweep-perf` flambda rebuild (155 days). Close or re-scope `tuning-methods` (175 days) and `spy-only-reference` (165 days).
9. **Retire or revive `dev/decisions.md`** (184 days), and point `DEEP_RESULTS.md` (109 days) at the current record ledger entry.

## Stats
- **77 PRs merged in last 7d** (11-08 → 11-15; includes last week's pacer #3550).
  - By prefix: 18 `docs`, 17 `ops`, 16 `experiment`, 13 `harness`, 5 `feat`, 3 `test`, 2 `cleanup`, 1 `strategy`, 1 `ci`, 1 unprefixed (#3626).
  - That is up from 51 last week.
- **284 PRs merged in last 30d.**
- 7 tracks active / 6 slowing / 12 stalled, out of 25 non-MERGED rows (8 / 5 / 12 last cycle).
- 4 `[info]` items carried ≥3 reconciles:
  - split-basis disposition (15);
  - same-SHA ranking (since 09-28);
  - `linter_coverage` (≥30);
  - deep-scan R1/R3 (7).

  3 resolved; 4 dropped without a recorded answer.
- 9 capability gaps flagged (2 new: the axis observatory P2, plus split-basis now including #3109 and td-full). 2 resolved: #3535 verification and decision-walk D3.
- **Orchestrator spend 11-08 … 11-14:** 13 runs, **$56.79** total, largest $11.54 (last week: 14 runs, $108.43). There were 9 daily summaries and none was lost this week.
- Ledger: **9 new entries** (6 Reject, 3 Inconclusive, 0 Accept); the newest is `2026-11-15-gate-funnel-p1`.
- Stale artifacts:
  - newest `dev/weekly-picks/` record: **93 days**;
  - `DEEP_RESULTS.md`: **109 days**;
  - `dev/decisions.md`: **184 days**;
  - newest local spend record: `local-2026-11-15.json` (current).
- **47** open `- [ ]` follow-ups in `dev/status/`.
- **Method note:** `gh` is not available in this environment. PR facts come from merge-commit subjects and bodies on `main`, `dev/daily/`, the 11-14 EOD handoff, `dev/budget/`, `dev/experiments/_ledger/` and `dev/findings/registry.sexp`.
  - Track attribution is by subject keyword and the index row's citations, so it is approximate for cross-cutting work.
  - Price-band, stale-E, entry-timing and gate-funnel PRs are counted under `screener`, as the index row books them.
  - #3535 docs are counted under `simulation`.
  - #3576 is counted under `orchestrator-automation`, because it edits `orchestrator.yml`.
  - Open-issue count was not measured this week.

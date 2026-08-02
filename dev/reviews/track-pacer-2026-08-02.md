# Track Pacer Report — 2026-08-02

## Summary
- Tracks audited: 49 index rows (25 IN_PROGRESS + 1 PENDING = 26 non-MERGED; 23 MERGED). Cadence run on the 26 non-MERGED rows.
- Active (≥1 PR last 7d): 12 IN_PROGRESS (+2 MERGED-labelled tracks that shipped work anyway)
- Slowing (7–30d since last PR): 6
- Stalled (>30d): 7 IN_PROGRESS + 1 PENDING parked
- `[info]` items needing decision: 0
- Capability gaps flagged: 9 (2 new/severe, 1 new evidence gap, 6 carried)

Headline: **the repo has merged nothing for three days.** `main`'s newest commit
is `7c43e983` (#2175) at 2026-07-30 09:36 −0400. Since then the orchestrator
fired **four times** (2 slots/day × 07-31 and 08-01, the new cadence from #2172)
and each run produced **only an orphaned budget branch recording `$0.0000`** —
`ops/budget-2026-07-31-30615598283`, `-30632543656`, `ops/budget-2026-08-01-30690853875`,
`-30700067082`. No `dev/daily/2026-07-31*.md`, no `2026-08-01*.md`, no merges.
This is `A-FASTEXIT-VACUOUS` + `A-NOOP-BUDGET-ORPHAN` (both open in
`orchestrator-automation.md`) firing exactly as documented, four more times.

Meanwhile **two finished agent branches have sat unmerged since 07-29** —
`harness/audit-atomic-write` (`993a1437`, PR #2169, the literal "next" item on
the `harness` row) and `cleanup/adjusted-basis-sync-pin` (`fa8c1595`, PR #2166,
the literal "next" item on the `cleanup` row). The 07-30 priorities doc assigned
both to the 2-slot loop as `[non-blocking]`; that loop has now had four
opportunities and taken none of them.

Second severe finding: **the 07-31 Friday live picks run — P0 in
`next-session-priorities-2026-07-30.md` — did not happen.** The newest record in
`dev/weekly-picks/` is 2026-07-24 (v4, `790d23a06`). The weekly cadence on the
M6.6 critical path has broken for the first time since the program started.

The week before the stall was strong: **13 weekly-snapshot PRs** (Picks Phase C
HTML/SVG, `record_fill` CLI, cross-week trailing-stop persistence, validator v1
wired warn-first, entry-cap alignment), the **record-of-record re-pinned to the
split-safe basis** (#2170, +8,366.8% / MaxDD 37.1), and last week's #1 and #7
recommendations resolved (deep health scan cadence restored; harness #2009
root-caused and fixed).

## Active tracks (≥1 PR last 7d)
- **weekly-snapshot** — 13 PRs (#2107 entry reconciliation, #2114 Picks Phase C v2, #2117 `record_fill` CLI, #2125 cross-week trailing-stop state machine, #2129/#2134/#2136 report defects + QC F1–F3, #2139 picks validator v1, #2145 split-safe sketch basis, #2153 `rebuild_weekly_sidetables`, #2165 validator wired warn-first, #2171 entry-cap alignment Phase 1) plus 5 record PRs (#2127/#2131/#2137/#2144/#2150); theme: **the live-picks execution program hardened end-to-end** — the generator now self-validates, threads stops across weeks, and emits STOPLIMIT tickets sized on a do-not-chase cap. By far the hottest track, for the second week.
- **harness** — 8 PRs (#2123 audit-record clobbering, #2135 QC quality-score polarity, #2140 deep-scan follow-up counter, #2143 `run-in-env.sh` worktree false-green, #2148 cache-blind check class, #2155 #2148 FLAG residuals, #2163 `set -e` diagnostic-loss audit, #2172 cron 8→2) + #2009 (adaptive-nugget Cholesky retry, 07-26); theme: **false-green elimination in the check suite** — five of eight PRs fix checks that silently passed when they should have failed. 21 backlog items remain open.
- **cleanup** (code-health) — 8 PRs (#2112, #2121, #2126, #2132, #2138, #2146, #2152, #2162); theme: docstring citation accuracy + stale-comment closure. Backlog is now 9 open / 47 closed — the feeder is healthy again (see P6 for the quality caveat).
- **screener** — 5 PRs (#2087 failed-breakout invalidation default-off, #2090 sparse-tail eligibility gate, #2091 structural stop for pick candidates, #2094 short-candidate overlay pin, #2106 subdir documentation); theme: **issue #2084 closed out** — both findings fixed, including F2 which last week's report flagged as unowned.
- **resistance-v2** — 6 PRs (#2145 split-safe sketch basis, #2150 v4 picks on split-safe grading, #2156 blast-radius ledger, #2159 fold-level re-cert, #2160 sp500 cell, #2170 R3 record re-pin); theme: **the split-basis correction** — the promoted config's own headline was flattered by −322pp return / +6.8pp MaxDD on the raw basis, and the record-of-record was re-pinned honestly. See P7 for the caveat this leaves open.
- **backtest-infra** — 1 PR (#2113, LAPACKE GP-Cholesky root-cause fix); un-redded main and retired the `test_bayesian_opt.exe` flake. Index row correctly reconciled — last week's flag RESOLVED.
- **simulation** — 1 PR (#2115, #2059 LH phantom short + duplicated `trades.csv` rows, root-caused to non-quantity-faithful round-trip pairing).
- **trade-audit** — 1 PR (#2115, shared with `simulation`; consumer-facing half of the same fix).
- **data-foundations** — 2 PRs (#2097 spike-bar data-suspect flag, #2100 live ticker-rename detection via returns-basis succession, both default-off; #2083 F2/F3).
- **rename-twin-dedup** — shares #2100 (returns-basis succession is this track's detector, applied live). First activity in 13 days.
- **short-side-strategy** — 1 PR (#2081, robust trailing dollar-ADV, default-off, 07-26 — exactly at the 7-day boundary).
- **orchestrator-automation** — 1 PR (#2172, cron cut 8→2 slots/day per user quota directive). Ironically the change whose after-effects are this report's headline.

_(MERGED-labelled tracks that shipped work this week, so they do not appear in the cadence buckets: **support-floor-stops** — #2167 `Wick|Close` anchoring knob + #2168 follow-ups doc, see P4; **leverage-dawn** — #2119 clean re-run REJECT re-certified + #2120 memory snapshot, closing last week's queued-run item.)_

## Slowing tracks (7–30d since last PR)
- **margin-realism** — last PR #2085 was 8 days ago (2026-07-25, `trade_audit.sexp` visibility); theme: the M1–M4 ladder finished and the track went quiet by design. #2076 (report-layer rendering) still listed open on the index. Recommendation: KEEP_AS_INFO.
- **backtest-perf** — last own-track PR #2024 was 13 days ago (2026-07-20, band-aware v4 `dump_snap`); its subject matter (snapshot format v2) shipped 6 PRs this week under `weekly-snapshot`/`resistance-v2`. Status file last updated 2026-06-16 (47 days). Recommendation: KEEP_AS_INFO (ownership has migrated; see P2).
- **post-run-validation** — last PR #1947 was 20 days ago (2026-07-13); next (golden-run integration test for V3/V4/V7) is data-gated. Recommendation: KEEP_AS_INFO.
- **extension-stop** — last PR #1960 was 20 days ago (2026-07-13); only a default flip remains, human-gated on a further insurance-basis ACCEPT (R3). Recommendation: KEEP_AS_INFO.
- **floor-quality** — last PR #1913 was 23 days ago (2026-07-10); P1b step 3 (lens screen vs TR-SPY) is deep-warehouse maintainer-LOCAL. Recommendation: KEEP_AS_INFO.
- **stage-accuracy** — last PR #1864 was 27 days ago (2026-07-06); a rejection streak, not churn — the file itself points at breadth as the remaining lever. Status file stale since 2026-06-06 (see P2). Recommendation: ESCALATE_TO_MAINTAINER (status refresh, 4th flag).

## Stalled tracks (>30d since last PR)
- **decline-character** — last PR #1740 at 2026-06-24 (39 days); reason: track **self-declares "WORKSTREAM EXHAUSTED (2026-06-25, #1739)"**; all decline mechanisms parked as default-off axes. Recommendation: ESCALATE_TO_MAINTAINER (mark closed — carryover, 5th week).
- **rolling-start-lens** — last own PR #1645/#1648 at 2026-06-18 (45 days); reason: next steps are explicitly maintainer-local (top-3000 PIT warehouse + screener), self-tagged `[blocking: by warehouse build]`. Recommendation: KEEP_AS_INFO.
- **cash-floor-correctness** — last PR #1582 at 2026-06-14 (49 days); reason: NS1 shipped and flipped ON, NS2 impl human-gated, NS4 DD-validation data-gated. Recommendation: KEEP_AS_INFO.
- **sweep-perf** — last substantive PR #1574 at 2026-06-13 (50 days); reason: the only remaining step is the **manual ghcr.io flambda rebuild**, a human action. Recommendation: ESCALATE_TO_MAINTAINER (carryover, 3rd week).
- **spy-only-reference** — last PR #1438 at 2026-06-03 (60 days); reason: next is explicitly a human session (sector-rotation testbed, top-1000 bankability gate, long-short verification). Recommendation: KEEP_AS_INFO.
- **experiment-platform** — last own PR #1372 at 2026-05-29 (65 days); reason: the platform is in steady daily use (every ledger entry this week ran through it) but the code track's single-dial surface is exhausted. Recommendation: KEEP_AS_INFO (steady-state infra, not a real stall).
- **tuning** — last PR #1333 at 2026-05-27 (67 days); reason: M1 complete 5/5; **M2 qNEHVI still awaiting a maintainer enable-commit per #1327**. On the M7 critical path. Note #2113/#2152 touched `backtest/tuner/` this week but were booked to `backtest-infra`/`cleanup`. Recommendation: ESCALATE_TO_MAINTAINER (carryover, 4th week).
- **tuning-methods** (PENDING) — parked since 2026-05-24 (70 days); Step 0 done, steps 1–3 demoted, component-decomposition objective queued but never dispatched. Recommendation: KEEP_AS_INFO.

## Next Steps staleness (P2)
- **`_index.md` header itself** — NEW. `Last updated: 2026-07-29 run1`, but **six PRs merged after it** (#2165, #2167, #2168, #2170, #2171, #2172 on 07-29/07-30, plus #2173/#2174/#2175). Two rows are provably stale as a result: `weekly-snapshot`'s next task reads "#2133 follow-up warehouse rebuild + golden re-pin" although **#2153 (`rebuild_weekly_sidetables`) merged 2026-07-28**; and no row reflects #2171's entry-cap alignment. ESCALATE_TO_MAINTAINER.
- **stage-accuracy** — `## Last updated: 2026-06-06`, file untouched in git since then (57 days). First `## Next Steps` item is self-marked "**DONE 2026-06-06: REJECTED**". **Flagged 2026-07-12, 07-19 and 07-26; not actioned.** ESCALATE_TO_MAINTAINER (4th ask).
- **simulation** — header refreshed to 2026-07-27 (last week's ask, partially actioned) **but `## Next Steps` was not touched**: it is still the "Future slices" list (position-level assertions, T2-B perf gate, sp500 rerun) that predates the fill-router cluster, #1926, #2074 and #2115. The index's stated next task — "sign-flip invariant (filed, default-off)" — appears nowhere in the file. KEEP_AS_INFO → ESCALATE_TO_MAINTAINER (half-done refresh).
- **backtest-infra** — header refreshed to 2026-07-27 and the index row reconciled (last week's ask, actioned) **but `## Next Steps` is stale**: item 1 defers to `backtest-scale.md` for the tier-aware loader and item 2 names "the Tiered loader flip" as a prerequisite — `backtest-scale` has been **MERGED** for months. Index now says "next: none queued", which the file contradicts. KEEP_AS_INFO.
- **screener** — `## Status: READY_FOR_REVIEW` with narrative reading "PR #2087 **OPEN**" and "#2079 PR **OPEN**"; both merged 2026-07-24/07-26. `_index.md` correctly lists IN_PROGRESS / "next: none queued". The file's status keyword and three "PR OPEN" claims are stale by ≥7 days. ESCALATE_TO_MAINTAINER.
- **trade-audit** — status-keyword drift persists: the file's `## Status` reads `MERGED` while `_index.md` lists the track `IN_PROGRESS` with a live next task. Flagged 2026-07-26; not actioned. KEEP_AS_INFO.
- **support-floor-stops** — `## Last updated: 2026-04-17` and `## Status: MERGED`, yet the file received **two PRs on 2026-07-29** (#2167, #2168) and now carries two live follow-ups, one a stated pre-promotion blocker. See P4. ESCALATE_TO_MAINTAINER.
- **backtest-perf / rolling-start-lens** — files last updated 2026-06-16 / 2026-06-15 (47 / 48 days) while their subject matter carried 6+ PRs this week under other tracks. Carried from 07-26; the ownership boundary has now drifted for three weeks. KEEP_AS_INFO.
- **Pattern note (carried, not individually actionable):** on 7+ tracks the first `## Next Steps` entry is a struck-through or ✅/DONE-marked completed item (`cash-floor-correctness`, `extension-stop`, `experiment-platform`, `tuning`, `weekly-snapshot`, `resistance-v2`, `backtest-perf`). Each marks its own completion, so this is a formatting convention rather than a defect — but the P2 "first item" heuristic still cannot be read mechanically on this repo.

## `[info]` items needing decision (P3)
- **None.** `dev/status/_index.md` carries **0** `[info]`-tagged items. The header block is a single-run reconcile narrative with no carried-forward `[info]` list, so there is nothing to age. (Sixth consecutive week with the same structural answer.)

## Tracks without owner (P4)
- **support-floor-stops** — NEW, and the cleanest P4 hit in six weeks. The index row is `MERGED | — | — | —` (no owner, no next task), yet the track shipped **#2167** (`support_floor_anchor_mode : Wick|Close`, default Wick) and **#2168** on 2026-07-29 and now carries two open follow-ups in `## Follow-ups`: (a) `snapshot/gen/lib/stop_recompute.ml:15` computes the display-only `stop_is_structural` flag via the Wick-only bar-list path while the level is Close-aware — a qc-behavioral finding on #2167 explicitly marked **"must close BEFORE `Close` is ever promoted default-on"**; (b) an **A2 architecture decision item** (split-safe floors need `Adjusted_basis`, which lives in `analysis/` — direct import would violate A2; needs a human/review call). Neither has an owner and neither is visible in the index. Recommend: ESCALATE_TO_MAINTAINER — restore a non-MERGED status with `feat-weinstein` as owner, or assign both follow-ups explicitly.
- No other IN_PROGRESS / READY_FOR_REVIEW row is missing an owner. No new track rows were created in the last 14 days.
- **Resolved since last week:** issue #2084 Finding 2 (the naive `entry * 0.92` structural stop), flagged unowned on 07-26, was fixed by **#2091** on 07-26. The weekly-picks execution program still has no dedicated index row, but all 13 of its PRs this week wrote to `dev/status/weekly-snapshot.md`, so de-facto ownership is now consistent — downgrading from RECOMMEND_NEW_TRACK to KEEP_AS_INFO.

## Recurring discussion topics (P5)
- **None from the P5 scan surface.** `dev/decisions.md` has **no entries in the last 30 days** — the newest is 2026-05-16 (the Norgate→EODHD/IWV vendor pivot), 78 days old. Standing observation, now carried for the **5th week**: `dev/decisions.md` has effectively been retired as the human→agent decision channel in favour of `dev/notes/next-session-priorities-*.md` handoffs, the experiment ledger (`dev/experiments/_ledger/`), and the daily orchestrator summaries — none of which P5 scans. If P5 is to keep producing signal, the check needs re-pointing at the handoff docs; that is a human decision. KEEP_AS_INFO.

## Diminishing returns (P6)
- **No track trips the strict heuristic** (≥3 of the last 5 PRs matching `chore` / `fix(linter)` / `golden` / `repin` / `fmt` / `ocamlformat`). Only #2118 (weekly opam update) is textually maintenance-shaped among 40 substantive merges. Four softer signals:
  - **cleanup** — NEW soft flag. All 8 PRs this week were **docs / comment / test-comment only**: two book-citation corrections (#2112, #2121), one stale-finding closure (#2126), one evidence-record precision fix (#2132), one test header pin (#2138), a milestone marker (#2146), a stale SPD comment (#2152), a duplication note (#2162). **Zero code-health refactors landed** — no extraction, no dead-code removal, no linter-exception retirement. The backlog itself has drifted toward citation nitpicks (5 of 9 open items are documentation/annotation findings). Per `code-health-discipline.md`, the cleanup agent is supposed to be a leading indicator; a queue of docstring citations is not that. Recommend: KEEP_AS_INFO, but worth re-weighting the deep-scan feeder toward structural findings.
  - **harness** — NEW soft flag. All 8 PRs are meta-work on the check suite itself (fixing checks that were false-green, fixing the deep-scan's own counters, fixing the audit recorder). Valuable and clearly not exhausted — 21 items still open — but the track has been fixing its own instrumentation for two straight weeks with no capability added to the system under test.
  - **decline-character** — self-declares exhausted (#1739); every mechanism ended as a default-off axis. 5th consecutive week recommending closure.
  - **resistance-v2** — the promotion it existed to produce shipped (#2047) and its record has now been honestly re-pinned (#2170). What remains is one open evidence caveat (see P7) plus a default-off lever-b softener. Worth deciding whether it stays at high dispatch priority or drops to axis-maintenance. 2nd ask.

## Capability gaps (P7)
- **The orchestrator loop is producing nothing — NEW, severe.** Four runs on 2026-07-31 and 2026-08-01 each emitted only an orphaned `ops/budget-*` branch recording **`$0.0000`**; there is no `dev/daily/` entry for either date and nothing merged to `main` since 2026-07-30. Two completed agent branches — `harness/audit-atomic-write` (#2169) and `cleanup/adjusted-basis-sync-pin` (#2166), both pushed 07-29 and both the literal "next task" on their track's index row — were handed to this loop as `[non-blocking]` by the 07-30 priorities doc and have been passed over four times. Root causes are already filed and open in `orchestrator-automation.md` (`A-FASTEXIT-VACUOUS`, `A-NOOP-BUDGET-ORPHAN`) but nothing is dispatched against them, and cutting the cron 8→2 (#2172) halved the number of chances to recover. Milestone impact: all tracks. Recommend: **ESCALATE_TO_MAINTAINER — highest priority this week.**
- **The 07-31 weekly live picks run did not happen — NEW, on the M6.6 critical path.** It was P0 in `next-session-priorities-2026-07-30.md` with a pinned recipe. `dev/weekly-picks/` newest record is 2026-07-24. This is the first missed week since the program started, and it lands immediately after the machinery finally became honest (#2145/#2153/#2165/#2171). Recommend: ESCALATE_TO_MAINTAINER.
- **The promoted bundle's relative margin has not been re-certified on the honest basis — NEW evidence gap.** `dev/backtest/DEEP_RESULTS.md:41-46` states it explicitly: *"the bundle's relative promotion margin (bundle vs pre-bundle/w15/floors alternatives) has not been re-measured on the honest basis — the re-pin records the honest level of the promoted config, not a re-certification of the promotion decision."* The bundle is **default-on since #2047**, and the basis it was promoted on has since been shown to flatter results by −322pp return / +6.8pp MaxDD (#2156). Under `promotion-confirmation.md` this is a live default whose justifying evidence is no longer certified. The 07-30 priorities doc scopes the fix at ~7–8h of grid time and leaves it as a user call. Recommend: ESCALATE_TO_MAINTAINER — decide explicitly to spend the grid or to record the caveat as accepted.
- **Follow-up accumulation: 76 open items across status files** (deep scan 2026-07-27, warning 2; threshold is 10). This is the aggregate of every track's un-triaged `- [ ]` backlog and it is now 7.6× the threshold. Recommend: KEEP_AS_INFO (mechanical consequence of long-lived tracks), but it is the quantitative form of the "close finished tracks" recommendation below.
- **EODHD data access absent in the GHA orchestrator environment** — still the dominant systemic blocker, **4th week**. Data-gated next-tasks on: `backtest-infra` P2 matrix, `backtest-perf` regime lenses, `stage-accuracy` broad WF-CV, `experiment-platform` continuation-buy recheck, `simulation` stale-exit grid, `weekly-snapshot` multi-week sweep, `cash-floor-correctness` NS4, `data-foundations` IWV scrape, `floor-quality` P1b step 4, `post-run-validation` golden-run test, `tuning` surfaces, `rolling-start-lens` top-3000 warehouse. Every piece of this week's decisive evidence (#2156/#2159/#2160/#2170) was generated LOCAL. Milestone impact: M6 + M7. Recommend: ESCALATE_TO_MAINTAINER — provision the key, or **formally re-scope the orchestrator to build/plan-only for WF-CV tracks** so the cron stops idling on ~12 data-gated rows. Given the fast-exit finding above, these two decisions are the same decision.
- **`tuning` M2 qNEHVI blocked on a maintainer enable-commit (#1327)** — 67 days stalled on a one-line human action, on the M7 critical path. Recommend: ESCALATE_TO_MAINTAINER. (Carryover, 4th week.)
- **`sweep-perf` manual ghcr.io flambda rebuild** — the only human/manual step left; substantive work has been stopped 50 days behind it. Recommend: ESCALATE_TO_MAINTAINER. (Carryover, 3rd week.)
- **`workflow`-scoped PAT still blocking six orchestrator-automation items (#1636)** — per the index row, "six items share the `workflow`-token blocker", including the ci.yml ENOSPC fix. One credential action unblocks six. Recommend: ESCALATE_TO_MAINTAINER. (Carryover.)
- **`support-floor-stops` `stop_recompute` Wick-only classifier** — a stated pre-promotion blocker on a mechanism that merged 4 days ago, with no owner (see P4). Milestone: none directly, but it gates any future `Close`-anchoring promotion. Recommend: ESCALATE_TO_MAINTAINER.
- **Resolved since 2026-07-26:** the weekly deep health scan cadence (#2022 landed the missing 07-20 scan on 07-26; #2128 landed 07-27 on schedule) — last week's #1 recommendation, closed. `harness` #2009 (LAPACKE GP-Cholesky) — merged 07-26 and root-caused by #2113 on 07-27, closing last week's #7 partially. The `leverage-dawn` WF-CV surface — ran, and the REJECT was re-certified after a baseline-drift root cause (#2108/#2109/#2119), closing last week's #8 partially. Issue #2084 Finding 2 — fixed by #2091.

## Recommendations
1. **Diagnose why the last four orchestrator runs produced zero output** and merge the two branches they passed over — #2169 (`harness/audit-atomic-write`) and #2166 (`cleanup/adjusted-basis-sync-pin`), both idle since 07-29. Then dispatch `A-FASTEXIT-VACUOUS` and `A-NOOP-BUDGET-ORPHAN` in `orchestrator-automation.md`; they are filed, diagnosed, and un-dispatched while the failure they describe recurs twice a day. At 2 slots/day the loop has no slack to absorb a vacuous exit.
2. **Run the missed weekly picks cycle.** The 07-31 record is absent; the recipe is pinned in `project_split_safe_resistance_basis` and P0 of `next-session-priorities-2026-07-30.md`. This is the first broken week on the M6.6 path and the machinery only just became honest — the gap is worth closing before it compounds into two.
3. **Decide the bundle-vs-alternatives honest-margin grid** (~7–8h). A default-on promotion (#2047) is currently justified by evidence measured on a basis since shown to be inflated by −322pp / +6.8pp. Either spend the grid or record in `DEEP_RESULTS.md` that the caveat is knowingly accepted — leaving it as an open note under `promotion-confirmation.md` is the weakest of the three options.
4. **Assign an owner to `support-floor-stops`.** It shipped a config mechanism on 07-29 with a stated pre-promotion blocker and an open A2 architecture decision, while its index row reads `MERGED | — | — | —` and its file header still says 2026-04-17. Restore a non-MERGED status with `feat-weinstein`, or reassign both follow-ups explicitly.
5. **Reconcile `_index.md` and finish the three half-done status refreshes.** The index header is 4 days and 9 PRs behind, and the `weekly-snapshot` next task names work that merged 07-28 (#2153). `simulation.md` and `backtest-infra.md` got new headers on 07-27 but their `## Next Steps` sections were not touched; `stage-accuracy.md` (57 days) and `screener.md` (three stale "PR OPEN" claims, wrong status keyword) are untouched. Fourth consecutive ask on `stage-accuracy`.
6. **Decide the EODHD-in-GHA question** — provision the key, or formally mark the WF-CV tracks build/plan-only. With the cron at 2 slots/day and ~12 data-gated rows, this is now the same decision as recommendation 1: the loop has nothing dispatchable, which is why it exits vacuously.
7. **Close the finished tracks** — `decline-character` (self-declared exhausted, 5th ask), `rename-twin-dedup` (no open Next Steps, 3rd ask), and decide whether `resistance-v2` drops to axis-maintenance now that both #2047 and #2170 have shipped. 76 open follow-up items across status files (7.6× the health threshold) is the aggregate cost of leaving finished work IN_PROGRESS.
8. **Unblock the three remaining one-action human gates**: `tuning` M2 enable-commit (#1327, 67d, M7 critical path); the `workflow`-scoped PAT (#1636, unblocks six orchestrator items at once); the manual ghcr.io flambda rebuild for `sweep-perf` (50d).
9. **Re-weight the `cleanup` feeder toward structural findings.** All 8 cleanup PRs this week were docs/comment-only and 5 of 9 open backlog items are citation or annotation findings. Per `code-health-discipline.md` the track is meant to be a leading indicator of file-length / nesting / dead-code accumulation, not a docstring proofreader.

## Stats
- **82 PRs merged in last 7d** (17 `ops: daily orchestrator summary`, 20 `ops:` total, 40 substantive feat/fix/test/perf/cleanup/harness/experiment/chore, 27 docs) — **but zero in the last 3 days** (newest commit `7c43e983`, 2026-07-30)
- **313 PRs merged in last 30d** (106 ops daily summaries, 136 substantive)
- 12 tracks active / 6 slowing / 7 stalled-IN_PROGRESS (+1 PENDING parked); 2 MERGED-labelled tracks also shipped work
- 0 `[info]` items carried ≥3 reconciles (6th consecutive week; the index carries no `[info]` list to age)
- 9 capability-gap bottlenecks flagged: 3 new (orchestrator no-op loop, missed 07-31 live run, uncertified bundle promotion margin), 1 new-aggregate (76 open follow-ups), 5 carried (EODHD-in-GHA 4th week, tuning M2 #1327 4th week, sweep-perf ghcr.io 3rd week, workflow-PAT #1636, support-floor-stops pre-promotion blocker)
- 4 orchestrator runs since 2026-07-30 with `$0.0000` spend and no output; 2 completed branches unmerged for 4 days
- 4 status-file reconciles outstanding (`stage-accuracy` 4th week; `simulation` + `backtest-infra` Next-Steps halves; `screener` status keyword) plus the `_index.md` header itself
- 4 of last week's 8 recommendations fully or partially resolved (deep-scan cadence, harness #2009, leverage-dawn surface, #2084 F2)

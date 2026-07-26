# Track Pacer Report — 2026-07-26

## Summary
- Tracks audited: 49 rows (25 non-MERGED: 24 IN_PROGRESS + 1 PENDING; 24 MERGED). Cadence run on the 25 non-MERGED rows.
- Active (≥1 PR last 7d): 6 IN_PROGRESS (+3 MERGED-labelled tracks that shipped work anyway)
- Slowing (7–30d since last PR): 11
- Stalled (>30d): 6 IN_PROGRESS + 1 PENDING parked (+1 idle-by-design, exempt)
- [info] items needing decision: 0
- Capability gaps flagged: 1 systemic (EODHD-in-GHA) + 6 human/manual-gated bottlenecks + 1 new unowned defect

Headline: **the resistance-v2 promotion landed.** After last week's 3/3 ACCEPT
grid, the maintainer executed R3 on 2026-07-23 — `feat(resistance-v2): PROMOTE
the bundle` (#2047) flips `w_overhead_supply = Some 30` + virgin-crossing
re-admission + floors-zero **default-on**, backed by a four-ledger evidence chain
and a supporting 4-PR `sketch-v5` snapshot-format stack (#2026/#2027/#2032/#2038).
That closes the single largest open decision the last three pacer reports carried.
`margin-realism` finished M2/M3a/M3b/M4 in the same week and **spun out
`leverage-dawn`**, which reached MERGED default-off in one cycle (#2077) after a
qc-behavioral "mechanism never funds" rework. A **new program appeared without a
track row**: weekly-picks execution (portfolio state + fixed-risk sized
instructions, #2078/#2075/#2067) plus a live-pick correctness defect (issue
#2084) whose fix is open as PR #2087 — neither is visible in `_index.md`.

Two process regressions. (1) The **weekly deep health scan for 2026-07-20 was
generated but never merged** — branch `ops/health-deep-2026-07-20` is not
contained in `main`, so the last deep scan on record is 2026-07-13; the `cleanup`
track's backlog is consequently empty and starved. (2) The **three status-file
refreshes recommended on 2026-07-12 and re-escalated on 2026-07-19 are still not
actioned** — `simulation.md`, `stage-accuracy.md`, `backtest-infra.md` are
unchanged, and the `backtest-infra` index row still calls C6b "dispatched" 13
days after #1947 merged. This is the third consecutive week.

## Active tracks (≥1 PR last 7d)
- **resistance-v2** — 11 PRs (#2012, #2013, #2015, #2021, #2026, #2027, #2032, #2038, #2045, #2047, #2048); theme: **the promotion itself** — bundle-studies results (#2021), lever-f age-band REJECT (#2045), the 4-PR `sketch-v5` side-table format stack that made armed scoring production-viable (#2026→#2038), and **#2047, the default-on flip** (w30 + virgin-crossing + floors-zero). The hottest track for the second week running, and it reached its terminal decision.
- **margin-realism** — 6 PRs (#2005 M1b-2 portfolio long-margin debit, #2010 M2 maintenance force-reduce, #2016 M3a borrow availability/HTB tiers, #2017 M3b buy-in stress, #2063 M4 validation record, #2074 exit-label observability); theme: **the margin realism ladder completed end-to-end** — parity PASS, squeeze PASS, leverage surface REJECT. All mechanisms default-off. M1b-2 was last week's escalated decision item; it landed.
- **weekly-snapshot** — 4 PRs (#2050 first live run on the promoted config, #2067 v2 grade rendering, #2075 07-10 backfill + decision record, #2078 **live portfolio state + fixed-risk sized trade instructions, Phase A+B**); theme: **the picks-execution program** — a genuinely new capability (the system now emits sized, actionable orders), launched 07-24 by user decision. Phase C (HTML report + per-candidate SVG charts) is next and not yet dispatched.
- **trade-audit** — 1 PR (#2085, 1 day ago); external-exit capture via the new `Simulator.on_transitions` hook, closing the second half of #2057. Note the track file's own `## Status` reads `MERGED` while the index row reads `IN_PROGRESS` (see P2).
- **data-foundations** — 1 PR (#2065 sectors.csv refresh + manifest, 2 days ago); theme: ops-data support for the live picks run. The load-bearing Phase-1.4 IWV scrape remains ops-gated.
- **backtest-perf** — active by adjacency only: #2024 (band-aware v4 `dump_snap`, 6d) and the `sketch-v5` snapshot-format stack all touch this track's surface but were **booked to resistance-v2**. Its own Next-steps queue (regime-diverse lenses on v2) is untouched and `backtest-perf.md` has not been updated in 40 days. Recommendation: KEEP_AS_INFO, but see P2 — the snapshot-format work has effectively migrated out of the track that owns it.

_(MERGED-labelled tracks that shipped work this week, so they do not appear in the cadence buckets: **leverage-dawn** — #2077, a new track opened and closed inside one week; **tax-lens** — #2066 Phase 1 + #2073 CP4 loader contract; **screener** — #2079 ranked-mode live arming, plus **open PR #2087** which the index does not show.)_

## Slowing tracks (7–30d since last PR)
- **short-side-strategy** — last PR #1968/#1969 was 12 days ago (2026-07-14, Run-E-capped A/B decomposition); **open PR #2081** (robust dollar-ADV, `feat/liquidity-adv-robust`, pushed 07-24, maintainer-LOCAL) addresses #2060. Next: short-leg regime-P&L decomposition (LOCAL). Recommendation: KEEP_AS_INFO.
- **backtest-infra** — last PR #1942 was 14 days ago (2026-07-12); theme: trades.csv export-join by position_id. Index row is stale (see P2). Recommendation: ESCALATE_TO_MAINTAINER (status refresh, third flag).
- **rename-twin-dedup** — last PR #1949 was 13 days ago (2026-07-13); **track has no open Next Steps** and the index reads "next: none". Recommended for closure on 2026-07-19; not actioned. Recommendation: ESCALATE_TO_MAINTAINER (close it).
- **post-run-validation** — last PR #1947 was 13 days ago (2026-07-13); next (golden-run integration test for V3/V4/V7) is data-gated. Recommendation: KEEP_AS_INFO.
- **harness** — last PRs #1954/#1961 were 13 days ago (2026-07-13); **open PR #2009** (LAPACKE GP-Cholesky nugget escalation) has sat 7 days as maintainer-LOCAL WIP, with the completion path fully written down in `harness.md:166`. The ci.yml ENOSPC fix stays PAT-gated. Recommendation: ESCALATE_TO_MAINTAINER.
- **extension-stop** — last PR #1960 was 13 days ago (2026-07-13); only a default flip remains and it is human-gated on a further insurance-basis ACCEPT (R3). Recommendation: KEEP_AS_INFO.
- **sweep-perf** — last attributable PR #1921 was 16 days ago (2026-07-10) but that was only an orphan-sweep test-race fix; **last substantive PR #1574 was 43 days ago (2026-06-13)**. Next (manual ghcr.io flambda rebuild + prune opt-in) is human/manual-gated. Recommendation: ESCALATE_TO_MAINTAINER (carryover, 2nd week).
- **floor-quality** — last PR #1913 was 16 days ago (2026-07-10); P1b step 3 (lens screen vs TR-SPY) is deep-warehouse maintainer-LOCAL. Was the hottest track two weeks ago. Recommendation: KEEP_AS_INFO.
- **cleanup** (code-health) — last true code-health PR #1902 was 17 days ago (2026-07-09, delete dead `check_limits`); **backlog in `cleanup.md` is 100% `[x]`**. Idle-by-design, but see the health-scan finding under P7 — the feeder is broken, not just quiet. (#2024's `cleanup(` prefix is snapshot tooling, not a code-health dispatch.) Recommendation: KEEP_AS_INFO.
- **stage-accuracy** — last PR #1864 was 20 days ago (2026-07-06); single-dial screener surface exhausted after four straight rejections. Status file stale since 2026-06-06 (see P2). Recommendation: KEEP_AS_INFO.
- **simulation** — last own-track PR #1847 was 22 days ago (2026-07-04); note #2074 (07-24) added `Simulator.on_transitions` to this track's code with **no status-file update**. Recommendation: ESCALATE_TO_MAINTAINER (status refresh, third flag).

## Stalled tracks (>30d since last PR)
- **decline-character** — last PR #1740 at 2026-06-24 (32 days); reason: track **self-declares "exhausted" (#1739)**, all decline mechanisms parked as default-off axes. Recommendation: ESCALATE_TO_MAINTAINER (mark closed — carryover, 4th week).
- **rolling-start-lens** — last own merged PR #1645/#1648 at 2026-06-18 (38 days); reason: next is LOCAL/data-gated deploy-proxy validation. Note the rolling-start *analysis* was heavily used this week — the tail-repair result inside #2001/#2021 is the decisive lens in the resistance-v2 promotion — but booked to resistance-v2. Recommendation: KEEP_AS_INFO.
- **cash-floor-correctness** — last PR #1582 at 2026-06-14 (42 days); reason: NS1 shipped and flipped ON, NS2 impl human-gated, NS4 DD-validation data-gated. Recommendation: KEEP_AS_INFO.
- **spy-only-reference** — last PR #1438 at 2026-06-03 (53 days); reason: next (sector-rotation testbed, top-1000 bankability gate, long-short verification) is explicitly a **human session**, not agent-dispatchable. Recommendation: KEEP_AS_INFO.
- **experiment-platform** — last PR #1372 at 2026-05-29 (58 days); reason: platform in steady daily use (every ledger entry this week ran through it); the code track's single-dial surface is exhausted, next continuation-buy recheck is data-gated. Recommendation: KEEP_AS_INFO (steady-state infra, not a real stall).
- **tuning** — last PR #1333 at 2026-05-27 (60 days); reason: M1 complete 5/5; **M2 qNEHVI still awaiting a maintainer enable-commit per #1327**. On the M7 critical path. Recommendation: ESCALATE_TO_MAINTAINER (carryover, 3rd week).
- **tuning-methods** (PENDING) — parked since 2026-05-24 (63 days); Step 0 done, steps 1–3 demoted, component-decomposition objective queued but never dispatched. Recommendation: KEEP_AS_INFO.
- **orchestrator-automation** — *exempt (idle by design)*: Phase 1 stable (#1332), Phase 2 deferred, "no outstanding work."

## Next Steps staleness (P2)
- **simulation** — `## Last updated: 2026-07-04`; `## Next Steps` is still the "Future slices" list (position-level assertions, T2-B perf gate) that predates the fill-router cluster (#1830/#1837/#1847), the stale-exit re-basis (#1926), and now #2074's `Simulator.on_transitions` hook. **Flagged 2026-07-12 and 2026-07-19; not actioned.** Recommend refreshing. ESCALATE_TO_MAINTAINER.
- **stage-accuracy** — `## Last updated: 2026-06-06`, file untouched in git since then (50 days). The early-Stage2 window knob shipped and was swept 2026-07-05/06 (#1862/#1864) with no file update. **Flagged 2026-07-12 and 2026-07-19; not actioned.** Recommend refreshing. ESCALATE_TO_MAINTAINER.
- **backtest-infra** — `## Last updated: 2026-06-14`; the file **never mentions C6b or #1947**, and the `_index.md` row still reads "next: validator audit-join fix (C6b, dispatched)" although **#1947 merged 2026-07-13 (13 days ago)**. The file's only July edit (#2054) appended a readme-results block without touching the header or Next Steps. **Flagged 2026-07-12 and 2026-07-19; not actioned.** Recommend refreshing the file **and** the index row. ESCALATE_TO_MAINTAINER.
- **resistance-v2** — NEW. Header says `## Last updated: 2026-07-17` but the file was edited through 2026-07-23. Both of the first two `## Next steps` items describe **already-merged** work: item 1 is the 3/3 confirmation grid (#1994, merged 07-17) and item 2 is "PROMOTION EXECUTED (2026-07-23)" (#2047). The forward queue (lever-b regime softener, WF-CV vs w30) sits below a completed-work log. Recommend refreshing the header and hoisting the live items. KEEP_AS_INFO.
- **trade-audit** — status-keyword drift: the file's `## Status` reads `MERGED` while `_index.md` lists the track `IN_PROGRESS` with open PR #2085 (which merged 2026-07-25). One of the two is wrong. KEEP_AS_INFO.
- **screener** — `_index.md` marks the track `MERGED` with no Open PR, but the track shipped #2079 on 07-24 and has **open PR #2087** (failed-breakout invalidation, issue #2084 F1) pushed 07-25, whose own branch flips the file to `READY_FOR_REVIEW`. The index row's next task ("arm min_history_bars for live weekly-review") predates all of it. Recommend an index reconcile that restores a non-MERGED status for this track. ESCALATE_TO_MAINTAINER.
- **backtest-perf / rolling-start-lens** — both files last updated 2026-06-16 / 2026-06-15 (40 / 41 days) while their subject matter (snapshot format, rolling-start distributions) carried 6+ PRs this week under `resistance-v2`. Not "first item already merged", but the ownership boundary has drifted far enough that the files no longer describe where the work happens. KEEP_AS_INFO.
- **Pattern note (not individually actionable):** on 7 further tracks the first `## Next Steps` entry is a struck-through or ✅-marked completed item — `cash-floor-correctness` (NS1 SHIPPED), `extension-stop` (acceptance audit DONE), `experiment-platform` (item 1 superseded), `tuning` (items 1–5 struck), `weekly-snapshot` (M6.6 DONE), `walk-forward-cv`, `experiments`. Nothing is hidden in any of them (each marks its own completion), so this is a formatting convention rather than a staleness defect — but it means the P2 "first item" heuristic cannot be read mechanically on this repo.

## [info] items needing decision (P3)
- None. `dev/status/_index.md` carries **0** `[info]`-tagged items; the 2026-07-25 header block explicitly records "No `[drift]`, no `[critical]`." The header is a single-run reconcile narrative with no carried-forward `[info]` list, so there is nothing to age.

## Tracks without owner (P4)
- None on the index. Every IN_PROGRESS / READY_FOR_REVIEW row carries an owner, including the two newest tracks — **leverage-dawn** (created ~2026-07-24, owner `feat-weinstein`) and **tax-lens** (created ~2026-07-24, owner `feat-backtest`).
- **Adjacent gap (not an index row, so P4 cannot see it):** the **weekly-picks execution program** (`dev/plans/weekly-picks-execution-protocol-2026-07-24.md`, Phases A+B merged as #2078, Phase C pending) has **no track row and no owner**, and issue **#2084 Finding 2** (naive `entry * 0.92` structural stop in the weekly-snapshot generator) is explicitly declared out of scope by #2087 with no owner assigned. Recommend: RECOMMEND_NEW_TRACK (or an explicit owner under `weekly-snapshot`).

## Recurring discussion topics (P5)
- None from the P5 scan surface. `dev/decisions.md` has **no entries in the last 30 days** — the most recent is 2026-05-16 (the Option-B IWV-scrape pivot). Standing observation (carried for the 4th week): `dev/decisions.md` has effectively been retired as the human→agent decision channel in favour of `dev/notes/next-session-priorities-*.md` handoffs and the daily orchestrator summaries, neither of which P5 scans. If the maintainer wants P5 to keep working, the check should be re-pointed at the handoff docs; that is a human decision, so: KEEP_AS_INFO.

## Diminishing returns (P6)
- **No track trips the strict heuristic** (≥3 of the last 5 PRs matching `chore` / `fix(linter)` / `golden` / `repin` / `fmt`). Only 1 of 21 substantive merges in the last 7d is maintenance-shaped (#2024). Four softer signals:
  - **resistance-v2** — **not** diminishing, but at a natural inflection: the promotion it existed to produce has shipped (#2047). What remains is the default-off lever-b regime softener and a data-gated WF-CV-vs-w30. Worth deciding whether the track stays open at high dispatch priority or drops to axis-maintenance.
  - **rename-twin-dedup** — **effectively complete**: v1+v2 (#1940/#1946) plus the record re-run (#1949) all landed, no open Next Steps, index next-task reads "none". Recommended for closure on 2026-07-19 and again here.
  - **decline-character** — self-declares exhausted (#1739); every mechanism ended as a default-off axis. 4th consecutive week recommending closure.
  - **stage-accuracy** — a rejection streak rather than maintenance churn (force_exit_off REJECT #1503, cascade-inversion #1509, late-stage2-stop-tighten grid REJECT, early-Stage2 window REJECT #1864). The file itself points at breadth, not stage dials, as the remaining lever. KEEP_AS_INFO.

## Capability gaps (P7)
- **Weekly deep health scan stopped landing — NEW, and it starves the `cleanup` track.** The 2026-07-20 scan was produced (branch `ops/health-deep-2026-07-20`, commit dated 07-20) but is **not contained in `main`**; the newest deep scan on main is `dev/health/2026-07-13-deep.md`. `cleanup.md`'s backlog is entirely `[x]`, so `code-health` has had nothing to dispatch for 17 days. Per `code-health-discipline.md` ("if the cleanup agent only fires on linter failure, it's already too late"), a silently-dropped deep scan is exactly the leading-indicator loss that rule warns about. Recommend: ESCALATE_TO_MAINTAINER — merge or re-run the 07-20 scan and check why the branch never became a merged PR.
- **Live weekly-pick correctness has no owning track — NEW.** Issue **#2084** came out of a real live artefact (the 07-17 report's rank-1 BUY carried an entry 30%+ above market). Finding 1 has a fix open as **PR #2087** (failed-breakout invalidation, default-off, filed against the `screener` track — which the index still marks MERGED). **Finding 2** (the naive `entry * 0.92` structural stop in the weekly-snapshot generator) is explicitly out of scope for #2087 and is **unowned**. Now that #2078 emits *sized, actionable orders*, defects on this path are the highest-consequence class in the system. Milestone: M6.6. Recommend: ESCALATE_TO_MAINTAINER.
- **EODHD data access absent in the GHA orchestrator environment** — still the dominant systemic blocker. Data-gated next-tasks on: backtest-infra P2 matrix, backtest-perf regime lenses, stage-accuracy broad WF-CV, experiment-platform continuation-buy recheck, simulation stale-exit grid, weekly-snapshot multi-week sweep, cash-floor NS4, data-foundations IWV scrape, floor-quality P1b step 4, post-run-validation golden-run test, tuning surfaces. The maintainer keeps routing around it — the entire resistance-v2 promotion evidence chain was generated **LOCAL**. Milestone impact: M6 + M7. Recommend: ESCALATE_TO_MAINTAINER — provision the key in GHA, or **formally re-scope the orchestrator to build/plan-only for WF-CV tracks** so the cron stops idling on ~11 data-gated rows. (Carryover, 3rd week.)
- **`tuning` M2 qNEHVI blocked on a maintainer enable-commit (#1327)** — 60 days stalled on a one-line human action, on the M7 critical path. Recommend: ESCALATE_TO_MAINTAINER. (Carryover, 3rd week.)
- **`harness` #2009 (LAPACKE GP-Cholesky nugget) is a 7-day-old WIP with a written completion path** — `harness.md:166` records the exact recovery recipe (`git apply` the preserved patch, add the near-singular-kernel guard test, build/runtest, push). It is the residual CI flake in `test_bayesian_opt.exe`. Separately, the ci.yml ENOSPC fix remains blocked on a `workflow`-scoped PAT (#1636). Recommend: ESCALATE_TO_MAINTAINER. (Carryover.)
- **`sweep-perf` manual ghcr.io flambda rebuild** — the only human/manual step left on the track; substantive work has been stopped 43 days behind it. Recommend: ESCALATE_TO_MAINTAINER. (Carryover.)
- **M6.6 true live cycle** — now the closest it has ever been: promoted config in production (#2047), first live run on it (#2050), portfolio state + sized instructions (#2078), picks backfill + decision record (#2075). Remaining: user edits real cash into `dev/weekly-picks/portfolio.sexp`, then Phase C (HTML + SVG charts), then live DATA_SOURCE + cron + alerts. Recommend: KEEP_AS_INFO (human-sequenced, and actively moving).
- **`leverage-dawn` WF-CV surface + promotion grid** — the mechanism merged default-off (#2077) after a funding-correctness rework; the ~8–9h surface run has not started and `sweep-hygiene.md` applies. Recommend: KEEP_AS_INFO (queued, not blocked).

## Recommendations
1. **Merge or re-run the 2026-07-20 weekly deep health scan** and diagnose why `ops/health-deep-2026-07-20` never landed — the `cleanup` backlog is empty and `code-health` has been unfed for 17 days. This is the only finding this week where a *process* is silently dropping output.
2. **Assign an owner to weekly-picks execution and to issue #2084 Finding 2** (the `entry * 0.92` structural stop). Either open a `picks-execution` track row or fold both explicitly under `weekly-snapshot`. The system now emits sized orders; this path has the highest defect consequence and the weakest ownership.
3. **Refresh the three lagging status files — third consecutive ask.** `simulation.md`, `stage-accuracy.md`, `backtest-infra.md`, plus the `backtest-infra` index row that still calls C6b "dispatched" 13 days after #1947 merged. Per `feedback_status_refresh_must_verify`, these mislead the next dispatch; two prior recommendations went unactioned.
4. **Reconcile the `screener` row** — it is marked MERGED with no Open PR while carrying open PR #2087 and a READY_FOR_REVIEW status on its own branch. Then **review and land #2087** (live-pick failed-breakout invalidation, default-off, R1/R2/R3 clean per its PR body).
5. **Decide the EODHD-in-GHA question** — provision the key, or formally mark the WF-CV tracks build/plan-only so the cron stops idling on ~11 data-gated rows. The de-facto answer (everything runs LOCAL) has held for three weeks; make it explicit.
6. **Close the three finished tracks** — `rename-twin-dedup` (no open Next Steps, 2nd ask), `decline-character` (self-declared exhausted, 4th ask), and decide whether `resistance-v2` drops to axis-maintenance now that #2047 shipped. Leaving them IN_PROGRESS overstates in-flight work by three rows.
7. **Unblock the four one-action human gates**: `tuning` M2 enable-commit (#1327, 60d, M7 critical path); `harness` #2009 nugget-escalation WIP (recipe already written); the `workflow`-scoped PAT for #1636; the manual ghcr.io flambda rebuild for `sweep-perf`.
8. **Sequence the two queued runs** — user edits real cash into `dev/weekly-picks/portfolio.sexp` (unblocks Phase C), and the `leverage-dawn` WF-CV surface (~8–9h, `sweep-hygiene.md` applies).

## Stats
- 70 PRs merged in last 7d (36 `ops: daily orchestrator summary`, 21 substantive feat/fix/test/experiment/perf/cleanup/spec, remainder docs/handoff/weekly-ops)
- 306 PRs merged in last 30d (107 ops daily summaries, 97 substantive)
- 6 tracks active / 11 slowing / 6 stalled-IN_PROGRESS (+1 PENDING parked, +1 idle-by-design exempt); 3 MERGED-labelled tracks also shipped work
- 0 `[info]` items carried ≥3 reconciles
- 8 capability-gap bottlenecks flagged: 1 systemic (EODHD-in-GHA), 2 new (deep-health-scan cadence break, unowned live-pick correctness/#2084 F2), 5 carried human/manual actions (tuning M2 enable-commit, harness #2009, harness workflow-PAT #1636, sweep-perf ghcr.io rebuild, M6.6 sequencing)
- 3 status-file refreshes now outstanding for a third consecutive week

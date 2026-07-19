# Track Pacer Report — 2026-07-19

## Summary
- Tracks audited: 47 rows (24 non-MERGED: 23 IN_PROGRESS + 1 PENDING; 23 MERGED). Cadence run on the 24 non-MERGED rows.
- Active (≥1 PR last 7d): 8
- Slowing (7–30d since last PR): 8
- Stalled (>30d): 6 IN_PROGRESS + 1 PENDING parked (+1 idle-by-design, exempt)
- [info] items needing decision: 0
- Capability gaps flagged: 1 systemic (EODHD data-gating in GHA) + 4 human/manual-gated bottlenecks

Headline: the maintainer-LOCAL focus **pivoted this week** — last week's hottest
track (`floor-quality`, 7 PRs) went quiet (9d), and a **brand-new track,
`resistance-v2` (created 2026-07-15), dominated**. In ~4 days it shipped an
entire continuous-supply-score mechanism end-to-end: score module (#1979) →
snapshot sketch feed (#1975/#1982) → default-off wiring (#1983) → WF-CV spec
(#1988) → **3/3 ACCEPT confirmation grid (#1994)** → promotion-decision handoff
(#2001/#2004). This is the standout: a mechanism that actually **reached ACCEPT
and is now at a human-gated R3 promotion decision**, not another default-off axis
parked in the ledger. A second new track, `margin-realism`, landed M1/M1b-1
default-off (#1990/#1998); its next step (M1b-2 portfolio-side debit) is an A1
core-module change gated on decision-item review. Throughput stayed high
(65 merges / 27 substantive in 7d). No pace pathology; the bottleneck is
decision/access — EODHD-in-GHA data-gating, plus four concrete human/manual
actions. **One process regression:** the three status-file refreshes recommended
on 2026-07-12 (`simulation`, `stage-accuracy`, `backtest-infra`) were **not
actioned** and are still stale — re-flagged with escalation.

## Active tracks (≥1 PR last 7d)
- **resistance-v2** — ~16 PRs (#1974, #1975, #1979, #1980, #1982, #1983, #1987, #1988, #1989, #1993, #1994, #1997, #2001, #2002, #2004, + #1966/#1952 resistance-history/min-history feeds); theme: **continuous supply-weight score built end-to-end and promoted through the full pipeline** — module + PIT-sketch feed + default-off wiring + WF-CV + **3/3 ACCEPT confirmation grid** + virgin-crossing re-admission lever (#1997/#2002). Now at a human-gated promotion decision. The hottest track this week.
- **margin-realism** — 2 substantive (#1990 M1 long buying power + priced margin interest; #1998 M1b-1 entry-walk cash-gate leverage relaxation), both default-off; plus #1969 long-short margin plan. New track; next (M1b-2 portfolio-side debit) is an A1 core-module change, decision-item-gated.
- **extension-stop** — 2 PRs (#1934 default-off tail-insurance extension stop; #1960 record-convention + live weekly-review arming package, P0); default-flip gated on further insurance-ACCEPT (R3, human-gated).
- **rename-twin-dedup** — 3 PRs (#1940 dedup pass, #1946 twin-detector v2 returns-basis, #1949 record re-run + first full-coverage audit); **track is effectively complete** — status file has no open Next Steps and the index next-task reads "next: none (optional V6 tweak)". See Diminishing returns.
- **post-run-validation** — 2 PRs (#1937 trade-validation harness v1 V1–V11; #1947 C6b audit-join-by-position_id, which un-skipped V1/V2/V7/V8); next golden-run integration test is data-gated.
- **harness** — 2 PRs (#1954 harden linter find calls vs dune sandbox races; #1961 pin owl to portable SIMD, kills the #1955 runner lottery). **Turned active this week** after 25d slowing — but the specific ci.yml ENOSPC fix remains PAT-gated (see P7).
- **backtest-infra** — 1 PR (#1942 key trades.csv exit_trigger/stop_trigger_kind by position_id, 2026-07-12 — boundary). Next validator work (C6b) already shipped as #1947; the index row lags (see P2).
- **data-foundations** — 1 PR (#1939 asset-type blocklist filter, default-off, 2026-07-12 — boundary); next: arm ATB.curated for live universe build. The load-bearing Phase-1.4 IWV scrape remains ops-gated.

_(Note: `screener` is marked MERGED in the index yet received resistance/arming work this week — #1941/#1952 fold into the resistance-v2 program above. Mild status-keyword drift, not a cadence finding.)_

## Slowing tracks (7–30d since last PR)
- **floor-quality** — last PR #1913 was 9 days ago (2026-07-10); theme: index circuit-breaker SPY-sleeve (P1b step 2). **Was last week's hottest track (7 PRs); the maintainer pivoted to resistance-v2.** Next (P1b step 3 lens screen vs TR-SPY) is deep-warehouse LOCAL / S5. Recommendation: KEEP_AS_INFO.
- **short-side-strategy** — last clearly-attributable PR #1919 was 9 days ago (2026-07-10, liquidity-overlay WF-CV); the 07-14 Run-E long-short A/B work (#1968) has migrated into the new `margin-realism` track. Next: short-leg regime-P&L decomposition (LOCAL/data-gated). Recommendation: KEEP_AS_INFO.
- **cleanup** (code-health) — last PR #1902 was 10 days ago (2026-07-09, delete dead check_limits); idle-by-design, fires on real findings. Recommendation: KEEP_AS_INFO.
- **stage-accuracy** — last PR #1864 was 13 days ago (2026-07-06); single-dial screener surface exhausted (four straight rejections). Status file stale (see P2). Recommendation: KEEP_AS_INFO.
- **simulation** — last PR #1847 was 15 days ago (2026-07-04); fill-router / round-trip correctness cluster. Next stale-exit grid is data-gated. Status file stale (see P2). Recommendation: KEEP_AS_INFO.
- **weekly-snapshot** — last PR #1784 was 21 days ago (2026-06-28); next (large-warehouse multi-week sweep) is data-gated, live-cycle human-gated. Recommendation: KEEP_AS_INFO.
- **decline-character** — last PR #1779 was 21 days ago (2026-06-28); track **self-declares "exhausted" (#1739)** — all decline mechanisms are default-off axes. Recommendation: KEEP_AS_INFO / lower dispatch priority (carryover).
- **sweep-perf** — last PR #1921 was 9 days ago (2026-07-10) but that was only an orphan-sweep test-race fix; **last substantive PR #1574 was 36 days ago (2026-06-13)**. Next (manual ghcr.io flambda rebuild + prune opt-in) is human/manual-gated. Recommendation: ESCALATE_TO_MAINTAINER (manual rebuild).

## Stalled tracks (>30d since last PR)
- **backtest-perf** — last PR #1631 at 2026-06-16 (33 days); crossed slowing→stalled this week. Reason: next (regime-diverse lenses on snapshot-format-v2) is LOCAL-only. Recommendation: KEEP_AS_INFO (not a true stall — LOCAL-gated).
- **rolling-start-lens** — last merged PR #1614 at 2026-06-16 (33 days); crossed slowing→stalled this week. Recent factor-lens matrices (#1639/#1642) are LOCAL, not merged; next is LOCAL/data-gated deploy-proxy validation. Recommendation: KEEP_AS_INFO.
- **cash-floor-correctness** — last PR #1582 at 2026-06-14 (35 days); NS1 shipped, NS2 impl human-gated, NS4 DD-validation data-gated. Recommendation: KEEP_AS_INFO.
- **spy-only-reference** — last PR #1438 at 2026-06-03 (46 days); next (sector-rotation testbed, top-1000 bankability gate, long-short verification) is explicitly a **human session**, not agent-dispatchable. Recommendation: KEEP_AS_INFO.
- **experiment-platform** — last PR #1372 at 2026-05-29 (51 days); this is a **platform in steady daily use** (every `experiment(...)` PR runs through it); the code track's single-dial surface is exhausted, next continuation-buy recheck is data-gated. Recommendation: KEEP_AS_INFO (steady-state infra, not a real stall).
- **tuning** — last PR #1333 at 2026-05-27 (53 days); M1 complete (5/5); **M2 qNEHVI awaiting a maintainer enable-commit per #1327**. On the M7 critical path. Recommendation: ESCALATE_TO_MAINTAINER.
- **tuning-methods** (PENDING) — parked since 2026-05-24; Step 0 done, steps 1–3 demoted; component-decomposition objective is the intended next unit but nothing is queued. Recommendation: KEEP_AS_INFO.
- **orchestrator-automation** — *exempt (idle by design)*: Phase 1 stable (#1332), Phase 2 deferred, "no outstanding work." No stalled-flag warranted.

## Next Steps staleness (P2)
- **simulation** — `## Last updated: 2026-07-04`; `## Next Steps` is still the old "Future slices" list (position-level assertions, T2-B perf gate) that predates the fill-router cluster (#1830/#1837/#1847) and the stale-exit re-basis (#1926). No first-item-already-merged trap, but the section is stale. **Flagged 2026-07-12; not actioned.** Recommend refreshing. (KEEP_AS_INFO → now ESCALATE given repeat.)
- **stage-accuracy** — `## Last updated: 2026-06-06`; the early-Stage2 window knob shipped + was swept 2026-07-06 (#1862/#1864) with no file update. First Next-Step correctly marked "DONE 2026-06-06: REJECTED", so nothing is hidden, but the recent knob work is unrecorded. **Flagged 2026-07-12; not actioned.** Recommend refreshing.
- **backtest-infra** — `## Last updated: 2026-06-14`; Next Steps reference Step 3 (tracked on `backtest-scale`) + per-bar instrumentation, none reflecting the C1–C4 correctness sweep (#1939–#1942). **Fresh index-level staleness this week:** the `_index.md` row still reads "next: validator audit-join fix (C6b, dispatched)" but **C6b shipped as #1947 (merged 2026-07-13)**. **Flagged 2026-07-12; not actioned.** Recommend refreshing the file + the index row.
- Minor, expected lag: the `_index.md` header (updated 2026-07-18 16:12) lists "1 open PR — #2002" but #2002 merged 2026-07-18 20:37 and #2004 followed 2026-07-19. Self-corrects on next reconcile; noted only for completeness.

## [info] items needing decision (P3)
- None. `dev/status/_index.md` carries 0 `[info]`-tagged items; the header is a single-run reconcile narrative with no carried-forward `[info]` list.

## Tracks without owner (P4)
- None. The two newest tracks — **resistance-v2** (created ~2026-07-15, owner `local-session` / `dayfine maintainer LOCAL`) and **margin-realism** (created ~2026-07-14, owner `dayfine maintainer LOCAL`) — both carry owners. No empty Owner cells on any non-MERGED row.

## Recurring discussion topics (P5)
- None from the P5 scan surface. `dev/decisions.md` has no entries within the last 30 days (most recent: 2026-05-16, the Option-B IWV-scrape pivot). Cross-session decision-making runs through the daily `ops: daily orchestrator summary` PRs and `dev/notes/next-session-priorities-*.md` handoff docs, which P5 does not scan. Standing observation (carried): `dev/decisions.md` has effectively been retired as the human→agent channel in favour of handoff docs.

## Diminishing returns (P6)
- No track trips the strict heuristic (≥3 of last 5 PRs matching chore/fix(linter)/golden/repin/fmt). Three signals:
  - **rename-twin-dedup** — **effectively complete**. v1+v2 (#1940/#1946) merged, dedup warehouse rebuilt + 28y record re-run landed (#1949); the status file has no open Next Steps and the index next-task reads "next: none (optional V6 report-consult tweak)." Not maintenance churn — a finished feature. Recommend **marking MERGED / closing** so it stops reading as IN_PROGRESS. (RESOLVED-adjacent.)
  - **decline-character** — self-declares "exhausted" (#1739); every mechanism swept to a default-off axis with no promotion. Consider marking effectively closed pending new evidence (carryover from 2026-07-05/07-12).
  - **stage-accuracy** — a rejection streak, not maintenance churn: force_exit_off REJECT (#1503), cascade-inversion (#1509), late-stage2-stop-tighten grid REJECT, early-Stage2 window REJECT (#1864). The single-dial screener surface is exhausted; the file itself points at breadth (not stage dials) as the lever. KEEP_AS_INFO.

## Capability gaps (P7)
- **EODHD data access absent in the GHA orchestrator environment** — still the single dominant cross-track blocker (data-gated next-tasks on backtest-infra P2 matrix, backtest-perf regime lenses, stage-accuracy broad WF-CV, experiment-platform continuation-buy recheck, simulation stale-exit grid, weekly-snapshot multi-week sweep, cash-floor NS4, data-foundations IWV scrape, floor-quality P1b step-4, tuning surfaces). The maintainer continues to route around it — resistance-v2's full WF-CV + 3/3 ACCEPT confirmation grid was generated **LOCAL**, the cron's role for these tracks is build/plan-only. Milestone impact: M6 (validation harness) + M7 (tuning). Recommend: ESCALATE_TO_MAINTAINER — either provision the EODHD key in GHA, or **formally re-scope the orchestrator to build/plan-only for WF-CV tracks** so it stops idling on data-gated rows (make the de-facto state explicit). (Carryover.)
- **resistance-v2 supply-weight promotion decision (R3) — NEW human-gated bottleneck.** The mechanism has a **3/3 ACCEPT confirmation grid (#1994)** and a promotion-decision handoff with rolling-start distribution + divergence forensic (#2001) and vc-pair 28y results (#2004). This is the closest any mechanism has come to a default-flip in weeks — it needs a maintainer promotion decision. Recommend: ESCALATE_TO_MAINTAINER (decide promote/hold on the supply-weight default).
- **margin-realism M1b-2 portfolio-side debit — human-gated A1 core-module change.** Next step touches a core module and requires decision-item review before proceeding. Recommend: ESCALATE_TO_MAINTAINER.
- **`tuning` M2 qNEHVI blocked on a maintainer enable-commit (#1327)** — on the M7 critical path; ~53 days stalled on a one-line human action. Recommend: ESCALATE_TO_MAINTAINER. (Carryover.)
- **`harness` ci.yml ENOSPC fix blocked on a `workflow`-scoped PAT (#1636)** — infrastructure, not a Weinstein-domain feature; YAML already staged. The track shipped other CI fixes this week (#1954/#1961), so it is not idle — only this item is PAT-gated. Recommend: ESCALATE_TO_MAINTAINER. (Carryover.)
- **M6.6 true live cycle** — the remaining open M6 item (live DATA_SOURCE + cron + alerts). Cross-track: weekly-snapshot live-cycle human-gated; decision-audit live-picks pipeline ready (#1812); resistance-v2 heading toward a promotable screener change. Not started; a human decision. Recommend: KEEP_AS_INFO.

## Recommendations
1. **Decide the resistance-v2 supply-weight promotion** (maintainer) — it has a 3/3 ACCEPT confirmation grid (#1994) and a promotion handoff (#2001/#2004); this is the ripest default-flip candidate on the board. Promote or hold with a recorded rationale.
2. **Refresh the three lagging status files** — `simulation.md`, `stage-accuracy.md`, `backtest-infra.md` — and fix the `backtest-infra` index row that still calls C6b "dispatched" when #1947 merged 2026-07-13. **These were recommended on 2026-07-12 and not actioned;** per `feedback_status_refresh_must_verify` they lag main and mislead the next dispatch.
3. **Decide the EODHD-in-GHA question, and make the LOCAL-only re-scope explicit** (maintainer) — the promotion pipeline already runs LOCAL for the hot tracks; either provision the key in GHA or formally mark the WF-CV tracks build/plan-only so the cron stops idling on ~10 data-gated rows.
4. **Unblock `tuning` M2** — land the maintainer enable-commit for qNEHVI (#1327); ~53 days stalled on a one-line action, M7 critical path.
5. **Review the `margin-realism` M1b-2 decision item** (A1 core-module portfolio-side debit) so the track can proceed past its default-off primitives.
6. **Mark `rename-twin-dedup` MERGED / closed** — v1+v2 + record re-run all landed and the track has no open Next Steps; leaving it IN_PROGRESS overstates in-flight work.
7. **Supply the `workflow`-scoped PAT** for the `harness` ci.yml ENOSPC fix (#1636), and **do the manual ghcr.io flambda rebuild** to unblock `sweep-perf`'s prune opt-in — both recurring, both the only human-gated step remaining on their tracks.
8. **Mark `decline-character` effectively closed** — self-declares exhausted (#1739); keep mechanisms as default-off axes and stop spending cron cycles until new evidence appears (carryover).

## Stats
- 65 merges in last 7d (20 ops daily summaries, 27 substantive feat/fix/experiment/data/perf/screen/test, remainder docs/handoff/weekly-ops)
- 336 merges in last 30d (89 substantive feat/fix/experiment/data/perf/screen/test)
- 8 tracks active / 8 slowing / 6 stalled-IN_PROGRESS (+1 PENDING parked, +1 idle-by-design exempt)
- 0 `[info]` items carried ≥3 reconciles
- 6 capability-gap bottlenecks flagged: 1 systemic (EODHD-in-GHA) + 5 concrete human/manual actions (resistance-v2 R3 promotion, margin-realism M1b-2 decision item, tuning M2 enable-commit, harness workflow-PAT, sweep-perf ghcr.io rebuild)

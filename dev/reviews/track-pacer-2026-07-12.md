# Track Pacer Report — 2026-07-12

## Summary
- Tracks audited: 43 (19 IN_PROGRESS + 1 PENDING + 23 MERGED); cadence run on the 20 non-MERGED rows
- Active (≥1 PR last 7d): 6
- Slowing (7–30d since last PR): 9
- Stalled (>30d): 3 actionable + 1 parked (PENDING) (+1 idle-by-design, exempt)
- [info] items needing decision: 0
- Capability gaps flagged: 1 systemic (EODHD data-gating in GHA) + 2 human-gated bottlenecks

Headline: throughput is high (82 merges / 23 substantive PRs in 7d) but the
substance has **concentrated hard into the maintainer-LOCAL floor-quality +
short-side realism program** — the `honest-tradeable deep baseline` re-basis
(warmup 210→364, entry-gate + stale-exit default-on) plus the P1b index
circuit-breaker SPY-sleeve. Everything else on the roadmap is gated on things
the cron cannot do: EODHD bars in GHA (10+ data-gated next-tasks), a maintainer
enable-commit (`tuning` M2), a `workflow`-scoped PAT (`harness` CI), and a manual
ghcr.io rebuild (`sweep-perf`). No pace pathology; the bottleneck is
decision/access, and the real promotion evidence is now being generated LOCAL,
not under the cron. Three status files (`simulation`, `stage-accuracy`,
`backtest-infra`) have Next-Steps that lag recent merges — recommend a refresh.

## Active tracks (≥1 PR last 7d)
- **floor-quality** — 7 PRs (#1894, #1903, #1904, #1910, #1912, #1913, #1931); theme: honest-tradeable deep baseline of record (realized beats TR-SPY, #1912) + **index circuit-breaker SPY-sleeve** built pure-lib → consumer (P1b steps 1–2, #1904/#1913) + Portfolio_floor ablation and **portfolio-floor trigger flipped default-off** (0.4→0.0, user mandate, #1910/#1903) + S1 AXTI exit verification (#1931). The hottest track; maintainer-LOCAL, deep-warehouse basis.
- **short-side-strategy** — 4 PRs (#1897, #1906, #1909, #1919); theme: short-leg realism — **neutral_blocks_shorts flipped default-true** (faithfulness flip, #1909), warmup-straddle round-trip mislabeled-as-SHORT LH-leak fix (#1906), catstop deep WF-CV (Reject-promotion, fold-honest wash, #1897), liquidity-overlay WF-CV (hold-exit alone is the real lever; bundle inverts at fold level, #1919). Disciplined land-safe/search/don't-promote loop.
- **extension-stop** — 2 PRs (#1933, #1934); theme: default-off **tail-insurance extension stop** — event-level counterfactual screen (no-build as an alpha axis; P0a insurance build queued, #1933) then the primitive merged default-off via 3-gate auto-merge (#1934). Newest track; next is a LOCAL insurance-basis acceptance audit (`[non-blocking]`).
- **stage-accuracy** — 2 PRs (#1862, #1864); theme: **early-Stage2 ≤4-week window lifted into a config knob** (#1862) then swept — alternatives REJECT, ≤4 validated (#1864). Stays default-off axis. (Status file lags — see P2.)
- **data-foundations** — 1 PR (#1900); theme: `audit_bars` spike-revert corrupt-bar warehouse scanner (data-quality tooling). The load-bearing Phase-1.4 IWV scrape remains ops-gated (needs a ~3-hr `ops-data` run); this PR is adjacent tooling, not the scrape.
- **cleanup** (code-health) — 1 PR (#1902); theme: delete dead `check_limits` (zero callers) in `portfolio_risk`. Idle-by-design track; fired on a real dead-code finding this week.

## Slowing tracks (7–30d since last PR)
- **simulation** — last PR #1847 was 8 days ago (2026-07-04); theme: fill-router / round-trip pairing correctness cluster. The maintainer realism re-basis (#1926 stale-exit default-on) touched this track's stated next-task (`stale-exit grid`) but landed as a basis flip, not the WF-CV grid. Recommendation: KEEP_AS_INFO (and refresh the file — see P2).
- **weekly-snapshot** — last PR #1826 was 10 days ago (2026-07-02); theme: weekly-picks integrity + configurable report display cap. Next (large-warehouse multi-week sweep) is data-gated; live-cycle human-gated. Recommendation: KEEP_AS_INFO.
- **decline-character** — last PR #1779 was 14 days ago (2026-06-28); track **self-declares "exhausted" (#1739)** — all decline mechanisms are default-off axes with no promotion. Recommendation: KEEP_AS_INFO / lower dispatch priority (carryover from 2026-07-05).
- **backtest-infra** — last clearly-attributable PR ~#1743/#1617 (~18–28 days ago); the maintainer basis-change PRs (#1890 warmup 210→364, #1926 realism) touch the backtest runner basis but are folded into the floor-quality program, not this track. Next P2 composition-policy matrix is data-gated. Recommendation: KEEP_AS_INFO (and refresh the file — see P2).
- **backtest-perf** — last PR #1631 was 18 days ago (2026-06-24); theme: snapshot-format-v2 (S4 PROVEN). Next regime-diverse lenses on v2 are LOCAL-only. Recommendation: KEEP_AS_INFO.
- **harness** — last PR #1636 was 25 days ago (2026-06-17); theme: CI disk-headroom fix. **ci.yml ENOSPC fix is BLOCKED on a human with a `workflow`-scoped PAT** (exact YAML in #1636 body). Recommendation: ESCALATE_TO_MAINTAINER.
- **rolling-start-lens** — last merged PR #1614 was 26 days ago (2026-06-16); recent factor-lens matrices (#1639/#1642) are LOCAL, not merged; next is LOCAL/data-gated deploy-proxy validation. Recommendation: KEEP_AS_INFO.
- **cash-floor-correctness** — last PR #1582 was 28 days ago (2026-06-14); NS1 shipped (#1567/#1582), NS2 impl is human-gated, NS4 DD-validation is data-gated. Recommendation: KEEP_AS_INFO.
- **sweep-perf** — last substantive PR #1574 was 29 days ago (2026-06-13); #1921 (07-10) was an orphan-sweep test-race fix only. Next is a **manual ghcr.io flambda rebuild** + enabling the prune opt-in — human/manual-gated. Recommendation: ESCALATE_TO_MAINTAINER (manual rebuild step).

## Stalled tracks (>30d since last PR)
- **spy-only-reference** — last PR #1438 at 2026-06-03 (39 days); reason: next task (sector-rotation scenarios, top-1000 bankability gate, long-short verification) is explicitly a **human session**, not agent-dispatchable. Recommendation: KEEP_AS_INFO.
- **experiment-platform** — last PR #1372 at 2026-05-29 (44 days); reason: this is now a **platform in steady daily use** (every `experiment(...)` PR runs through it) — the *code* track's single-dial surface is exhausted; next continuation-buy recheck on top-3000 is data-gated. Recommendation: KEEP_AS_INFO (not a real stall — steady-state infra).
- **tuning** — last PR #1333 at 2026-05-28 (45 days); reason: M1 complete (5/5); **M2 qNEHVI is awaiting a maintainer enable-commit per #1327** — a concrete pending human action. On the M7 critical path. Recommendation: ESCALATE_TO_MAINTAINER.
- **tuning-methods** (PENDING) — parked since 2026-05-24; Step 0 done, steps 1–3 demoted ("surface is the bind"); component-decomposition objective is the intended next unit but nothing is queued. Recommendation: KEEP_AS_INFO.
- **orchestrator-automation** — *exempt (idle by design)*: Phase 1 stable (#1332), Phase 2 deferred, "no outstanding work." No stalled-flag warranted.

## Next Steps staleness (P2)
- **simulation** — `## Next Steps` is an old "Future slices" list (position-level assertions, performance-gate T2-B) that predates the fill-router correctness cluster (#1830/#1837/#1847) and the stale-exit re-basis (#1926). The index "Next task" cell (`stale-exit grid via WF-CV`) is not reflected in the file. No first-item-already-merged trap, but the section is stale. Recommend the owner refresh `dev/status/simulation.md`. (KEEP_AS_INFO.)
- **stage-accuracy** — file `## Last updated: 2026-06-06`, but the early-Stage2 window knob shipped + was swept 2026-07-06 (#1862/#1864) with no file update. First Next-Step is correctly marked "DONE 2026-06-06: REJECTED", so nothing is hidden, but the recent knob work is unrecorded. Recommend refreshing. (KEEP_AS_INFO.)
- **backtest-infra** — file `## Last updated: 2026-06-14`; Next Steps reference Step 3 (tracked on `backtest-scale`) and per-bar instrumentation, while the index next-task is the data-gated P2 composition matrix. Drift, not a merged-item trap. Recommend a light refresh. (KEEP_AS_INFO.)
- All other active/slowing tracks (floor-quality, extension-stop, short-side-strategy, data-foundations, weekly-snapshot, cash-floor-correctness) mark completed items explicitly and their first pending item is genuinely open. No staleness.

## [info] items needing decision (P3)
- None. `dev/status/_index.md` carries 0 `[info]`-tagged items; the header is a single-run reconcile narrative with no carried-forward `[info]` list.

## Tracks without owner (P4)
- None. The two newest tracks — **extension-stop** (created ~2026-07-10) and **floor-quality** (created ~2026-07-08) — both carry `dayfine (maintainer LOCAL)` as owner. No empty Owner cells on any non-MERGED row.

## Recurring discussion topics (P5)
- None from the P5 scan surface. `dev/decisions.md` has no entries within the last 30 days (most recent: 2026-05-16). Cross-session decision-making runs through the daily `ops: daily orchestrator summary` PRs and `dev/notes/next-session-priorities-*.md` / handoff PRs, which P5 does not scan. No unresolved recurring topic to surface. (Standing observation, carried from prior weeks: `dev/decisions.md` has effectively been retired as the human→agent channel in favour of handoff docs.)

## Diminishing returns (P6)
- No track trips the strict heuristic (≥3 of last 5 PRs matching chore/fix(linter)/golden/repin/fmt). Three soft signals:
  - **decline-character** — self-declares "exhausted" (#1739); every mechanism swept to a default-off axis with no promotion. Recent PRs are feature+ledger work that all ended default-off. Consider marking effectively closed pending new evidence (carryover recommendation from 2026-07-05).
  - **stage-accuracy** — a rejection streak, not maintenance churn: force_exit_off REJECT (#1503), cascade-inversion documented (#1509), late-stage2-stop-tighten grid REJECT (2026-06-06), early-Stage2 window REJECT (#1864). The single-dial screener surface looks exhausted; the file itself points at breadth (not stage dials) as the lever. KEEP_AS_INFO.
  - **simulation** — the last cluster is 4 back-to-back `fix(...)` on the fill-router / round-trip path (#1830/#1837/#1847 + #1906 label fix). Genuine correctness fixes, not linter/format churn, so not "diminishing returns" — but the cluster confirms that area was structurally buggy; worth a confirming WF-CV once data-gating lifts. KEEP_AS_INFO.

## Capability gaps (P7)
- **EODHD data access absent in the GHA orchestrator environment** — still the single dominant cross-track blocker (10+ "data-gated" next-tasks: backtest-infra P2 matrix, backtest-perf regime lenses, stage-accuracy broad-universe WF-CV, experiment-platform continuation-buy recheck, simulation stale-exit grid, weekly-snapshot multi-week sweep, cash-floor NS4, data-foundations IWV re-pin, floor-quality P1b step-4 deep bear-regime grid, tuning surfaces). **New framing this week:** the maintainer has effectively routed around it — the floor-quality + short-side promotion evidence (deep-warehouse WF-CV, S5 lens screens) is now generated **LOCAL**, and the cron's role for these tracks has become build/plan-only. Milestone impact: M6 (validation harness) + M7 (tuning). Recommend: ESCALATE_TO_MAINTAINER — either provision the EODHD key in GHA, or **formally re-scope the orchestrator to build/plan-only for WF-CV tracks** so it stops idling on data-gated rows (the de-facto state; make it explicit).
- **`tuning` M2 qNEHVI blocked on a maintainer enable-commit (#1327)** — on the M7 critical path; ~45 days stalled on a one-line human action. Recommend: ESCALATE_TO_MAINTAINER.
- **`harness` ci.yml ENOSPC fix blocked on a `workflow`-scoped PAT (#1636)** — infrastructure, not a Weinstein-domain feature, but a recurring CI disk risk; YAML already staged. Recommend: ESCALATE_TO_MAINTAINER.
- **M6.6 true live cycle** — the remaining open M6 item (live DATA_SOURCE + cron + alerts). Cross-track: weekly-snapshot live-cycle is human-gated; decision-audit's live-picks pipeline is ready (#1812). Not started; a human decision, not agent work. Recommend: KEEP_AS_INFO.

## Recommendations
1. **Decide the EODHD-in-GHA question, and make the LOCAL-only re-scope explicit** (maintainer). The promotion pipeline already runs LOCAL for the hot tracks; either provision the key in GHA or formally mark the WF-CV tracks build/plan-only so the cron stops idling on ~10 data-gated rows.
2. **Unblock `tuning` M2** — land the maintainer enable-commit for qNEHVI (#1327); ~45 days stalled on a one-line action, M7 critical path.
3. **Supply the `workflow`-scoped PAT** for the `harness` ci.yml ENOSPC fix (#1636) — recurring CI disk risk, YAML already staged.
4. **Do the manual ghcr.io flambda rebuild** to unblock `sweep-perf`'s prune opt-in (last substantive PR 29 days ago; only human-gated step remaining).
5. **Refresh three lagging status files** — `simulation.md` (Next Steps predate the fill-router cluster + stale-exit re-basis), `stage-accuracy.md` (Last-updated 2026-06-06, misses the #1862/#1864 early-Stage2 work), `backtest-infra.md` (Last-updated 2026-06-14). Per `feedback_status_refresh_must_verify` these lag main and mislead the next dispatch.
6. **Mark `decline-character` effectively closed** — self-declares exhausted (#1739); keep mechanisms as default-off axes and stop spending cron cycles until new evidence appears (carryover).
7. **Note `stage-accuracy`'s single-dial screener surface is exhausted** — four straight rejections; the track's own conclusion is that breadth, not stage dials, is the lever. Consider lowering dispatch priority pending a breadth-focused re-frame.

## Stats
- 82 merges in last 7d (27 ops summaries, 23 substantive feat/fix/experiment/data/perf/screen, remainder docs/handoff)
- 374 merges in last 30d (98 substantive feat/fix/experiment/data/perf/screen)
- 6 tracks active / 9 slowing / 3 stalled-actionable (+1 PENDING parked, +1 idle-by-design exempt)
- 0 `[info]` items carried ≥3 reconciles
- 1 systemic capability gap flagged (EODHD data-gating in GHA) + 2 human-gated bottlenecks (`tuning` M2 enable-commit, `harness` workflow-PAT) + 1 manual-gated (`sweep-perf` ghcr.io rebuild)

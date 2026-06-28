# Track Pacer Report — 2026-06-28

## Summary
- Tracks audited: 18 (17 IN_PROGRESS + 1 PENDING `tuning-methods`)
- Active (≥1 PR last 7d): 6
- Slowing (7–30d since last PR): 9
- Stalled (>30d): 3 (`tuning` #1327-gated, `tuning-methods` PENDING, `cleanup` exempt/no-backlog)
- [info] items needing decision: 0 (one standing by-design `[info]` in orchestrator-automation, non-actionable)
- Capability gaps flagged: 3 (M6.6 live cycle, M7.1 train/test ML, M5.5/M7 tuning gated on #1327)

Headline: very high merge volume (94 PRs/7d, 397/30d) but heavily concentrated
in strategy *experimentation* — decline-character, barbell, short-side,
concentration — that mostly terminates in default-off axes or REJECT/NO-BUILD
verdicts. Of the last 7d, 18 are ops summaries and 53 are docs-only; net new
feature surface is small. The program is in a self-declared "understanding-first
/ regime-edge" mode (index header). Meanwhile the milestone-advancing work —
M6.6 live cycle, M7.1 ML — sits untouched and human-gated.

## Active tracks (≥1 PR last 7d)
- **stage-accuracy** — 3+ PRs; theme: declining-MA long-entry gate (#1775, default-off) + broad-universe concentration 0.14→0.30 promotion (#1751 WF-CV ACCEPT, #1753 golden promote, #1756).
- **short-side-strategy** — 4+ PRs; theme: liquidity-realism overlay (#1760, held-degradation exit + entry gate, default-off, fixes ELCO −48% artifact) + deep margin off/on acceptance (#1759, premise refuted).
- **decline-character** — many PRs; theme: A-D-default flip + arming-speed A-D-live WF-CV (#1737 NO-promote, #1725 flip) + broad-golden re-pins. **Self-declared EXHAUSTED (#1739)** — closing, see P6.
- **experiment-platform** — 2 PRs; theme: capacity/concentration WF-CV surface (#1748 INCONCLUSIVE) + laggard-cadence WF-CV (#1749).
- **backtest-infra** — 1 PR; theme: snapshot-dir mode for optimal + all-eligible runners (#1743).
- **harness** — 2 PRs; theme: maintenance only — [main-fix] arch_layer whitelist for stage_chart (#1773) + weekly opam update (#1698). See P6.

## Slowing tracks (7–30d since last PR)
- **rolling-start-lens** — last code PR ~#1645 (~10 days ago); theme: top-3000 factor-lens matrix; recommendation: KEEP_AS_INFO (Next Steps all data-gated/maintainer-local, correctly tagged).
- **backtest-perf** — last PR #1631 (~11 days ago); theme: snapshot-format-v2 Rosetta VMA fix (S4 PROVEN); recommendation: KEEP_AS_INFO (S5/v1-cleanup deferred by oversight; next step is LOCAL).
- **weekly-snapshot** — last PR #1598 (~13 days ago); theme: first live baseline + C2 test; recommendation: KEEP_AS_INFO (M6.1–M6.6 generator shipped; remaining live-cycle is human-gated — see P7).
- **data-foundations** — last PR #1595 (~13 days ago); theme: eligibility-filter universe builder + bar-store refresh; recommendation: KEEP_AS_INFO (policy artifact "largely subsumed by eligibility builder," human-gated).
- **cash-floor-correctness** — last PR #1582 (~14 days ago, default flip ON); theme: closing-trade cash-floor exemption; recommendation: KEEP_AS_INFO (NS2 impl human-gated, NS4 data-gated).
- **sweep-perf** — last PR #1574 (~14 days ago); theme: Win #4 prune wiring; recommendation: ESCALATE_TO_MAINTAINER — next step "manual ghcr.io flambda rebuild + enable prune opt-in" is a recurring human-gated manual action (see P5).
- **simulation** — last PR ~#1575 (~14 days ago, CancelExit); theme: position transitions; recommendation: KEEP_AS_INFO (M5 walk-forward done elsewhere; remaining items are catch-all/local).
- **orchestrator-automation** — last PR ~#1573 (~14 days ago); theme: 8x cadence + per-run cap; recommendation: KEEP_AS_INFO (index + status both say "no outstanding work"; effectively complete, not drifting).
- **spy-only-reference** — last code PR #1438 (2026-06-03, ~25 days ago); status file last updated 2026-06-03; recommendation: ESCALATE_TO_MAINTAINER — **carried unchanged from the 2026-06-21 pacer (rec #4)**; top Next Steps still "open question, not dispatched" / "human session." Either schedule the sector-rotation K-sweep run or mark the track parked so the 25-day silence stops reading as drift.

## Stalled tracks (>30d since last PR)
- **tuning** — last tuning-specific PR ~#1372 (2026-05-29, ~30 days); reason: M2 qNEHVI awaiting a maintainer enable-commit (#1327); recommendation: ESCALATE_TO_MAINTAINER — **carried unchanged across the last three pacer runs** (now the longest-standing human-gated item). Either enable qNEHVI or formally park M2 so the track stops reading as "next-task pending."
- **tuning-methods** — PENDING; status file last updated 2026-05-24 (~35 days); reason: steps 1-3 demoted ("surface is the bind"); next is "component-decomposition objective"; recommendation: KEEP_AS_INFO (parked by design; not a pace failure, but the 35-day-stale file should be reconciled or the track folded into `tuning`).
- **cleanup** — exempt; status file last updated 2026-05-22 (~37 days); reason: "no active backlog" by design — fires only on weekly deep-scan / Step-2e findings; recommendation: KEEP_AS_INFO (status file is stale but the track is correctly idle).

## Next Steps staleness (P2)
- **stage-accuracy** — status file last updated 2026-06-06 (22d), but #1751 (concentration WF-CV ACCEPT 0.30), #1753 (golden promote), and #1775 (declining-MA entry gate) have all merged *under this track's entry-quality surface* since. The index header itself notes the declining-MA gate "has no dedicated track file; landed under stage-accuracy's entry-quality surface." The status file does not reflect this recent work; recommend refreshing it (docs-only, admin-mergeable).
- **weekly-snapshot** — first Next Step item leads with "[M6.6, DONE] `generate_weekly_snapshot` bin — SHIPPED 2026-06-14"; the list opens with a completed item. Low-severity (it is clearly marked DONE), but the actionable head-of-queue is now item #2/#3 (both deferred/human-gated); recommend trimming the DONE item.
- Other IN_PROGRESS tracks' first Next Steps are current or correctly struck-through (tuning, experiment-platform, cash-floor — the last two were refreshed via #1681/#6ffa2f9 last week). No further stale first-items found.

## [info] items needing decision (P3)
- None in the `_index.md` header block — the index no longer carries `[info]` tags inline.
- One standing `[info]` exists in `orchestrator-automation.md §3` ("orchestrator under-utilized, ~16% of cap") — explicitly non-actionable by design (queue-depth bound), correctly labeled, carried because the pattern persists. Recommended action: KEEP_AS_INFO (no decision needed).

## Tracks without owner (P4)
- None. Every IN_PROGRESS / PENDING row in `_index.md` has an owner.
- Tracking-hygiene note (P4-adjacent, carried theme from 2026-06-21 rec #2): two substantive items landed this week with **no dedicated track row** — the declining-MA long-entry gate (#1775, folded into stage-accuracy) and the barbell closure (#1770, Option B decision). Both are visible only in the index-header prose. Not a missing-owner finding, but pace/gates for these are not independently auditable. Recommend confirming they are intentionally folded rather than orphaned.

## Recurring discussion topics (P5)
- `dev/decisions.md` has **no entries in the last 30 days** (most recent is 2026-05-16, ~43 days ago). The de-facto human↔agent decision channel has migrated to the daily ops summaries + handoff docs + the experiment ledger. No recurring-topic detection is possible from `decisions.md` itself; flag that the file is dormant — KEEP_AS_INFO.
- Recurring human-gated items surfacing repeatedly across handoffs and prior pacer reports (the de-facto "open questions"):
  - **tuning M2 enable-commit (#1327)** — appears in ≥3 pacer reports; ESCALATE_TO_MAINTAINER.
  - **sweep-perf manual flambda ghcr.io rebuild + prune opt-in** — recurring manual action; ESCALATE_TO_MAINTAINER.
  - **harness ci.yml ENOSPC fix blocked on a `workflow`-scoped PAT (#1636)** — recurring; ESCALATE_TO_MAINTAINER.
  - **spy-only-reference confirm/park** — recurring (raised 2026-06-21 rec #4); ESCALATE_TO_MAINTAINER.
  - **Stale ci-red issue #1772 close blocked 403** (token lacks `issues:write`) — ops/permissions escalation noted in this morning's index header; ESCALATE_TO_MAINTAINER.

## Diminishing returns (P6)
- **decline-character** — last 5 PRs are predominantly docs+fixtures (WF-CV writeups, golden re-pins: #1733/#1734/#1737/#1738) terminating in NO-promote/REJECT. The track itself declares "WORKSTREAM EXHAUSTED (2026-06-25, #1739) … the single-dial decline-character surface is exhausted." Recommendation: formally close / lower dispatch priority — it is already self-parked; the index row should reflect closure so it stops appearing in the active set.
- **harness** — recent PRs are maintenance only: #1773 [main-fix] arch_layer whitelist, #1698 chore weekly opam, #1636 ci disk-headroom. ≥3 of last 5 are chore/fix/main-fix. Expected for an infra track; KEEP_AS_INFO.
- **Golden-churn cluster (cross-track)** — a steady stream of golden re-pin / prose-fix maintenance (#1733/#1734/#1737/#1738/#1753/#1755/#1756) driven by the concentration 0.14→0.30 and A-D-default flips. Not a single track winding down; rather a sign that default-flips force broad golden churn. KEEP_AS_INFO (watch that re-pins stay paired with the flip that motivated them, per code-health-discipline).

## Capability gaps (P7)
- **M6.6 — True live cycle** (`live` DATA_SOURCE + cron + alerts + state durability) — NOT started; mentioned in `weekly-snapshot.md` (deferred), `spy-only-reference.md`, and §Milestones. This is the load-bearing gap on the critical path to **M6 "Full Automated Cycle"** — the verification harness (M6.1–M6.5) and generator are shipped and a first baseline is committed (#1598), but nothing wires live data → cron → report → trade. Human-gated. Recommendation: ESCALATE_TO_MAINTAINER — decide whether M6.6 is in scope this cycle or explicitly deferred until the strategy-edge exploration concludes.
- **M5.5 / M7 — Parameter tuning (Bayesian M2 → ML)** — blocked at the M2 qNEHVI gate (#1327 enable-commit); M7.1 train/test ML not started. Gates the entire downstream tuning + ML milestone. Recommendation: ESCALATE_TO_MAINTAINER (same as P5 #1327).
- **M6.4 — Split/dividend verification harness** (replay AAPL/TSLA/GOOG/NVDA splits as deterministic regression) — the broker-model split handling shipped, but the dedicated M6.4 *verification harness* is not evidenced in any `## Completed` section. Recommendation: KEEP_AS_INFO — confirm whether M6.4 is satisfied by existing split tests or still owed.

## Recommendations
1. **Decide M6.6 (live cycle) scope (P7).** The verification harness is done and a first baseline is committed; the single biggest milestone-advancing gap is now the live `DATA_SOURCE` + cron + alerts. Either greenlight it or explicitly defer it in writing so "Full Automated Cycle" stops reading as silently stalled.
2. **Resolve or park tuning M2 (#1327).** Carried unchanged across three pacer runs — the longest-standing human-gated item. Enable qNEHVI or formally park M2.
3. **Close decline-character (P6).** The track self-declares EXHAUSTED (#1739); flip its index row to MERGED/parked so it leaves the active set and the 6-active count reflects reality.
4. **Confirm or park spy-only-reference (P5/Slowing).** 25 days since last PR, status file untouched since 2026-06-03, top Next Steps "not dispatched" — second consecutive week flagged. Schedule the sector-rotation K-sweep or mark parked.
5. **Refresh stage-accuracy.md (P2).** Concentration promotion (#1751/#1753) and the declining-MA gate (#1775) merged under its surface but the file is 22 days stale and the gate has no track row. Docs-only, admin-mergeable.
6. **Batch the recurring manual/ops escalations (P5).** sweep-perf flambda rebuild, harness ci.yml ENOSPC PAT (#1636), and the #1772 ci-red issue-close 403 are all blocked on maintainer/permission actions that recur every cycle. Clear them in one pass.
7. **Reconcile the dormant decision channel.** `dev/decisions.md` is 43 days stale; either resume using it for human→agent decisions or note in-repo that the handoff docs + ledger have superseded it, so future pacer P5 checks have a live source.

## Stats
- 94 PRs merged in last 7d (all tracks; of which 18 ops summaries, 53 docs-only)
- 397 PRs merged in last 30d (all tracks)
- 6 tracks active / 9 slowing / 3 stalled (1 of the 3, `cleanup`, exempt by design)
- 0 [info] items carried ≥3 reconciles (1 standing by-design [info], non-actionable)
- 3 capability gaps flagged (M6.6 live cycle, M5.5/M7 tuning+ML gated on #1327, M6.4 split-verify harness unconfirmed)

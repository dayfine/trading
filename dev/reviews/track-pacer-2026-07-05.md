# Track Pacer Report — 2026-07-05

## Summary
- Tracks audited: 40 (18 IN_PROGRESS + 1 PENDING + 21 MERGED); cadence run on the 19 non-MERGED rows
- Active (≥1 PR last 7d): 6 IN_PROGRESS (+1 MERGED-status still shipping: `decision-audit`)
- Slowing (7–30d since last PR): 6
- Stalled (>30d): 3 actionable (+2 idle-by-design, exempt)
- [info] items needing decision: 0
- Capability gaps flagged: 1 systemic (EODHD data-gating in GHA) + 2 human-gated bottlenecks

Headline: pace is healthy (22 substantive PRs merged in 7d), but the work is
concentrated in **~6 hot tracks** while the rest of the roadmap is **gated on
things the orchestrator cannot do** — EODHD API access in GHA (10 "data-gated"
next-tasks), a maintainer enable-commit (`tuning` M2), and a `workflow`-scoped
PAT (`harness` CI fix). No pace pathology; the bottleneck is decision/access, not throughput.

## Active tracks (≥1 PR last 7d)
- **capital-management-scale-in** — 6 PRs (#1855, #1856, #1843, #1840, #1835, #1832/#1833 tail); theme: continuation-add / scale-in mechanism — v1 surface REJECTED (#1840), add-channel defect diagnosed (#1843) and rebuilt as `Consolidation_breakout` + explicit `add_fraction` (default-off, #1855), v2 WF-CV surface spec staged (#1856). Disciplined explore/reject/rebuild loop.
- **simulation** — 4 PRs (#1830, #1837, #1847, #1853); theme: fill-routing **correctness cluster** — side-aware `Fill_router` extraction (#1830), route fills by order→position link (#1837), position-faithful round-trip pairing for sibling positions (#1847). Per-trade scale-in reporting now trustworthy.
- **weekly-snapshot** — 5 PRs (#1781, #1784, #1816/#1818, #1826); theme: weekly-picks integrity — `prior_stage` chain fix so `weeks_advancing` is correct (#1818), corrected 5-week series (#1781), fast snapshot-warehouse input path (#1784), configurable report display cap (#1826).
- **stage-accuracy** (candidate-ranking thread) — 4 PRs (#1786, #1788, #1793, #1795); theme: candidate-ranking quality tiebreak added as a default-off axis (#1786) then swept — WF-CV breadth grid, earliness-primary, and noise-floor controls **all REJECT the default-flip** (#1788/#1793/#1795). Faithful "land-safe, search, don't promote" discipline.
- **decline-character** — 2 PRs (#1775, #1779); theme: declining-MA long-entry gate (default-off) + grid ledger. Track **self-declares "exhausted"** (#1739) — all decline mechanisms stay default-off axes (see Diminishing returns).
- **data-foundations** — 1 PR (#1790); theme: configurable eligible-universe staleness tolerance + observability. Track otherwise largely subsumed (ADR $-vol policy is human-gated).
- **decision-audit** (Status=MERGED, still shipping) — 3 PRs (#1799, #1806, #1811); theme: per-screen faithfulness audit + Phase-2 forward-return counterfactual + weekly-snapshot live-picks adapter. Row is marked MERGED but the owner (`feat-backtest`) is actively extending it; consider flipping the index Status back to IN_PROGRESS for accuracy (KEEP_AS_INFO).

## Slowing tracks (7–30d since last PR)
- **short-side-strategy** — last PR #1760 was 9 days ago (2026-06-26); theme: liquidity-realism overlay (default-off). Next is short-leg regime-P&L decomposition (LOCAL/data-gated); recommendation: KEEP_AS_INFO.
- **backtest-infra** — last PR #1743 was 11 days ago (2026-06-24); theme: snapshot-dir mode for optimal + all-eligible runners. Next P2 composition-policy matrix is data-gated; recommendation: KEEP_AS_INFO.
- **backtest-perf** — last PR ~#1631 was ~18 days ago (~2026-06-17); theme: snapshot-format-v2 columnar mmap (S1–S4 PROVEN). Next regime-diverse lenses on v2 are LOCAL-only; recommendation: KEEP_AS_INFO.
- **harness** — last PR #1636 was 18 days ago (2026-06-17); theme: CI disk-headroom fix. **ci.yml ENOSPC fix is BLOCKED on a human with a `workflow`-scoped PAT** (exact YAML in #1636 body); recommendation: ESCALATE_TO_MAINTAINER.
- **rolling-start-lens** — last merged PR #1614 was 19 days ago (2026-06-16); theme: rolling-start factor-lens columns. Recent factor-lens matrices (#1639/#1642) are LOCAL, not merged; next is LOCAL/data-gated deploy-proxy validation; recommendation: KEEP_AS_INFO.
- **sweep-perf** — last PR #1574 was 22 days ago (2026-06-13); theme: `active_through` per-fold pruning (opt-in, default-off). Next is a **manual ghcr.io flambda rebuild** + enabling the prune opt-in in sweeps — human/manual-gated; recommendation: ESCALATE_TO_MAINTAINER (manual rebuild step).

## Stalled tracks (>30d since last PR)
- **spy-only-reference** — last PR #1438 at 2026-06-03 (32 days); reason: next task (top-1000 bankability gate, long-short verification) is explicitly a **human session**, not agent-dispatchable; recommendation: KEEP_AS_INFO.
- **experiment-platform** — last PR #1372 at 2026-05-29 (~37 days); reason: single-dial surface exhausted; next continuation-buy recheck on top-3000 is **data-gated**; recommendation: KEEP_AS_INFO.
- **tuning** — last PR #1329/#1333 at 2026-05-26/27 (~39 days); reason: M1 complete (5/5); **M2 qNEHVI is awaiting a maintainer enable-commit per #1327** — a concrete pending human action, not agent work; recommendation: ESCALATE_TO_MAINTAINER.
- **orchestrator-automation** — *exempt (idle by design)*: Phase 1 stable (#1332), Phase 2 deferred, "no outstanding work." No stalled-flag warranted.
- **cleanup** — *exempt (idle by design)*: no active backlog; next finding arrives via the weekly deep health scan / orchestrator Step 2e. No stalled-flag warranted.
- **tuning-methods** (PENDING) — parked: Step 0 done, steps 1–3 demoted ("surface is the bind"); component-decomposition objective is the intended next unit but nothing queued. KEEP_AS_INFO.

## Next Steps staleness (P2)
- **capital-management-scale-in** — the first actionable Next-Step still frames the "P0 add-channel-fix build" (plan #1844) as work to do, but that build **landed as #1855** (2026-07-05, default-off). The index row is already correct ("add-channel-fix landed (#1855); next: continuation-add v2 WF-CV surface"); the per-track file's Next Steps lags the merge. Recommend the owner refresh `dev/status/capital-management-scale-in.md` to promote the v2 WF-CV surface (#1856) to the top item. (Soft flag — KEEP_AS_INFO.)
- All other active/slowing tracks checked (simulation, weekly-snapshot, backtest-infra, cash-floor-correctness, stage-accuracy, data-foundations) mark completed items explicitly (struck-through / "SHIPPED" / "DONE") and their first pending item is genuinely open. No staleness.

## [info] items needing decision (P3)
- None. `dev/status/_index.md` carries 0 `[info]`-tagged items; the header is a single-run reconcile narrative with no carried-forward `[info]` list.

## Tracks without owner (P4)
- None. Every IN_PROGRESS / READY_FOR_REVIEW row has a named owner; no empty Owner cells on non-MERGED rows.

## Recurring discussion topics (P5)
- None. `dev/decisions.md` has no entries within the last 30 days (most recent: 2026-05-16). Cross-session decision-making has migrated to the daily `ops: daily orchestrator summary` PRs and `dev/notes/next-session-priorities-*.md` handoffs, which are outside P5's scan surface. No unresolved recurring topic to surface.

## Diminishing returns (P6)
- No track trips the strict heuristic (≥3 of last 5 PRs matching chore/fix(linter)/golden/repin/fmt). Two soft signals worth a maintainer glance:
  - **decline-character** — not a maintenance-churn pattern, but the track **self-declares "exhausted" (#1739)**: every decline mechanism (fast-V arming, declining-MA gate) swept to a default-off axis with no promotion. Recent PRs (#1775/#1779) are feature+ledger work that all ended default-off. Consider lowering dispatch priority / marking effectively closed pending new evidence.
  - **simulation** — last 4 PRs are all `fix(...)` on the fill-routing path (#1830/#1837/#1847). These are genuine correctness fixes (not linter/format churn), so not "diminishing returns" — but the *cluster* suggests the fill-router / round-trip-pairing area was structurally buggy. Now claimed trustworthy; worth a confirming WF-CV once data-gating lifts. KEEP_AS_INFO.

## Capability gaps (P7)
- **EODHD data access absent in the GHA orchestrator environment** — the single dominant cross-track blocker. **10 "data-gated" next-tasks** span capital-management-scale-in (v2 WF-CV surface), backtest-infra (P2 composition matrix), backtest-perf, stage-accuracy (broad-universe WF-CV re-run), experiment-platform (continuation-buy recheck), simulation (stale-exit grid), weekly-snapshot (multi-week sweep), cash-floor-correctness (NS4 DD-validation), and data-foundations. Milestone impact: **M6 (validation harness) + M7 (tuning)** — the promotion pipeline (`experiment-flag-discipline` → WF-CV → ledger ACCEPT) cannot advance under the cron because the surfaces need EODHD bars the GHA runner lacks. Recommend: ESCALATE_TO_MAINTAINER — either provision the EODHD key in GHA, or formally accept that all WF-CV surface runs execute LOCAL and re-scope the orchestrator's role for these tracks to build/plan-only.
- **`tuning` M2 qNEHVI blocked on a maintainer enable-commit (#1327)** — on the M7 critical path; a one-line human action gates ~6 weeks of stall. Recommend: ESCALATE_TO_MAINTAINER.
- **`harness` ci.yml ENOSPC fix blocked on a `workflow`-scoped PAT** — infrastructure, not a Weinstein-domain feature, but a recurring CI risk (ENOSPC during link). Exact YAML staged in #1636 body. Recommend: ESCALATE_TO_MAINTAINER.
- Note: M6.4 split/dividend verification harness and the synthetic generator (v1–v3) are **already shipped** (`weinstein/snapshot/bin/verify_corporate_actions.ml`, `test_split_replay.ml`, `analysis/data/synthetic`) — not gaps.

## Recommendations
1. **Decide the EODHD-in-GHA question** (maintainer) — it gates 10 next-tasks and the entire promotion pipeline. Provision the key in GHA, or explicitly re-scope those tracks to LOCAL-only WF-CV so the orchestrator stops idling on data-gated rows.
2. **Unblock `tuning` M2** — land the maintainer enable-commit for qNEHVI (#1327); ~6 weeks stalled on a one-line action.
3. **Supply the `workflow`-scoped PAT** for the `harness` ci.yml ENOSPC fix (#1636) — recurring CI disk risk, YAML already staged.
4. **Refresh `capital-management-scale-in.md` Next Steps** (owner `dayfine`) — promote the v2 WF-CV surface (#1856) to the top item; the add-channel-fix build it currently lists shipped as #1855.
5. **Lower `decline-character` dispatch priority** — track self-declares exhausted; keep mechanisms as default-off axes and stop spending cron cycles until new evidence appears.
6. **Fix the `decision-audit` index Status** — it reads MERGED but `feat-backtest` is actively shipping into it (#1799/#1806/#1811); flip to IN_PROGRESS for an accurate single-source view.
7. **Confirm the `simulation` fill-router fixes** with a WF-CV pass once data-gating lifts — three back-to-back correctness fixes on that path warrant a regression check.

## Stats
- 77 merges in last 7d (23 ops summaries, 22 substantive feat/fix/experiment/data/perf, remainder docs/handoff)
- 385 merges in last 30d (107 substantive feat/fix/experiment/data/perf)
- 6 tracks active / 6 slowing / 3 stalled-actionable (+2 idle-by-design exempt)
- 0 `[info]` items carried ≥3 reconciles
- 1 systemic capability gap flagged (EODHD data-gating in GHA) + 2 human-gated bottlenecks (`tuning` M2 enable-commit, `harness` workflow-PAT)

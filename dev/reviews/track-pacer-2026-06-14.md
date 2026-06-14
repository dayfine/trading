# Track Pacer Report — 2026-06-14

## Summary
- Tracks audited: 15 (14 IN_PROGRESS + 1 PENDING; MERGED rows excluded)
- Active (≥1 PR last 7d): 10
- Slowing (7–30d since last PR): 2
- Stalled (>30d): 0 (3 exempt — winding-down/by-design)
- [info] items needing decision: 0
- Capability gaps flagged: 3

Cadence note: extremely high throughput this week — 104 merge commits in
7d, 457 in 30d (38 of the last 7d are `feat`/`fix`/`experiment`; the rest
are `ops`/`docs` orchestrator summaries, handoffs, and memory snapshots).
The orchestrator went to 8x daily cadence on 2026-06-13 (#1573), which
explains the volume. Throughput is not the risk this week; status-file
staleness and a cross-track data blocker are.

## Active tracks (≥1 PR last 7d)
- **cash-floor-correctness** — 3+ PRs (#1567 NS1, #1569 NS2 design, #1575 NS3 CancelExit, #1556); theme: default-off cash-floor correctness flags, all auto-merged with QC APPROVED.
- **backtest-infra** — 3 PRs (#1555/#1566 suppress_warmup flag+flip, #1558 Fold_health wiring); theme: measurement-correctness (warmup-suppression default flip).
- **backtest-perf** — 2 PRs (#1536 rolling-start v2, #1546 min-window guard/maxdd); theme: rolling-start dispersion + edge-vs-SPY matrix.
- **sweep-perf** — 1 PR (#1574 Win #4 active_through pruning production wiring, opt-in default-off); theme: sweep-speedup production wiring.
- **short-side-strategy** — 2 PRs (#1551 short_min_price gate, #1560 enable_short_side honest suppression); theme: short-side hygiene/no-op-default flags.
- **stage-accuracy** — 1 PR (#1509 cascade-selection inversion forensics, 06-09); theme: forensics/diagnosis (no new feature surface — see Diminishing returns).
- **simulation** — 2 PRs (#1487 stale-position force-exit 06-08, #1556 cash-floor exit revert); theme: exit-path correctness.
- **experiment-platform** — 1 PR (#1503 stage3-force-exit-off confirmation grid REJECT, 06-09); theme: experiment ledger verdicts (no promotion — see Diminishing returns).
- **data-foundations** — 4 PRs (#1537/#1539/#1540 composition-policy pipeline, #1542 $-volume wiring, 06-11); theme: composition-policy universe machinery.
- **orchestrator-automation** — 1 PR (#1573 8x daily cadence + per-run cap raise, 06-13); theme: orchestrator cadence tuning (despite status file claiming "no outstanding work").

(Borderline: **harness** — last attributable PR #1475 `chore(agents)` finish-step at 06-07, exactly at the 7d edge; track states "Tier 1 fully checked off, no active dispatch surface" → effectively winding down by design.)

## Slowing tracks (7–30d since last PR)
- **spy-only-reference** — last attributable PR #1438 (sector-rotation, 2026-06-03 → 11 days ago); theme: SPY reference + sector-rotation testbed. Next Steps are explicitly "(open question, not dispatched)" / "human session" — this is intentionally paused awaiting a maintainer decision on the short-side lever and sector-rotation K-sweep run. Recommendation: KEEP_AS_INFO.
- **tuning** — last attributable PR #1333 (holdout/sensitivity scripts, 2026-05-27 → 18 days ago); theme: M2 qNEHVI is gated. Status: "M2 qNEHVI next (awaiting maintainer enable-commit per #1327)". Human-gated, not stalled-by-neglect. Recommendation: ESCALATE_TO_MAINTAINER (the enable-commit decision is the bottleneck).

## Stalled tracks (>30d since last PR)
None. Three IN_PROGRESS/PENDING tracks have no recent PR but are exempt (winding-down / by-design, not neglected):
- **cleanup** (code-health) — "no active backlog; next finding via weekly deep scan." Fires reactively on linter findings; idle is expected. Exempt.
- **harness** (harness-maintainer) — "Tier 1 fully checked off; T3-H low-priority; no active dispatch surface." Exempt.
- **tuning-methods** (PENDING, feat-backtest) — "Step 0 done; steps 1-3 demoted (surface is the bind)." Deliberately demoted. Exempt.

## Next Steps staleness (P2)
- **backtest-infra** — STATUS-FILE HEADER STALE. File header reads `## Last updated: 2026-05-01` and `## Status: MERGED`, but the file carries a 2026-06-13 warmup-suppression section and the index lists it IN_PROGRESS with maintainer-owned work merged this week (#1555/#1558/#1566). The `## Next Steps` first item ("Step 3 tier-aware bar loader now unblocked… pick this up once the Tiered flip lands") references `backtest-scale.md`, which is now MERGED — the Tiered flip already landed. Recommend refreshing header date/status + retiring the Step-3 Next Step. RECOMMEND: refresh status file.
- **experiment-platform** — header `## Last updated: 2026-05-30` lags ~15 days behind merged work attributed to it (#1503 force-exit-off grid REJECT, 06-09). First Next Step ("Repair the index/breadth golden coverage… extend GSPC.INDX back to ~2009") is partially overtaken by the GSPC 2017-floor fix (#1380/#1383) and the tier-4 PIT migration (#1449/#1455); whether it is fully closed is unverifiable from the file. Recommend reconciling the date + verifying the golden-coverage item against merged work.
- **data-foundations** — first Next Step #1 ("Phase 1.4 — run the actual IWV scrape… Tooling complete; data is not") has been the top item since the 2026-05-16 vendor pivot (~29 days). IWV tooling merged 2026-05-16…18 (#1112–#1147) but no scrape-completion commit exists, and the track has since pivoted to the composition-policy universe path (#1537–#1542). The Next Step does not reflect that the broad-universe data strategy moved. Recommend reconciling: is the IWV scrape still wanted, or formally superseded by composition-policy? RECOMMEND: refresh + decide.

## [info] items needing decision (P3)
None. `dev/status/_index.md` carries no `[info]`-tagged items; its header is a single reconciled "Last updated" line (2026-06-14), not a multi-reconcile carryover block.

## Tracks without owner (P4)
None. Every IN_PROGRESS/READY_FOR_REVIEW row has an owner. No new ownerless tracks created in the last 14 days.

## Recurring discussion topics (P5)
- `dev/decisions.md` has had **no new entry in ~29 days** (most recent: two 2026-05-16 vendor-pivot entries, both resolved decisions). Active decision-making has migrated to the per-session priorities docs (`dev/notes/next-session-priorities-*.md`), handoff docs, and the append-only experiment ledger (`dev/experiments/_ledger/`). No unresolved topic recurs ≥2× in decisions.md. Recommendation: KEEP_AS_INFO — decisions.md is effectively dormant as a channel; not a defect, but P5 (as scoped to that file) yields no signal. The real recurring pattern lives in the experiment ledger (see Recommendations §4).

## Diminishing returns (P6)
No track meets the literal heuristic (≥3 of last 5 PRs being `chore`/`fix(linter)`/`golden`/`repin`/`fmt`/`format`) — the codebase is shipping default-off flags and experiment verdicts, not maintenance churn. Two tracks show *strategic* diminishing returns (repeated rejects, no promotable surface), worth flagging:
- **experiment-platform** — index notes "single-dial surface exhausted"; recent attributed work is REJECT verdicts (#1503 force-exit-off, #1500 ma_hold). The single-dial search space is producing no ACCEPTs. Consider lowering dispatch priority until a new hypothesis class (not another single dial) is queued.
- **stage-accuracy** — recent work is forensics + REJECTED grids (#1509 docs, #1503/#1500 REJECTs, #1499/#1446 default-off dials that don't promote). Next concrete surface ("broad-universe WF-CV re-run") is data-gated. Effectively blocked on the same broad-universe data as everyone else (P7).

## Capability gaps (P7)
- **Broad-universe / composition-policy universe artifact (cross-track blocker)** — mentioned as "data-gated" / "composition-policy universe" across ≥6 tracks: backtest-infra (P2 matrix), backtest-perf (matrix run), short-side-strategy (WF-CV short_min_price axis), stage-accuracy (broad WF-CV re-run), experiment-platform (surface sweep), cash-floor-correctness (NS4 WF-CV cash-floor DD). The data-foundations track shipped the composition-policy machinery (#1537–#1542) but the consumed artifact + the downstream WF-CV re-runs are not yet done. This is the single highest-leverage unblock — it gates strategy-validation work on at least 6 tracks. Milestone: M5/M7 (broad-universe backtesting). RECOMMEND: ESCALATE_TO_MAINTAINER.
- **tuning M2 qNEHVI** — blocked ~19 days awaiting a maintainer enable-commit (#1327). Milestone: M7 (parameter optimization). RECOMMEND: ESCALATE_TO_MAINTAINER (single decision unblocks the track).
- **M6.6 live cycle (live DATA_SOURCE + cron + alerts)** — not started; the system remains backtest/experiment-only ("M1–M4 libraries landed, no live CLI yet"). This is the deepest milestone gap (M6 "Full Automated Cycle"), but it is a deliberate verification-first sequencing choice, not neglect. Milestone: M6. RECOMMEND: KEEP_AS_INFO.

## Recommendations
1. **Unblock the broad-universe data path (P7).** At least 6 active tracks are "data-gated" on the composition-policy universe artifact + the WF-CV re-runs it enables. data-foundations shipped the machinery (#1537–#1542); the next concrete step is emitting/consuming the artifact. This is the highest-leverage action this week — decide and dispatch the artifact emit + a canary WF-CV re-run.
2. **Refresh three stale status files (P2).** `backtest-infra.md` (header says MERGED/2026-05-01 while IN_PROGRESS work merged this week; retire the dead Step-3 Next Step), `experiment-platform.md` (date 15d stale; verify the golden-coverage item), `data-foundations.md` (reconcile the 29-day-old IWV-scrape Next Step against the composition-policy pivot). Docs-only PRs — admin-mergeable.
3. **Resolve the tuning M2 enable-commit decision (#1327).** The track has been idle 18 days purely awaiting a maintainer commit. Either enable qNEHVI or formally park M2 so the track stops reading as "next-task pending."
4. **Decide on the experiment-rejection saturation.** The ledger has accumulated a long run of single-dial REJECTs (harvest-rotate #1532, cascade-reweight #1516, force-exit-off #1503, ma-hold/laggard/macro-trim/late-stage2/hysteresis/continuation/early-admission). This is consistent with `weinstein-faithful-core.md`'s warning against single-dial grafting. Consider lowering experiment-platform/stage-accuracy dispatch priority until a new hypothesis *class* (breadth/selection lever, per the standing "concentration is the return" finding) is queued, rather than another single dial.
5. **Confirm spy-only-reference's paused state is intentional.** Its top Next Steps are "open question, not dispatched" / "human session." Either schedule the human session (sector-rotation K-sweep run) or mark the track parked so it doesn't read as slowing.

## Stats
- 104 merge commits in last 7d (38 `feat`/`fix`/`experiment`; remainder `ops`/`docs`)
- 457 merge commits in last 30d
- 10 tracks active / 2 slowing / 0 stalled (3 exempt: cleanup, harness, tuning-methods)
- 0 `[info]` items carried ≥3 reconciles
- 3 capability gaps flagged (broad-universe data blocker; tuning M2 enable-commit; M6.6 live cycle)

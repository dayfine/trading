# Track Pacer Report — 2026-05-24

## Summary
- Tracks audited: 8 non-MERGED (6 IN_PROGRESS: `backtest-perf`, `short-side-strategy`, `harness`, `cleanup`, `simulation`, `tuning`; 1 READY_FOR_REVIEW: `data-foundations`; 1 PENDING: `tuning-methods`)
- Active (≥1 PR last 7d): 7
- Slowing (7–30d since last PR): 0
- Stalled (>30d): 0
- [info] items needing decision: 2 (qc-structural recurring [info]s — carried since 2026-04-30 / 2026-05-03, **STILL not resolved** despite explicit Recommendation 5 in the 2026-05-22 pacer)
- Capability gaps flagged: 4 (M6.6 live cycle; M7.1/M7.2 ML+synth; shares-outstanding source still NOT resolved; cross-scenario validation methodology infra)

## Active tracks (≥1 PR last 7d)

- **tuning** — ~35 PRs since 2026-05-17 pacer (last full count: 76 PRs across all tracks since 2026-05-17 13:00Z; tuning is by far the largest single contributor). New since 2026-05-22 pacer: `promote_config.sh` cross-scenario validation gate (#1240), promote-gate hardening + MaxDD + N_trades gate (#1255), V8 random-restart analysis (#1256), 11-knob BO int-key plumbing (#1258/#1261/#1267/#1268), int-keys spec + smoke test (#1267/#1268), trend regression closed-form fix (#1272), epsilon bumps (#1265), and the 11-knob plateau verdict + new `tuning-methods` track spec (#1283). Theme: closing out the V1→V8 BO sweep stack with the explicit verdict that **single-objective BO on 11 knobs has plateaued** (`dev/notes/11knob-plateau-verdict-2026-05-24.md`); new methodology comparison track opened to break the plateau.
- **data-foundations** — ~10 PRs since 2026-05-22. New: full-pool 2019 baseline on top-3000-2019 settles random-universe-sweep methodology (#1281, 2026-05-23); drop cosmetic `[name]` field from sexp output (-4.8 MB, #1235); Shiller / French / sectors backfill / delisted enrichment continued (#1207/#1209/#1211/#1212/#1213/#1194). Theme: deep-history Weinstein cross-cycle validation + universe composition methodology (decomposes the +65pp top-500-vs-random-sample gap into ~30% size-weighted-pool-richness + ~70% selection-bias premium).
- **backtest-perf** — 0 net-new feature PRs since 2026-05-22 pacer; the fork-pool stack (#1199/#1200/#1202/#1203) landed in the prior week. Theme: track ran out of in-flight scope after the parallelism stack; cost-model wiring stack consumed the perf surface (see `cost-model` MERGED).
- **simulation** — 0 net-new PRs since 2026-05-22 pacer. The #1177 fix from prior week was the last activity. Theme: residual fix-forward complete; track in steady state.
- **harness** — ~5 PRs (#1239 docs-only PR exception in pr-merge-gates, #1238 status refresh per pacer, #1227 rules promotion, #1198 weekly deep health scan, #1284 devcontainer bind-mount + sweep-hygiene rules, #1275 docs(rules): extract 4 feat-agent dispatch invariants). Theme: meta — codifying agent-norms from memory into repo rules + safe-sweep infrastructure (devcontainer + bind-mount + disk-hygiene). The #1284 devcontainer bind-mount is a real feature (unblocks long-running sweeps for `tuning-methods` track).
- **short-side-strategy** — 2 PRs: #1262 margin Phase 3 bear-window validation sweep (4 bear windows × 2 configs); #1274 fix margin dedup same-tick TriggerExit (closes #1266, the Phase 2 transition bug). Theme: Phase 3 verdict locked (only GFC has positive short-side edge; Plan §2.2 acceptance gate FAILS), Phase 2 bug fixed; track in steady state.
- **cleanup** — 1 PR (#1245 docs(cleanup): close 4 stale [~] items verified resolved 2026-05-22). Theme: cleanup of stale backlog markers from 2026-05-08; no new findings dispatched.

## Slowing tracks (7–30d since last PR)

- None. All 7 active tracks shipped within the last 7 days.

## Stalled tracks (>30d since last PR)

- None.

## Next Steps staleness (P2)

- **short-side-strategy** — `dev/status/short-side-strategy.md` last updated 2026-05-23; "Next short-side step: fix the Phase 2 margin_call transition bug" is stale because PR #1274 fixed exactly that bug (closes #1266) on the same day. The `_index.md` row reflects the fix; the per-track status body still names the bug as the next action. Recommend refreshing the §"In Progress" + "Next short-side step:" lines to either declare track wrapped on the bear-window verdict or surface a new specific next item.
- **tuning** — `dev/status/tuning.md` last updated 2026-05-22; `## In Progress` block claims "Bayesian Phase 3 stack COMPLETE; V1→V7 production sweep stack run; methodology redesign IN REVIEW (PR #1237)". PR #1237 MERGED. V8 has run since (#1256 V8 analysis). The 11-knob plateau verdict (`dev/notes/11knob-plateau-verdict-2026-05-24.md`) + new `tuning-methods` track spawn explicitly defer further 4-param sweep work. The bottom-of-file "Remaining work" block still references "81-cell flagship sweep rerun" — superseded since 2026-05-12. Recommend full status-file rewrite: V1→V8 stack DONE, plateau verdict locked, surface routed to `tuning-methods`.
- **data-foundations** — `dev/status/data-foundations.md` last updated 2026-05-23; `## Next Steps` item 1 "Phase 1.4 — run the actual IWV scrape (ops-data, ~3-hour wall-clock)" is stale because the EODHD `?delisted=1` endpoint discovery (2026-05-17, `memory/project_eodhd_delisted_unlock.md` + index row preamble) made IWV moot. The `## Blocking Refactors` block still leads with "Option B pivot — IWV scrape becomes the primary survivorship-correct source" — true at the time, now superseded. The current Next Steps body does not direct the next concrete action under the new world (bars-retention recovery vs accept). Recommend reconciling Next Steps with the EODHD-delisted unlock.
- **weekly-snapshot** — `dev/status/weekly-snapshot.md` last updated 2026-05-04 (**20 days stale**), `## Status` still says `PENDING`, `## Blocked on` says "M5.1 hardening to land (CI green)", and `## Next Steps` item 1 is "Wait for M5.1 hardening to land". Reality: M5.1 was resolved by PR #752 (2026-05-02), the entire M6 verification surface (M6.1–M6.5) is MERGED, and `_index.md` row already says MERGED. The maintainer flagged this exact divergence in the 2026-05-02 run-2 reconcile and again in 2026-05-22 pacer; **still not refreshed in 20 days**. This is the longest-running per-track staleness signal in the audit. Recommend either rewrite per current reality (entire M6.1–M6.5 surface DONE; M6.6 explicitly DEFERRED) or formally retire the file with a one-line pointer to `dev/plans/m6.6-live-cycle-scoping-2026-05-22.md` (#1248).
- **backtest-perf** — `dev/status/backtest-perf.md` last updated 2026-05-22; the `## Next Steps` block is items 1–7 all marked DONE with no forward-looking next item. The track is IN_PROGRESS in the index, but the actual next dispatchable surface is unclear from the file. Recommend either adding a concrete next item (e.g., release-gate N≥5000 awaiting snapshot streaming verification; tier-4 first manual `workflow_dispatch` for canonical baseline; cost-model market-impact-bps ADV wiring) or flipping to MERGED.

5 of 8 non-MERGED tracks have stale Next Steps. The 2026-05-22 status-refresh sweep (#1238 reconciled 5 stale files) targeted `simulation`/`tuning`/`experiments`/`harness`/`backtest-perf` and only partially settled the `tuning` body. Same operational debt signal as last week, with two new contributors (`short-side-strategy` from #1274 same-day fix, `data-foundations` from the EODHD unlock).

## [info] items needing decision (P3)

- **qc-structural recurring H3 false-positive on advisory linter text** — carried in reconcile preambles since 2026-05-03; flagged in both 2026-05-17 and 2026-05-22 pacer reports; **STILL not resolved** in any of the post-pacer PRs (`promote_config.sh`, V8 work, cost-model wiring, devcontainer bind-mount all unrelated). Per the 2026-05-22 pacer's explicit Recommendation 5 — "Resolve the two recurring qc-structural [info] items — carried for 7+ weeks. Either patch the agent or record explicit acceptance in `dev/decisions.md`." — no action taken in the 2 days since. Recommended action: ESCALATE_TO_MAINTAINER (third pacer in a row).
- **qc-structural review-file persistence gap** (`/w/...` vs `/__w/...` path typo on some runs) — carried since 2026-04-30. No new occurrences in 2026-05-22+ PRs, but no explicit RESOLVED marker either. Same Recommendation 5 above applies. Recommended action: ESCALATE_TO_MAINTAINER (third pacer in a row) — formally mark RESOLVED in `dev/decisions.md` OR patch the agent if intermittent.

(Lower-severity carried `[info]`s — magic_numbers docstring false-positives, status_file_integrity advisory FAILs — remain harness-backlog candidates; no decision needed this week. The 2026-05-21 #1227 rules promotion appears to have NOT included a fix or formal acceptance of these two.)

## Tracks without owner (P4)

- None. The PENDING `tuning-methods` row (created today, 2026-05-24, per #1283) carries owner `feat-backtest`. All 8 non-MERGED rows have owners populated.

## Recurring discussion topics (P5)

- **`dev/decisions.md`** has only the two 2026-05-16 vendor pivot entries (Option B IWV + Norgate retired) in the last 30 days. Both were resolved that day and explicitly superseded by `memory/project_eodhd_delisted_unlock.md` (2026-05-17) — recurring no longer; landed on a new path. KEEP_AS_INFO.
- **Cross-scenario validation as load-bearing methodology** — flagged in 2026-05-22 pacer as RECOMMEND_NEW_TRACK candidate. Partial resolution since: `promote_config.sh` MERGED #1234/#1240, cross-scenario validation gate landed #1240, MaxDD + N_trades gate extension #1255. The actual structured `validation.sexp` writer + REFERENCE scenario panel landed implicitly through these PRs. Recommendation evolved: KEEP_AS_INFO — infrastructure landed; no separate track needed. The next surface (per #1283) is the `tuning-methods` methodology comparison, which inherits this gate.

## Diminishing returns (P6)

- **harness** — 5 PRs in last 7d (#1284 devcontainer bind-mount, #1275 docs(rules), #1239 rules docs-only PR exception, #1227 rules promote, #1238 docs(status) refresh, #1198 ops health scan). 5 of 5 (or 4 of 5 if you count #1284 as feature) are docs/rules/ops — same theme as 2026-05-22 pacer. The #1284 devcontainer bind-mount is genuine feature surface (unblocks the new `tuning-methods` sweep step 0 per the track's `## Blocked on`). Recommendation: KEEP_AS_INFO — natural state for a wrapped Tier 1 track; #1284 demonstrates the track still has real feature scope when sweep-infra hazards surface. Same as 2026-05-22 pacer.
- **cleanup** — 1 PR in 7d (#1245 close 4 stale [~] items). Backlog is empty as of #1245. Track is structurally maintenance — no diminishing-returns signal (it's the goal-state). Recommendation: KEEP_AS_INFO.
- **simulation** — 0 PRs in 7d; 1 PR in 7-14d window. The track has converged on steady state per its own `## In Progress` block ("M5 walk-forward + parameter tuner — DONE via cross-tracks"). Recommendation: KEEP_AS_INFO — consider flipping to MERGED if no additional residual fix-forward is queued; current Next Steps body lists only "Local sp500-2019-2023 baseline rerun" (deferred, needs full universe) and "Position-level assertions" (low priority).

## Capability gaps (P7)

- **M6.6 — True live cycle** (`live` DATA_SOURCE + cron + alert dispatch + trading-state durability). Same gap flagged in 2026-05-17 + 2026-05-22 pacers. New since: PR #1248 (2026-05-22) `docs(plan): M6.6 live cycle scoping (per P2 of 2026-05-22 priorities)` — scoping plan landed. No implementation track spawned. The 11-knob plateau verdict (#1283) reinforces #1237 §7's question: with M5 tuning at structural plateau, M6.6 is the next critical milestone toward the system goal per `weinstein-trading-system-v2.md` §3. Recommendation: ESCALATE_TO_MAINTAINER — plan landed; explicit go/defer decision now overdue.
- **M7.1 ML training (T-C supervised)** — Status file `tuning.md` `## Blocked on` still lists "data-foundations track M7.0 Norgate ingest (needed for survivorship-bias-aware train/test split)". Norgate was retired 2026-05-16 per `dev/decisions.md`; EODHD `?delisted=1` is the new survivorship-correct source (2026-05-17). T-C is therefore **no longer blocked on its named blocker**, but the `## Blocked on` text has not been refreshed. Recommendation: ESCALATE_TO_MAINTAINER — refresh `tuning.md` blocker list, then take an explicit decision on T-C: dispatch on the EODHD-delisted unlock, or defer to post-`tuning-methods` verdict.
- **M7.2 Synthetic stress** — not on any active track; Synth-v1/v2/v3 generators all MERGED but no "run tuned configs on Synth-v3 universe and reject configs that fail stress on 80yr synthetic histories" track exists. Same gap as 2026-05-17 + 2026-05-22 pacers. Per PR #1237 §7 (now MERGED), M7.2 maps to the §2.1 "missing randomness" gap and was recommended to open a track post-cross-scenario-validation. Cross-scenario validation infra has now landed (`promote_config.sh` + gate extensions). Recommendation: KEEP_AS_INFO — natural successor to `tuning-methods` track verdict; revisit after step 0 (random-search baseline) runs.
- **Shares-outstanding bulk run** — still vendor-blocked on EODHD Fundamentals tier upgrade ($59.99/mo). The dollar-volume pivot (#1169) and EODHD `?delisted=1` discovery (2026-05-17) together substantially mitigated the Phase 1.1 / Q2-A block, but shares-outstanding for market-cap-weighted composition remains absent. Same gap as 2026-05-17 + 2026-05-22 pacers. Recommendation: ESCALATE_TO_MAINTAINER (third pacer) — tier-vs-Sharadar-vs-AlphaVantage-vs-park decision overdue.

## Recommendations

1. **Refresh 5 stale Next Steps blocks** in one reconcile commit, modelled on PR #1238: `weekly-snapshot.md` (20d stale, Status + Blocked-on + Next Steps all wrong — highest priority), `tuning.md` (post-V8 + plateau-verdict refresh; route active surface to `tuning-methods`), `data-foundations.md` (EODHD-delisted-unlock obsoletes IWV Next Step), `short-side-strategy.md` (Phase 2 fix shipped same day as last refresh, Next Steps wording stale), `backtest-perf.md` (Next Steps items 1–7 all DONE; needs forward-looking item or flip to MERGED).
2. **Resolve the two recurring qc-structural [info] items** — carried 7+ weeks, flagged in 3 consecutive pacer reports with explicit recommendations to ESCALATE_TO_MAINTAINER. Either patch the agent (H3 advisory false-positive detector; review-file path persistence) or record explicit acceptance in `dev/decisions.md` with a "RESOLVED-by-acceptance" marker.
3. **Take the M6.6 go/defer decision** — scoping plan #1248 landed 2026-05-22; no implementation track spawned in 2 days. With the M5 tuning surface at structural plateau (#1283 verdict), M6.6 is the next critical-path milestone toward the documented system goal.
4. **Refresh `tuning.md` `## Blocked on`** — T-C's named blocker (Norgate ingest) was retired 2026-05-16; the actual blocker (if any) is now either the `tuning-methods` step-0 verdict or M7.0 EODHD-delisted-derived survivorship-correct dataset shape. Update the blocker list so future dispatch decisions don't trip on stale gating.
5. **Make the shares-outstanding source decision** — third consecutive pacer flagging this. Tier upgrade ($59.99/mo) vs Sharadar/AlphaVantage swap vs formally park. The dollar-volume pivot is acknowledged as a workaround in `_index.md` row preamble.
6. **Flip `simulation` to MERGED** — 0 PRs in 7d, `## In Progress` block says "DONE via cross-tracks", Next Steps body has only deferred / low-priority items. Track is in steady state; IN_PROGRESS without an active surface for 7+ days is the same staleness pattern flagged for `orchestrator-automation` last week (now MERGED via #1246/#1251).
7. **Dispatch safe-sweep infrastructure** to unblock `tuning-methods` step 0 (random-search baseline). #1284 landed the devcontainer bind-mount today; `dev/plans/safe-sweep-infrastructure-2026-05-24.md` calls for disk-watcher + checkpoint-resume in addition. Step 0 cannot launch until these land.

## Stats

- 117 PRs merged in last 7d (all tracks) — ~17 PRs/day pace, consistent with the maintainer-driven cadence
- ~709 commits in last 30d (note: includes ops daily-summary + main-fix commits, not just feature PRs)
- 7 tracks active / 0 slowing / 0 stalled (of 8 non-MERGED tracks audited; `tuning-methods` is exempt as PENDING, blocked on safe-sweep infra)
- 5 of 8 non-MERGED tracks have stale Next Steps (`short-side-strategy`, `tuning`, `data-foundations`, `weekly-snapshot`, `backtest-perf`)
- 2 [info] items carried ≥3 reconciles (qc-structural H3 FP; review-file persistence gap) — flagged 3 consecutive pacers, **STILL not resolved**
- 4 capability gaps flagged (M6.6 live cycle with new scoping plan #1248; M7.1 stale blocker refresh; M7.2 synthetic stress; shares-outstanding source third-pacer-carry)
- 1 new track opened this week (`tuning-methods`, #1283, PENDING on safe-sweep infrastructure)
- 1 track wrapped this week (`cost-model` MERGED end-to-end via #1260/#1273/#1276/#1277/#1278)

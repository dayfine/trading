# Track Pacer Report — 2026-05-10

## Summary
- Tracks audited: 11 IN_PROGRESS / READY_FOR_REVIEW (24 total in `_index.md`; 13 are MERGED)
- Active (≥1 PR last 7d): 10
- Slowing (7–30d since last PR): 1
- Stalled (>30d): 0
- [info] items needing decision: 2
- Capability gaps flagged: 4

## Active tracks (≥1 PR last 7d)

- **cleanup** — 30+ PRs (#925, #926, #927, #928, #929, #930, #935–#945, #947–#978, #981); theme: nesting / file-length / fn-length / magic-numbers cleanups across `weinstein/`, `backtest/`, `analysis/data/`, `engine/`. Every PR is a single small mechanical extraction with no behavior change — track is operating exactly as designed (code-health absorption).
- **harness** — ~10 PRs (#895 branch-protection, #905 velocity_report, #918 cleanup_merged_worktrees default, #943 dune dep tracking fix, #946 sweep lock-honoring, #983 CI red-main watchdog, #984 list_active_exceptions, #990 split golden-runs 5y/15y, #991 pin opam-repo SHA, #995 missing test deps, #1001 upload golden-runs artefacts, #1003 broaden artefact glob, #1011 auto-merge poll 6m→10m); theme: CI hardening + watchdog automation + post-incident sweep-script fixes (closing #919 and the 2026-05-08 mid-flight sweep incident).
- **all-eligible** — 6 PRs (#899 grading lib, #901 CLI runner, #904 Friday-breakout dedup, #908 min_grade quality gate, #962 nesting cleanup, #1012 PR-3 status flip); theme: PR-1+PR-2 lib+CLI shipped, then `min_grade` + dedup follow-ups; PR-3 release-report wiring just flipped to dispatchable.
- **data-foundations** — 4 PRs (#988 stream csv_snapshot per-symbol, #992 dedupe Daily_panels LRU, #993 skinny portfolio summary projection, #998 15y split-day adjustment investigation); theme: 15y SP500 RAM cliff fixes (Fixes A/B/C from `dev/notes/15y-memory-cliff-2026-05-08.md`).
- **experiments** — 7 PRs (#996 capital-recycling Cell A-E, #999 E3 stop-buffer sweep results, #1000 E4 scoring-weight sweep results, #1002 Cell E generalisation, #1004 session summary, #1005 Cell E walk-forward, #1007 Cell E 15y impractical writeup); theme: M5.4 E3/E4 sweeps published + Cell E (combined Stage3+Laggard) generalisation + 15y blocker writeup.
- **simulation** — 3 PRs (#916 equity-curve truncation + Stale_hold detection, #919 docs strategy clarification, #920 cost-overlay slippage_bps knob); theme: maintainer-driven follow-ons after run-2 NEEDS_REWORK.
- **backtest-perf** — 4 PRs (#897 tier4-broad-1y SCALE cell, #1010 docs O(N²) trade-history hotspot is next P0, #1014 prepend-trades O(N²)→O(N) fix, #1015 hoist trade_context audit_idx out of trades.csv loop); theme: post-15y-cliff perf-hotspot work.
- **tuning** — 1 PR (#914 T-B Bayesian-opt CLI binary); theme: T-B CLI mirror of T-A. Status file claims READY_FOR_REVIEW but PR merged 2026-05-07 — see P2 staleness flag.
- **orchestrator-automation** — 1 PR (#1011 auto-merge poll bump); theme: cron tuning. Daily summary PRs (#1008/#1009) are runtime products, not orchestrator-automation feature work.
- **weekly-snapshot** — MERGED on the M6 verification surface; M6.6 live cycle explicitly DEFERRED. Exempt from cadence flag.

## Slowing tracks (7–30d since last PR)

- **cost-tracking** — last direct PR was #708 (orchestrator stash budget JSON across git reset/clean) on 2026-04-30, ~10 days ago; before that the cluster #483/#495/#499/#504/#505/#510/#511/#516/#577/#580 in 2026-04-21..26. Status file `## Last updated` is 2026-04-20. Theme: GHA cost capture + bundle. Recommendation: KEEP_AS_INFO — Next Steps explicitly say "verify measured `total_cost_usd` lands on this run's `dev/budget/...json` post-orchestrator-exit" and "Compare costs before/after PRs #481/#482"; that comparison can be done on accumulated data without new PRs and the track is naturally low-cadence (infra-only).

## Stalled tracks (>30d since last PR)

- None.

## Next Steps staleness (P2)

- **tuning.md** — `## Status` line claims `READY_FOR_REVIEW` and "T-B CLI binary `bayesian_runner.exe` ready for review on branch `feat/backtest-tuning-bayesian-opt-cli` (this PR)", but PR #914 (T-B Bayesian-opt CLI) merged on 2026-05-07. Status file last updated 2026-05-07. The first §Next Steps item ("Wire CLI binary at `bayesian_runner.ml`") is correctly struck through with "done (this PR)", but `## Status` and `## In Progress` rows lag the merge. Recommend refreshing.
- **experiments.md** — `## Next Steps` first item is "Run M5.4 E3 stop-buffer sweep locally; write `dev/experiments/m5-4-e3-stop-buffer-sweep/report.md` with verdict." That report landed via PR #999 (`experiment(m5-4-e3): stop-buffer sweep results — 1.00 buffer wins`) on 2026-05-08. Same for item #2 (E4 scoring-weight sweep) which landed via #1000 (`resistance-heavy wins`) on 2026-05-08. Status file last updated 2026-05-06. Recommend refreshing.
- **data-foundations.md** — `## Next Steps` first item is "Open Synth-v1 block bootstrap PR (~250 LOC)", but Synth-v1 (#755) and Synth-v2 (#775) both merged 2026-05-02 per the `_index.md` reconcile entries. Status file last updated 2026-05-06; the F.3 narrative is current but the §Next Steps list still references unstarted Synth-v1. Recommend refreshing to reflect remaining items (Synth-v3, EODHD multi-market, Norgate).
- **backtest-perf.md** — Status file's own `## Open work` block self-flags as stale ("Status file §Open work block remains stale — refresh deferred until next dispatched-on-this-track run") in the `_index.md` row. The `## Next steps` section lists items 1–4 that are all marked DONE inline. Recommend a real refresh — the new perf hotspot work (#1010/#1014/#1015) isn't in the file.
- **cost-tracking.md** — last updated 2026-04-20, before the #495/#499/#510/#511/#583/#675/#708 cluster of cost-capture fixes landed. Next Steps item 1 ("Verify GHA Capture run cost step produces valid JSON on next orchestrator run") was satisfied many runs ago. Recommend refreshing.

## [info] items needing decision (P3)

- **qc-structural recurring H3 false-positive on advisory linter text** — carried since at least 2026-05-01 (visible in `_index.md` reconciles for 2026-05-01, 05-03 run-1+run-2, 05-04, 05-05, 05-06, 05-07 run-1+run-2, 05-08 run-2). Five+ consecutive reconciles, well past the ≥3 threshold. Most recent run notes "NOT exercised this run — qc-structural exited cleanly", so it surfaces only intermittently, but no permanent fix has landed in the qc-structural agent definition. Recommended action: ESCALATE_TO_MAINTAINER — needs an explicit fix in `.claude/agents/qc-structural.md` Step H3 (or the rule it cites) to disambiguate advisory-only linter exit codes from gating ones.
- **qc-structural review-file persistence gap** — carried since at least 2026-05-04 (`/w/trading/...` typo path; orchestrator relocated). Visible in `_index.md` for 2026-05-04, 05-05, 05-06, 05-07 run-1+run-2, 05-08 run-2. Most recent two runs note "NOT exercised this run — agent wrote correctly to canonical `/__w/trading/...` path", but the agent's instruction set still permits the typo. Recommended action: ESCALATE_TO_MAINTAINER — pin the canonical path in qc-structural's "Writing the review file" section so the agent cannot drop a leading underscore.

(`magic_numbers linter false-positives on docstring text` was the third long-running carryover — RESOLVED 2026-05-08 via #952/#955; not flagged.)

## Tracks without owner (P4)

- None. Every IN_PROGRESS / READY_FOR_REVIEW row in `_index.md` carries an Owner (feat-backtest, feat-data, feat-weinstein, harness-maintainer, harness-adjacent, code-health). PASS.

## Recurring discussion topics (P5)

- None. `dev/decisions.md` has no entries in the last 30 days other than the 2026-05-03 agent-scope extension (feat-backtest expanded + feat-data created — RESOLVED in the same entry) and the 2026-04-29 split-day broker-model decisions (all marked "DONE" inline). `## Open Questions` is `(None yet — system just initialized.)`. PASS — no recurring unresolved topics.

## Diminishing returns (P6)

- **cleanup** — 5 of last 5 PRs are `cleanup(nesting)` / `cleanup(file_length)` / `cleanup(magic_numbers)` / `cleanup(fn_length)` extractions. Heuristic matches "diminishing returns" but this is the track's stated purpose ("absorbs small mechanical fix-ups surfaced by `health-scanner`") and current intake is high (~30 PRs in 7d). Not a candidate for closure; KEEP_AS_INFO. The high cadence signals real findings from #919-driven dune dep tracking fix (#943) — many violations were silently uncached and surfaced in a flood. Track will self-quiet when the backlog drains.
- **harness** — last 5 are mixed (CI hardening, sweep-script fix, test-deps fix, opam pin, golden-runs split). Not pure chore. PASS.
- **backtest-perf** — last 4 are real perf work (O(N²) fixes, hoisting). PASS.
- **data-foundations** — last 4 are 15y memory-cliff fixes + investigation. PASS.
- **experiments** — last 7 are sweep-result publication + Cell E generalisation. PASS.

## Capability gaps (P7)

- **Norgate vendor signup** — blocking M5.3 survivorship-bias-aware data ingest, M7.0 Track 1, and M5.5 T-C ML supervised tuning. Cited as `Blocked on` in both `data-foundations.md` and `tuning.md` (cross-track dependency). User-confirmed budget OK ($32–66/mo) per `data-foundations.md` §"Track 1", but no signup since at least 2026-05-02 when the track was created (~8+ days; not yet >30 but trending). Mitigation already in flight: Wiki+EODHD historical universe (#803/#808/#809/#813 merged) provides 2010–2026 point-in-time membership without Norgate, unblocking the experiment side. Recommendation: KEEP_AS_INFO — mitigation exists; revisit when T-C work attempts to start and the Wiki+EODHD horizon (2010+) proves insufficient.
- **M6.6 — true live cycle** (live `DATA_SOURCE` impl + cron + alert dispatch + trading-state durability) — explicitly DEFERRED in `weekly-snapshot.md`; not orchestrator-dispatchable. Critical-path for actually using the system per design-doc §3 ("Saturday review workflow"). Not started. Recommendation: KEEP_AS_INFO — deferral is intentional per the M6 reframe ("verification harness, not live trading yet"), and the M5/M7 backtesting + tuning stack is still being hardened. Revisit once tuning lands a champion config.
- **Synth-v3 multi-symbol factor model** (~1000 LOC, M7.0 Track 3) — listed in `data-foundations.md` §Pending. Required for full strategy backtests on synthetic universes, which is required for M7.2 antifragility check. Not started. Mentioned only in `data-foundations.md` (single-track dependency). Recommendation: KEEP_AS_INFO — no immediate downstream blocker since M5.5 grid + Bayesian tuning operate on real data.
- **EODHD multi-market expansion** (LSE/TSE/ASX/HKEX/TSX) — listed in `data-foundations.md` §Pending as "small, parallel" item. Lost-decade test bed (TSE 1990–2020) would let M5.4-style experiments check antifragility properties before Synth-v3 lands. Not started. Recommendation: ESCALATE_TO_MAINTAINER for prioritisation — small/cheap and would expand the experiment surface materially.

## Recommendations

1. **Refresh status files for tuning, experiments, data-foundations, backtest-perf, cost-tracking** — five files have stale `## Next Steps` or `## Status` headers that lag the merged work by 2–20 days. None are blocking, but they degrade the orchestrator's ability to pick the right Next task on dispatch.
2. **Decide the two qc-structural [info] carryovers** — H3 false-positive + review-file path. Both have been carried for 5+ reconciles. Pin the canonical review-file path in `.claude/agents/qc-structural.md` and disambiguate H3's gating-vs-advisory rule.
3. **Decide on EODHD multi-market expansion priority** — small, paid-for, parallel-trackable; would broaden the M5.4 experiment surface (TSE lost-decade is uniquely useful) without waiting on Norgate signup.
4. **Triage cost-tracking track for closure or active follow-through** — the GHA cost-capture infrastructure is built and functioning. Either close the track and move residual `## Follow-up` items to a maintenance backlog, or schedule the cost-trend comparison the Next Steps call for.
5. **Norgate signup status check** — surface to the maintainer whether the vendor signup is still planned. If yes, set a target date; if no, formally retire the Norgate scope from `data-foundations.md` and `tuning.md` and let Wiki+EODHD remain the canonical historical-universe path.

## Stats
- 197 PRs merged in last 7d (all tracks) — heavy week dominated by cleanup intake (#925–#978) and 15y memory-cliff fixes (#988/#992/#993)
- 726 PRs merged in last 30d (all tracks)
- 10 tracks active / 1 slowing / 0 stalled
- 2 [info] items carried ≥3 reconciles (H3 false-positive, review-file persistence gap)
- 4 capability gaps flagged (Norgate, M6.6 live cycle, Synth-v3, EODHD multi-market)

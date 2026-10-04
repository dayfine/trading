# Track Pacer Report — 2026-10-04

## Summary
- Tracks audited: 50 index rows (26 IN_PROGRESS + 1 PENDING = 27 non-MERGED; 23 MERGED exempt). Cadence run on the 27 non-MERGED rows.
- Active (≥1 PR last 7d): 14
- Slowing (7–30d since last PR): 2
- Stalled (>30d): 11 (10 IN_PROGRESS + 1 PENDING parked)
- `[info]` items needing decision: 1 (orchestrator summary loss, carried across ≥3 dailies)
- Capability gaps flagged: 8 (2 new, 6 carried; 3 of last week's resolved)

**Headline: last week's two biggest risks both closed.** The five unbuilt
write-only branches flagged in the 09-27 report all shipped as reviewed PRs
within ~48 h: `feat/stop-decision-audit` → #2986, `feat/split-corpus` → #2987,
`fix/stop-raise-count` → #2988, `feat/suspend-tickets-bearish` → #2995,
`feat/stop-basis-flags` → #2996 (the #2982 `stop_ma_same_basis` flag). They were
followed by a validator wave that encodes the #2982 defect class as checks: V19
audit join / V20 audit basis (#3024), V21 installed-tighter-than-proxy + V23
macro bypass at fill (#3033), V22 stalled trailing-stop ratchet (#3034). The
same week added the findings registry and its CI check (#3026, issue #3001), so
every finding now has to name a guard that still exists. Rec 1 and Rec 2 of the
last report are done.

**Second: throughput was the highest on record and feature-heavy.** 98 PRs
merged in 7 days (84 last week); 59 (60 %) carry a code-bearing prefix
(`feat`/`fix`/`harness`/`cleanup`/`refactor`/`test`/`perf`), up from 44 %. Active
tracks went from 9 to 14. `data-foundations` broke a 77-day stall (4 PRs,
including the vendor-wick check #3106 and SPY-history preservation #3029).

**What did not move:** the status files. Six tracks shipped this week without
their status file being touched (`post-run-validation`, `rename-twin-dedup`,
`simulation`, `short-side-strategy`, `weekly-snapshot`, `experiment-platform` —
see P2), and the index has not been reconciled since 10-02 despite ~25 merges
since. The five long-running human gates (tuning #1327, sweep-perf flambda,
weekly picks, `dev/decisions.md`, record-of-record) are all unchanged and now on
their 4th–11th ask.

## Active tracks (≥1 PR last 7d)
- **harness** — ~18 PRs (#2991, #3000, #3008, #3021, #3025, #3026, #3030, #3050, #3058, #3063, #3066, #3076, #3079, #3080, #3086, #3088, #3096, #3112); theme: findings registry + CI check (#3026), Issue↔PR `Done when`/`Closes`/`Refs` protocol (#3025), review-pack render-and-look step with signal detectors (#3076, #3080, #3086, #3088), deep-scan exceptions table (#3008, #3050), model/effort routing + `results-analyst` agent (#3112). #3113 (`harness/usage-model`) open at rework iteration 1.
- **cleanup** — 8 PRs (#2992, #3009, #3031, #3049, #3059, #3064, #3078, #3094); theme: file-length extractions — `release_report.ml` (769→636 and further), `trade_audit_ratings` (3 passes), `build_runner.ml` 771→266, `trade_audit_report.ml` split; four linter exceptions removed rather than re-dated. Exactly what `code-health-discipline.md` asks for.
- **support-floor-stops** (stops) — 7 PRs (#2996, #2997, #3004, #3042, #3052, #3071, #3073); theme: the #2982 stop-basis flags, late-Stage-2 tighten actually firing (#2997) and pinned (#3004), `trailing_stop_ma_period` dial (#3052), split-safe floor level restated on the raw basis (#3071).
- **trade-audit** — 6 PRs (#2986, #3006, #3007, #3087, #3095, #3100); theme: every trailing-stop decision recorded per held position, proxy stop named so it is not read as the installed stop, entry-ticket anchor kind recorded, `trades.csv` stop columns follow the stop machine (#3075).
- **post-run-validation** — 5 PRs (#3024, #3033, #3034, #3044, #3051); theme: V19–V23 (#3002 parts A–C) and V6 share-class fixes (#3035, #3045). **Status file not touched since 09-20** (P2).
- **data-foundations** — 4 PRs (#3018, #3029, #3105, #3106); theme: SPY bar refresh and append-only preservation, split-detector raw-gap confirmation (default off), vendor intraday wick warning on fetch. **Back from 77 days stalled.**
- **screener** — 3 code PRs (#3067, #3099, #3103) + trader-presets experiment PRs (#3041, #3053, #3061, #3081); theme: continuation-buy entry anchored at `consolidation_high`, book write-back on the continuation-buy initial stop, continuation-buy ranking + pullback-low stop (#3069).
- **backtest-infra** — 3 PRs (#2988, #3005, #3023); theme: stop raises counted from the installed stop, broker stops on entry fill and every stop change (#2984 — last week's open item, closed), no `UpdateRiskParams` for exiting positions.
- **simulation** (entry tickets) — 2 PRs (#3108, #3022); theme: cancel resting entry ticket on split (default-off, #3075), one-share-class-per-issuer entry rule (default-off, #3015). **Status file not touched since 09-02** (P2).
- **arc-readiness** — 1 PR (#2995); theme: default-off macro suspension of resting entry tickets. Its pre-registered investor arm (`experiments/macro-suspend`, 2026-10-03) is on origin with no PR yet.
- **rename-twin-dedup** — 1 PR (#3102); theme: default-off longest-matching-run criterion for rename twins (#3057). Status file not updated (P2).
- **short-side-strategy** — 1 PR (#3110, results-only); theme: shorts liveness pair — "short leg dead under faithful gates (0 fills, 5d)". This is the track's first output in 70 days and it is a terminal-looking read; status file not updated (P2).
- **orchestrator-automation** — 1 PR (#3063); theme: fast-exit Condition 2 exempts a real daily-summary subject (the 4-run summary-loss fix).
- **backtest-perf** — ledger-only: 4 `perf-long-cells` rows PRs (#3017, #3062, #3082, #3092); last code PR #2965 (09-25, 9 days). The ledger is being used after every chain as `perf-review-weekly.md` asks. Counted active on ledger upkeep; code is slowing.

## Slowing tracks (7–30d since last PR)
- **cash-floor-correctness / extension-stop / etc.** — none newly enter this bucket; see stalled.
- **weekly-snapshot** — last booked PR #2453 at 2026-08-20 (45 days), *but* M6.4-class work landed this week outside it: #2987 (split corpus + first cross-consumer suite), #3105 (split-detector raw-gap confirmation), #3108 (cancel tickets on split), #3071 (split-safe floor). Treated as slowing, not stalled, because the work exists; recommendation: ESCALATE_TO_MAINTAINER — book M6.4 to an owner and link these four PRs (4th ask).
- **experiment-platform** — ledger heavily used (new entry `2026-10-02-continuation-buys-trader-rerun`; 10 entries in 30d), platform code idle; last booked PR #2631 at 2026-09-01 (**33 days** — now crosses into stalled on the strict rule); recommendation: ESCALATE_TO_MAINTAINER — close as MERGED (the platform is done; the ledger lives on) or name a code successor. 4th cycle.

## Stalled tracks (>30d since last PR)
- **stage-accuracy** — last PR #2450 at 2026-08-20 (45 days); reason: broad-universe WF-CV re-run data-gated; recommendation: KEEP_AS_INFO.
- **resistance-v2** — last PR #2145 at 2026-07-28 (68 days); reason: WF-CV vs w30 data-gated/LOCAL; default-on bundle #2047 still uncertified and now on a stop system that #2996 can change; recommendation: ESCALATE_TO_MAINTAINER. 8th cycle.
- **tuning** — last PR #2113 at 2026-07-27 (69 days); reason: M2 qNEHVI awaiting maintainer enable-commit per #1327 (2026-05-26, **131 days**); recommendation: ESCALATE_TO_MAINTAINER. 11th ask.
- **margin-realism** — last PR #2077 at 2026-07-24 (72 days); reason: M4 complete, no successor, no `## Next Steps`; recommendation: KEEP_AS_INFO — close to MERGED. 4th ask.
- **extension-stop** — last PR #1960 at 2026-07-13 (83 days); reason: default flip human-gated (R3); insurance-ACCEPT measured on pre-#2996 stops; recommendation: KEEP_AS_INFO.
- **floor-quality** — last PR #1913 at 2026-07-10 (86 days); reason: deep-warehouse LOCAL; recommendation: KEEP_AS_INFO.
- **rolling-start-lens** — last PR #1645/#1648 at 2026-06-18 (108 days); reason: LOCAL/data-gated; recommendation: KEEP_AS_INFO.
- **cash-floor-correctness** — last PR #1582 at 2026-06-14 (112 days); reason: NS2 human-gated, NS4 data-gated; recommendation: KEEP_AS_INFO.
- **sweep-perf** — last PR #1574 at 2026-06-13 (113 days); reason: manual ghcr.io flambda rebuild; recommendation: ESCALATE_TO_MAINTAINER. 10th ask.
- **spy-only-reference** — last PR #1438 at 2026-06-03 (123 days); reason: item 1 "(Open question, not dispatched)"; recommendation: ESCALATE_TO_MAINTAINER — decide or close. 4th ask.
- **tuning-methods** (PENDING) — no PR ever; file last updated 2026-05-24 (133 days); recommendation: ESCALATE_TO_MAINTAINER — close or re-scope. 4th ask.

## Next Steps staleness (P2)

**Resolved since last cycle:** `screener.md` refreshed 10-02 (was 4 weeks stale);
`support-floor-stops.md` refreshed 10-02; `trade-audit.md` refreshed 10-03; the
`backtest-infra` index row now reads #2984 (was #2839); `cleanup.md` content
current (8 updates this week).

New drift this week (track shipped, file did not move):

- **post-run-validation** — `Last updated: 2026-09-20`; five validator PRs since (#3024, #3033, #3034, #3044, #3051). Next Steps still opens with "Arm `-detect-series-level` on the next warehouse rebuild". Status heading reads `READY_FOR_REVIEW`, index row reads `IN_PROGRESS`. recommend refreshing status file.
- **rename-twin-dedup** — `Last updated: 2026-09-16`; #3102 (longest-matching-run criterion) shipped 10-03; `## Next task` does not mention it. recommend refreshing status file.
- **simulation** — `Last updated: 2026-09-02`; #2963, #2967 (09-25), #3022, #3108 since; index row still "next: none queued". **2nd cycle.** recommend refreshing status file.
- **short-side-strategy** — `Last updated: 2026-07-26`; #3110 liveness result (0 fills) is a decision-grade read the file does not record. recommend refreshing status file and deciding the track's fate (see Recs).
- **Index-row / file status mismatches** — `trade-audit` file `READY_FOR_REVIEW` vs index `IN_PROGRESS`; `post-run-validation` same; `tax-lens` file `READY_FOR_REVIEW` vs index `MERGED`. The index's own `Last updated` is 10-02 (run 37043659588); no reconcile has run against the ~25 merges of 10-03/10-04.
- **Index rows naming shipped work:** `backtest-infra` "#2984 open" — closed by #3005 (09-28); `support-floor-stops` row unchanged since 09-15 ("next: UNSET") despite the file being refreshed twice; `backtest-perf` "next: #2899 … (#2896)" — both shipped (#2899, #2920). 2nd cycle for the last two.
- **cleanup** — header still `Last updated: 2026-08-30` (content current). KEEP_AS_INFO.

Carried unchanged (files untouched): `cash-floor-correctness`, `resistance-v2`, `experiment-platform`, `tuning`, `extension-stop`, `tuning-methods`, `spy-only-reference`, `weekly-snapshot`. `data-foundations` was touched (10-03) but its `## Next Steps` still opens with a recital of May merges (#755 … #1122). recommend refreshing status files — 4th cycle for the first eight.

## [info] items needing decision (P3)

`dev/status/_index.md` carries zero `[info]` / `[critical]` tags. Across the
week's daily summaries:

- **Orchestrator runs losing their daily summary** — `[info]` in `dev/daily/2026-09-28.md` ("4 consecutive runs lost their summary": 36473902107, 36580075545, 36609553699, 36724290588) and `2026-09-30.md`; prior instances in 07-26, 09-08, 09-14, 09-15, 09-23. #3063 (10-01) is the latest fix. **But 10-03 has two funded runs (37123376327 $14.95, 37136361984 $2.23) and no `dev/daily/2026-10-03.md`.** Carried since 2026-09-28 (≥3 reconciles, 7 historical occurrences); recommended action: ESCALATE_TO_MAINTAINER — verify whether 10-03 is an eighth instance after the #3063 fix.
- **Strict-checks re-attest tax** — `[info]` in 09-27 and 09-28 (~780k tokens, ~23 % of a run; ~25 min CI per sequential merge). 2 reconciles, below threshold. KEEP_AS_INFO.
- **Prune-candidates weekly** — carried 09-27/09-28 as unverified; verified OK 09-28 (run 36489660080, streak 0; report #3014). RESOLVED — #2847 can close.

## Tracks without owner (P4)

None. No track created in the last 14 days; every non-MERGED row has an owner. PASS.

## Recurring discussion topics (P5)

`dev/decisions.md` — 0 entries in 30 days, last modified 2026-05-15 (**142 days**). P5 unrunnable as specified. recommend: ESCALATE_TO_MAINTAINER (4th ask — retire it or revive it). Scanning the live channel (handoffs, ledger, experiment writeups):

- **Split / adjustment correctness** — now the most-touched cross-cutting topic: #2982/#2996 (adjusted MA in the stop), #2987 (split corpus), #3071 (split-safe floor), #3105 (split detector), #3108 (tickets on split), #3075 (late stop on a rested ticket). Six PRs across four tracks, no owner. recommend: RECOMMEND_NEW_TRACK or re-home under `weekly-snapshot` M6.4 (3rd ask).
- **Recovery / re-entry gap after macro-gate reopens** — entry-anchor-recovery (#3091, "dilutes 6/6; no phase 2"), the gate-reopen review-pack signal (#3086), the selection-2025 screen (#3107, no-build), macro-suspend pre-registration (branch, 10-03). Four items in one week, each correctly calibrated as no-build/screen; the topic is converging, not looping. KEEP_AS_INFO.
- **Record-of-record re-basing** — 26y investor preset (#3048, #3068, #3070 correction), trader presets (#3061, #3081), investor-vs-hybrid V6-clean rerun (#3036). `dev/backtest/DEEP_RESULTS.md` last touched 2026-07-29 (**67 days**). recommend: RECOMMEND_NEW_TRACK (`record-of-record`). 4th ask.
- **Book write-back loop** fired twice (#3040 trader MA, #3099 continuation-buy stop). KEEP_AS_INFO — working as designed.

## Diminishing returns (P6)

**Mechanical heuristic: 0 flags.** Last 5 PRs: `harness` (#3112, #3096, #3086, #3088, #3080) — 0 keyword hits; `cleanup` (#3094, #3078, #3064, #3059, #3049) — 0 hits on the specified keywords (subjects are `cleanup(...)`/`refactor(...)`, maintenance by charter); `support-floor-stops` (#3073, #3071, #3052, #3042, #2997) — 0 hits. PASS.

Qualitative: `fix` rose to 17 of 98 PRs, but they are defect fixes found by the new validators and review-pack look (#3075, #3089, #3020), i.e. new correctness surface, not churn. KEEP_AS_INFO.

## Capability gaps (P7)

- **[NEW] Short side has no live path.** #3110: 0 fills in 5d under faithful gates; prior reserved-sleeve and deep-short screens lost on broad. Mentioned in: `short-side-strategy`, priorities 10-03 §4(d). Milestone: M7 (bear-market behaviour). Status: liveness failed. recommend: ESCALATE_TO_MAINTAINER — decide whether the track closes (REJECT-as-default/keep-as-axis) or gets a diagnostic of *which* gate blocks every short.
- **[NEW] No reconcile path for the cloud/local merge rate.** ~25 merges since the last index reconcile (10-02); 6 tracks shipped without a status-file touch. Mentioned in: `_index.md`, P2 above. recommend: KEEP_AS_INFO — the per-PR "update your track file" contract is not holding at this throughput.
- **M6.4 split/dividend verification harness** — carried; six split-class PRs landed this week (P5) with no owning track. Milestone: M6. recommend: ESCALATE_TO_MAINTAINER. 4th cycle.
- **Weekly live-picks run — 51 days stale, 7 consecutive Fridays missed** (08-21 … 10-02). Newest record `dev/weekly-picks/f88c277d5/2026-08-14.*`. Mentioned in: `weekly-snapshot`, `arc-readiness`, `decision-audit`. Milestone: M6. recommend: ESCALATE_TO_MAINTAINER. 7th cycle.
- **Promoted bundle margin uncertified** (`DEEP_RESULTS.md` 67 days; #2047 default-on) — now additionally exposed to the #2996 stop flags if any flips. recommend: ESCALATE_TO_MAINTAINER. 10th cycle.
- **`tuning` M2 enable-commit (#1327) — 131 days.** Milestone: M7. ESCALATE_TO_MAINTAINER. 11th ask.
- **`sweep-perf` ghcr.io flambda rebuild — 113 days**; `-O3` a silent no-op in CI. ESCALATE_TO_MAINTAINER. 10th ask.
- **`arc-readiness` A2-4** (picks chart, plan #2453) — 44 days behind plan; dispatchable. KEEP_AS_INFO.

Resolved since last report: **five unbuilt write-only branches** (all merged, #2986–#2996); **#2982 stop-basis fix** (landed default-off as `stop_ma_same_basis`, #2996; validators V19–V23 now guard the class); **prune-candidates-weekly** (verified 09-28, run 36489660080).

Follow-up accumulation: **69** open `- [ ]` items in `dev/status/` (down from 79), driven by `cleanup` closing four file-length rows. KEEP_AS_INFO.

## Recommendations
1. **Run an index + status reconcile now.** Refresh `post-run-validation`, `rename-twin-dedup`, `simulation`, `short-side-strategy` (4 files that shipped this week unrecorded) and fix the 3 status mismatches (`trade-audit`, `post-run-validation`, `tax-lens`) and 3 stale rows (`backtest-infra`, `support-floor-stops`, `backtest-perf`). One docs-only PR.
2. **Decide `short-side-strategy` on the #3110 result**: close as keep-as-axis, or scope one diagnostic of which gate blocks every short. Do not let it re-stall.
3. **Check whether 10-03's two orchestrator runs lost their summary** (37123376327, $14.95). If yes, #3063 did not close the class.
4. **Assign M6.4 an owner and link #2987, #3071, #3105, #3108 to it** — the split/adjustment class is now the busiest unowned topic. 4th ask.
5. **Unblock the two one-action human gates**: `tuning` #1327 (131 days) and the `sweep-perf` flambda rebuild (113 days).
6. **Decide the weekly picks cadence**: automate or de-scope M6.6. 51 days, 7 Fridays missed.
7. **Spawn a `record-of-record` track, or explicitly refuse to.** `DEEP_RESULTS.md` 67 days. 4th ask.
8. **Close or re-scope the parked tracks**: `tuning-methods` (133 days, never shipped), `spy-only-reference` (123 days), `margin-realism` (no successor), `experiment-platform` (code idle 33+ days; ledger fine).
9. **Open the PR for `experiments/macro-suspend`** (pre-registered 10-03) once its chain lands, and close #2847 (prune fix verified).
10. **Retire or revive `dev/decisions.md`** (142 days empty). 4th ask.

## Stats
- **98 PRs merged in last 7d** (20 `ops`, 17 `fix`, 15 `harness`, 14 `feat`, 8 `experiments`, 7 `docs`, 7 `cleanup`, 3 `test`, 2 `status`, 2 `results`, 2 `refactor`, 1 `perf`) — **59 (60 %) code-bearing**, up from 44 %
- **357 PRs merged in last 30d** (96 `docs`, 76 `ops`, 50 `harness`, 42 `fix`, 41 `feat`, 22 `exp`/`experiments`, 10 `cleanup`, 6 `test`, 4 `chore`, 3 `refactor`, other 7)
- 14 tracks active / 2 slowing / 11 stalled out of 27 non-MERGED rows (vs 9 / 4 / 14 last cycle); `data-foundations`, `post-run-validation`, `trade-audit`, `rename-twin-dedup`, `short-side-strategy`, `arc-readiness` moved up
- 1 `[info]` item carried ≥3 reconciles (orchestrator summary loss) — first non-zero week in 13
- **14 orchestrator budget records 09-27 … 10-03, $197.12 total** (vs $410.86 last week); 8 `dev/daily/` summaries (no summary for 09-29 or 10-03)
- Weekly deep health scan ran 2026-09-28 (#3013); prune-candidates 09-28 OK (#3014); weekly-start sweep 09-30 (#3047)
- Experiment ledger: 1 new entry this week (`2026-10-02-continuation-buys-trader-rerun`); 10 in 30d. Results PRs: #3016, #3036, #3061, #3068/#3070, #3081, #3091, #3107, #3110
- Newest `dev/weekly-picks/` record **51 days** old; `DEEP_RESULTS.md` **67 days**; `dev/decisions.md` **142 days**
- **69** open `- [ ]` follow-ups in `dev/status/` (down from 79)
- 1 open PR known (#3113, harness, rework iteration 1); 1 pre-registered branch without PR (`experiments/macro-suspend`)
- 8 capability gaps flagged (2 new); 3 resolved
- **Method note:** `gh` unavailable in this environment; PR facts from merge-commit subjects on `main`, open-branch facts from `origin/*` refs and the 10-03 handoff. Window 2026-09-27 → 2026-10-04 (main at `3bf05429c`).

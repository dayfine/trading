# Next-session priorities (2026-05-17) — Phase 1 + Phase 2 complete; Phase 3 ready

Supersedes `dev/notes/next-session-priorities-2026-05-16.md`. Written
end-of-session 2026-05-16 after the 25-PR push (#1098-#1124) landed the
full IWV scraper stack, the walk-forward CV harness, short-side margin
Phase 1+2, the Bayesian Phase 3 plan-first PR, and several CI / tech-
debt fixes.

## TL;DR

- **P0 Phase 1 — universe extension: TOOLING COMPLETE.** The IWV scraper
  stack (PR-A through PR-D) is merged. All four pieces — holdings client
  / membership replay / fetch-history CLI / build-universe CLI — are on
  main. Next step is **operational**, not a feature PR: run the actual
  ~3-hour IWV backfill against ishares.com to produce
  `data/cache/iwv/*.csv` and emit the
  `russell-3000-2006-2026.sexp` fixture. This belongs to an `ops-data`
  session, not `feat-data`.
- **P0 Phase 2 — walk-forward CV harness: COMPLETE.** PR #1100 (first
  PR), PR #1111 (PR-A: Explicit folds + structured aggregate), PR #1116
  (PR-B: multi-metric sensitivity + CAGR + fixture sexps) all merged.
  The harness is ready to be the evaluator surface for Bayesian Phase 3.
- **P0 Phase 3 — Bayesian multi-parameter scaling: PLAN-FIRST LANDED.**
  PR #1124 shipped `dev/plans/bayesian-multi-param-scaling-2026-05-16.md`
  (5-PR stack: scoring → knob inventory → walk-forward integration →
  encoding / GP tuning → end-to-end runner). Ready to dispatch PR-A.
- **P1 sector concentration cap: MERGED** (PR #1098, session start).
- **P1 short-side margin Phase 1 + Phase 2: MERGED** (PR #1113 with the
  PR #1115 file-length fix-forward; simulator wiring in PR #1119). Phase
  3 (Stage A bear-window validation) is the next short-side step but is
  gated on an ops-data session — needs to run shorts on the 3 bear
  windows (2000-2002, 2008-2009, 2020-Q1 + 2022) against pinned scenarios
  to compare bottom-line metrics with margin on vs off.
- **Tech debt — simulator NAV fallback: MERGED** (PR #1123). The silent
  current-cash substitution is gone; pricing failures now mark with the
  last-known cost-basis price and surface a structured warning. Removes
  the corruption that `memory/project_simulator_nav_fallback_bug.md`
  flagged.
- **CI infra — race fix + cache hardening: MERGED** (PR #1117
  `no_python_check.sh` sandbox race-proof prune; PR #1121 remove cache
  `restore-keys` to prevent stale-binary corruption). If new races
  surface, `memory/feedback_pr_merge_ci_gate.md` §"narrow exception"
  documents the merge-with-admin-flag pattern for infra flakes — but
  these two PRs eliminate the most common failure modes.

## Next priorities (in dispatch order)

### P0a — Run the actual IWV scrape (ops-data, ~3-hour wall-clock)

The scraper stack is in place. What's missing is the data.

```
dune exec analysis/data/sources/ishares/bin/fetch_iwv_history.exe -- \
  --cache-dir dev/data/ishares/iwv \
  --start 2006-09-29 --end 2026-05-16 \
  --cadence auto --polite-spacing 2.0
```

Then:

```
dune exec analysis/data/sources/ishares/bin/build_iwv_universe.exe -- \
  --cache-root dev/data/ishares/iwv \
  --output trading/test_data/goldens-russell-3000-historical/russell-3000-2006-2026.sexp \
  --start 2006-09-29 --end 2026-05-16
```

Owner: `ops-data` (operational fetch, not feature work). Ship the
emitted sexp + a manifest fingerprint. The CSV cache itself is
gitignored under `dev/data/ishares/iwv/` per
`memory/project_broad_universe_semantics.md` and PR-A's `.gitignore`
entry.

### P0b — Bayesian Phase 3 PR-A (~200 LOC, ~2 hours)

Per `dev/plans/bayesian-multi-param-scaling-2026-05-16.md` §7 PR-A.
Adds:

- `trading/trading/backtest/tuner/bin/bayesian_runner_scoring.{ml,mli}`
  — pure scoring function. Input = `parameters` + walk-forward
  aggregate + baseline aggregate. Output = float.
- ~12 unit tests on synthetic aggregates pinning the MaxDD-hinge,
  gate-penalty, and excess-improvement terms.

Pure addition; testable in isolation (consumes a pre-computed
aggregate, no backtest invocation). Plan §3 has the formula.

Owner: `feat-backtest`.

### P0c — Survivorship-correct re-pin of `sp500-2010-2026.sexp` baseline

**Gated on P0a.** Once `russell-3000-2006-2026.sexp` exists, re-pin
the 16y backtest baseline against the IWV-derived universe. The new
baseline numbers will differ from today's 510-symbol baseline
(Russell 3000 is wider and survivorship-correct) — this is a fresh
sign-off, not a like-for-like comparison.

Owner: `feat-backtest` (re-pin) + `ops-data` (run the actual sweep).

## P1 priorities (continuing)

### Margin Phase 3 — Stage A bear-window validation (~ops session)

Plan: `dev/plans/short-side-margin-2026-05-13.md` §Stage A. Phase 1
(#1113) + Phase 2 (#1119) merged. Phase 3 is a validation pass — run
shorts on 3 bear windows (2000-2002, 2008-2009, 2020-Q1 + 2022) with
`margin_config.enabled = true` and compare bottom-line metrics
(total return, MaxDD, force-cover count, accrued borrow fee) against
the flag-off baseline. Hypothesis: realistic margin makes shorts
strictly negative-EV at the current Stage-4 entry edge.

Owner: `ops-data` (run the sweep) → `feat-weinstein` (interpret +
decide tuning vs. retirement of the short-side path).

### Margin Phase 4-5 — long-short combined (~deferred until Phase 3)

Plan §Stage B (4) and §Stage C (5). Gated on the Phase 3 results.

### Sector concentration cap follow-on

The cap is in (#1098). Optimizer integration happens naturally via
Bayesian Phase 3 PR-B (knob inventory) — `max_sector_exposure_pct`
will be one of the sentinel-encoded Option knobs (plan §7 PR-D).

## P2 / defer (unchanged from 2026-05-15/2026-05-16)

- Synthetic data with proper statistical attributes — deferred. Synth-
  v1/v2/v3 (PRs #755 / #775 / #1028) are enough for unit testing.
- More single-axis sweeps under Cell E — REJECTED. See
  `memory/project_m5-5-tuning-exhausted.md` and
  `memory/project_continuation_combined_rejected.md`.
- Hand-tuned Cell F variants — REJECTED. Pass to Phase 3 BO.
- fja05680 1996-1999 SP500 tail seed — deferred per the broader-first
  pivot. 20y × Russell 3000 is the load-bearing horizon.

## CI infra status (post 25-PR push)

- **`no_python_check.sh` sandbox race** — fixed (#1117). The check
  now prunes against `dune` sandbox cleanup deterministically.
- **GHA cache `restore-keys` corruption** — fixed (#1121). Cache hits
  now require an exact key match; stale binaries can no longer be
  resurrected across rebuilds.
- **Admin-merge override** — main has admin-merges tonight on infra
  flakes (`memory/feedback_cleanup_local_lint_then_merge.md`); QC is
  the meaningful signal for those merges. New sessions should not
  treat tonight's main-CI history as a precedent for routine merges.

## What landed tonight (PRs #1098-#1124, 25 PRs)

Track 1 — data foundations P0 (IWV scraper stack + supporting docs):
- **#1101** — Phase 1.1 sp500-1996 blocker findings (Wikipedia
  insufficient pre-2010)
- **#1103** — broad-3000-2010-01-01 cohort + picker CLI (sectors.csv
  proxy, supersedes by 1.4)
- **#1104** — tighten broad-3000 cardinality pin to 3000
- **#1105** — vendor pivot Norgate retired
- **#1106** — Phase 1.1 EODHD Fundamentals tier verification FAIL
- **#1108** — Phase 1.4 IWV URL probe findings
- **#1109** — Phase 1.4 iShares IWV holdings scraper plan
- **#1110** — Option B pivot doc
- **#1112** — IWV holdings client (PR-A of 4)
- **#1118** — IWV membership replay (PR-B of 4)
- **#1120** — `fetch_iwv_history.exe` (PR-C of 4)
- **#1122** — `build_iwv_universe.exe` (PR-D of 4) — completes the
  scraper

Track 2 — walk-forward CV P0:
- **#1100** — walk-forward CV harness first PR
- **#1107** — Phase 2.2 plan (rolling 30-fold extension)
- **#1111** — Phase 2.2 PR-A (Explicit fold spec + structured aggregate)
- **#1116** — Phase 2.2 PR-B (multi-metric sensitivity + CAGR +
  fixture sexps)

Track 3 — short-side margin P1:
- **#1113** — Phase 1 Reg-T collateral + borrow fee
- **#1115** — Phase 1 fix-forward (extract margin logic to
  `portfolio_margin` to satisfy file-length linter)
- **#1119** — Phase 2 simulator wiring (daily borrow accrual +
  maintenance force-cover)

Track 4 — sector cap P1:
- **#1098** — sector concentration cap (P1)

Track 5 — CI infra:
- **#1117** — `no_python_check.sh` sandbox race-proof prune
- **#1121** — remove cache `restore-keys` to prevent stale-binary
  corruption

Track 6 — tech debt:
- **#1123** — simulator NAV fallback fail-loud

Track 7 — Bayesian Phase 3:
- **#1124** — multi-parameter optimizer scaling plan-first

Ops:
- **#1093** — daily orchestrator summary 2026-05-14 run-2
- **#1099** — daily orchestrator summary 2026-05-15

## Carry-forward in-flight (none)

All 25 PRs merged. Nothing in flight at session end.

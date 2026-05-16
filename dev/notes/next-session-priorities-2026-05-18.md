# Next-session priorities (2026-05-18)

Supersedes `dev/notes/next-session-priorities-2026-05-17.md`. Written
end-of-session 2026-05-16 PM after the autonomous recovery from a
~14-hour red-main incident + 5 PRs landed.

## TL;DR

- **Main CI was red for 14h.** Root cause was a docker-image rebuild on
  2026-05-15 18:54Z (triggered by the new `ishares.opam` from PR #1112)
  on a runner with AVX-512, baking AVX-512 instructions into
  `libta-lib.so`. Most GHA `ubuntu-latest` runners lack AVX-512 →
  SIGILL on every ta_ocaml-linked test. PR #1130 fixed it with
  `-march=x86-64-v2 -mtune=generic` + a CPU-flag smoke step. Watchdog
  issue #1114 fired 12 times before action; full timeline +
  process-level lessons in updated memory files.
- **5 PRs merged this session**: #1128 (nesting fix), #1130 (image
  rebuild), #1126 (Bayesian Phase 3 PR-A scoring), #1131 (IWV
  browser headers + 503 retry), #1132 (Bayesian Phase 3 PR-B knob
  inventory).
- **2 issues closed**: #1114 (watchdog), #1129 (SIGILL infra).
- **3 memory files updated** with stricter merge / session-rampup rules
  to prevent recurrence.

## What shipped 2026-05-16 PM (this session)

| PR | Track | Summary | Notes |
|---|---|---|---|
| #1128 | tech-debt | `_fail_loud_on_missing_mark` extraction | Fixes nesting linter on `portfolio_valuation.compute` (was 3.03, limit 3.0). |
| #1130 | CI infra | TA-Lib portable rebuild + smoke step | `-march=x86-64-v2 -mtune=generic`; admin-merged as `[main-fix]` per memory exception. Smoke step had two iterative fixes (pipefail / fs-search). |
| #1126 | tuning (P0b) | Bayesian Phase 3 PR-A scoring function | Already had QC APPROVED pre-rebase; rebased + verified + autonomous-merged. |
| #1131 | data (P0a code) | IWV fetcher browser headers + 503/429 retry | qc-structural + behavioral both APPROVED quality 5; CI green after image rebuild; autonomous-merged. |
| #1132 | tuning (P0b PR-B) | Bayesian Phase 3 knob inventory + spec | qc-structural + behavioral APPROVED quality 4; CI green after rebase; autonomous-merged. |

## Still pending (carried forward)

### P0a — IWV ops scrape (BLOCKED on Akamai 503)

- PR #1131 ships the *code* (browser headers + 503/429 retry, mock-fetcher
  retry tests). What's missing is the *data*.
- **Blocker**: my local egress IP is in Akamai cooldown (1-24h block
  window per their docs). 4 cooldown probes between 10:34Z and ~14Z
  all returned 503. Scheduled probes continue at +1h intervals; if
  probe 4 (~17:30Z) still 503, give up local path tonight.
- Full diagnosis + alternative path in
  `dev/notes/iwv-scrape-akamai-block-2026-05-16.md`.
- **Alternative**: run scrape from a GHA runner (different egress IP,
  not flagged). ~40 LOC manual workflow_dispatch yaml. Recommended
  for next session if local IP stays blocked.

### P0b PR-C/D/E — Bayesian Phase 3 stack continuation

Plan: `dev/plans/bayesian-multi-param-scaling-2026-05-16.md`.

- **PR-C** (~400 LOC) — walk-forward in-process integration:
  pull per-fold execution out of `walk_forward_runner.ml` into a
  library, rewrite `bayesian_runner_evaluator` to call it per BO
  iteration. **Next dispatch.**
- **PR-D** (~250 LOC) — int/Option encoding + GP length-scale
  tuning + early-stop.
- **PR-E** (~300 LOC) — end-to-end runner + result reporter +
  OOS holdout.

### P0c — Survivorship-correct re-pin (gated on P0a data)

Unchanged from priorities-2026-05-17 doc. Once
`russell-3000-2006-2026.sexp` exists, re-pin
`goldens-sp500-historical/sp500-2010-2026.sexp` against the
IWV-derived cohort. Authority: PR #1076's survivorship-bias
hypothesis.

### P1 — Margin Phase 3 bear-window validation (unchanged)

Per `dev/plans/short-side-margin-2026-05-13.md` §Stage A. Phase 1+2
merged in prior session; Phase 3 needs ops-data sweep on 3 bear
windows (2000-2002, 2008-2009, 2020-Q1 + 2022). Gated on having
universe data covering those windows — depends on P0a completing.

## CI infra hardening (memory updates this session)

Two new memory rules + index entry in `~/.claude/projects/.../memory/`:

1. `feedback_session_rampup_check_main_ci.md` — **NEW**. Step 0 of every
   session: `gh run list --branch main --limit 3 --json conclusion`. If
   red, fix first.
2. `feedback_pr_merge_ci_gate.md` — **UPDATED** with two HARD STOP
   sections:
   - Any `^FAIL:` line in CI log → never an infra flake.
   - Main must be green before merging the next PR (only fix-forward
     `[main-fix]` PRs may merge on red main).
3. `feedback_cleanup_local_lint_then_merge.md` — **UPDATED** with the
   same two HARD STOP preconditions.
4. `feedback_no_pr_merging.md` — **UPDATED** to explicitly drop
   `--admin` from the default merge command. `--admin` is the narrow
   `[main-fix]` exception only.

These were motivated by the 14-hour red-main incident where 12 PRs
piled on a red main before anyone caught it.

## Recommended sequencing for next session

1. **Step 0 (always):** `gh run list --branch main --limit 3` — verify
   green. If red, fix first.
2. **Akamai probe** if blocker still open per
   `dev/notes/iwv-scrape-akamai-block-2026-05-16.md`. If unblocked
   (>=24h elapsed by then) → kick off full IWV backfill in background.
3. **Dispatch feat-backtest on Bayesian Phase 3 PR-C** — walk-forward
   in-process integration. Largest PR in the stack at ~400 LOC.
   Independent of IWV scrape outcome.
4. **If IWV backfill succeeds**: P0c re-pin (survivorship-correct
   baseline).
5. **If IWV backfill still blocked after >=24h**: implement GHA-runner
   scrape workflow per `iwv-scrape-akamai-block-2026-05-16.md` §
   alternative.

## Open follow-ups

- Watchdog issue #1114 (closed) had cc @dayfine 12 times — consider
  adding a paging mechanism (Slack? Email?) so future red-main
  incidents surface within the same hour, not 14 hours later.
- PR #1130's smoke step had two bugs (pipefail on empty grep, then
  wrong lib path) that needed iterative fixing under fire. Worth
  hardening the smoke-step pattern as a `dev/scripts/check_ta_lib_isa.sh`
  for re-use + unit testing.

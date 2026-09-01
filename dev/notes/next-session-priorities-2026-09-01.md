# Next-session priorities — 2026-09-01 (post issue-burn-down session 08-31 evening)

Supersedes `next-session-priorities-2026-08-31.md` (whose P0 — the clock-52
decision — is RESOLVED: USER kept 52, ledger amended #2611).

## P0 — read the #2408 stop-anchor surface

An 11-arm chain was LAUNCHED 2026-08-31 20:55 PT and should finish ~03:30-04:30
PT: `stop_anchor_at_entry_base` {false,true} × `initial_stop_buffer`
{1.0, 0.98, 0.96, 0.92, 0.885} + duplicate null, salt 0, broad5y cell-B base
(record-convention — REQUIRED, the anchor flag is a structural no-op on the
shipped default path). Everything you need:

- `dev/experiments/stop-anchor-surface-2026-08-31/README.md` — design, the
  post-08-24 buffer semantics table (widths 4/5.9/7.8/11.7/15%), and the FOUR
  read-before-verdict obligations (fat-tail decomposition; #2389 blind-judge
  question BEFORE any promotion reading; salt-0-only caveat; never compare to
  CSV-basis numbers).
- Chain log `/tmp/sa2408-chain.log`; artifacts `/tmp/sweeps/sa2408/` (per-arm
  actual/trades/params) → commit under `results/` with the writeup.
- Specs+chain committed on branch `wip/sa2408-specs` (pushed, NO PR — bundle
  specs+results+writeup into one PR).
- Duplicate-null spread (sa-off-b1.0 vs sa-null-dup) IS the same-cell noise
  floor — read it first.
- Pinned run tree `.claude/worktrees/sweep-sa2408` @ `3a726edfa` — remove after
  results are archived. Disk was 16GB free at launch (guard aborts <6GB).

## P1 — post-merge validation watches

1. **Soak graduation (#2615)**: first post-merge runs of golden-runs-custom-universe
   (next main push) and golden-runs-sp500-15y (cron 09:00 UTC) now FAIL LOUDLY on
   breach (continue-on-error false, 15y cap 300 min / 7200s per cell). A red run
   = real signal, act on it.
2. **SC2012 rewrites (#2619)**: same runs exercise the find-based newest-file
   pattern in six workflows. Differentially tested pre-merge; still watch the
   first live pass.

## P2 — new mechanical issues filed this session

- **#2620** — pr_gate_status.sh counted a section heading INSIDE a structural
  review as the behavioral verdict (live false-MERGE on #2619, caught manually).
  Fix = attribute verdicts by the review's FIRST H1 only + regression fixture.
  Small, high-value (it guards the merge loop).
- **#2618** — four workflow-cap residuals from #2615's QC (custom-universe
  no-summary branch lacks exit 1 = silent-green path; its 90-min/60-min cap
  inversion; 15y comment provenance inversion — no 15y cell has EVER been
  measured with --no-emit-all-eligible active; invariant prose imprecision).
  One config PR discharges all four.

## Issue tracker state after this session

Closed: #2547 #2588 #2403 #2606 #2607 (+#2405-family fully settled earlier).
Open P1s remaining: #2489 (representative-trade audit, ASKABLE + container),
#2408 (in flight — P0 above). #2539 shrunk to orchestrator.yml only
(SC2012+SC2086+SC2010; needs orchestrator-run validation window).
#2404 value unification is still the standing ASKABLE user decision.

## Merged this session (all full-gate unless docs-only)

#2612 (docs reconcile), #2613 (ci.yml fmt-before-runtest — #2588 remedy 1),
#2614 (#2382 asymmetry docstrings), #2615 (soak graduation + timeout coherence,
1 rework), #2616 (wall-span fix, RED-verified), #2617 (bold-SHA extractor,
RED/GREEN 70/70), #2619 (SC2012 six workflows, differential-tested).

## Durable lessons (in memory)

- QC caught a real coherence bug pre-merge (#2615 job-cap vs per-cell timeout)
  AND a false-green parser hazard (#2620) in one session — the gate loop is
  earning its cost.
- jj working-copy snapshots can lose a race with concurrent agent workspace
  churn: the #2408 specs commit came up EMPTY after 13 files were "removed" by
  a jj new; regenerate-and-verify (`jj diff -r @ --stat` non-empty) before
  trusting any commit made amid agent activity.

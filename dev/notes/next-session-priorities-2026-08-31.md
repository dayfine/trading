# Next-session priorities — 2026-08-31 (post clock-52 promotion + overnight burn-down)

Supersedes `next-session-priorities-2026-08-27.md`. Written at the close of
the 08-30/31 overnight session (user-directed "find 12h of work" run).

## P0 — the clock-52 default decision (ASKABLE, blocks nothing)

`entry_order_max_rest_weeks=52` was promoted (#2587) on a grid whose one
composition-independent cell had no null. The D-null now exists
(#2600 → PR #2610, `d-null-2026-08-31.md`): paired Δreturn at top-1000 =
**−39 / −395 / −310pp** across salts — value-52 fails
promotion-confirmation's "never badly dominated" rule **on return** (it
still wins maxDD on all three salts — not Pareto-dominated); only maxDD
is composition-robust. **Safe to defer** — the #2587 paired-golden table
MEASURED the default-path blast radius as empty (the clock predicate runs
on every default tick but finds nothing: trigger-at-close tickets fill
within a bar and never rest 52w; empirical over the golden set, not a
structural guarantee) — but every future trigger-at-E / record-convention
experiment inherits the contested value.
Options (writeup §Verdict implication): revert to 0 / keep 52 documented /
keep 52 + require record-convention specs to pin the knob. Amend the
ledger entry with the D-null table whichever way. Also worth queuing: the
trade-level join across the six D arms to test the shallow-pool-monster
mechanism hypothesis.

## State at session close (2026-08-31 ~10:45 PT)

- Main GREEN throughout; **zero open PRs except #2610** (D-null evidence,
  CI running at close — merge after QC pair; docs+script+artifacts).
- Merged this session: **#2587** (clock 0→52, 1 rework), **#2601**
  (E-anchored broad golden, 1 rework), **#2602** (fmt_check was a
  PERMANENT silent no-op — the fmt gate is real for the first time),
  **#2603** (QC-audit sha restored), **#2605** (mechanical fast-exit gate,
  1 rework — fail-closed curl + git-timestamp drift).
- Issues closed: #2405 #2440 #2556 #2576 #2579 #2591 #2598 (+#2600 closes
  with #2610). Filed: #2606 (wall-span excludes post-steps — mechanism
  CORRECTED in comments, read them before building), #2607 (bold
  `**Reviewed SHA:**` defeats the audit sha extractor + F1 comment fix).
- Deferred with rationale: #2539 (SC-code burn-down needs live-GHA
  validation; daytime + canary), #2547 (40/40 green observed — close
  after one more window).

## Durable lessons this session (already in memory)

- **The clock binds only behind trigger-at-E arming** — default-path
  blast radius empty by construction; 11/12 goldens bit-identical.
- **Warehouse vs committed-CSV basis gap is ~54pp** on a 5y broad book
  (25.31% vs 79.2%, identical config/salt/build) — never compare across
  bases (`weinstein-2019-armed-e.sexp` header carries the warning).
- **Postsubmit goldens no longer run the all_eligible diagnostic**
  (#2601 rework): golden-runs walls drop ~an order of magnitude; the 15y
  workflow's 600-min cap is now stale — retighten after one post-change
  run (noted on #2606).
- Book §4.7 GTC-cancel = pattern change + discretion, never time
  (tier-2 VERIFIED, written back).

## Follow-ups (GHA-eligible, [non-blocking] unless noted)

1. #2607 — bold-SHA extractor fix + dune-comment F1 (small, mechanical).
2. #2606 — wall-span enforcement (read the CORRECTED mechanism in
   comments; the band comparison already exists, the measured span is
   what's wrong) + retighten golden-runs-sp500-15y timeout-minutes.
3. #2547 — one more 40-run observation window, then close.
4. Ledger amendment for `2026-08-27-entry-rest-weeks-surface.sexp` with
   the D-null table (fold into the P0 decision PR).

## Parked arcs (unchanged from 08-27)

#2489 (ASKABLE), #2403 residual, #2567, #2382, #2394, #2539, #2408
(container-exclusive research surface), P4s (#2407 #2409 #2006 #2406),
#1729 — NOTE: the 54pp basis-gap measurement makes #1729 (complete data
for broad/custom goldens) materially more urgent than its P3 label.

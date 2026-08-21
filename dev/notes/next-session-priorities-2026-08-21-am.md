# Next-session priorities — 2026-08-21 AM

Supersedes `next-session-priorities-2026-08-19-pm.md` and the 08-20 evening
framing. Written at the end of the overnight session that closed the user's
three stated goals (faithful combination → picks → 26y).

## What landed overnight (all through full gates)

- **#2452** — the arc-faithful bundle, now **four** overrides: rt + anchor 4 +
  E-anchored StopLimit 2pp + volume-at-fill + `initial_stop_buffer 1.0`.
- **#2455** — 6-arm trade-inspection harness (2019H1, top-3000), the ADP
  fallback-stop canonical test (`test_fallback_stop_width.ml`), the dissection
  record, committed per-arm artifacts, book-reference §4.2 upgrade
  SECONDARY→PRIMARY-VERIFIED.
- **#2459** — corrected-bundle 26y record (−62.4%) with the anatomy and
  null-discipline framing. #2453/#2454 docs merged earlier.

## The three load-bearing findings

1. **Fallback initial stop was 2.08% — half the book §5.3 band — on the
   COMMON path** (`project_fallback_stop_half_book_band`). Zero-code fix
   (`initial_stop_buffer 1.0`) verified exactly (0.0208 → 0.0400) and armed in
   the bundle. **OPEN USER DECISION: the global default flip** (1.02 → 1.0)
   moves every fallback-path golden and breaks record-baseline comparability.
2. **The volume eject is FAITHFUL — §4.2's own sell rule** — my initial
   "wrong basis" claim was retracted after the primary book read. At 26y it
   ejects 72% of entries; the faithful bundle loses −62.4% while the non-book
   record convention makes +287%. "Faithful and profitable diverge" is now
   quantified at scale (`project_arc_faithful_costs_the_tail_at_scale`).
3. **Null discipline held:** the −40.1 → −62.4 intra-bundle delta (22pp) is
   inside the 132.5pp 26y floor — NOT a stop-fix effect claim. The corrected
   run also moved `data_dir` (AD-breadth reads from the live store), one more
   non-claimability axis.

## P0 — funding trio (the arc's only feature hole)

Tasks #6/#7/#8/#9: build G2a `entry_fill_reject_retries`, G2b
`entry_fill_size_to_available`, arm G3 in a combined cell, run the internal
three-way grid. Unblocked by the noise floor (internal comparison). The 26y
run showed the starvation live (~$19k free vs ~$139k tickets at 70% deployed).

## Open user decisions

- Global `initial_stop_buffer` default flip (above).
- **#2433** still under `do-not-merge`, both gates stale — task #14 proposes
  reframing as faithfulness-equipped, not perf-promoted.
- `strong_threshold` era-tuning ({1.2, 1.5, 2.0}) is a licensed W2 dial but
  **NOT sweepable today** — `Volume.config` is unreachable from
  `Overlay_validator`; plumbing PR required first (QC catch on #2459).
- Eject-timing dial (book sells into the advance; runner sells next open) —
  recorded in the book reference, not built.

## Compression / hygiene backlog

- #12 delete 84 uncited priorities docs (tool-verified via #2449's
  `prune_candidates.sh`); #13 compress `weinstein_strategy_config.mli`
  docstrings; #10 automate effect-vs-null reporting.
- Stale comment in `fullbook-graded` + arc spec: `entry_order_max_rest_weeks`
  pin cites #2384's 0→26 which #2397 reverted (QC non-blocking note on #2452).
- `dev/experiments/inspect-6mo-2026-08-21/` has `results/` but no committed
  `run.sh` (QC non-blocking note on #2459).

## Process notes for the next session

- QC rework loops ran 2 iterations on both #2455 and #2459, and **every
  iteration's findings were record-accuracy, three of them errors introduced
  by my own corrections** — `feedback_corrections_have_a_base_rate` is the
  operative discipline: scope rework commits to exactly the prescribed edits.
- The cron auto-merges main into open branches (observed on #2455) — a fresh
  tip is not necessarily your push; verify with `git log` before diagnosing.
- Background `run_in_background` watchers were killed twice mid-wait;
  foreground bounded `until` loops with `timeout: 600000` were reliable.

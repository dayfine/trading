# Prune candidates -- 2026-09-14

Verified compression worklist. This report PROPOSES rows for human review;
it deletes nothing. See dev/scripts/prune_candidates.sh header for method.

## Checker 1 -- superseded priorities docs

Newest (kept): `dev/notes/next-session-priorities-2026-09-14.md`

Candidates: 23 files, 2270 total lines (cited-elsewhere and excluded: 23).

| file | lines |
|---|---:|
| dev/notes/next-session-priorities-2026-06-02-PM2.md | 163 |
| dev/notes/next-session-priorities-2026-06-03.md | 132 |
| dev/notes/next-session-priorities-2026-06-21.md | 79 |
| dev/notes/next-session-priorities-2026-06-22-EOD.md | 96 |
| dev/notes/next-session-priorities-2026-06-22.md | 102 |
| dev/notes/next-session-priorities-2026-06-27.md | 153 |
| dev/notes/next-session-priorities-2026-07-08.md | 129 |
| dev/notes/next-session-priorities-2026-08-21-am.md | 72 |
| dev/notes/next-session-priorities-2026-08-22-eod.md | 121 |
| dev/notes/next-session-priorities-2026-08-24-eod.md | 88 |
| dev/notes/next-session-priorities-2026-08-24.md | 59 |
| dev/notes/next-session-priorities-2026-08-25-post-overnight.md | 77 |
| dev/notes/next-session-priorities-2026-08-25.md | 69 |
| dev/notes/next-session-priorities-2026-08-27.md | 84 |
| dev/notes/next-session-priorities-2026-08-31.md | 86 |
| dev/notes/next-session-priorities-2026-09-01.md | 73 |
| dev/notes/next-session-priorities-2026-09-04.md | 146 |
| dev/notes/next-session-priorities-2026-09-05.md | 167 |
| dev/notes/next-session-priorities-2026-09-07.md | 148 |
| dev/notes/next-session-priorities-2026-09-08.md | 32 |
| dev/notes/next-session-priorities-2026-09-09.md | 33 |
| dev/notes/next-session-priorities-2026-09-10.md | 33 |
| dev/notes/next-session-priorities-2026-09-13.md | 128 |

## Checker 2 -- orphaned experiment dirs

Candidates: 11 dirs, 53 total files (uncited AND untouched >= 30 days).

| dir | files | age (days) | last touched |
|---|---:|---:|---|
| dev/experiments/candidate-universe-acceptance-2026-08-13 | 3 | 32 | 2026-08-13 |
| dev/experiments/decision-grading-first-report-2026-06-18 | 3 | 88 | 2026-06-18 |
| dev/experiments/decision-grading-phase5-2026-06-18 | 3 | 88 | 2026-06-18 |
| dev/experiments/diagnostics-fullsize-2026-05-28 | 8 | 109 | 2026-05-28 |
| dev/experiments/fuzz-startdate-canonical-full | 13 | 135 | 2026-05-02 |
| dev/experiments/nearfloor-26y-salts-2026-08-13 | 3 | 32 | 2026-08-13 |
| dev/experiments/p0-screens-2026-06-20 | 11 | 86 | 2026-06-20 |
| dev/experiments/path-seed-salt-distribution-2026-08-12 | 1 | 32 | 2026-08-13 |
| dev/experiments/rolling-start-matrix-t3k-1998-2026 | 3 | 88 | 2026-06-18 |
| dev/experiments/rolling-start-matrix-t3k-2000-2026 | 2 | 89 | 2026-06-17 |
| dev/experiments/rolling-start-matrix-t3k-2011-2026 | 3 | 89 | 2026-06-17 |

## Checker 3 -- Rule-4 flag eligibility

Flags with a ledger REJECT: 12 (eligible: 0, not eligible: 12, needs classification: 0).

| flag | eligibility | total specs | live specs | live .ml assignments |
|---|---|---:|---:|---:|
| catastrophic_stop_pct | NOT ELIGIBLE | 478 | 78 | 0 |
| deteriorating_blocks_longs | NOT ELIGIBLE | 6 | 0 | 1 |
| enable_continuation_buys | NOT ELIGIBLE (classified KEEP-AXIS) | 16 | 0 | 0 |
| enable_entry_ticket_rescreen | NOT ELIGIBLE | 134 | 25 | 0 |
| enable_laggard_rotation | NOT ELIGIBLE | 742 | 171 | 0 |
| enable_late_stage2_stop_tighten | NOT ELIGIBLE (classified KEEP-AXIS) | 7 | 0 | 0 |
| enable_slow_grind_short_gate | NOT ELIGIBLE | 9 | 7 | 1 |
| enable_stage3_force_exit | NOT ELIGIBLE | 756 | 171 | 0 |
| fast_v_arm_on_rate_alone | NOT ELIGIBLE | 18 | 13 | 0 |
| neutral_blocks_longs | NOT ELIGIBLE | 1 | 0 | 1 |
| reject_declining_ma_long_entry | NOT ELIGIBLE | 464 | 70 | 0 |
| virgin_crossing_readmission | NOT ELIGIBLE | 22 | 18 | 2 |


# Prune candidates -- 2026-09-28

Verified compression worklist. This report PROPOSES rows for human review;
it deletes nothing. See dev/scripts/prune_candidates.sh header for method.

## Checker 1 -- superseded priorities docs

Newest (kept): `dev/notes/next-session-priorities-2026-09-27.md`

Candidates: 32 files, 3066 total lines (cited-elsewhere and excluded: 24).

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
| dev/notes/next-session-priorities-2026-09-15.md | 67 |
| dev/notes/next-session-priorities-2026-09-16.md | 95 |
| dev/notes/next-session-priorities-2026-09-17.md | 93 |
| dev/notes/next-session-priorities-2026-09-20.md | 114 |
| dev/notes/next-session-priorities-2026-09-21.md | 61 |
| dev/notes/next-session-priorities-2026-09-22.md | 75 |
| dev/notes/next-session-priorities-2026-09-23.md | 66 |
| dev/notes/next-session-priorities-2026-09-24.md | 154 |
| dev/notes/next-session-priorities-2026-09-26.md | 71 |

## Checker 2 -- orphaned experiment dirs

Candidates: 16 dirs, 109 total files (uncited AND untouched >= 30 days).

| dir | files | age (days) | last touched |
|---|---:|---:|---|
| dev/experiments/candidate-universe-acceptance-2026-08-13 | 3 | 46 | 2026-08-13 |
| dev/experiments/candidate-universe-payoff-2026-08-13 | 7 | 42 | 2026-08-17 |
| dev/experiments/decision-grading-first-report-2026-06-18 | 3 | 102 | 2026-06-18 |
| dev/experiments/decision-grading-phase5-2026-06-18 | 3 | 102 | 2026-06-18 |
| dev/experiments/diagnostics-fullsize-2026-05-28 | 8 | 123 | 2026-05-28 |
| dev/experiments/entry-cap-horizon-2026-08-19 | 6 | 40 | 2026-08-19 |
| dev/experiments/fuzz-startdate-canonical-full | 13 | 149 | 2026-05-02 |
| dev/experiments/ladder-v4-grid-2026-08-15 | 9 | 42 | 2026-08-17 |
| dev/experiments/nearfloor-26y-salts-2026-08-13 | 3 | 46 | 2026-08-13 |
| dev/experiments/p0-screens-2026-06-20 | 11 | 100 | 2026-06-20 |
| dev/experiments/path-seed-salt-distribution-2026-08-12 | 1 | 46 | 2026-08-13 |
| dev/experiments/rep-trade-audit-2026-08-26 | 17 | 33 | 2026-08-26 |
| dev/experiments/rolling-start-matrix-t3k-1998-2026 | 3 | 102 | 2026-06-18 |
| dev/experiments/rolling-start-matrix-t3k-2000-2026 | 2 | 103 | 2026-06-17 |
| dev/experiments/rolling-start-matrix-t3k-2011-2026 | 3 | 103 | 2026-06-17 |
| dev/experiments/rt-freshness-seeded-2026-08-20 | 17 | 37 | 2026-08-22 |

## Checker 3 -- Rule-4 flag eligibility

Flags with a ledger REJECT: 13 (eligible: 0, not eligible: 13, needs classification: 0).

| flag | eligibility | total specs | live specs | live .ml assignments |
|---|---|---:|---:|---:|
| catastrophic_stop_pct | NOT ELIGIBLE | 521 | 79 | 0 |
| deteriorating_blocks_longs | NOT ELIGIBLE | 6 | 0 | 1 |
| enable_continuation_buys | NOT ELIGIBLE (classified KEEP-AXIS) | 16 | 0 | 0 |
| enable_entry_ticket_rescreen | NOT ELIGIBLE | 134 | 25 | 0 |
| enable_laggard_rotation | NOT ELIGIBLE | 786 | 172 | 0 |
| enable_late_stage2_stop_tighten | NOT ELIGIBLE (classified KEEP-AXIS) | 7 | 0 | 0 |
| enable_slow_grind_short_gate | NOT ELIGIBLE | 9 | 7 | 1 |
| enable_stage3_force_exit | NOT ELIGIBLE | 799 | 172 | 0 |
| fast_v_arm_on_rate_alone | NOT ELIGIBLE | 18 | 13 | 0 |
| index_stage_veto_blocks_longs | NOT ELIGIBLE | 6 | 0 | 2 |
| neutral_blocks_longs | NOT ELIGIBLE | 1 | 0 | 1 |
| reject_declining_ma_long_entry | NOT ELIGIBLE | 508 | 71 | 0 |
| virgin_crossing_readmission | NOT ELIGIBLE | 22 | 18 | 2 |


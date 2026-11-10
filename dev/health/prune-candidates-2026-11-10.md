# Prune candidates -- 2026-11-10

Verified compression worklist. This report PROPOSES rows for human review;
it deletes nothing. See dev/scripts/prune_candidates.sh header for method.

## Checker 1 -- superseded priorities docs

Newest (kept): `dev/notes/next-session-priorities-2026-11-08.md`

Candidates: 39 files, 3952 total lines (cited-elsewhere and excluded: 25).

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
| dev/notes/next-session-priorities-2026-09-27.md | 58 |
| dev/notes/next-session-priorities-2026-10-03.md | 479 |
| dev/notes/next-session-priorities-2026-10-04.md | 123 |
| dev/notes/next-session-priorities-2026-10-11.md | 56 |
| dev/notes/next-session-priorities-2026-10-12.md | 62 |
| dev/notes/next-session-priorities-2026-11-02.md | 63 |
| dev/notes/next-session-priorities-2026-11-05.md | 45 |

## Checker 2 -- orphaned experiment dirs

Candidates: 20 dirs, 306 total files (uncited AND untouched >= 30 days).

| dir | files | age (days) | last touched |
|---|---:|---:|---|
| dev/experiments/candidate-universe-acceptance-2026-08-13 | 3 | 89 | 2026-08-13 |
| dev/experiments/candidate-universe-payoff-2026-08-13 | 7 | 85 | 2026-08-17 |
| dev/experiments/decision-grading-first-report-2026-06-18 | 3 | 145 | 2026-06-18 |
| dev/experiments/decision-grading-phase5-2026-06-18 | 3 | 145 | 2026-06-18 |
| dev/experiments/diagnostics-fullsize-2026-05-28 | 8 | 166 | 2026-05-28 |
| dev/experiments/entry-cap-horizon-2026-08-19 | 6 | 83 | 2026-08-19 |
| dev/experiments/fuzz-startdate-canonical-full | 13 | 192 | 2026-05-02 |
| dev/experiments/ladder-v4-grid-2026-08-15 | 9 | 85 | 2026-08-17 |
| dev/experiments/macro-suspend-investor-2026-10-04 | 135 | 37 | 2026-10-04 |
| dev/experiments/nearfloor-26y-salts-2026-08-13 | 3 | 89 | 2026-08-13 |
| dev/experiments/p0-screens-2026-06-20 | 11 | 143 | 2026-06-20 |
| dev/experiments/path-seed-salt-distribution-2026-08-12 | 1 | 89 | 2026-08-13 |
| dev/experiments/rep-trade-audit-2026-08-26 | 17 | 76 | 2026-08-26 |
| dev/experiments/rolling-start-matrix-t3k-1998-2026 | 3 | 145 | 2026-06-18 |
| dev/experiments/rolling-start-matrix-t3k-2000-2026 | 2 | 146 | 2026-06-17 |
| dev/experiments/rolling-start-matrix-t3k-2011-2026 | 3 | 146 | 2026-06-17 |
| dev/experiments/rt-freshness-seeded-2026-08-20 | 17 | 80 | 2026-08-22 |
| dev/experiments/selection-2025-screen-2026-10-03 | 6 | 38 | 2026-10-03 |
| dev/experiments/short-only-liveness-2026-10-04 | 38 | 33 | 2026-10-08 |
| dev/experiments/spy-benchmark-26y-2026-10-04 | 18 | 37 | 2026-10-04 |

## Checker 3 -- Rule-4 flag eligibility

Flags with a ledger REJECT: 16 (eligible: 2, not eligible: 13, needs classification: 1).

| flag | eligibility | total specs | live specs | live .ml assignments |
|---|---|---:|---:|---:|
| catastrophic_stop_pct | NOT ELIGIBLE | 613 | 79 | 0 |
| deteriorating_blocks_longs | NOT ELIGIBLE | 6 | 0 | 1 |
| enable_continuation_buys | NOT ELIGIBLE (classified KEEP-AXIS) | 51 | 0 | 0 |
| enable_entry_ticket_rescreen | NOT ELIGIBLE | 134 | 25 | 0 |
| enable_laggard_rotation | NOT ELIGIBLE | 1126 | 172 | 0 |
| enable_late_stage2_stop_tighten | NOT ELIGIBLE (classified KEEP-AXIS) | 7 | 0 | 0 |
| enable_slow_grind_short_gate | NOT ELIGIBLE | 23 | 7 | 1 |
| enable_stage3_force_exit | NOT ELIGIBLE | 916 | 172 | 0 |
| fast_v_arm_on_rate_alone | NOT ELIGIBLE | 20 | 13 | 0 |
| index_stage_veto_blocks_longs | NOT ELIGIBLE | 6 | 0 | 2 |
| neutral_blocks_longs | NOT ELIGIBLE | 1 | 0 | 1 |
| reject_declining_ma_long_entry | NOT ELIGIBLE | 827 | 71 | 0 |
| share_class_gate_covers_shorts | ELIGIBLE | 9 | 0 | 0 |
| short_cancel_on_non_bearish | NEEDS-CLASSIFICATION | 5 | 0 | 0 |
| short_min_price_on_order_price | ELIGIBLE | 9 | 0 | 0 |
| virgin_crossing_readmission | NOT ELIGIBLE | 22 | 18 | 2 |


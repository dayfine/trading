((date 2026-11-12) (slug post-stop-reentry-screen)
 (hypothesis
  "Follow-up of the entry-timing screen: after every stop_loss exit of the record (k0-k4, ~280 per seed), re-buy with a stop-limit at the highest high made while held x 1.005 for 8, 13 or 26 weeks; stop 0.96 x the shakeout low; 26-week proxy hold; with and without the 15 % stop-width gate. Book: a whipsaw re-buy is acceptable (insurance premium); listed untested in memory project_weekly_close_stop_lever. Proxy screen: may conclude only build or no-build.")
 (base_scenario
  "entry-timing-screen-2026-11-12 run.sh step 4 (lib/reentry.awk GATE 0.15 and 0, lib/rsum.awk, lib/rrobust.awk) over record-kseed-2026-10-27 k0-k4")
 (window_id top3000-pitv12-2000-2026-record-kseed5-trades) (baseline_label record-kseed-actual)
 (variants
  (((label R1-gate15-w13) (config_hash reentry-screen-r1-gate15) (aggregate ()))
   ((label R1-nogate-w13) (config_hash reentry-screen-r1-nogate) (aggregate ()))))
 (verdict Reject)
 (notes
  "NO-BUILD (proxy screen). With the gate: 69-146 re-triggers per seed blocked, 23-37 fills, median trade about -11 %, 4 of 5 seeds negative. Without the gate: +143..+194 NAV-% (5/5) but it is one trade: GME stopped 2020-09-11, re-bought 09-14, +2,684 % on the 26-week hold (+139 NAV-% in k0); minus each seed's top 3 fills +1..+17, minus top 10 negative 5/5, 2000-2012 fills +2..+14; shallow shakeouts (stop within 15 %) re-fail. WHY: recoveries to a new high are not better than average entries once the one squeeze is removed; in a cash-bound book they would displace better tickets. Writeup dev/experiments/entry-timing-screen-2026-11-12/README.md section R1."))

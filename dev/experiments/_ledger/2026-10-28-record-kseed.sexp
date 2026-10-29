((date 2026-10-28) (slug record-kseed)
 (hypothesis
  "Not a mechanism test: the record N config (rb1-26) re-baselined as K = 5 tie-order seeds on the Seeded default (#3425), the remaining [after-merge] item of #3404. Pre-registered in dev/experiments/record-kseed-2026-10-27/README.md at 57eedc3e8: >= 4 seeds included (V6 vs k0 exit 0) -> the K-seed set replaces the single-run record; the band's width is the finding.")
 (base_scenario
  "Run tree fc78391dd (holds #3425 Seeded, #3391 lists md5 51fba79e, #3283, #3339); warehouse /tmp/snap_top3000_pit_v12wk 9,236 entries; top-3000 PIT v12 schedule; 2000-01-01 -> 2026-06-26; path salt 0; tiebreak_seed 0..4. V6 PASS every cell; validator_diff -check V6 k1..k4 vs k0 exit 0. macro_trend byte-identical across seeds.")
 (window_id top3000-pitv12-1999-2025-record-26y-kseed5) (baseline_label record-kseed5)
 (variants
  (((label k0) (config_hash rb1-26-seeded-k0@fc78391dd) (aggregate (((mean_sharpe 0.6059) (mean_calmar 0.4009) (mean_return_pct 1312.79) (mean_max_drawdown_pct 26.23)))))
   ((label k1) (config_hash rb1-26-seeded-k1@fc78391dd) (aggregate (((mean_sharpe 0.7258) (mean_calmar 0.5216) (mean_return_pct 2218.82) (mean_max_drawdown_pct 24.16)))))
   ((label k2) (config_hash rb1-26-seeded-k2@fc78391dd) (aggregate (((mean_sharpe 0.6317) (mean_calmar 0.3453) (mean_return_pct 1515.03) (mean_max_drawdown_pct 32.08)))))
   ((label k3) (config_hash rb1-26-seeded-k3@fc78391dd) (aggregate (((mean_sharpe 0.6015) (mean_calmar 0.4249) (mean_return_pct 1192.69) (mean_max_drawdown_pct 23.87)))))
   ((label k4) (config_hash rb1-26-seeded-k4@fc78391dd) (aggregate (((mean_sharpe 0.6531) (mean_calmar 0.4370) (mean_return_pct 1648.66) (mean_max_drawdown_pct 26.11)))))))
 (verdict Inconclusive)
 (notes
  "BASELINE ENTRY (re-baseline; the band is the result). Supersedes 2026-10-12-breadth-fix-rb1-record-baseline as the record. Median ln(1+R) 2.7819 (+1,515 %, CAGR 11.07 %), SD 0.2254, range 2.5593-3.1436 (CAGR 10.14-12.60 %); medians Sharpe 0.632, max DD 26.1 %, Calmar 0.425; SPY TR +705.8 % (ln 2.0866). 26y SD ~ 6y SD (0.2108, ratio 1.07; 90 % CI on SD 0.146-0.535): one 26y cell cannot resolve < ~0.45 log; every 26y verdict needs K >= 5 paired per seed. WHY: gate 1 (tie cut at the binding top-20) and gate 2 (cash at placement) decide which tails a seed catches; ADMA 2023-08-18 (k1/k2/k4, 0.30 of entry NAV) is the largest single draw; exposure is the same in every seed (56.1-57.3 %). Old N (Alphabetical, 2.2505) sits below every seed because of the build change #3266 measured (M = 2.7860, mid-band), not Seeded. CONSEQUENCES: 26y lever reads on the record config run seeds k0-k4, read paired per seed. Writeup: dev/experiments/record-kseed-2026-10-27/README.md."))

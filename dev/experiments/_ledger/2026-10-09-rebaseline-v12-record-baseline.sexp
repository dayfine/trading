((date 2026-10-09) (slug rebaseline-v12-record-baseline)
 (hypothesis
  "Not a mechanism test: the record baseline re-measured on the pit-v12 universe (true-dollar-volume list ranking #3136, inventory fix, rebuilt warehouse) on the total-return basis (cash interest DTB3 - 10 bp, EODHD dividends, split_dividend_guard #3181). Pre-registered in dev/experiments/rebaseline-v12-2026-10-08/README.md at 725507d9c (#3188/#3189). rb0 = interest only, rb1 = rb0 + dividend_crediting; both arms carry the guard. Item 3 (dividend implementation check) decides the default flip.")
 (base_scenario
  "rebaseline-v12-2026-10-08: run SHA 3f0f6333d, one build (chain-R), warehouse /tmp/snap_top3000_pit_v12pit 9,236 entries, lists = the 27 pit-v12 top-3000 files with the v12 twin alias delta (#3198), window 2000-01-01 -> 2026-06-26, salts 0/1/2, CELL_TIMEOUT 36000. V6 = 0 on all six cells; validator_diff -check V6 rb0 vs rb1 exit 0 per salt; n_symbols_absent 1 (MEL).")
 (window_id top3000-pitv12-1999-2025-record-26y-3salt-tr) (baseline_label record-rebaseline-v12-rb1)
 (variants
  (
   ((label rb1-v12-s0) (config_hash rb1-26-tr-guard-div)
    (aggregate (((mean_sharpe 0.5418) (mean_calmar 0.3943) (mean_return_pct 851.83) (mean_max_drawdown_pct 22.52)))))
   ((label rb1-v12-s1) (config_hash rb1-26-tr-guard-div)
    (aggregate (((mean_sharpe 0.5329) (mean_calmar 0.3934) (mean_return_pct 818.39) (mean_max_drawdown_pct 22.19)))))
   ((label rb1-v12-s2) (config_hash rb1-26-tr-guard-div)
    (aggregate (((mean_sharpe 0.5326) (mean_calmar 0.3917) (mean_return_pct 809.51) (mean_max_drawdown_pct 22.19)))))
   ((label rb0-v12-s0) (config_hash rb0-26-int-guard)
    (aggregate (((mean_sharpe 0.4684) (mean_calmar 0.2886) (mean_return_pct 632.86) (mean_max_drawdown_pct 27.06)))))
   ((label rb0-v12-s1) (config_hash rb0-26-int-guard)
    (aggregate (((mean_sharpe 0.4478) (mean_calmar 0.2788) (mean_return_pct 570.30) (mean_max_drawdown_pct 26.71)))))
   ((label rb0-v12-s2) (config_hash rb0-26-int-guard)
    (aggregate (((mean_sharpe 0.4820) (mean_calmar 0.2971) (mean_return_pct 665.26) (mean_max_drawdown_pct 26.88)))))
  ))
 (verdict Inconclusive)
 (notes
  "BASELINE ENTRY (verdict Inconclusive = no mechanism was tested; the band IS the result). Sharpe here is excess over the net T-bill rate. New record = rb1 (v12, total return): +852 / +818 / +810 %, CAGR 8.88 / 8.73 / 8.69 % vs SPY total return 8.20 %, max DD 22.5 / 22.2 / 22.2 % vs 55.2 %, Calmar 0.39 vs 0.15. The CAGR margin (+0.5-0.7 pp/yr) is thin and sits inside known unmodelled items (spin-offs #3215, ADR withholding, #3174 ex-date stops, #3136 liquidity gates); the drawdown/Calmar edge is robust (three separate ~21 % episodes). Pre-registered items 1-3 PASS: ordinary dividends +0.142 log in band, crediting reconstructs to < $1, guard rejects 2-3 events per path (WING, DHLGY ticket, TDG), BCH not tested. Salt spread 0.045 log (v11 tr1 0.18): ADMA / GLNG / MMYT / INVX are in all six cells. 2025-26 = picks (UP-regime days -19.8 % vs SPY +22.8 % at 62 % invested); the window ends inside the deepest drawdown, still open. NOT COMPARABLE as a level to the v11 bands (pit-universe-record-baseline 152/188/457 % price-only; total-return-26y tr1): different lists, candidate set, warehouse and accounting. CONSEQUENCES: the dividend_crediting + split_dividend_guard default-flip PR; every arm from here pairs against rb1-26-s{0,1,2}-v12 at the same salt on _v12pit (validator_diff -check V6); shorts Phase B (dev/experiments/shorts-phase-b-2026-10-09/) runs on the same warehouse. Writeup: dev/experiments/rebaseline-v12-2026-10-08/results/results-2026-10-08.md (#3219)."))

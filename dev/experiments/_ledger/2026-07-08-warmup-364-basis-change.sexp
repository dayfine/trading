((date 2026-07-08)
 (slug warmup-364-basis-change)
 (hypothesis
  "BASIS CHANGE, not an experiment: warmup_days_for Weinstein|Spy_only_weinstein 210->364 (option A of dev/notes/rs-warmup-gap-2026-07-07.md, USER-APPROVED 2026-07-08). The panel now carries the full 52 aligned weekly bars the RS analyzer needs, so rs_value is present from the FIRST screen of every backtest window instead of None for every symbol in the first 22 weeks (~21% of every 2y WF-CV fold).")
 (base_scenario "goldens-small/covid-recovery-2020-2024.sexp (sanity-diff cell)")
 (window_id warmup-364-basis-change-2026-07-08)
 (baseline_label warmup-210)
 (variants
  (((label warmup-210)
    (config_hash "")
    (aggregate
     (((mean_sharpe 0.81492497215427462) (mean_calmar 0.51635123871046229)
       (mean_return_pct 78.517463979649321)
       (mean_max_drawdown_pct 23.816418488988592)))))
   ((label warmup-364)
    (config_hash "")
    (aggregate
     (((mean_sharpe 1.017351154849971) (mean_calmar 0.88317147697383658)
       (mean_return_pct 106.38613766651331)
       (mean_max_drawdown_pct 17.670057066656877)))))))
 (verdict Accept)
 (notes
  "Harness-faithfulness fix, not a mechanism (no flag; live already fetches full history - sim now matches; exempt from experiment-flag-discipline R1/R2). Divergence shape verified on the sanity cell: day-1 candidate ranking changes (RS scored from the first screen), path drifts after; entry cadence unchanged (40 vs 40 entries 2020H1). LEDGER CONSEQUENCE: every ABSOLUTE backtest number shifts from this date; RELATIVE verdicts of prior entries stay valid (baseline and variant were equally RS-starved for the same first 22 weeks of every fold) - no re-litigation. All tight-band goldens re-pinned against their own validator store; warmup-windowed snapshot warehouses rebuilt (window start moves 154d earlier; deep floor 1997-12-31 covers it). Full record: dev/notes/warmup-364-repin-2026-07-08.md."))

((date 2026-06-06) (slug late-stage2-stop-tighten-grid)
 (hypothesis
  "Does the default-off late-Stage2 trailing-stop tightening dial (#1446: on held Stage2 {late=true} longs, raise the trailing stop to close*(1-buffer_pct)) cut the deep/bull MaxDD (37.3% / 17.5%) without killing the 918% / 237% return, robustly across buffer in {0.03,0.05,0.08} and across two macro-diverse windows (deep 2000-2026 dot-com+GFC, bull 2010-2026)?")
 (base_scenario "dev/backtest/p0-barbell-prod/production-deep.sexp + p0-barbell-bull-prod/production-bull.sexp")
 (window_id "deep-pit2000-2000-2026 + bull-pit2010-2010-2026 (single-window full-period, Cell E config)")
 (baseline_label baseline)
 (variants
  (((label deep-baseline)
    (aggregate
     (((mean_sharpe 0.70) (mean_calmar 0.25) (mean_return_pct 917.94)
       (mean_max_drawdown_pct 37.32) (win_count 359) (loss_count 664)))))
   ((label "deep-buffer=0.03/0.05/0.08 (byte-identical)")
    (aggregate
     (((mean_sharpe 0.76) (mean_calmar 0.28) (mean_return_pct 1238.79)
       (mean_max_drawdown_pct 37.32) (win_count 361) (loss_count 663)))))
   ((label bull-baseline)
    (aggregate
     (((mean_sharpe 0.65) (mean_calmar 0.44) (mean_return_pct 237.60)
       (mean_max_drawdown_pct 17.50) (win_count 256) (loss_count 414)))))
   ((label "bull-buffer=0.03/0.05/0.08 (identical to bull-baseline)")
    (aggregate
     (((mean_sharpe 0.65) (mean_calmar 0.44) (mean_return_pct 237.60)
       (mean_max_drawdown_pct 17.50) (win_count 256) (loss_count 414)))))))
 (verdict Reject)
 (notes
  "Confirmation-grid surface for the #1446 late-Stage2 stop-tighten dial. The dial FIRES (params.sexp confirms enable_late_stage2_stop_tighten=true + the buffer value loaded per cell), but the grid is a clean REJECT on three independent grounds: (1) FAILS ITS DESIGN PURPOSE - the dial was built to cut the 37.3%/17.5% MaxDD by de-risking late-Stage2 held positions, and MaxDD is UNCHANGED to the basis point in BOTH windows (37.32 deep, 17.50 bull). (2) BUFFER-INSENSITIVE - buffer 0.03/0.05/0.08 give byte-identical results within each window, so where the mechanism acts it is effectively binary (the exits it triggers happen on weeks whose close is below all three stop levels), giving no tunable surface. (3) DOES NOT GENERALIZE - on the bull window the dial is a COMPLETE no-op (baseline == every treatment, exactly); on the deep window its only effect is a +321pp return bump (917.9->1238.8%) driven by ~1 trade (1023->1024; +2W/-1L), DD-neutral, with Sharpe barely moving (0.70->0.76) and Calmar 0.25->0.28 - a single-episode capital-recycling path artifact in the 26y compounding run, not a robust improvement (a best-of-N / Deflated-Sharpe correction on one buffer-insensitive single-window win heavily discounts it). MECHANISTIC ROOT CAUSE: the worst drawdowns are FAST crashes (2000-02, 2008, 2020) that reset the `late` flag before the top, so the dial never engages on the DD-defining episodes - it only acts on slow-topping cases, which are not the max-DD drivers. This vindicates the diagnosis's own Next-Step-3 caveat (dev/notes/stage-lifecycle-pivot-diagnosis-2026-06-03.md: pair with the daily gap stop for fast blow-offs that reset `late`). DECISION: do NOT promote; the dial stays default-off and available as a Variant_matrix axis per flag-discipline, but earns no further investment. The lever for the 2020-stall regime remains BREADTH (project_cell_e_2020_stall_regime), not late-Stage2 stop-tightening."))

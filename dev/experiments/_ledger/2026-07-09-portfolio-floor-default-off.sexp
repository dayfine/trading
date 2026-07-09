((date 2026-07-09)
 (slug portfolio-floor-default-off)
 (hypothesis
  "DEFAULT FLIP (user mandate, explicit 'let's do it' 2026-07-09): turn the portfolio-floor force-liquidation trigger OFF by default — Force_liquidation.default_config.min_portfolio_value_fraction_of_peak 0.4 -> 0.0 (0.0 = documented disable). The floor force-closes ALL positions + halts new entries when portfolio_value < peak * fraction. The two per-position triggers (0.25 long / 0.15 short) are UNCHANGED — they are the real protection and stay on. Evidence: the floor never helped in 26+y of tested history and hurt catastrophically the single time it ever fired (GME meme-squeeze)." )
 (base_scenario "goldens-sp500-historical/sp500-2010-2026.sexp")
 (window_id floor-off-ablation-gme-window-2026-07-09)
 (baseline_label floor-on-0.4)
 (variants
  (((label floor-on-0.4)
    (config_hash "")
    (aggregate
     (((mean_sharpe 0.538) (mean_calmar 0.242) (mean_return_pct 1013.8)
       (mean_max_drawdown_pct 65.8)))))
   ((label floor-off-0.0)
    (config_hash "")
    (aggregate
     (((mean_sharpe 0.610) (mean_calmar 0.271) (mean_return_pct 2223.3)
       (mean_max_drawdown_pct 78.3)))))))
 (verdict Accept)
 (notes
  "Accept(the flip). Single-window paired ablation (NOT a WF-CV surface): on the ONLY window where the portfolio floor ever fired (sp500-2010-2026 long-only, 0.30 concentration, 364 basis, test_data store — the GME Sept-2020 Stage-2 breakout held through the Jan-2021 squeeze), floor-OFF dominates every risk-adjusted metric: return 1013.8->2223.3%, Sharpe .538->.610, Sortino .813->.865, Calmar .242->.271, Ulcer(time-underwater) 33.9->23.6, 32->0 portfolio-floor liqs; floor-off also runs ~178 more trades (2021-2025 no longer sterilized). The floor's SOLE raw-MaxDD 'win' (65.8 vs 78.3) is hollow: both DDs are measured from the same unrealizable $28.9M squeeze-MTM peak, and the floor's 65.8 is its OWN bottom-tick sell-everything (it force-sold the whole book near the local low, then re-liquidated 31 more times, locking the loss + foreclosing recovery). Across EVERY other tested config (deep top-3000 2000-2026 + 28y, sp500 deep windows, longshort twins) the portfolio floor fires ZERO times — no observed beneficial fire exists anywhere. PHILOSOPHY (user steer): we are not trying to time reversals; a brake whose only action is sell-everything-at-max-drawdown + halt-until-macro-flip is reversal-adjacent forced bottom-realization. Stops + per-position force-liq + stage-3/4 exits are the sanctioned risk layers. HONEST CAVEAT: the true-death-spiral protective case (a real, non-recovering collapse the floor would cushion) is UNTESTED — it also never occurs in 26+y of tested history — so the knob stays config-expressed as an axis (set > 0.0 to re-enable); the P1b index circuit-breaker lib is the squeeze-immune re-design if a portfolio brake is wanted back. Re-pins the sp500-2010-2026 golden floor-OFF (old floor-on pin 1013.84 / 32 floor liqs preserved in git history). Exempt from experiment-flag-discipline R1/R2 framing (this REMOVES a default-on risk-control, restoring the pre-floor no-op as default; the mechanism is retained + searchable). Full record: dev/backtest/floor-off-exp-2026-07-09/FINDINGS.md (merged #1903); GME pathology background dev/notes/warmup-364-repin-2026-07-08.md Findings.") )

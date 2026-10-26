((date 2026-10-25) (slug floor-nearest)
 (hypothesis
  "Floor-nearest arm SN (#3418 pre-registration; read #3423): under require_structural_stop, does support_floor_anchor_scope Nearest turn No_structural_stop skips into placed tickets (liveness: SN p0 No_structural_stop <= 0.75 x S p0's 5,078 AND Placed > 190), and if live, does median ln(1+R) beat the path-stability null S by spread(S) = 0.2108 without a do-no-harm cost? SN = S + the Nearest override, 6 cells paired by seed and list perturbation p0-p5, top-3000 PIT v12, 2019-2024, run tree 3db869d32 (the null's build, lists and names).")
 (base_scenario
  "floor-nearest-2026-10-25: 6 SN cells vs the 6 path-stability S cells, run tree 3db869d32; all 6 RESULT, 0 excluded; liveness SN p0 No_structural_stop 4,822 (0.950 x S), Placed 238 (1.253 x S) -> NOT LIVE as screened, no return read")
 (window_id top3000-pitv12-2019-2024-path-stability-6x4)
 (baseline_label seeded-S)
 (variants
  (((label S-median) (config_hash seeded-s0-s5) (aggregate (((mean_sharpe 0.838) (mean_calmar 0.674) (mean_return_pct 180.5) (mean_max_drawdown_pct 23.29)))))
   ((label SN-median) (config_hash seeded-floor-nearest) (aggregate (((mean_sharpe 0.533) (mean_calmar 0.409) (mean_return_pct 86.6) (mean_max_drawdown_pct 28.51)))))))
 (verdict Inconclusive)
 (notes
  "NOT LIVE as screened (rule step 1), so the pre-registered return rule was not applied: Inconclusive, NO-BUILD decision for this lever at this window; Nearest stays a default-off keep-axis; no 26y escalation. The liveness bar was mis-set about 4x stricter than the screen's own per-decision conversion (5.7-6.7 %); observed 5 %. Descriptive only: delta median ln(1+R) -0.407, 6/6 seeds below S, median max DD +5.2 pp. WHY: the book is cash-bound. Each cell converted 217-235 decisions and placed 87-100 of them, displacing 39-58 S placements per cell (APPS, MMYT, GLNG, ADMA, MSTR among them), and the admitted tickets were not better than the displaced ones (screen: Nearest skips mean +5.0 %, median -5.9 % vs placed +7.1 %). After Nearest, the 15 % stop gate binds (81 % of floors lie beyond it). FORWARD: funnel-widening levers must pre-register a displacement count and beat what they displace, not the empty slot; arm SM (monthly universe) carries that amendment. Writeup: dev/experiments/floor-nearest-2026-10-25/README.md."))

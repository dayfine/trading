((fold_count 15) (baseline_label baseline) (metric_label Sharpe)
 (stability
  (((variant_label baseline)
    (total_return_pct
     ((mean 12.950175847379974) (stdev 22.618292019823588)
      (min -19.005390539999958) (max 76.327379320000063)))
    (sharpe_ratio
     ((mean 0.64281770518313874) (stdev 1.035903103408901)
      (min -1.3497426614545693) (max 2.477847091992945)))
    (max_drawdown_pct
     ((mean 14.790393995098752) (stdev 7.6295421545449154)
      (min 4.83580819694276) (max 29.472804615426089)))
    (calmar_ratio
     ((mean 1.3816425612264558) (stdev 1.9832979358211229)
      (min -0.89513301326801242) (max 6.4305724204432115)))
    (cagr_pct
     ((mean 12.960955114086703) (stdev 22.637319854560033)
      (min -19.017083297276237) (max 76.395891247279053)))
    (avg_holding_days
     ((mean 33.199530843360172) (stdev 9.39446128560447)
      (min 22.226415094339622) (max 51.270270270270274))))
   ((variant_label
     enable_stage3_force_exit=true__enable_stage2_ma_hold=false)
    (total_return_pct
     ((mean 12.950175847379974) (stdev 22.618292019823588)
      (min -19.005390539999958) (max 76.327379320000063)))
    (sharpe_ratio
     ((mean 0.64281770518313874) (stdev 1.035903103408901)
      (min -1.3497426614545693) (max 2.477847091992945)))
    (max_drawdown_pct
     ((mean 14.790393995098752) (stdev 7.6295421545449154)
      (min 4.83580819694276) (max 29.472804615426089)))
    (calmar_ratio
     ((mean 1.3816425612264558) (stdev 1.9832979358211229)
      (min -0.89513301326801242) (max 6.4305724204432115)))
    (cagr_pct
     ((mean 12.960955114086703) (stdev 22.637319854560033)
      (min -19.017083297276237) (max 76.395891247279053)))
    (avg_holding_days
     ((mean 33.199530843360172) (stdev 9.39446128560447)
      (min 22.226415094339622) (max 51.270270270270274))))
   ((variant_label enable_stage3_force_exit=true__enable_stage2_ma_hold=true)
    (total_return_pct
     ((mean 10.508354709585092) (stdev 25.855760436873179)
      (min -24.216280299999983) (max 79.073895020000009)))
    (sharpe_ratio
     ((mean 0.48570609483795746) (stdev 1.1932335757551042)
      (min -1.6147810552812745) (max 2.7052846396420476)))
    (max_drawdown_pct
     ((mean 14.847173350329793) (stdev 7.3171561808326739)
      (min 4.2096473317037235) (max 30.526491871907389)))
    (calmar_ratio
     ((mean 1.354390444506872) (stdev 2.6105203025341956)
      (min -0.89511727003656916) (max 9.3899717271447756)))
    (cagr_pct
     ((mean 10.51773829382671) (stdev 25.877059649817273)
      (min -24.230671958823425) (max 79.145370601866219)))
    (avg_holding_days
     ((mean 33.908525256298404) (stdev 11.433379622431037)
      (min 21.818181818181817) (max 66.304347826086953))))
   ((variant_label
     enable_stage3_force_exit=false__enable_stage2_ma_hold=false)
    (total_return_pct
     ((mean 13.071462363117345) (stdev 23.812345378211258)
      (min -19.005390539999958) (max 76.257458490000019)))
    (sharpe_ratio
     ((mean 0.67908431692581472) (stdev 1.1560036671117906)
      (min -1.3497426614545693) (max 3.2613369874348104)))
    (max_drawdown_pct
     ((mean 14.73842200757595) (stdev 7.6167657334455479)
      (min 4.7250949954722765) (max 29.472804615426089)))
    (calmar_ratio
     ((mean 1.6307899577087506) (stdev 2.7847268228904736)
      (min -0.89513301326801242) (max 10.317195318886634)))
    (cagr_pct
     ((mean 13.082487927524323) (stdev 23.832267680011064)
      (min -19.017083297276237) (max 76.325895349489969)))
    (avg_holding_days
     ((mean 33.108705428358263) (stdev 9.6982490914023565)
      (min 22.30188679245283) (max 51.270270270270274))))
   ((variant_label
     enable_stage3_force_exit=false__enable_stage2_ma_hold=true)
    (total_return_pct
     ((mean 9.214691949886566) (stdev 26.181017393150555)
      (min -27.619899899999982) (max 75.9134828)))
    (sharpe_ratio
     ((mean 0.45684989319278591) (stdev 1.2274623937042251)
      (min -1.8880926451701279) (max 2.4493470013793219)))
    (max_drawdown_pct
     ((mean 14.787875733307981) (stdev 7.4971402810983028)
      (min 2.9984479748682635) (max 31.220104301509377)))
    (calmar_ratio
     ((mean 1.2991960986810773) (stdev 2.3358211989355482)
      (min -0.92041544673685127) (max 8.0965928432555483)))
    (cagr_pct
     ((mean 9.22318495756724) (stdev 26.202223294965936)
      (min -27.63592282184586) (max 75.981550640386672)))
    (avg_holding_days
     ((mean 33.758929146264606) (stdev 11.622055426984094)
      (min 22.036363636363635) (max 66.304347826086953))))))
 (sensitivity
  (((variant_label
     enable_stage3_force_exit=true__enable_stage2_ma_hold=false)
    (sharpe_wins 0) (calmar_wins 0) (total_return_wins 0)
    (max_drawdown_wins 0))
   ((variant_label enable_stage3_force_exit=true__enable_stage2_ma_hold=true)
    (sharpe_wins 8) (calmar_wins 8) (total_return_wins 7)
    (max_drawdown_wins 7))
   ((variant_label
     enable_stage3_force_exit=false__enable_stage2_ma_hold=false)
    (sharpe_wins 1) (calmar_wins 2) (total_return_wins 1)
    (max_drawdown_wins 3))
   ((variant_label
     enable_stage3_force_exit=false__enable_stage2_ma_hold=true)
    (sharpe_wins 7) (calmar_wins 8) (total_return_wins 6)
    (max_drawdown_wins 7))))
 (verdicts
  ((enable_stage3_force_exit=true__enable_stage2_ma_hold=false
    (Fail (wins 0) (n 15) (worst_fold fold-000) (worst_gap 0)
     (reason "M-threshold miss: 0 wins < 8 required")))
   (enable_stage3_force_exit=true__enable_stage2_ma_hold=true
    (Fail (wins 8) (n 15) (worst_fold fold-014)
     (worst_gap 2.3122818927776652)
     (reason
      "\206\148-threshold miss: fold fold-014 trails by 2.3123 > \206\148=0.2000")))
   (enable_stage3_force_exit=false__enable_stage2_ma_hold=false
    (Fail (wins 1) (n 15) (worst_fold fold-009)
     (worst_gap 0.12756914224486016)
     (reason "M-threshold miss: 1 wins < 8 required")))
   (enable_stage3_force_exit=false__enable_stage2_ma_hold=true
    (Fail (wins 7) (n 15) (worst_fold fold-014)
     (worst_gap 2.5855934826665186)
     (reason
      "M-threshold miss: 7 wins < 8 required; worst fold fold-014 trails by 2.5856 > \206\148=0.2000"))))))

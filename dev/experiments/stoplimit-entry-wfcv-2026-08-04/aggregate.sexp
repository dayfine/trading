((fold_count 31) (baseline_label market) (metric_label Sharpe)
 (stability
  (((variant_label market)
    (total_return_pct
     ((mean 28.702745940967752) (stdev 102.8985377712233)
      (min -11.228551329999998) (max 577.865961)))
    (sharpe_ratio
     ((mean 0.78886802244567233) (stdev 0.87233283445921206)
      (min -0.750348833674944) (max 2.3418031186044113)))
    (max_drawdown_pct
     ((mean 13.431420593821331) (stdev 12.774258574340557)
      (min 4.6264218745499113) (max 77.603829786711145)))
    (calmar_ratio
     ((mean 1.5642577403497451) (stdev 2.0573555972287858)
      (min -0.6645306480375951) (max 7.50395436875202)))
    (cagr_pct
     ((mean 28.739249623708211) (stdev 103.05680851090257)
      (min -11.23579290674469) (max 578.75509560250714)))
    (avg_holding_days
     ((mean 36.522822780840258) (stdev 7.6243446557162811)
      (min 21.618181818181817) (max 51.210526315789473))))
   ((variant_label cap10)
    (total_return_pct
     ((mean 24.788063110292828) (stdev 102.38056803259509)
      (min -14.105628999940528) (max 571.56632111606382)))
    (sharpe_ratio
     ((mean 0.52450196936161086) (stdev 0.8882629904891538)
      (min -0.904302321437977) (max 1.9857769479611909)))
    (max_drawdown_pct
     ((mean 14.569081648660182) (stdev 12.72879827290812)
      (min 5.1672656841083819) (max 77.821581917757669)))
    (calmar_ratio
     ((mean 1.1469152149346862) (stdev 1.9560503699998641)
      (min -0.78126451919737716) (max 7.401195548190187)))
    (cagr_pct
     ((mean 24.82138929793803) (stdev 102.53704236872954)
      (min -14.114574014519587) (max 572.44289235768542)))
    (avg_holding_days
     ((mean 36.774047547534316) (stdev 7.5181921201257733)
      (min 21.618181818181817) (max 51.210526315789473))))
   ((variant_label cap15)
    (total_return_pct
     ((mean 24.811950950879606) (stdev 102.44069266563045)
      (min -14.153322847226985) (max 572.0344038493314)))
    (sharpe_ratio
     ((mean 0.52217254060101537) (stdev 0.88003226224427222)
      (min -0.90809677176073689) (max 1.9604793670086611)))
    (max_drawdown_pct
     ((mean 14.57926180611604) (stdev 12.688094248617483)
      (min 5.1673487554481738) (max 77.82866597509404)))
    (calmar_ratio
     ((mean 1.114532986275393) (stdev 1.8972374872096014)
      (min -0.78362934995152156) (max 7.4065964124927968)))
    (cagr_pct
     ((mean 24.845300936523252) (stdev 102.59733297764302)
      (min -14.16229554952324) (max 572.91190719743622)))
    (avg_holding_days
     ((mean 36.459606165005745) (stdev 7.4906724798995414)
      (min 21.618181818181817) (max 51.210526315789473))))
   ((variant_label cap20)
    (total_return_pct
     ((mean 24.147120911287423) (stdev 102.50770462071165)
      (min -14.529447732259262) (max 571.961520249073)))
    (sharpe_ratio
     ((mean 0.49581151036453935) (stdev 0.9262316953682187)
      (min -1.032628273659649) (max 1.9871430289070546)))
    (max_drawdown_pct
     ((mean 14.549861539222986) (stdev 12.702139482332713)
      (min 5.1666192002943072) (max 77.817356036218825)))
    (calmar_ratio
     ((mean 1.1170069482516873) (stdev 1.9940232808350653)
      (min -0.883688681251465) (max 7.4067269006222141)))
    (cagr_pct
     ((mean 24.179968586796331) (stdev 102.66438448770636)
      (min -14.53863814929155) (max 572.83887844727678)))
    (avg_holding_days
     ((mean 36.244824172454841) (stdev 7.38929545982462)
      (min 21.618181818181817) (max 51.210526315789473))))))
 (sensitivity
  (((variant_label cap10) (sharpe_wins 2) (calmar_wins 3)
    (total_return_wins 3) (max_drawdown_wins 4))
   ((variant_label cap15) (sharpe_wins 2) (calmar_wins 3)
    (total_return_wins 2) (max_drawdown_wins 5))
   ((variant_label cap20) (sharpe_wins 1) (calmar_wins 2)
    (total_return_wins 1) (max_drawdown_wins 5))))
 (verdicts
  ((cap10
    (Fail (wins 2) (n 31) (worst_fold fold-006)
     (worst_gap 0.6224445928202238)
     (reason
      "M-threshold miss: 2 wins < 16 required; worst fold fold-006 trails by 0.6224 > \206\148=0.2000")))
   (cap15
    (Fail (wins 2) (n 31) (worst_fold fold-006)
     (worst_gap 0.6816813100061867)
     (reason
      "M-threshold miss: 2 wins < 16 required; worst fold fold-006 trails by 0.6817 > \206\148=0.2000")))
   (cap20
    (Fail (wins 1) (n 31) (worst_fold fold-029)
     (worst_gap 0.6237670264452676)
     (reason
      "M-threshold miss: 1 wins < 16 required; worst fold fold-029 trails by 0.6238 > \206\148=0.2000"))))))

((fold_count 15) (baseline_label baseline) (metric_label Sharpe)
 (stability
  (((variant_label baseline)
    (total_return_pct
     ((mean 12.992383233076946) (stdev 22.59481710736609)
      (min -19.005390539999958) (max 76.327379320000063)))
    (sharpe_ratio
     ((mean 0.6452002541114964) (stdev 1.0350831869835606)
      (min -1.3497426614545693) (max 2.477847091992945)))
    (max_drawdown_pct
     ((mean 14.774313514197063) (stdev 7.6065270656731157)
      (min 4.83580819694276) (max 29.472804615426089)))
    (calmar_ratio
     ((mean 1.3800315061283348) (stdev 1.9806744208286644)
      (min -0.89513301326801242) (max 6.4305724204432115)))
    (cagr_pct
     ((mean 13.003191760959814) (stdev 22.613828579007251)
      (min -19.017083297276237) (max 76.395891247279053)))
    (avg_holding_days
     ((mean 33.190380516562783) (stdev 9.3895785491286841)
      (min 22.226415094339622) (max 51.270270270270274))))
   ((variant_label harvest_k033)
    (total_return_pct
     ((mean 11.062231093894187) (stdev 29.8098558039357)
      (min -18.748315787371851) (max 87.395936789767518)))
    (sharpe_ratio
     ((mean 0.4108682060006405) (stdev 0.93441108746305679)
      (min -1.298356349868641) (max 1.9472987293308295)))
    (max_drawdown_pct
     ((mean 15.459920977043332) (stdev 6.778861107633924)
      (min 6.91349666154804) (max 28.541989470257427)))
    (calmar_ratio
     ((mean 0.97847721028583268) (stdev 1.4394670346580336)
      (min -0.83568057502029747) (max 3.772185632791254)))
    (cagr_pct
     ((mean 11.072580622885399) (stdev 29.835011641000957)
      (min -18.759869324682622) (max 87.476566921604814)))
    (avg_holding_days
     ((mean 29.821466136247508) (stdev 6.8008065752774032)
      (min 18.03846153846154) (max 40.45945945945946))))
   ((variant_label harvest_k050)
    (total_return_pct
     ((mean 17.632710890883214) (stdev 37.005853025162409)
      (min -17.282745582832014) (max 126.13636041400973)))
    (sharpe_ratio
     ((mean 0.62684504843281441) (stdev 0.84276008739925423)
      (min -1.1514159157987907) (max 2.5154343590167745)))
    (max_drawdown_pct
     ((mean 14.440581972823416) (stdev 6.5176898366503648)
      (min 4.7735154325473452) (max 25.84153036522337)))
    (calmar_ratio
     ((mean 1.3143673271463421) (stdev 1.8112844951227935)
      (min -0.77570415634248546) (max 5.9864190892981144)))
    (cagr_pct
     ((mean 17.649029532824581) (stdev 37.041020532120889)
      (min -17.293494839508949) (max 126.26277932148651)))
    (avg_holding_days
     ((mean 28.998670798078308) (stdev 5.673291804741952) (min 22.5)
      (max 42.761904761904759))))
   ((variant_label harvest_k100)
    (total_return_pct
     ((mean 13.24762394066668) (stdev 27.747756799475276)
      (min -19.65523731999998) (max 72.26140897)))
    (sharpe_ratio
     ((mean 0.41447869675333848) (stdev 1.0881221613859944)
      (min -1.299789935769442) (max 2.3839952586869186)))
    (max_drawdown_pct
     ((mean 15.50467660443104) (stdev 7.806638559773547)
      (min 5.51618489159603) (max 27.894003568615091)))
    (calmar_ratio
     ((mean 1.3099201371621521) (stdev 2.1787489516873446)
      (min -0.78441909035943369) (max 6.2380866337881455)))
    (cagr_pct
     ((mean 13.259376496371907) (stdev 27.770254851699594)
      (min -19.667279507306034) (max 72.325587466165089)))
    (avg_holding_days
     ((mean 26.777800116656884) (stdev 5.9052046384804715)
      (min 18.807017543859651) (max 38.946428571428569))))))
 (sensitivity
  (((variant_label harvest_k033) (sharpe_wins 7) (calmar_wins 6)
    (total_return_wins 6) (max_drawdown_wins 6))
   ((variant_label harvest_k050) (sharpe_wins 8) (calmar_wins 8)
    (total_return_wins 8) (max_drawdown_wins 7))
   ((variant_label harvest_k100) (sharpe_wins 6) (calmar_wins 7)
    (total_return_wins 9) (max_drawdown_wins 7))))
 (verdicts
  ((harvest_k033
    (Fail (wins 7) (n 15) (worst_fold fold-014) (worst_gap 1.65517236093618)
     (reason
      "M-threshold miss: 7 wins < 8 required; worst fold fold-014 trails by 1.6552 > \206\148=0.3000")))
   (harvest_k050
    (Fail (wins 8) (n 15) (worst_fold fold-006)
     (worst_gap 1.5692613118011467)
     (reason
      "\206\148-threshold miss: fold fold-006 trails by 1.5693 > \206\148=0.3000")))
   (harvest_k100
    (Fail (wins 6) (n 15) (worst_fold fold-014)
     (worst_gap 1.7416614247012441)
     (reason
      "M-threshold miss: 6 wins < 8 required; worst fold fold-014 trails by 1.7417 > \206\148=0.3000"))))))

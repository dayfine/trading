((audit_records
  (((entry
     ((symbol AAA) (entry_date 2020-01-10) (position_id AAA-wein-1)
      (macro_trend Bullish) (macro_confidence 0.75)
      (side Long) (suggested_entry 10.00) (close_at_decision 9.90))))
   ((entry
     ((symbol BBB) (entry_date 2020-02-21) (position_id BBB-wein-2)
      (macro_trend Bearish) (macro_confidence 0.25)
      (side Short) (suggested_entry 50.00) (close_at_decision 40.00)
      (alternatives_considered
       (((symbol CCC) (side Short) (score 110) (grade A_plus))))))
   ((entry
     ((symbol DDD) (entry_date 2020-03-13) (position_id DDD-wein-3)
      (macro_trend Bearish) (macro_confidence 0.25)
      (side Short) (suggested_entry 20.00) (close_at_decision 16.00))))))
 (cascade_summaries
  (((date 2020-02-14) (total_stocks 3) (candidates_after_held 3)
    (macro_trend Bearish) (breadth_state Bearish_breadth)
    (long_macro_admitted 0) (long_top_n_admitted 0) (short_macro_admitted 3)
    (short_grade_admitted 0)
    (short_top_n_admitted 0) (entered 0))
   ((date 2020-02-21) (total_stocks 3) (candidates_after_held 3)
    (macro_trend Bearish) (breadth_state Bearish_breadth)
    (long_macro_admitted 0) (long_top_n_admitted 0) (short_macro_admitted 3)
    (short_grade_admitted 2)
    (short_top_n_admitted 2) (entered 1))
   ((date 2020-02-28) (total_stocks 3) (candidates_after_held 3)
    (macro_trend Bullish) (breadth_state Bullish_breadth)
    (long_macro_admitted 3) (long_top_n_admitted 1) (short_macro_admitted 0)
    (short_grade_admitted 0)
    (short_top_n_admitted 4) (entered 0)))))

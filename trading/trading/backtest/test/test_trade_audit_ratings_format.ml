(** Exact-output pins for the moved markdown formatters of
    [Trade_audit_ratings], covering the alternate branches (NaN vs finite, every
    label variant, truncation caps, empty input) that the single-fixture tests
    in [test_trade_audit_ratings] do not reach. *)

open OUnit2
open Core
open Matchers
module TR = Trade_audit_report.Trade_audit_ratings

let _date d = Date.of_string d

let _outlier symbol metric : TR.outlier_trade =
  { symbol; entry_date = _date "2024-01-15"; metric }

let _outliers prefix n =
  List.init n ~f:(fun i -> _outlier (sprintf "%s%d" prefix i) "m")

let _outlier_lines prefix n =
  List.init n ~f:(fun i -> sprintf "  - %s%d 2024-01-15 — m" prefix i)

let _quartile_stat quartile trade_count win_count win_rate_pct :
    TR.cascade_quartile_stat =
  { quartile; trade_count; win_count; win_rate_pct }

let _quartile_header =
  [ "| quartile | trades | wins | win_rate |"; "|---|---:|---:|---:|" ]

let _rating symbol outcome r_multiple hold_time_anomaly weinstein_score :
    TR.rating =
  {
    symbol;
    entry_date = _date "2024-01-15";
    r_multiple;
    mfe_pct = 0.1;
    mae_pct = -0.02;
    hold_time_anomaly;
    outcome;
    weinstein_score;
  }

let test_per_trade_extras_variants _ =
  assert_that
    (TR.format_per_trade_extras
       ~ratings:
         [
           _rating "WIN" TR.Win 1.5 TR.Held_indefinitely 0.75;
           _rating "NAN" TR.Loss Float.nan TR.Normal Float.nan;
         ])
    (equal_to
       [
         "## Per-trade ratings";
         "";
         "| symbol | entry_date | outcome | r_multiple | mfe_% | mae_% | \
          hold_anomaly | weinstein_score |";
         "|---|---|---|---:|---:|---:|---|---:|";
         "| WIN | 2024-01-15 | W | +1.50R | +10.00% | -2.00% | held_indef | \
          0.75 |";
         "| NAN | 2024-01-15 | L | — | +10.00% | -2.00% | normal | — |";
         "";
       ])

let test_per_trade_extras_empty _ =
  assert_that
    (TR.format_per_trade_extras ~ratings:[])
    (equal_to
       [
         "## Per-trade ratings";
         "";
         "| symbol | entry_date | outcome | r_multiple | mfe_% | mae_% | \
          hold_anomaly | weinstein_score |";
         "|---|---|---|---:|---:|---:|---|---:|";
         "_No ratings._";
         "";
       ])

let test_behavioral_nan_below_threshold_truncated _ =
  let m : TR.behavioral_metrics =
    {
      over_trading =
        {
          total_trades = 7;
          trades_per_year = Float.nan;
          exceeds_threshold = false;
          concentrated_burst_pct = 0.0;
          outliers = _outliers "O" 6;
        };
      exit_winners_too_early =
        {
          winners_evaluated = 0;
          flagged_count = 0;
          avg_left_on_table_pct = 0.0;
          outliers = [];
        };
      exit_losers_too_late =
        {
          losers_evaluated = 0;
          flagged_count = 0;
          stop_discipline_pct = 0.0;
          outliers = [];
        };
      entering_losers_often =
        { per_quartile = []; flagged_count = 0; outliers = [] };
    }
  in
  assert_that
    (TR.format_behavioral_section m)
    (equal_to
       ([
          "## Behavioural metrics";
          "";
          "### (a) Over-trading";
          "- Total trades: 7";
          "- Trades / year: —";
          "- Concentrated-burst share: 0.0%";
          "- Outliers (top 5):";
        ]
       @ _outlier_lines "O" 5
       @ [
           "";
           "### (b) Exit-winners-too-early";
           "- Winners evaluated: 0";
           "- Flagged (realized < 50% of MFE): 0";
           "- Avg pp left on the table: 0.00";
           "- Outliers (top 5):";
           "  _none_";
           "";
           "### (c) Exit-losers-too-late";
           "- Losers evaluated: 0";
           "- Flagged (|R|>1.5 or MAE\xe2\x89\xa51.5\xc3\x97realized): 0";
           "- Stop discipline (|R|\xe2\x89\xa41.0): 0.0%";
           "- Outliers (top 5):";
           "  _none_";
           "";
           "### (d) Entering-losers-too-often (cascade quartile vs outcome)";
           "";
         ]
       @ _quartile_header
       @ [ ""; "- Flagged outliers: 0"; "- Outliers (top 5):"; "  _none_"; "" ]
       ))

let test_exit_winners_outlier_cap _ =
  let m : TR.behavioral_metrics =
    {
      over_trading =
        {
          total_trades = 7;
          trades_per_year = Float.nan;
          exceeds_threshold = false;
          concentrated_burst_pct = 0.0;
          outliers = [];
        };
      exit_winners_too_early =
        {
          winners_evaluated = 6;
          flagged_count = 6;
          avg_left_on_table_pct = 0.0;
          outliers = _outliers "W" 6;
        };
      exit_losers_too_late =
        {
          losers_evaluated = 0;
          flagged_count = 0;
          stop_discipline_pct = 0.0;
          outliers = [];
        };
      entering_losers_often =
        { per_quartile = []; flagged_count = 0; outliers = [] };
    }
  in
  assert_that
    (TR.format_behavioral_section m)
    (equal_to
       ([
          "## Behavioural metrics";
          "";
          "### (a) Over-trading";
          "- Total trades: 7";
          "- Trades / year: —";
          "- Concentrated-burst share: 0.0%";
          "- Outliers (top 5):";
          "  _none_";
          "";
          "### (b) Exit-winners-too-early";
          "- Winners evaluated: 6";
          "- Flagged (realized < 50% of MFE): 6";
          "- Avg pp left on the table: 0.00";
          "- Outliers (top 5):";
        ]
       @ _outlier_lines "W" 5
       @ [
           "";
           "### (c) Exit-losers-too-late";
           "- Losers evaluated: 0";
           "- Flagged (|R|>1.5 or MAE\xe2\x89\xa51.5\xc3\x97realized): 0";
           "- Stop discipline (|R|\xe2\x89\xa41.0): 0.0%";
           "- Outliers (top 5):";
           "  _none_";
           "";
           "### (d) Entering-losers-too-often (cascade quartile vs outcome)";
           "";
         ]
       @ _quartile_header
       @ [ ""; "- Flagged outliers: 0"; "- Outliers (top 5):"; "  _none_"; "" ]
       ))

let test_weinstein_all_rules_truncated _ =
  let agg : TR.weinstein_aggregate =
    {
      per_rule =
        List.map TR.all_rules ~f:(fun rule : TR.rule_violation_summary ->
            {
              rule;
              fail_count = 0;
              marginal_count = 0;
              applicable_count = 1;
              pass_rate_pct = 100.0;
            });
      spirit_score = 0.5;
      trades_with_critical_violation = _outliers "C" 11;
    }
  in
  assert_that
    (TR.format_weinstein_section agg)
    (equal_to
       ([
          "## Weinstein conformance";
          "";
          "- Spirit score (avg per-trade): 0.50";
          "";
          "| rule | description | passed/applicable | pass_rate | fails |";
          "|---|---|---:|---:|---:|";
          "| R1 | Long entry above 30w MA AND MA flat-or-rising (Ch.2, \
           \xc2\xa74.1) | 1 / 1 | 100.0% | 0 |";
          "| R2 | Long entry breakout with volume \xe2\x89\xa52x avg (Ch.4) | \
           1 / 1 | 100.0% | 0 |";
          "| R3 | Never long in Stage 4 (Ch.2, CRITICAL) | 1 / 1 | 100.0% | 0 |";
          "| R4 | Short entry below 30w MA AND MA flat-or-falling (Ch.7, \
           \xc2\xa76.1) | 1 / 1 | 100.0% | 0 |";
          "| R5 | Short entry is a Stage-4 breakdown (Ch.7) | 1 / 1 | 100.0% | \
           0 |";
          "| R6 | No entry within 5d of a 10% drop in last 30d (Ch.4 \
           \xe2\x80\x94 plunge-buy avoidance) | 1 / 1 | 100.0% | 0 |";
          "| R7 | Exit on Stage3 \xe2\x86\x92 Stage4 transition, and never \
           reach force-liquidation (Ch.6) | 1 / 1 | 100.0% | 0 |";
          "| R8 | Macro alignment: Bullish for longs, Bearish for shorts \
           (Ch.3, Ch.8) | 1 / 1 | 100.0% | 0 |";
          "";
          "- Critical R3 violations:";
        ]
       @ _outlier_lines "C" 10 @ [ "" ]))

let test_decision_quality_nan_q2_q3 _ =
  let m : TR.decision_quality_matrix =
    {
      per_quartile =
        [ _quartile_stat TR.Q2 3 1 33.3; _quartile_stat TR.Q3 2 2 100.0 ];
      total_trades = 5;
      overall_win_rate_pct = Float.nan;
    }
  in
  assert_that
    (TR.format_decision_quality_section m)
    (equal_to
       ([
          "## Decision quality (cascade quartile vs outcome)";
          "";
          "- Total trades: 5";
          "- Overall win rate: —";
          "";
        ]
       @ _quartile_header
       @ [ "| Q2 | 3 | 1 | 33.3% |"; "| Q3 | 2 | 2 | 100.0% |"; "" ]))

let suite =
  "Trade_audit_ratings_format"
  >::: [
         "per-trade extras variants" >:: test_per_trade_extras_variants;
         "per-trade extras empty" >:: test_per_trade_extras_empty;
         "behavioral nan / below threshold / truncated"
         >:: test_behavioral_nan_below_threshold_truncated;
         "exit winners outlier cap" >:: test_exit_winners_outlier_cap;
         "weinstein all rules + critical cap"
         >:: test_weinstein_all_rules_truncated;
         "decision quality nan + Q2/Q3" >:: test_decision_quality_nan_q2_q3;
       ]

let () = run_test_tt_main suite

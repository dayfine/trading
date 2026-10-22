(** CSV and Markdown output for the all-eligible diagnostic. *)

open Core
module OT = Backtest_optimal.Optimal_types

let _csv_header =
  "signal_date,symbol,side,entry_price,exit_date,exit_reason,return_pct,hold_days,entry_dollars,shares,pnl_dollars,cascade_score,passes_macro,rs_value,rs_trend,volume_ratio,weeks_advancing,stage2_late,resistance_quality"

let _side_to_string : Trading_base.Types.position_side -> string = function
  | Long -> "LONG"
  | Short -> "SHORT"

let _exit_reason_to_string : OT.exit_trigger -> string = function
  | Stage3_transition -> "Stage3_transition"
  | Stop_hit -> "Stop_hit"
  | End_of_run -> "End_of_run"

(** Render an optional feature column: the value when present, the empty string
    when [None] — so a missing decision-time feature reads as a blank cell
    rather than a sentinel that downstream parsers must special-case. *)
let _opt_to_string ~f = function Some v -> f v | None -> ""

let _rs_trend_to_string (t : Weinstein_types.rs_trend) : string =
  Sexp.to_string (Weinstein_types.sexp_of_rs_trend t)

let _resistance_quality_to_string (q : Weinstein_types.overhead_quality) :
    string =
  Sexp.to_string (Weinstein_types.sexp_of_overhead_quality q)

let _trade_to_csv_row (t : All_eligible.trade_record) : string =
  Printf.sprintf
    "%s,%s,%s,%.4f,%s,%s,%.6f,%d,%.2f,%.6f,%.4f,%d,%b,%s,%s,%s,%s,%s,%s"
    (Date.to_string t.signal_date)
    t.symbol (_side_to_string t.side) t.entry_price
    (Date.to_string t.exit_date)
    (_exit_reason_to_string t.exit_reason)
    t.return_pct t.hold_days t.entry_dollars t.shares t.pnl_dollars
    t.cascade_score t.passes_macro
    (_opt_to_string ~f:(Printf.sprintf "%.6f") t.rs_value)
    (_opt_to_string ~f:_rs_trend_to_string t.rs_trend)
    (_opt_to_string ~f:(Printf.sprintf "%.6f") t.volume_ratio)
    (_opt_to_string ~f:Int.to_string t.weeks_advancing)
    (_opt_to_string ~f:Bool.to_string t.stage2_late)
    (_opt_to_string ~f:_resistance_quality_to_string t.resistance_quality)

let write_trades_csv ~path (result : All_eligible.result) : unit =
  let lines = _csv_header :: List.map result.trades ~f:_trade_to_csv_row in
  Out_channel.write_lines path lines

(** Render one row of the bucket histogram. Uses [neg_infinity] / [infinity]
    sentinels for the open ends. *)
let _bucket_row (low, high, count) : string =
  let fmt_low =
    if Float.is_negative low && Float.is_inf low then "-inf"
    else Printf.sprintf "%.2f" low
  in
  let fmt_high =
    if Float.is_inf high then "+inf" else Printf.sprintf "%.2f" high
  in
  Printf.sprintf "| %s | %s | %d |" fmt_low fmt_high count

let format_summary_md ~scenario_name ~start_date ~end_date
    ~(result : All_eligible.result) : string =
  let agg = result.aggregate in
  let bucket_lines =
    "| Low | High | Count |" :: "|---|---|---|"
    :: List.map agg.return_buckets ~f:_bucket_row
  in
  let stats_lines =
    [
      "| Metric | Value |";
      "|---|---|";
      Printf.sprintf "| trade_count | %d |" agg.trade_count;
      Printf.sprintf "| winners | %d |" agg.winners;
      Printf.sprintf "| losers | %d |" agg.losers;
      Printf.sprintf "| win_rate_pct | %.4f |" agg.win_rate_pct;
      Printf.sprintf "| mean_return_pct | %.6f |" agg.mean_return_pct;
      Printf.sprintf "| median_return_pct | %.6f |" agg.median_return_pct;
      Printf.sprintf "| total_pnl_dollars | %.2f |" agg.total_pnl_dollars;
    ]
  in
  let header_lines =
    [
      Printf.sprintf "# All-eligible diagnostic — %s" scenario_name;
      "";
      Printf.sprintf "Period: %s to %s"
        (Date.to_string start_date)
        (Date.to_string end_date);
      "";
      "## Aggregate";
      "";
    ]
  in
  let bucket_header = [ ""; "## Return-bucket histogram"; "" ] in
  String.concat ~sep:"\n"
    (header_lines @ stats_lines @ bucket_header @ bucket_lines @ [ "" ])

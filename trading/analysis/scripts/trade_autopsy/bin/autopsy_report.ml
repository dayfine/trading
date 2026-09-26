open Core
module Autopsy = Trade_autopsy_lib.Trade_autopsy

let _fmt_pct v = sprintf "%+7.2f%%" (v *. 100.0)
let _fmt_pct_abs v = sprintf "%6.2f%%" (Float.abs v *. 100.0)

(* Per-symbol failure-mode row: symbol | # trades | stage3_fp missed | late
   reentry missed | late stage2 missed | stop_out_whipsaw missed. *)
let _render_breakdown_row (b : Autopsy.per_symbol_breakdown) =
  sprintf "| %s | %d | %s | %s | %s | %s |" b.symbol b.num_trades
    (_fmt_pct b.stage3_false_positive_missed_gain)
    (_fmt_pct b.late_reentry_missed_gain)
    (_fmt_pct b.late_stage2_admission_missed_gain)
    (_fmt_pct b.stop_out_whipsaw_missed_gain)

let _render_breakdown_table breakdowns =
  let header =
    "| Symbol | # trades | Stage3 false-positive total | Late re-entry total | \
     Late Stage2 admission total | Stop-out whipsaw total |"
  in
  let divider = "|---|---|---|---|---|---|" in
  let rows = List.map breakdowns ~f:_render_breakdown_row in
  String.concat ~sep:"\n" (header :: divider :: rows)

let _render_aggregate_row (s : Autopsy.mode_summary) =
  sprintf "| %s | %d | %s | %s |" s.mode_name s.trade_count
    (_fmt_pct s.total_missed_gain_pct)
    (_fmt_pct s.avg_missed_gain_pct)

let _render_aggregate_table summary =
  let header =
    "| Failure mode | # trades flagged | Total missed gain | Avg missed gain \
     (per flagged trade) |"
  in
  let divider = "|---|---|---|---|" in
  let rows = List.map summary ~f:_render_aggregate_row in
  String.concat ~sep:"\n" (header :: divider :: rows)

(* Exit-reason histogram across all autopsies — a sanity check the autopsy
   schema covers the input strategy's exit mechanics. *)
let _exit_reason_label = function
  | Autopsy.Stage3_exit -> "Stage3_exit"
  | Stage1_cover_short -> "Stage1_cover_short"
  | End_of_period -> "End_of_period"
  | Stop_out -> "Stop_out"
  | Stage4_decline -> "Stage4_decline"
  | Laggard_rotation -> "Laggard_rotation"

let _render_exit_reason_histogram autopsies =
  let table =
    List.fold autopsies
      ~init:(Map.empty (module String))
      ~f:(fun acc a ->
        let key = _exit_reason_label a.Autopsy.exit_reason in
        Map.update acc key ~f:(function None -> 1 | Some n -> n + 1))
  in
  let rows =
    Map.to_alist table |> List.map ~f:(fun (k, v) -> sprintf "| %s | %d |" k v)
  in
  String.concat ~sep:"\n" ("| Exit reason | Count |" :: "|---|---|" :: rows)

let render ~start_date ~end_date ~breakdowns ~aggregate_summary ~autopsies =
  let breakdown_table = _render_breakdown_table breakdowns in
  let aggregate_table = _render_aggregate_table aggregate_summary in
  let exit_histogram = _render_exit_reason_histogram autopsies in
  let intro =
    sprintf
      "Per-symbol Weinstein stage strategy: %d trades over %d symbols × (%s to \
       %s). Failure modes classified per\n\
       [dev/notes/next-session-priorities-2026-05-29.md] §P3. Thresholds: \
       Stage 3 recovery ≥ 5%% within 12 weeks; late re-entry > 8 weeks AND \
       missed gain ≥ 10%%; late Stage-2 admission > 8 weeks past prior \
       cyclical low (12-week lookback); stop-out whipsaw 4 weeks / 5%% (inert \
       under this strategy)."
      (List.length autopsies) (List.length breakdowns)
      (Date.to_string start_date)
      (Date.to_string end_date)
  in
  String.concat ~sep:"\n\n"
    [
      sprintf "# Trade autopsy — %s to %s"
        (Date.to_string start_date)
        (Date.to_string end_date);
      intro;
      "## Per-symbol failure-mode breakdown";
      "Each cell is the SUM of [missed_gain_pct] across trades for that symbol \
       that the failure-mode flag matched. Positive values = missed upside \
       (strategy exited too early or admitted too late). Modes are INDEPENDENT \
       classifications — one trade can flag more than one mode.";
      breakdown_table;
      "## Aggregate ranking";
      "Total missed gain across all 12 symbols × 27y. The mode with the \
       largest [Total missed gain] dominates and is the priority candidate for \
       a targeted fix.";
      aggregate_table;
      "## Exit-reason histogram (sanity check)";
      "Distribution of exit reasons across all classified trades. Should be \
       dominated by [Stage3_exit] (canonical Stage 2→3 transition) with a \
       small [End_of_period] tail (one per symbol whose window closes with an \
       open position). [Stop_out], [Stage4_decline], and [Laggard_rotation] \
       should all be ZERO under this strategy.";
      exit_histogram;
    ]

(** Markdown formatting of a trade-audit report. See [.mli]. *)

open Core
module Split_safe = Backtest.Split_safe_metric
module Trade_audit_ratings = Trade_audit_ratings
open Trade_audit_report_types

let _stage_label (s : Weinstein_types.stage) =
  match s with
  | Stage1 _ -> "Stage1"
  | Stage2 _ -> "Stage2"
  | Stage3 _ -> "Stage3"
  | Stage4 _ -> "Stage4"

let _rs_trend_label (rs : Weinstein_types.rs_trend) =
  match rs with
  | Bullish_crossover -> "Bullish_xover"
  | Positive_rising -> "Pos_rising"
  | Positive_flat -> "Pos_flat"
  | Positive_declining -> "Pos_declining"
  | Negative_improving -> "Neg_improving"
  | Negative_declining -> "Neg_declining"
  | Bearish_crossover -> "Bearish_xover"

let _macro_label (m : Weinstein_types.market_trend) =
  match m with
  | Bullish -> "Bullish"
  | Bearish -> "Bearish"
  | Neutral -> "Neutral"

let _side_label (s : Trading_base.Types.position_side) =
  match s with Long -> "Long" | Short -> "Short"

let _opt_label f = function Some v -> f v | None -> "—"
let _opt_int = function Some i -> Int.to_string i | None -> "—"
let _opt_date = function Some d -> Date.to_string d | None -> "—"
let _opt_string = function Some s -> s | None -> "—"
let _fmt_float_2 v = sprintf "%.2f" v
let _fmt_pct v = sprintf "%+.2f%%" v
let _fmt_pct_unsigned v = sprintf "%.1f%%" v

(* [execution_faithfulness.fill_vs_trigger_pct] is a signed *fraction*
   ([(fill -. trigger) /. trigger]); scale to a percentage for display. *)
let _fmt_fill_vs_trigger = function
  | Some fraction -> _fmt_pct (fraction *. 100.0)
  | None -> "" (* blank cell when the entry had no execution record *)

(* Byte glyphs: ✓ = U+2713, ✗ = U+2717, em-dash = U+2014 (the None placeholder
   used elsewhere in the table). *)
let _fmt_faithful = function
  | Some true -> "\xe2\x9c\x93"
  | Some false -> "\xe2\x9c\x97"
  | None -> "\xe2\x80\x94"

let _format_header (h : scenario_header) : string list =
  let title =
    sprintf "# Trade audit \xe2\x80\x94 %s" (_opt_string h.scenario_name)
  in
  [
    title;
    "";
    sprintf "- Period: %s \xe2\x86\x92 %s" (_opt_date h.period_start)
      (_opt_date h.period_end);
    sprintf "- Universe: %s" (_opt_int h.universe_size);
    sprintf "- Total round-trips: %d" h.total_round_trips;
    sprintf "- Winners: %d / %d (%s)" h.winners h.total_round_trips
      (_fmt_pct_unsigned h.win_rate_pct);
    sprintf "- Total realized return (sum of pnl%%): %s"
      (_fmt_pct h.total_realized_return_pct);
    "";
  ]

(* One-line execution-faithfulness rollup across every row that carried an
   [execution] record. Returns [[]] when no row had one, so the aggregate block
   is byte-identical to a pre-execution report; the [fill_vs_trigger] mean is a
   fraction (scaled to a percentage for display, matching the per-row column). *)
let _execution_summary_line (rows : per_trade_row list) : string list =
  let execs =
    List.filter_map rows ~f:(fun (r : per_trade_row) ->
        match (r.faithful, r.fill_vs_trigger_pct) with
        | Some faithful, Some fraction -> Some (faithful, fraction)
        | _ -> None)
  in
  match execs with
  | [] -> []
  | _ ->
      let n = List.length execs in
      let faithful_count =
        List.count execs ~f:(fun (faithful, _) -> faithful)
      in
      let faithful_pct =
        Float.of_int faithful_count /. Float.of_int n *. 100.0
      in
      let mean_fraction =
        List.fold execs ~init:0.0 ~f:(fun acc (_, fraction) -> acc +. fraction)
        /. Float.of_int n
      in
      [
        sprintf "- Execution: %d records, %s faithful, mean fill_vs_trigger %s"
          n
          (_fmt_pct_unsigned faithful_pct)
          (_fmt_pct (mean_fraction *. 100.0));
      ]

let _format_aggregate (bw : best_worst) (rows : per_trade_row list) :
    string list =
  let fmt_triple = function
    | None -> "—"
    | Some (sym, d, pct) ->
        sprintf "%s %s \xe2\x86\x92 %s" sym (Date.to_string d) (_fmt_pct pct)
  in
  [
    "## Aggregate summary";
    "";
    sprintf "- Best trade: %s" (fmt_triple bw.best);
    sprintf "- Worst trade: %s" (fmt_triple bw.worst);
  ]
  @ _execution_summary_line rows
  @ [ "" ]

let _row_cells (r : per_trade_row) =
  [
    r.symbol;
    Date.to_string r.entry_date;
    _side_label r.side;
    _fmt_float_2 r.entry_price;
    Date.to_string r.exit_date;
    _fmt_float_2 r.exit_price;
    Int.to_string r.days_held;
    _fmt_float_2 r.pnl_dollars;
    _fmt_pct r.pnl_percent;
    (if String.is_empty r.exit_trigger then "—" else r.exit_trigger);
    _opt_label _stage_label r.entry_stage;
    _opt_label _rs_trend_label r.entry_rs_trend;
    _opt_label _macro_label r.entry_macro_trend;
    _opt_label Weinstein_types.grade_to_string r.cascade_grade;
    _opt_int r.cascade_score;
    _fmt_fill_vs_trigger r.fill_vs_trigger_pct;
    _fmt_faithful r.faithful;
  ]

let _format_row r =
  let cells = _row_cells r in
  "| " ^ String.concat ~sep:" | " cells ^ " |"

let _format_table_header () =
  [
    "| symbol | entry_date | side | entry_px | exit_date | exit_px | days | \
     pnl_$ | pnl_% | exit_trigger | stage | rs | macro | grade | score | \
     fill_vs_trig | faithful |";
    "|---|---|---|---:|---|---:|---:|---:|---:|---|---|---|---|---|---:|---:|---|";
  ]

let _format_table (rows : per_trade_row list) : string list =
  let head = "## Per-trade table" :: "" :: _format_table_header () in
  let body =
    if List.is_empty rows then [ "_No trades._" ]
    else List.map rows ~f:_format_row
  in
  head @ body @ [ "" ]

(* Which of the three causes put the population in [Not_exercised]. The order
   mirrors {!Backtest.Split_safe_metric.inertness}: a [flag_off] count is the
   loudest signal (the flag never reached the scan at all) and so is reported
   first even when empty windows are also present. *)
let _not_exercised_cause (tally : Split_safe.tally) =
  if tally.flag_off > 0 then
    sprintf
      "%d decision(s) carry flag_off, so none reached the basis choice. In a \
       run configured split_safe_floors=true that is a wiring alarm, not a \
       data point."
      tally.flag_off
  else if tally.empty_window > 0 then
    sprintf
      "the flag reached the scan, but all %d lookback window(s) were empty — \
       the mechanism ran with nothing to act on, so this run has no exposure \
       to it."
      tally.empty_window
  else "no entry decisions were captured, so this run says nothing either way."

(* Always emitted. An omitted section is indistinguishable from an arm that was
   inert, which is precisely the confusion [Split_safe_metric.inertness]
   exists to prevent — so the undefined case gets prose, never a percentage and
   never a blank. *)
let _format_split_safe (tally : Split_safe.tally) : string list =
  let total =
    tally.flag_off + tally.adjusted + tally.raw_fallback + tally.empty_window
  in
  let counts =
    sprintf
      "- Basis of %d entry decision(s): adjusted %d, raw_fallback %d, flag_off \
       %d, empty_window %d"
      total tally.adjusted tally.raw_fallback tally.flag_off tally.empty_window
  in
  let inertness =
    match Split_safe.inertness_of_tally tally with
    | Split_safe.Inert_fraction f ->
        sprintf
          "- Inert fraction (raw_fallback / (raw_fallback + adjusted)): %s"
          (_fmt_pct_unsigned (f *. 100.0))
    | Split_safe.Not_exercised t ->
        sprintf
          "- Inert fraction: NOT EXERCISED \xe2\x80\x94 the denominator is \
           zero, so there is no measurement here; this is not zero inertness. \
           %s"
          (_not_exercised_cause t)
  in
  [ "## Split-safe floor basis"; ""; counts; inertness; "" ]

let _format_analysis (a : analysis) : string list =
  Trade_audit_ratings.format_per_trade_extras ~ratings:a.ratings
  @ Trade_audit_ratings.format_behavioral_section a.behavioral
  @ Trade_audit_ratings.format_weinstein_section a.weinstein
  @ Trade_audit_ratings.format_decision_quality_section a.decision_quality

let to_markdown (t : t) : string =
  let core_lines =
    _format_header t.header
    @ _format_aggregate t.best_worst t.rows
    @ _format_table t.rows
    @ _format_split_safe t.split_safe_tally
  in
  let analysis_lines =
    match t.analysis with Some a -> _format_analysis a | None -> []
  in
  String.concat ~sep:"\n" (core_lines @ analysis_lines) ^ "\n"

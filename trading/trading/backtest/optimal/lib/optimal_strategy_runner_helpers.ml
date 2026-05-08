open Core
module Snapshot_bar_views = Snapshot_runtime.Snapshot_bar_views
module Scanner = Stage_transition_scanner
module Scorer = Outcome_scorer
module OT = Optimal_types

(* ---------------------------------------------------------------- *)
(* Shared constants                                                   *)
(* ---------------------------------------------------------------- *)

let index_symbol = "GSPC.INDX"

(** Weekly-bar lookback per per-Friday analysis. Large enough to cover the
    30-week MA + breakout-base lookback in [Stock_analysis.default_config]. *)
let bar_lookback_weeks = 90

(* ---------------------------------------------------------------- *)
(* Friday calendar                                                    *)
(* ---------------------------------------------------------------- *)

(** Resolve the most recent Friday on or before [d]. *)
let friday_on_or_before (d : Date.t) : Date.t =
  let dow = Date.day_of_week d in
  let offset =
    match dow with
    | Day_of_week.Mon -> 3
    | Day_of_week.Tue -> 4
    | Day_of_week.Wed -> 5
    | Day_of_week.Thu -> 6
    | Day_of_week.Fri -> 0
    | Day_of_week.Sat -> 1
    | Day_of_week.Sun -> 2
  in
  Date.add_days d (-offset)

(** All Fridays in [start, end_], inclusive on each end where a Friday lies in
    range. Drives the per-week scan loop. *)
let fridays_in_range ~start ~end_ : Date.t list =
  let first_fri =
    let f = friday_on_or_before start in
    if Date.( < ) f start then Date.add_days f 7 else f
  in
  let rec loop d acc =
    if Date.( > ) d end_ then List.rev acc
    else loop (Date.add_days d 7) (d :: acc)
  in
  loop first_fri []

(* ---------------------------------------------------------------- *)
(* Per-Friday analysis                                                *)
(* ---------------------------------------------------------------- *)

(** Run [Stock_analysis.analyze] for one symbol on one Friday. Returns [None]
    when there are not enough bars for the analysis (e.g. early in the run). *)
let analyze_symbol_on_friday ~snapshot_callbacks ~friday ~stock_config
    ~bar_lookback (symbol : string) : Stock_analysis.t option =
  let weekly =
    Snapshot_bar_views.weekly_bars_for snapshot_callbacks ~symbol
      ~n:bar_lookback ~as_of:friday
  in
  let benchmark =
    Snapshot_bar_views.weekly_bars_for snapshot_callbacks ~symbol:index_symbol
      ~n:bar_lookback ~as_of:friday
  in
  match (weekly, benchmark) with
  | [], _ | _, [] -> None
  | _ ->
      Some
        (Stock_analysis.analyze ~config:stock_config ~ticker:symbol ~bars:weekly
           ~benchmark_bars:benchmark ~prior_stage:None ~as_of_date:friday)

(** Pass-through sector context used by the counterfactual. [Neutral] rating and
    [Stage2] stage because sector caps are handled separately via the filler's
    [max_sector_concentration]. *)
let _neutral_ctx (sector_name : string) : Screener.sector_context =
  {
    sector_name;
    rating = Screener.Neutral;
    stage = Stage2 { weeks_advancing = 4; late = false };
  }

(** Build a [sector_map] (symbol -> [Screener.sector_context]) from a flat
    [sectors : (symbol -> sector_name)] table. The screener's sector-context
    expects a [rating] and [stage] per sector; we use [Neutral] / [Stage2] as
    pass-throughs because the counterfactual treats sector caps separately (via
    the filler's [max_sector_concentration]). *)
let build_sector_context_map (sectors : (string, string) Hashtbl.t) :
    (string, Screener.sector_context) Hashtbl.t =
  let out = Hashtbl.create (module String) in
  Hashtbl.iteri sectors ~f:(fun ~key ~data ->
      Hashtbl.set out ~key ~data:(_neutral_ctx data));
  out

(* ---------------------------------------------------------------- *)
(* Forward-walk outlooks for the scorer                               *)
(* ---------------------------------------------------------------- *)

(** Compute one [Scorer.weekly_outlook] for [symbol] at [friday], or [None] when
    the symbol has no weekly bars at that Friday. *)
let _outlook_at ~snapshot_callbacks ~stage_config ~bar_lookback ~symbol ~friday
    : Scorer.weekly_outlook option =
  let weekly =
    Snapshot_bar_views.weekly_bars_for snapshot_callbacks ~symbol
      ~n:bar_lookback ~as_of:friday
  in
  match List.last weekly with
  | None -> None
  | Some bar ->
      let stage_result =
        Stage.classify ~config:stage_config ~bars:weekly ~prior_stage:None
      in
      Some { Scorer.date = friday; bar; stage_result }

(** Collect the chronological outlook list for one [symbol] across all
    [fridays]. Factored out of [build_forward_table] to reduce nesting depth. *)
let _outlooks_for_symbol ~snapshot_callbacks ~fridays ~stage_config
    ~bar_lookback ~symbol =
  List.filter_map fridays ~f:(fun friday ->
      _outlook_at ~snapshot_callbacks ~stage_config ~bar_lookback ~symbol
        ~friday)

(** Build the per-symbol forward-outlook table (PR-1). Iterates [fridays] once
    per symbol and memoizes the full chronological outlook list. Sized to
    [List.length universe] for predictable hashtable growth. *)
let build_forward_table ~snapshot_callbacks ~fridays ~stage_config ~bar_lookback
    ~universe : (string, Scorer.weekly_outlook list) Hashtbl.t =
  let table = Hashtbl.create ~size:(List.length universe) (module String) in
  List.iter universe ~f:(fun symbol ->
      let outlooks =
        _outlooks_for_symbol ~snapshot_callbacks ~fridays ~stage_config
          ~bar_lookback ~symbol
      in
      Hashtbl.set table ~key:symbol ~data:outlooks);
  table

(* ---------------------------------------------------------------- *)
(* Scanning all candidates                                            *)
(* ---------------------------------------------------------------- *)

(** Run the scanner for a single [friday], collecting per-symbol analyses and
    looking up the macro trend. Factored out of [scan_all_fridays] to reduce
    nesting depth. *)
let _scan_one_friday ~snapshot_callbacks ~friday ~universe ~sector_map
    ~stock_config ~scanner_config ~bar_lookback ~macro_trend_table :
    OT.candidate_entry list =
  let analyses =
    List.filter_map universe ~f:(fun sym ->
        analyze_symbol_on_friday ~snapshot_callbacks ~friday ~stock_config
          ~bar_lookback sym)
  in
  let macro_trend =
    Hashtbl.find macro_trend_table friday
    |> Option.value ~default:Weinstein_types.Neutral
  in
  let week : Scanner.week_input =
    { date = friday; macro_trend; analyses; sector_map }
  in
  Scanner.scan_week ~config:scanner_config week

(** Run the scanner over all Fridays in the run and emit candidates. Each week's
    [macro_trend] is sourced from [macro_trend_table] (built from the run's
    [macro_trend.sexp]); Fridays absent from the table fall back to [Neutral].
*)
let scan_all_fridays ~snapshot_callbacks ~fridays ~universe ~sector_map
    ~stock_config ~scanner_config ~bar_lookback ~macro_trend_table :
    OT.candidate_entry list =
  List.concat_map fridays ~f:(fun friday ->
      _scan_one_friday ~snapshot_callbacks ~friday ~universe ~sector_map
        ~stock_config ~scanner_config ~bar_lookback ~macro_trend_table)

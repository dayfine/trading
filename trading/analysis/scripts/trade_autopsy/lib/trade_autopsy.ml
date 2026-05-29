open Core
module Walk_step = Per_symbol_stage_strategy_lib.Walk_step

type trade_side = Long_side | Short_side [@@deriving show, eq, sexp]

(* Re-export of {!Exit_reason.t} so the autopsy record type can carry an
   [exit_reason] field and downstream consumers can pattern-match using
   [Trade_autopsy.<Variant>] without taking on a direct [Exit_reason]
   dependency. The manifest re-export carries the deriving signatures
   through. *)
type exit_reason = Exit_reason.t =
  | Stage3_exit
  | Stage1_cover_short
  | End_of_period
  | Stop_out
  | Stage4_decline
  | Laggard_rotation
[@@deriving show, eq, sexp]

type failure_modes = {
  stage3_false_positive : bool;
  late_reentry : bool;
  late_stage2_admission : bool;
  stop_out_whipsaw : bool;
}
[@@deriving show, eq, sexp]

type trade_autopsy = {
  symbol : string;
  side : trade_side;
  entry_date : Date.t;
  exit_date : Date.t;
  entry_price : float;
  exit_price : float;
  return_pct : float;
  exit_reason : exit_reason;
  weeks_held : int;
  missed_gain_pct : float;
  next_entry_date : Date.t option;
  weeks_to_reentry : int option;
  weeks_since_cyclical_low : int option;
  modes : failure_modes;
}
[@@deriving show, sexp]

type mode_summary = {
  mode_name : string;
  trade_count : int;
  total_missed_gain_pct : float;
  avg_missed_gain_pct : float;
}
[@@deriving show, sexp]

type per_symbol_breakdown = {
  symbol : string;
  num_trades : int;
  stage3_false_positive_missed_gain : float;
  late_reentry_missed_gain : float;
  late_stage2_admission_missed_gain : float;
  stop_out_whipsaw_missed_gain : float;
}
[@@deriving show, sexp]

(* ------------------------------------------------------------------ *)
(* Trade-side conversion                                               *)
(* ------------------------------------------------------------------ *)

let _side_of_walk_trade (t : Walk_step.trade) =
  match t.variant_side with `Long -> Long_side | `Short -> Short_side

(* ------------------------------------------------------------------ *)
(* Per-trade autopsy assembly                                          *)
(* ------------------------------------------------------------------ *)

let _classify_modes ~config ~weekly_bars ~exit_reason ~weeks_to_reentry
    ~missed_gain_pct ~weeks_since_cyclical_low ~trade =
  {
    stage3_false_positive =
      Classifiers.stage3_false_positive ~config ~weekly_bars ~exit_reason ~trade;
    late_reentry =
      Classifiers.late_reentry ~config ~weeks_to_reentry ~missed_gain_pct;
    late_stage2_admission =
      Classifiers.late_stage2 ~config ~weeks_since_cyclical_low ~trade;
    stop_out_whipsaw =
      Classifiers.stop_whipsaw ~config ~weekly_bars ~exit_reason ~trade;
  }

let _autopsy_one_trade ~config ~symbol ~weekly_bars ~trades ~final_bar_date
    ~(trade : Walk_step.trade) =
  let exit_reason = Exit_reason.derive ~final_bar_date ~trade in
  let missed_gain_pct, next_entry_date, weeks_to_reentry =
    Classifiers.compute_missed_gain_and_reentry ~weekly_bars ~trades
      ~exit_reason ~trade
  in
  let weeks_since_cyclical_low =
    Classifiers.weeks_since_cyclical_low ~config ~weekly_bars ~trade
  in
  let modes =
    _classify_modes ~config ~weekly_bars ~exit_reason ~weeks_to_reentry
      ~missed_gain_pct ~weeks_since_cyclical_low ~trade
  in
  {
    symbol;
    side = _side_of_walk_trade trade;
    entry_date = trade.entry_date;
    exit_date = trade.exit_date;
    entry_price = trade.entry_price;
    exit_price = trade.exit_price;
    return_pct = trade.return_pct;
    exit_reason;
    weeks_held = Classifiers.weeks_held ~weekly_bars ~trade;
    missed_gain_pct;
    next_entry_date;
    weeks_to_reentry;
    weeks_since_cyclical_low;
    modes;
  }

let _autopsy_all ~config ~symbol ~weekly_bars ~trades ~final_bar_date =
  List.map trades ~f:(fun trade ->
      _autopsy_one_trade ~config ~symbol ~weekly_bars ~trades ~final_bar_date
        ~trade)

let classify_trades ~config ~symbol ~weekly_bars ~trades =
  match List.last weekly_bars with
  | None -> []
  | Some final ->
      let final_bar_date = final.Types.Daily_price.date in
      _autopsy_all ~config ~symbol ~weekly_bars ~trades ~final_bar_date

(* ------------------------------------------------------------------ *)
(* Aggregation                                                         *)
(* ------------------------------------------------------------------ *)

let _summarize_one ~mode_name ~mode_selector ~autopsies =
  let matching = List.filter autopsies ~f:(fun a -> mode_selector a.modes) in
  let trade_count = List.length matching in
  let total_missed_gain_pct =
    List.fold matching ~init:0.0 ~f:(fun acc a -> acc +. a.missed_gain_pct)
  in
  let avg_missed_gain_pct =
    if trade_count = 0 then 0.0
    else total_missed_gain_pct /. Float.of_int trade_count
  in
  { mode_name; trade_count; total_missed_gain_pct; avg_missed_gain_pct }

let summarize autopsies =
  [
    _summarize_one ~mode_name:"stage3_false_positive"
      ~mode_selector:(fun m -> m.stage3_false_positive)
      ~autopsies;
    _summarize_one ~mode_name:"late_reentry"
      ~mode_selector:(fun m -> m.late_reentry)
      ~autopsies;
    _summarize_one ~mode_name:"late_stage2_admission"
      ~mode_selector:(fun m -> m.late_stage2_admission)
      ~autopsies;
    _summarize_one ~mode_name:"stop_out_whipsaw"
      ~mode_selector:(fun m -> m.stop_out_whipsaw)
      ~autopsies;
  ]

let _sum_when ~selector autopsies =
  List.fold autopsies ~init:0.0 ~f:(fun acc a ->
      if selector a.modes then acc +. a.missed_gain_pct else acc)

let breakdown_for_symbol ~symbol autopsies =
  {
    symbol;
    num_trades = List.length autopsies;
    stage3_false_positive_missed_gain =
      _sum_when ~selector:(fun m -> m.stage3_false_positive) autopsies;
    late_reentry_missed_gain =
      _sum_when ~selector:(fun m -> m.late_reentry) autopsies;
    late_stage2_admission_missed_gain =
      _sum_when ~selector:(fun m -> m.late_stage2_admission) autopsies;
    stop_out_whipsaw_missed_gain =
      _sum_when ~selector:(fun m -> m.stop_out_whipsaw) autopsies;
  }

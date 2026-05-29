open Core
module Walk_step = Per_symbol_stage_strategy_lib.Walk_step

type trade_side = Long_side | Short_side [@@deriving show, eq, sexp]

type exit_reason =
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
(* Exit-reason derivation                                             *)
(* ------------------------------------------------------------------ *)

(* The per-symbol stage strategy has no stops and no Stage4-skip path; those
   exit-reason variants exist for schema completeness but are never produced
   here. Trades whose exit_date matches the final bar are force-closes; all
   other long trades exit via Stage 2→3; all other short trades cover via
   Stage 4→1. *)
let _derive_exit_reason ~final_bar_date ~(trade : Walk_step.trade) =
  if Date.equal trade.exit_date final_bar_date then End_of_period
  else
    match trade.variant_side with
    | `Long -> Stage3_exit
    | `Short -> Stage1_cover_short

(* ------------------------------------------------------------------ *)
(* Failure-mode classification                                         *)
(* ------------------------------------------------------------------ *)

(* Stage 3 false positive: exit_reason = Stage3_exit AND the symbol's close
   [stage3_recovery_weeks] later is >= (exit_price * (1 +
   stage3_recovery_pct)). End-of-period trades are NOT counted (no forward
   window to evaluate). *)
let _classify_stage3_false_positive ~config ~weekly_bars ~exit_reason
    ~(trade : Walk_step.trade) =
  match exit_reason with
  | Stage3_exit -> (
      match
        Missed_gain.close_at_offset ~bars:weekly_bars
          ~anchor_date:trade.exit_date
          ~weeks:config.Trade_autopsy_config.stage3_recovery_weeks
      with
      | None -> false
      | Some recovery_close ->
          let threshold =
            trade.exit_price *. (1.0 +. config.stage3_recovery_pct)
          in
          Float.( >= ) recovery_close threshold)
  | _ -> false

let _classify_late_reentry ~config ~weeks_to_reentry ~missed_gain_pct =
  match weeks_to_reentry with
  | None -> false
  | Some w ->
      let weeks_exceed = w > config.Trade_autopsy_config.late_reentry_weeks in
      let gain_exceed = Float.( >= ) missed_gain_pct config.late_reentry_pct in
      weeks_exceed && gain_exceed

(* Only LONG entries can be late Stage 2 admissions. *)
let _classify_late_stage2 ~config ~weeks_since_cyclical_low
    ~(trade : Walk_step.trade) =
  match trade.variant_side with
  | `Short -> false
  | `Long -> (
      match weeks_since_cyclical_low with
      | None -> false
      | Some w -> w > config.Trade_autopsy_config.late_stage2_weeks)

let _classify_stop_whipsaw ~config ~weekly_bars ~exit_reason
    ~(trade : Walk_step.trade) =
  match exit_reason with
  | Stop_out -> (
      match
        Missed_gain.close_at_offset ~bars:weekly_bars
          ~anchor_date:trade.exit_date
          ~weeks:config.Trade_autopsy_config.stop_whipsaw_weeks
      with
      | None -> false
      | Some recovery_close ->
          let threshold =
            trade.exit_price *. (1.0 +. config.stop_whipsaw_pct)
          in
          Float.( >= ) recovery_close threshold)
  | _ -> false

(* ------------------------------------------------------------------ *)
(* Missed-gain computation                                             *)
(* ------------------------------------------------------------------ *)

(* For long trades: missed_gain_pct = (reference_price - exit_price) /
   exit_price (positive = missed upside). For short trades: inverted
   (positive = missed downside the short would have captured). *)
let _compute_missed_gain ~exit_price ~reference_price ~side =
  let raw = (reference_price -. exit_price) /. exit_price in
  match side with `Long -> raw | `Short -> -.raw

let _find_same_side_next_entry ~trades ~side ~exit_date =
  let same_side =
    List.filter trades ~f:(fun (t : Walk_step.trade) ->
        match (t.variant_side, side) with
        | `Long, `Long | `Short, `Short -> true
        | _ -> false)
  in
  Missed_gain.next_entry_after ~trades:same_side
    ~trade_entry_date:(fun (t : Walk_step.trade) -> t.entry_date)
    ~after_date:exit_date

let _weeks_between ~bars ~from_date ~to_date =
  match
    ( List.findi bars ~f:(fun _ b ->
          Date.equal b.Types.Daily_price.date from_date),
      List.findi bars ~f:(fun _ b ->
          Date.equal b.Types.Daily_price.date to_date) )
  with
  | Some (i, _), Some (j, _) -> Some (j - i)
  | _ -> None

(* Reference price for missed-gain: either (a) the next same-side entry
   price, if such an entry exists, or (b) the end-of-window close, if no
   same-side re-entry happens. End-of-period trades report missed_gain =
   0.0 — there is no forward window to evaluate. *)
let _compute_missed_gain_and_reentry ~weekly_bars ~trades ~exit_reason
    ~(trade : Walk_step.trade) =
  match exit_reason with
  | End_of_period -> (0.0, None, None)
  | _ -> (
      let next_opt =
        _find_same_side_next_entry ~trades ~side:trade.variant_side
          ~exit_date:trade.exit_date
      in
      match next_opt with
      | Some (next_trade : Walk_step.trade) ->
          let missed =
            _compute_missed_gain ~exit_price:trade.exit_price
              ~reference_price:next_trade.entry_price ~side:trade.variant_side
          in
          let weeks_to_reentry =
            _weeks_between ~bars:weekly_bars ~from_date:trade.exit_date
              ~to_date:next_trade.entry_date
          in
          (missed, Some next_trade.entry_date, weeks_to_reentry)
      | None -> (
          match Missed_gain.close_at_end ~bars:weekly_bars with
          | None -> (0.0, None, None)
          | Some end_close ->
              let missed =
                _compute_missed_gain ~exit_price:trade.exit_price
                  ~reference_price:end_close ~side:trade.variant_side
              in
              (missed, None, None)))

(* ------------------------------------------------------------------ *)
(* Per-trade autopsy assembly                                          *)
(* ------------------------------------------------------------------ *)

let _weeks_held ~weekly_bars ~(trade : Walk_step.trade) =
  match
    _weeks_between ~bars:weekly_bars ~from_date:trade.entry_date
      ~to_date:trade.exit_date
  with
  | Some w -> w
  | None -> 0

let _weeks_since_cyclical_low ~config ~weekly_bars ~(trade : Walk_step.trade) =
  match trade.variant_side with
  | `Short -> None
  | `Long -> (
      match
        Missed_gain.cyclical_low_close_before ~bars:weekly_bars
          ~entry_date:trade.entry_date
          ~lookback_weeks:config.Trade_autopsy_config.late_stage2_lookback_weeks
      with
      | None -> None
      | Some (low_date, _) ->
          _weeks_between ~bars:weekly_bars ~from_date:low_date
            ~to_date:trade.entry_date)

let _classify_modes ~config ~weekly_bars ~exit_reason ~weeks_to_reentry
    ~missed_gain_pct ~weeks_since_cyclical_low ~trade =
  {
    stage3_false_positive =
      _classify_stage3_false_positive ~config ~weekly_bars ~exit_reason ~trade;
    late_reentry =
      _classify_late_reentry ~config ~weeks_to_reentry ~missed_gain_pct;
    late_stage2_admission =
      _classify_late_stage2 ~config ~weeks_since_cyclical_low ~trade;
    stop_out_whipsaw =
      _classify_stop_whipsaw ~config ~weekly_bars ~exit_reason ~trade;
  }

let _autopsy_one_trade ~config ~symbol ~weekly_bars ~trades ~final_bar_date
    ~(trade : Walk_step.trade) =
  let exit_reason = _derive_exit_reason ~final_bar_date ~trade in
  let missed_gain_pct, next_entry_date, weeks_to_reentry =
    _compute_missed_gain_and_reentry ~weekly_bars ~trades ~exit_reason ~trade
  in
  let weeks_since_cyclical_low =
    _weeks_since_cyclical_low ~config ~weekly_bars ~trade
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
    weeks_held = _weeks_held ~weekly_bars ~trade;
    missed_gain_pct;
    next_entry_date;
    weeks_to_reentry;
    weeks_since_cyclical_low;
    modes;
  }

let classify_trades ~config ~symbol ~weekly_bars ~trades =
  match List.last weekly_bars with
  | None -> []
  | Some final ->
      let final_bar_date = final.Types.Daily_price.date in
      List.map trades ~f:(fun trade ->
          _autopsy_one_trade ~config ~symbol ~weekly_bars ~trades
            ~final_bar_date ~trade)

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

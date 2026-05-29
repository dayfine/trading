open Core
module Walk_step = Per_symbol_stage_strategy_lib.Walk_step

type weekly_bar = Types.Daily_price.t

(* ------------------------------------------------------------------ *)
(* Bar-index distance helpers                                          *)
(* ------------------------------------------------------------------ *)

let weeks_between ~bars ~from_date ~to_date =
  match
    ( List.findi bars ~f:(fun _ b ->
          Date.equal b.Types.Daily_price.date from_date),
      List.findi bars ~f:(fun _ b ->
          Date.equal b.Types.Daily_price.date to_date) )
  with
  | Some (i, _), Some (j, _) -> Some (j - i)
  | _ -> None

let weeks_held ~weekly_bars ~(trade : Walk_step.trade) =
  match
    weeks_between ~bars:weekly_bars ~from_date:trade.entry_date
      ~to_date:trade.exit_date
  with
  | Some w -> w
  | None -> 0

(* Long-trade arm of [weeks_since_cyclical_low], extracted to keep the
   exported function shallow. *)
let _weeks_since_cyclical_low_long ~config ~weekly_bars
    ~(trade : Walk_step.trade) =
  match
    Missed_gain.cyclical_low_close_before ~bars:weekly_bars
      ~entry_date:trade.entry_date
      ~lookback_weeks:config.Trade_autopsy_config.late_stage2_lookback_weeks
  with
  | None -> None
  | Some (low_date, _) ->
      weeks_between ~bars:weekly_bars ~from_date:low_date
        ~to_date:trade.entry_date

let weeks_since_cyclical_low ~config ~weekly_bars ~(trade : Walk_step.trade) =
  match trade.variant_side with
  | `Short -> None
  | `Long -> _weeks_since_cyclical_low_long ~config ~weekly_bars ~trade

(* ------------------------------------------------------------------ *)
(* Missed-gain computation                                             *)
(* ------------------------------------------------------------------ *)

(* For long trades: missed_gain_pct = (reference_price - exit_price) /
   exit_price (positive = missed upside). For short trades: inverted
   (positive = missed downside the short would have captured). *)
let _missed_gain_signed ~exit_price ~reference_price ~side =
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

(* When a same-side re-entry exists, missed_gain is the price-change from exit
   to the re-entry. *)
let _missed_with_next_entry ~weekly_bars ~(trade : Walk_step.trade)
    ~(next_trade : Walk_step.trade) =
  let missed =
    _missed_gain_signed ~exit_price:trade.exit_price
      ~reference_price:next_trade.entry_price ~side:trade.variant_side
  in
  let weeks_to_reentry =
    weeks_between ~bars:weekly_bars ~from_date:trade.exit_date
      ~to_date:next_trade.entry_date
  in
  (missed, Some next_trade.entry_date, weeks_to_reentry)

(* When no same-side re-entry exists, missed_gain is the price-change from
   exit to the end-of-window close. *)
let _missed_with_window_end ~weekly_bars ~(trade : Walk_step.trade) =
  match Missed_gain.close_at_end ~bars:weekly_bars with
  | None -> (0.0, None, None)
  | Some end_close ->
      let missed =
        _missed_gain_signed ~exit_price:trade.exit_price
          ~reference_price:end_close ~side:trade.variant_side
      in
      (missed, None, None)

let compute_missed_gain_and_reentry ~weekly_bars ~trades ~exit_reason
    ~(trade : Walk_step.trade) =
  match (exit_reason : Exit_reason.t) with
  | End_of_period -> (0.0, None, None)
  | _ -> (
      match
        _find_same_side_next_entry ~trades ~side:trade.variant_side
          ~exit_date:trade.exit_date
      with
      | Some next_trade ->
          _missed_with_next_entry ~weekly_bars ~trade ~next_trade
      | None -> _missed_with_window_end ~weekly_bars ~trade)

(* ------------------------------------------------------------------ *)
(* Per-mode classifiers                                                *)
(* ------------------------------------------------------------------ *)

(* Shared shape for the two "recovery-after-exit" classifiers: look up the
   close [weeks] later and test it against [exit_price * (1 + recovery_pct)].
   Returns [false] if no such forward bar exists. *)
let _recovery_above_threshold ~weekly_bars ~(trade : Walk_step.trade) ~weeks
    ~recovery_pct =
  match
    Missed_gain.close_at_offset ~bars:weekly_bars ~anchor_date:trade.exit_date
      ~weeks
  with
  | None -> false
  | Some recovery_close ->
      let threshold = trade.exit_price *. (1.0 +. recovery_pct) in
      Float.( >= ) recovery_close threshold

let stage3_false_positive ~config ~weekly_bars ~exit_reason
    ~(trade : Walk_step.trade) =
  match (exit_reason : Exit_reason.t) with
  | Stage3_exit ->
      _recovery_above_threshold ~weekly_bars ~trade
        ~weeks:config.Trade_autopsy_config.stage3_recovery_weeks
        ~recovery_pct:config.stage3_recovery_pct
  | _ -> false

let late_reentry ~config ~weeks_to_reentry ~missed_gain_pct =
  match weeks_to_reentry with
  | None -> false
  | Some w ->
      let weeks_exceed = w > config.Trade_autopsy_config.late_reentry_weeks in
      let gain_exceed = Float.( >= ) missed_gain_pct config.late_reentry_pct in
      weeks_exceed && gain_exceed

let late_stage2 ~config ~weeks_since_cyclical_low ~(trade : Walk_step.trade) =
  match trade.variant_side with
  | `Short -> false
  | `Long -> (
      match weeks_since_cyclical_low with
      | None -> false
      | Some w -> w > config.Trade_autopsy_config.late_stage2_weeks)

let stop_whipsaw ~config ~weekly_bars ~exit_reason ~(trade : Walk_step.trade) =
  match (exit_reason : Exit_reason.t) with
  | Stop_out ->
      _recovery_above_threshold ~weekly_bars ~trade
        ~weeks:config.Trade_autopsy_config.stop_whipsaw_weeks
        ~recovery_pct:config.stop_whipsaw_pct
  | _ -> false

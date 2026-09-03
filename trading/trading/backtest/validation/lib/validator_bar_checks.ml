open Core
open Validator_types
open Validator_step

(* ---- V9: entry beneath overhead supply --------------------------------- *)

let _v9_detail top (c : check_config) (row : trade_row) =
  sprintf "prior_top=%.2f within +%.0f%% of entry=%.2f" top
    (100.0 *. c.overhead_pct) row.entry_price

let _v9_top (c : check_config) (row : trade_row) prior =
  match Array.max_elt prior ~compare:Float.compare with
  | Some top
    when Float.( < ) row.entry_price top
         && Float.( <= ) top (row.entry_price *. (1.0 +. c.overhead_pct)) ->
      Fail (spec row (_v9_detail top c row))
  | _ -> Pass

let _v9_pred (c : check_config) (row : trade_row) (b : bars) i =
  let lo = Int.max 0 (i - c.overhead_lookback_bars) in
  if i <= lo then Pass
  else _v9_top c row (Array.sub b.weekly_closes ~pos:lo ~len:(i - lo))

let check_v9 inputs =
  fold_steps (longs inputs)
    ~f:(wbars_step inputs ~pred:(_v9_pred inputs.config))

(* ---- V10: entry-week vertical spike ------------------------------------ *)

let _v10_detail (c : check_config) prev cur =
  sprintf "entry_wk_close=%.2f > prior=%.2f (spike>%.0f%%)" cur prev
    (100.0 *. c.spike_pct)

let _v10_check (c : check_config) (row : trade_row) prev cur =
  if Float.( > ) cur (prev *. (1.0 +. c.spike_pct)) then
    Fail (spec row (_v10_detail c prev cur))
  else Pass

let _v10_pred (c : check_config) (row : trade_row) (b : bars) i =
  if i < c.spike_lookback_weeks then Pass
  else
    _v10_check c row
      b.weekly_closes.(i - c.spike_lookback_weeks)
      b.weekly_closes.(i)

let check_v10 inputs =
  fold_steps (longs inputs)
    ~f:(wbars_step inputs ~pred:(_v10_pred inputs.config))

(* ---- V7: virgin-territory label vs available history ------------------- *)

let _is_virgin = function
  | Some Weinstein_types.Virgin_territory -> true
  | _ -> false

let _v7_detail hist (c : check_config) =
  sprintf "Virgin_territory but only %d weekly bars (< %d) before entry" hist
    c.virgin_lookback_bars

let _v7_hist (c : check_config) (row : trade_row) (b : bars) =
  let hist =
    Array.count b.weekly_dates ~f:(fun d -> Date.( < ) d row.entry_date)
  in
  if hist < c.virgin_lookback_bars then Fail (spec row (_v7_detail hist c))
  else Pass

let _v7_step inputs (c : check_config) (row : trade_row) =
  match (inputs.audit row, inputs.bars row.symbol) with
  | Some ctx, Some b when _is_virgin ctx.resistance_quality -> _v7_hist c row b
  | Some _, Some _ -> Pass
  | _ -> Skip

let check_v7 inputs =
  fold_steps (longs inputs) ~f:(_v7_step inputs inputs.config)

(* ---- V3: entry-week dollar-ADV floor (armed via config) ---------------- *)

let _v3_adv threshold (c : check_config) (b : bars) (row : trade_row) =
  match dollar_adv b ~as_of:row.entry_date ~lookback:c.adv_lookback_bars with
  | None -> Skip
  | Some adv when Float.( < ) adv threshold ->
      Fail (spec row (sprintf "entry dollar-ADV=%.0f < %.0f" adv threshold))
  | Some _ -> Pass

let _v3_step threshold inputs (row : trade_row) =
  match inputs.bars row.symbol with
  | None -> Skip
  | Some b -> _v3_adv threshold inputs.config b row

let check_v3 inputs =
  match inputs.config.min_entry_dollar_adv with
  | None -> empty_finding
  | Some t -> fold_steps (longs inputs) ~f:(_v3_step t inputs)

(* ---- V4: stale open position with no fresh bars (armed via config) ------ *)

let _v4_detail last_date gap run_end stale =
  sprintf "last bar %s is %dd before run_end %s (> %dd)"
    (Date.to_string last_date) gap (Date.to_string run_end) stale

let _v4_gap stale run_end (op : open_row) (b : bars) =
  let last_date = b.daily.(Array.length b.daily - 1).date in
  let gap = Date.diff run_end last_date in
  if gap > stale then
    Fail (open_spec op (_v4_detail last_date gap run_end stale))
  else Pass

let _v4_step stale inputs (op : open_row) =
  match inputs.bars op.symbol with
  | Some b when not (Array.is_empty b.daily) ->
      _v4_gap stale inputs.run_end op b
  | _ -> Skip

let check_v4 inputs =
  match inputs.config.stale_exit_after_days with
  | None -> empty_finding
  | Some stale -> fold_steps inputs.open_positions ~f:(_v4_step stale inputs)

(* ---- V13: fill dates and prices must lie on a real bar ----------------- *)

(* A fill can only happen on a day the symbol actually traded, at a price the
   day's range contains. The 26y arc run (dev/experiments/arc-rerun-2026-09-01
   §D1) dated 2,500+ exits on a SATURDAY at the preceding Friday's open — a
   fill on a day with no bar, at a price that predates the Friday-close
   decision. Nothing in V1-V12 could see it. *)

let _v13_missing_detail (b : bars) ~leg ~date =
  let nearest =
    match nearest_daily_date b date with
    | Some d -> Date.to_string d
    | None -> "none"
  in
  sprintf "no bar on %s_date %s (nearest earlier bar: %s)" leg
    (Date.to_string date) nearest

let _v13_range_detail ~leg ~price (bar : daily_bar) =
  sprintf "%s_price=%.4f outside %s bar [%.4f, %.4f]" leg price
    (Date.to_string bar.date) bar.low bar.high

let _v13_in_range (c : check_config) ~price (bar : daily_bar) =
  let eps = c.fill_price_epsilon_pct in
  Float.( >= ) price (bar.low *. (1.0 -. eps))
  && Float.( <= ) price (bar.high *. (1.0 +. eps))

(* Per-leg outcome. [Leg_waived] is un-evaluable rather than clean: the price
   leg is only meaningful when the stored bar shares the run's price basis, and
   a post-run re-basing of the CSV store shifts every price for the symbol at
   once. The date leg is basis-free and always runs, so a waived price leg
   never suppresses a missing-bar violation. *)
type _leg_outcome = Leg_clean | Leg_waived | Leg_violation of string

let _v13_leg (c : check_config) (b : bars) ~leg ~date ~price =
  match daily_on b date with
  | None -> Leg_violation (_v13_missing_detail b ~leg ~date)
  | Some bar when not (price_basis_ok ~bar_price:bar.close ~fill_price:price) ->
      Leg_waived
  | Some bar when _v13_in_range c ~price bar -> Leg_clean
  | Some bar -> Leg_violation (_v13_range_detail ~leg ~price bar)

let _v13_first_violation legs =
  List.find_map legs ~f:(function Leg_violation d -> Some d | _ -> None)

let _v13_any_waived legs =
  List.exists legs ~f:(function Leg_waived -> true | _ -> false)

(* Entry leg first, so it supplies the specimen when both legs fail. *)
let _v13_legs (c : check_config) (b : bars) (row : trade_row) =
  [
    _v13_leg c b ~leg:"entry" ~date:row.entry_date ~price:row.entry_price;
    _v13_leg c b ~leg:"exit" ~date:row.exit_date ~price:row.exit_price;
  ]

let _v13_verdict (c : check_config) (b : bars) (row : trade_row) =
  let legs = _v13_legs c b row in
  match _v13_first_violation legs with
  | Some detail -> Fail (spec row detail)
  | None -> if _v13_any_waived legs then Skip else Pass

let _v13_step inputs (row : trade_row) =
  match inputs.bars row.symbol with
  | None -> Skip
  | Some b when Array.is_empty b.daily -> Skip
  | Some b -> _v13_verdict inputs.config b row

let check_v13 inputs = fold_steps inputs.trades ~f:(_v13_step inputs)

(* ---- V14: stop-out judged against the entry bar ------------------------ *)

(* 261 of 668 stop-losses on the 26y arc run exited within one day, and 173 of
   those had entry-day low < stop <= entry-day close, then sold at the next
   open ABOVE the stop (dev/experiments/arc-rerun-2026-09-01 §D2): the stop was
   evaluated against the entry bar's PRE-FILL low, which the position did not
   hold through. A real gap-down entry-day stop-out is legitimate and closes
   BELOW the stop — hence EXP, not INV. *)

let _stop_loss_trigger = "stop_loss"
let _is_short (row : trade_row) = String.equal row.side "SHORT"

(* Fill-basis first: [stop_fill_distance_pct] is |installed_stop - fill| / fill,
   so it reconstructs the installed stop exactly. [stop_initial_distance_pct] is
   E-basis (measured from the screener's suggested entry) and only approximates
   it when the fill diverges from E. *)
let _v14_stop_distance (row : trade_row) =
  Option.first_some row.stop_fill_distance_pct row.stop_initial_distance_pct

let _v14_stop_level (row : trade_row) ~dist =
  if _is_short row then row.entry_price *. (1.0 +. dist)
  else row.entry_price *. (1.0 -. dist)

(* True when the entry bar CLOSED on the protected side of the stop — at or
   above it for a LONG, at or below it for a SHORT. Such a position never
   closed through its stop, so a stop-out on that bar had nothing to fire on. *)
let _v14_closed_on_safe_side (row : trade_row) ~stop (bar : daily_bar) =
  if _is_short row then Float.( <= ) bar.close stop
  else Float.( >= ) bar.close stop

let _v14_detail (row : trade_row) ~stop (bar : daily_bar) =
  sprintf "entry bar %s open=%.4f low=%.4f close=%.4f vs stop=%.4f, exit=%.4f"
    (Date.to_string bar.date) bar.open_price bar.low bar.close stop
    row.exit_price

let _v14_judge (row : trade_row) ~stop (bar : daily_bar) =
  if not (price_basis_ok ~bar_price:bar.close ~fill_price:row.entry_price) then
    Skip
  else if _v14_closed_on_safe_side row ~stop bar then
    Fail (spec row (_v14_detail row ~stop bar))
  else Pass

let _v14_prompt_exit (c : check_config) (b : bars) (row : trade_row) =
  bars_in_window b ~after:row.entry_date ~upto:row.exit_date
  <= c.entry_bar_stopout_max_bars

let _v14_verdict (c : check_config) (b : bars) (row : trade_row) =
  if not (_v14_prompt_exit c b row) then Pass
  else
    match (daily_on b row.entry_date, _v14_stop_distance row) with
    | Some bar, Some dist ->
        _v14_judge row ~stop:(_v14_stop_level row ~dist) bar
    | _ -> Skip

let _v14_step inputs (row : trade_row) =
  if not (String.equal row.exit_trigger _stop_loss_trigger) then Pass
  else
    match inputs.bars row.symbol with
    | None -> Skip
    | Some b when Array.is_empty b.daily -> Skip
    | Some b -> _v14_verdict inputs.config b row

let check_v14 inputs = fold_steps inputs.trades ~f:(_v14_step inputs)

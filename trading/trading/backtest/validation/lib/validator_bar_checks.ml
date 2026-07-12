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
  let last_date, _, _ = b.daily.(Array.length b.daily - 1) in
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

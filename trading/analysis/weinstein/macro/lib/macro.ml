open Core
open Types
open Weinstein_types
include Macro_types

(* ------------------------------------------------------------------ *)
(* Internal helpers — confidence + trend                                *)
(* ------------------------------------------------------------------ *)

(** Compute composite confidence from weighted indicator readings.

    Only non-Neutral indicators contribute to the total weight. This ensures
    that missing data (Neutral) doesn't dilute valid signals. Returns 0.5
    (Neutral) when all indicators are Neutral. *)
let _compute_confidence (indicators : indicator_reading list) : float =
  let weighted_bullish =
    List.sum
      (module Float)
      indicators
      ~f:(fun r -> match r.signal with `Bullish -> r.weight | _ -> 0.0)
  in
  let weighted_active =
    List.sum
      (module Float)
      indicators
      ~f:(fun r -> match r.signal with `Neutral -> 0.0 | _ -> r.weight)
  in
  if Float.(weighted_active = 0.0) then 0.5
  else weighted_bullish /. weighted_active

(** Classify confidence into market_trend. *)
let _classify_trend ~bullish_threshold ~bearish_threshold confidence :
    market_trend =
  if Float.(confidence > bullish_threshold) then Bullish
  else if Float.(confidence < bearish_threshold) then Bearish
  else Neutral

(** Build the rationale list from indicator readings and regime-change flag. *)
let _build_rationale ~indicators ~regime_changed ~trend : string list =
  let per_indicator =
    List.filter_map indicators ~f:(fun r ->
        match r.signal with
        | `Neutral -> None
        | `Bullish -> Some (Printf.sprintf "[Bullish] %s: %s" r.name r.detail)
        | `Bearish -> Some (Printf.sprintf "[Bearish] %s: %s" r.name r.detail))
  in
  let regime_line =
    if regime_changed then
      [ Printf.sprintf "Regime change: %s" (show_market_trend trend) ]
    else []
  in
  per_indicator @ regime_line

(** Detect whether [trend] differs from the prior result's trend. *)
let _regime_changed_of ~trend ~prior =
  match prior with
  | None -> false
  | Some p -> not (equal_market_trend trend p.trend)

(* ------------------------------------------------------------------ *)
(* Main function — callback shape                                       *)
(* ------------------------------------------------------------------ *)

let analyze_with_callbacks ~config ~(callbacks : callbacks) ~prior_stage ~prior
    : result =
  let { stage_config; bullish_threshold; bearish_threshold; _ } = config in
  let index_stage =
    Stage.classify_with_callbacks ~config:stage_config
      ~get_ma:callbacks.index_stage.get_ma
      ~get_close:callbacks.index_stage.get_close ~prior_stage
  in
  let indicators =
    Macro_indicators.build_indicators_from_callbacks ~config ~index_stage
      ~callbacks
  in
  let confidence = _compute_confidence indicators in
  let trend =
    _classify_trend ~bullish_threshold ~bearish_threshold confidence
  in
  let regime_changed = _regime_changed_of ~trend ~prior in
  let rationale = _build_rationale ~indicators ~regime_changed ~trend in
  { index_stage; indicators; trend; confidence; regime_changed; rationale }

(* ------------------------------------------------------------------ *)
(* Bar-list wrapper — preserves the existing API                        *)
(*                                                                      *)
(* The wrapper precomputes the cumulative A-D float array and the       *)
(* momentum-MA scalar once, then builds index closures for the          *)
(* primary-index closes, the global-index Stage callbacks, and the      *)
(* nested {!Stage.callbacks} for the primary index. Behaviour is        *)
(* bit-identical to the bar-list path: the same MA, cumulative A-D,     *)
(* momentum scalar, and index closes feed every signal.                 *)
(* ------------------------------------------------------------------ *)

(** Build the cumulative A-D float array from a list of A-D bars (oldest first).
    Index [i] holds the running sum of [advancing - declining] over bars [0..i].
    The float conversion happens at the boundary so the callback's contract
    returns floats while the underlying arithmetic is integer (matching the
    bar-list path's [int] fold). *)
let _build_cumulative_ad_array (ad_bars : ad_bar list) : float array =
  let _, rev_acc =
    List.fold ad_bars ~init:(0, []) ~f:(fun (running, acc) bar ->
        let running = running + bar.advancing - bar.declining in
        (running, running :: acc))
  in
  rev_acc |> List.rev |> Array.of_list |> Array.map ~f:Float.of_int

(** Compute the A-D momentum MA scalar from a list of A-D bars. Returns the
    simple mean of the most recent [min momentum_period n] net values. Matches
    the bar-list [_compute_momentum_ma] expression form: take the last [period]
    elements, sum them as ints, divide as float. [None] when [ad_bars] is empty.
*)
let _compute_momentum_ma_scalar ~momentum_period (ad_bars : ad_bar list) :
    float option =
  if List.is_empty ad_bars then None
  else
    let nets = List.map ad_bars ~f:(fun b -> b.advancing - b.declining) in
    let n = List.length nets in
    let period = min momentum_period n in
    let recent_nets =
      List.rev nets |> (fun l -> List.sub l ~pos:0 ~len:period) |> List.rev
    in
    let sum = List.sum (module Int) recent_nets ~f:Fn.id in
    Some (Float.of_int sum /. Float.of_int period)

(** Build a [week_offset]-indexed float lookup over a chronologically-ordered
    [float array]. [week_offset:0] returns the newest entry; offsets past the
    array's depth return [None]. *)
let _make_get_from_float_array (arr : float array) :
    week_offset:int -> float option =
  let n = Array.length arr in
  fun ~week_offset ->
    let idx = n - 1 - week_offset in
    if idx < 0 || idx >= n then None else Some arr.(idx)

(** Build [get_index_close] over [Daily_price.t array]. *)
let _make_get_index_close_from_bars (bars : Daily_price.t array) :
    week_offset:int -> float option =
  let n = Array.length bars in
  fun ~week_offset ->
    let idx = n - 1 - week_offset in
    if idx < 0 || idx >= n then None
    else Some bars.(idx).Daily_price.adjusted_close

(** Build the [get_ad_momentum_ma] closure: the precomputed scalar at offset 0,
    [None] for any other offset (callers only read offset 0). *)
let _make_get_ad_momentum_ma (ma : float option) :
    week_offset:int -> float option =
 fun ~week_offset -> if week_offset = 0 then ma else None

(** Build per-global-index Stage callbacks from a list of [(name, bars)] pairs.
*)
let _global_index_callbacks ~stage_config
    (global_index_bars : (string * Daily_price.t list) list) :
    (string * Stage.callbacks) list =
  List.map global_index_bars ~f:(fun (name, bars) ->
      (name, Stage.callbacks_from_bars ~config:stage_config ~bars))

let callbacks_from_bars ~(config : config) ~(index_bars : Daily_price.t list)
    ~(ad_bars : ad_bar list)
    ~(global_index_bars : (string * Daily_price.t list) list) : callbacks =
  let index_stage =
    Stage.callbacks_from_bars ~config:config.stage_config ~bars:index_bars
  in
  let index_arr = Array.of_list index_bars in
  let cum_ad_arr = _build_cumulative_ad_array ad_bars in
  let ma_scalar =
    _compute_momentum_ma_scalar
      ~momentum_period:config.indicator_thresholds.momentum_period ad_bars
  in
  let global_index_stages =
    _global_index_callbacks ~stage_config:config.stage_config global_index_bars
  in
  {
    index_stage;
    get_index_close = _make_get_index_close_from_bars index_arr;
    get_cumulative_ad = _make_get_from_float_array cum_ad_arr;
    get_ad_momentum_ma = _make_get_ad_momentum_ma ma_scalar;
    global_index_stages;
  }

let analyze ~config ~index_bars ~ad_bars ~global_index_bars ~prior_stage ~prior
    : result =
  let callbacks =
    callbacks_from_bars ~config ~index_bars ~ad_bars ~global_index_bars
  in
  analyze_with_callbacks ~config ~callbacks ~prior_stage ~prior

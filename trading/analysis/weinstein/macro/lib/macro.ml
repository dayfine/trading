open Core
open Types
open Weinstein_types

type indicator_reading = {
  name : string;
  signal : [ `Bullish | `Bearish | `Neutral ];
  weight : float;
  detail : string;
}

type indicator_weights = {
  w_index_stage : float;
  w_ad_line : float;
  w_momentum_index : float;
  w_nh_nl : float;
  w_global : float;
}

type config = {
  stage_config : Stage.config;
  bullish_threshold : float;
  bearish_threshold : float;
  indicator_weights : indicator_weights;
}

type ad_bar = { date : Date.t; advancing : int; declining : int }

type result = {
  index_stage : Stage.result;
  indicators : indicator_reading list;
  trend : market_trend;
  confidence : float;
  regime_changed : bool;
  rationale : string list;
}

let default_indicator_weights =
  {
    w_index_stage = 3.0;
    w_ad_line = 2.0;
    w_momentum_index = 2.0;
    w_nh_nl = 1.5;
    w_global = 1.5;
  }

let default_config =
  {
    stage_config = Stage.default_config;
    bullish_threshold = 0.65;
    bearish_threshold = 0.35;
    indicator_weights = default_indicator_weights;
  }

(* ------------------------------------------------------------------ *)
(* Internal helpers                                                     *)
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

(** Analyze index stage signal. *)
let _index_stage_signal ~weight (stage_result : Stage.result) :
    indicator_reading =
  let signal, detail =
    match stage_result.stage with
    | Stage2 { late = false; _ } -> (`Bullish, "Index in Stage 2 (advancing)")
    | Stage2 { late = true; _ } ->
        (`Neutral, "Index in late Stage 2 (decelerating)")
    | Stage1 _ -> (
        match stage_result.transition with
        | Some (Stage4 _, Stage1 _) | Some (Stage4 _, _) ->
            (`Neutral, "Index entering Stage 1 base after Stage 4")
        | _ -> (`Neutral, "Index in Stage 1 base"))
    | Stage4 _ -> (`Bearish, "Index in Stage 4 (declining)")
    | Stage3 _ -> (
        match stage_result.transition with
        | Some (Stage2 _, Stage3 _) ->
            (`Bearish, "Index entering Stage 3 top — caution")
        | _ -> (`Bearish, "Index in Stage 3 top"))
  in
  { name = "Index Stage"; signal; weight; detail }

(** Compute A-D cumulative line and detect divergence vs index. *)
let _ad_line_signal ~weight ~ad_bars ~(index_bars : Daily_price.t list) :
    indicator_reading =
  if List.is_empty ad_bars || List.is_empty index_bars then
    { name = "A-D Line"; signal = `Neutral; weight; detail = "No A-D data" }
  else
    (* Compute cumulative A-D line *)
    let cum_ad =
      List.fold ad_bars ~init:[] ~f:(fun acc bar ->
          let net = bar.advancing - bar.declining in
          let prev = Option.value (List.hd acc) ~default:0 in
          (prev + net) :: acc)
      |> List.rev
    in
    let n_ad = List.length cum_ad in
    let n_idx = List.length index_bars in
    let lookback = min 26 (min n_ad n_idx) in
    (* ~6 months *)
    if lookback < 4 then
      {
        name = "A-D Line";
        signal = `Neutral;
        weight;
        detail = "Insufficient A-D data";
      }
    else
      let ad_recent = List.last_exn cum_ad in
      let ad_prior = List.nth_exn cum_ad (n_ad - lookback) in
      let idx_recent = (List.last_exn index_bars).Daily_price.adjusted_close in
      let idx_prior =
        (List.nth_exn index_bars (n_idx - lookback)).Daily_price.adjusted_close
      in
      let ad_rising = ad_recent > ad_prior in
      let idx_rising = Float.(idx_recent > idx_prior) in
      let signal, detail =
        match (idx_rising, ad_rising) with
        | true, true -> (`Bullish, "A-D line confirming index advance")
        | false, false -> (`Bearish, "A-D line confirming index decline")
        | true, false ->
            (`Bearish, "A-D line diverging bearishly (index up, A-D down)")
        | false, true ->
            (`Bullish, "A-D line diverging bullishly (index down, A-D up)")
      in
      { name = "A-D Line"; signal; weight; detail }

(** Compute simple MA of A-D net (momentum index) and signal zero-line crossing.
*)
let _momentum_index_signal ~weight ~ad_bars : indicator_reading =
  if List.is_empty ad_bars then
    {
      name = "Momentum Index";
      signal = `Neutral;
      weight;
      detail = "No A-D data";
    }
  else
    let nets = List.map ad_bars ~f:(fun b -> b.advancing - b.declining) in
    let period = min 200 (List.length nets) in
    let recent_nets =
      List.rev nets |> (fun l -> List.sub l ~pos:0 ~len:period) |> List.rev
    in
    let ma =
      let sum = List.sum (module Int) recent_nets ~f:Fn.id in
      Float.of_int sum /. Float.of_int period
    in
    let signal, detail =
      if Float.(ma > 0.0) then
        (`Bullish, Printf.sprintf "Momentum index positive (%.1f)" ma)
      else (`Bearish, Printf.sprintf "Momentum index negative (%.1f)" ma)
    in
    { name = "Momentum Index"; signal; weight; detail }

(** Check NH-NL indicator: ratio of new highs to (new highs + new lows). *)
let _nh_nl_signal ~weight ~(index_bars : Daily_price.t list) : indicator_reading
    =
  (* We don't have NH-NL data directly; approximate using index MA slope as proxy *)
  if List.length index_bars < 10 then
    { name = "NH-NL"; signal = `Neutral; weight; detail = "Insufficient data" }
  else
    let n = List.length index_bars in
    let lookback = min 13 (n - 1) in
    (* ~3 months *)
    let recent = (List.last_exn index_bars).Daily_price.adjusted_close in
    let prior =
      (List.nth_exn index_bars (n - 1 - lookback)).Daily_price.adjusted_close
    in
    let signal, detail =
      if Float.(recent > prior *. 1.02) then
        (`Bullish, "Index trending higher over 3 months (NH-NL proxy positive)")
      else if Float.(recent < prior *. 0.98) then
        (`Bearish, "Index trending lower over 3 months (NH-NL proxy negative)")
      else (`Neutral, "Index flat over 3 months (NH-NL proxy neutral)")
    in
    { name = "NH-NL"; signal; weight; detail }

(** Check global index consensus: majority of world indices in bullish stages.
*)
let _global_signal ~weight ~stage_config
    ~(global_index_bars : (string * Daily_price.t list) list) :
    indicator_reading =
  if List.is_empty global_index_bars then
    {
      name = "Global Markets";
      signal = `Neutral;
      weight;
      detail = "No global data";
    }
  else
    let classify_index bars =
      let result =
        Stage.classify ~config:stage_config ~bars ~prior_stage:None
      in
      match result.stage with
      | Stage2 _ -> `Bullish
      | Stage4 _ -> `Bearish
      | _ -> `Neutral
    in
    let signals =
      List.map global_index_bars ~f:(fun (_, bars) -> classify_index bars)
    in
    let bullish_count = List.count signals ~f:(fun s -> Poly.(s = `Bullish)) in
    let bearish_count = List.count signals ~f:(fun s -> Poly.(s = `Bearish)) in
    let total = List.length signals in
    let bullish_frac = Float.of_int bullish_count /. Float.of_int total in
    let signal, detail =
      if Float.(bullish_frac > 0.6) then
        ( `Bullish,
          Printf.sprintf "Global consensus bullish (%d/%d markets Stage2)"
            bullish_count total )
      else if Float.(Float.of_int bearish_count /. Float.of_int total > 0.6)
      then
        ( `Bearish,
          Printf.sprintf "Global consensus bearish (%d/%d markets Stage4)"
            bearish_count total )
      else
        ( `Neutral,
          Printf.sprintf "Global markets mixed (%d bullish, %d bearish)"
            bullish_count bearish_count )
    in
    { name = "Global Markets"; signal; weight; detail }

(* ------------------------------------------------------------------ *)
(* Main function                                                        *)
(* ------------------------------------------------------------------ *)

let analyze ~config ~index_bars ~ad_bars ~global_index_bars ~prior_stage ~prior
    : result =
  let {
    stage_config;
    bullish_threshold;
    bearish_threshold;
    indicator_weights = iw;
  } =
    config
  in
  let index_stage =
    Stage.classify ~config:stage_config ~bars:index_bars ~prior_stage
  in
  let indicators =
    [
      _index_stage_signal ~weight:iw.w_index_stage index_stage;
      _ad_line_signal ~weight:iw.w_ad_line ~ad_bars ~index_bars;
      _momentum_index_signal ~weight:iw.w_momentum_index ~ad_bars;
      _nh_nl_signal ~weight:iw.w_nh_nl ~index_bars;
      _global_signal ~weight:iw.w_global ~stage_config ~global_index_bars;
    ]
  in
  let confidence = _compute_confidence indicators in
  let trend =
    _classify_trend ~bullish_threshold ~bearish_threshold confidence
  in
  let regime_changed =
    match prior with
    | None -> false
    | Some p -> not (equal_market_trend trend p.trend)
  in
  let rationale =
    List.filter_map indicators ~f:(fun r ->
        match r.signal with
        | `Neutral -> None
        | `Bullish -> Some (Printf.sprintf "[Bullish] %s: %s" r.name r.detail)
        | `Bearish -> Some (Printf.sprintf "[Bearish] %s: %s" r.name r.detail))
    @
    if regime_changed then
      [ Printf.sprintf "Regime change: %s" (show_market_trend trend) ]
    else []
  in
  { index_stage; indicators; trend; confidence; regime_changed; rationale }

open Core
open Weinstein_types
open Macro_types

(* ------------------------------------------------------------------ *)
(* Index stage signal                                                   *)
(* ------------------------------------------------------------------ *)

let _stage1_detail transition =
  match transition with
  | Some (Stage4 _, _) -> (`Neutral, "Index entering Stage 1 base after Stage 4")
  | _ -> (`Neutral, "Index in Stage 1 base")

let _stage3_detail transition =
  match transition with
  | Some (Stage2 _, Stage3 _) ->
      (`Bearish, "Index entering Stage 3 top — caution")
  | _ -> (`Bearish, "Index in Stage 3 top")

(** Analyze index stage signal. *)
let _index_stage_signal ~weight (stage_result : Stage.result) :
    indicator_reading =
  let signal, detail =
    match stage_result.stage with
    | Stage2 { late = false; _ } -> (`Bullish, "Index in Stage 2 (advancing)")
    | Stage2 { late = true; _ } ->
        (`Neutral, "Index in late Stage 2 (decelerating)")
    | Stage1 _ -> _stage1_detail stage_result.transition
    | Stage4 _ -> (`Bearish, "Index in Stage 4 (declining)")
    | Stage3 _ -> _stage3_detail stage_result.transition
  in
  { name = "Index Stage"; signal; weight; detail }

(* ------------------------------------------------------------------ *)
(* Depth probing for callback walks                                     *)
(*                                                                      *)
(* The bar-list path computes lookback as                                *)
(*   [min lookback (min n_ad n_idx)]                                    *)
(* where [n_ad] / [n_idx] are list lengths. The callback path doesn't   *)
(* know these lengths upfront, so we probe each callback by walking     *)
(* offsets [0..max] and counting [Some] returns until the first [None]. *)
(* The cap [max] is the configured lookback so we never walk further    *)
(* than necessary.                                                      *)
(* ------------------------------------------------------------------ *)

(** Count consecutive [Some] returns from [get] starting at [week_offset:0],
    stopping at the first [None] or after [max] probes. *)
let _probe_depth ~max ~(get : week_offset:int -> _ option) : int =
  let rec walk off =
    if off >= max then off
    else
      match get ~week_offset:off with Some _ -> walk (off + 1) | None -> off
  in
  walk 0

(* ------------------------------------------------------------------ *)
(* A-D line signal                                                      *)
(* ------------------------------------------------------------------ *)

(** Decide A-D divergence given recent + prior cum_ad and index closes. The
    four-way cross of [(idx_rising, ad_rising)] mirrors the bar-list path. *)
let _ad_divergence_decision ~ad_recent ~ad_prior ~idx_recent ~idx_prior :
    [ `Bullish | `Bearish | `Neutral ] * string =
  let ad_rising = Float.(ad_recent > ad_prior) in
  let idx_rising = Float.(idx_recent > idx_prior) in
  match (idx_rising, ad_rising) with
  | true, true -> (`Bullish, "A-D line confirming index advance")
  | false, false -> (`Bearish, "A-D line confirming index decline")
  | true, false ->
      (`Bearish, "A-D line diverging bearishly (index up, A-D down)")
  | false, true ->
      (`Bullish, "A-D line diverging bullishly (index down, A-D up)")

(** Compute A-D divergence signal given the precomputed cumulative-A-D callback
    and the primary-index close callback. Walks each callback to determine the
    available depth, caps the lookback at the smaller of the two, then samples
    (recent, prior) from each. *)
let _ad_divergence_signal ~ad_min_bars ~ad_line_lookback ~get_cumulative_ad
    ~get_index_close : [ `Bullish | `Bearish | `Neutral ] * string =
  let n_ad = _probe_depth ~max:ad_line_lookback ~get:get_cumulative_ad in
  let n_idx = _probe_depth ~max:ad_line_lookback ~get:get_index_close in
  let lookback = min ad_line_lookback (min n_ad n_idx) in
  if lookback < ad_min_bars then (`Neutral, "Insufficient A-D data")
  else
    match
      ( get_cumulative_ad ~week_offset:0,
        get_cumulative_ad ~week_offset:(lookback - 1),
        get_index_close ~week_offset:0,
        get_index_close ~week_offset:(lookback - 1) )
    with
    | Some ad_recent, Some ad_prior, Some idx_recent, Some idx_prior ->
        _ad_divergence_decision ~ad_recent ~ad_prior ~idx_recent ~idx_prior
    | _ -> (`Neutral, "Insufficient A-D data")

(** A-D line indicator using the callback bundle. Empty A-D series (depth 0) or
    empty index series (depth 0) → Neutral with "No A-D data" — matches the
    bar-list [List.is_empty] guard. *)
let _ad_line_signal ~weight ~ad_min_bars ~ad_line_lookback ~get_cumulative_ad
    ~get_index_close : indicator_reading =
  let has_ad = Option.is_some (get_cumulative_ad ~week_offset:0) in
  let has_idx = Option.is_some (get_index_close ~week_offset:0) in
  if (not has_ad) || not has_idx then
    { name = "A-D Line"; signal = `Neutral; weight; detail = "No A-D data" }
  else
    let signal, detail =
      _ad_divergence_signal ~ad_min_bars ~ad_line_lookback ~get_cumulative_ad
        ~get_index_close
    in
    { name = "A-D Line"; signal; weight; detail }

(* ------------------------------------------------------------------ *)
(* Momentum index signal                                                *)
(* ------------------------------------------------------------------ *)

(** Decide momentum-index signal from a non-missing MA scalar. *)
let _momentum_index_decision (ma : float) :
    [ `Bullish | `Bearish | `Neutral ] * string =
  if Float.(ma > 0.0) then
    (`Bullish, Printf.sprintf "Momentum index positive (%.1f)" ma)
  else (`Bearish, Printf.sprintf "Momentum index negative (%.1f)" ma)

(** Momentum-index signal from a precomputed MA scalar. [None] = empty A-D
    series (matches the bar-list [List.is_empty] guard). *)
let _momentum_index_signal ~weight ~get_ad_momentum_ma : indicator_reading =
  match get_ad_momentum_ma ~week_offset:0 with
  | None ->
      {
        name = "Momentum Index";
        signal = `Neutral;
        weight;
        detail = "No A-D data";
      }
  | Some ma ->
      let signal, detail = _momentum_index_decision ma in
      { name = "Momentum Index"; signal; weight; detail }

(* ------------------------------------------------------------------ *)
(* NH-NL proxy signal                                                   *)
(* ------------------------------------------------------------------ *)

(** Decide NH-NL proxy signal from recent + prior index closes. *)
let _nh_nl_decision ~nh_nl_up_threshold ~nh_nl_down_threshold ~recent ~prior :
    [ `Bullish | `Bearish | `Neutral ] * string =
  if Float.(recent > prior *. nh_nl_up_threshold) then
    (`Bullish, "Index trending higher over 3 months (NH-NL proxy positive)")
  else if Float.(recent < prior *. nh_nl_down_threshold) then
    (`Bearish, "Index trending lower over 3 months (NH-NL proxy negative)")
  else (`Neutral, "Index flat over 3 months (NH-NL proxy neutral)")

(** Build the [NH-NL] insufficient-data reading. *)
let _nh_nl_insufficient ~weight : indicator_reading =
  { name = "NH-NL"; signal = `Neutral; weight; detail = "Insufficient data" }

(** Sample [(recent, prior)] from the index-close callback once depth is known
    to be sufficient and produce the resulting reading. *)
let _nh_nl_sample_and_decide ~weight ~nh_nl_up_threshold ~nh_nl_down_threshold
    ~lookback ~get_index_close : indicator_reading =
  match
    (get_index_close ~week_offset:0, get_index_close ~week_offset:lookback)
  with
  | Some recent, Some prior ->
      let signal, detail =
        _nh_nl_decision ~nh_nl_up_threshold ~nh_nl_down_threshold ~recent ~prior
      in
      { name = "NH-NL"; signal; weight; detail }
  | _ -> _nh_nl_insufficient ~weight

(** NH-NL proxy from index price trend. The bar-list path used [n - 1] lookback
    steps from the newest bar, where [n = min nh_nl_lookback (n - 1)]. In offset
    space the prior bar is at [week_offset = lookback]. *)
let _nh_nl_signal ~weight ~nh_nl_min_bars ~nh_nl_lookback ~nh_nl_up_threshold
    ~nh_nl_down_threshold ~get_index_close : indicator_reading =
  let depth = _probe_depth ~max:(nh_nl_lookback + 1) ~get:get_index_close in
  if depth < nh_nl_min_bars then _nh_nl_insufficient ~weight
  else
    let lookback = min nh_nl_lookback (depth - 1) in
    _nh_nl_sample_and_decide ~weight ~nh_nl_up_threshold ~nh_nl_down_threshold
      ~lookback ~get_index_close

(* ------------------------------------------------------------------ *)
(* Global consensus signal                                              *)
(* ------------------------------------------------------------------ *)

(** Classify a single global-index entry by stage signal. *)
let _classify_global ~stage_config (cb : Stage.callbacks) :
    [ `Bullish | `Bearish | `Neutral ] =
  let result =
    Stage.classify_with_callbacks ~config:stage_config ~get_ma:cb.get_ma
      ~get_close:cb.get_close ~prior_stage:None
  in
  match result.stage with
  | Stage2 _ -> `Bullish
  | Stage4 _ -> `Bearish
  | _ -> `Neutral

(** Decide global consensus signal from the (bullish, bearish, total) counts. *)
let _global_consensus_decision ~global_consensus_threshold ~bullish_count
    ~bearish_count ~total : [ `Bullish | `Bearish | `Neutral ] * string =
  let bullish_frac = Float.of_int bullish_count /. Float.of_int total in
  let bearish_frac = Float.of_int bearish_count /. Float.of_int total in
  if Float.(bullish_frac > global_consensus_threshold) then
    ( `Bullish,
      Printf.sprintf "Global consensus bullish (%d/%d markets Stage2)"
        bullish_count total )
  else if Float.(bearish_frac > global_consensus_threshold) then
    ( `Bearish,
      Printf.sprintf "Global consensus bearish (%d/%d markets Stage4)"
        bearish_count total )
  else
    ( `Neutral,
      Printf.sprintf "Global markets mixed (%d bullish, %d bearish)"
        bullish_count bearish_count )

(** Aggregate per-index Stage signals into a global consensus signal. *)
let _global_consensus_signal ~stage_config ~global_consensus_threshold
    ~global_index_stages : [ `Bullish | `Bearish | `Neutral ] * string =
  let signals =
    List.map global_index_stages ~f:(fun (_, cb) ->
        _classify_global ~stage_config cb)
  in
  let bullish_count =
    List.count signals ~f:(fun s ->
        match s with `Bullish -> true | _ -> false)
  in
  let bearish_count =
    List.count signals ~f:(fun s ->
        match s with `Bearish -> true | _ -> false)
  in
  let total = List.length signals in
  _global_consensus_decision ~global_consensus_threshold ~bullish_count
    ~bearish_count ~total

(** Global consensus indicator. Empty {!global_index_stages} → Neutral / "No
    global data" (matches the bar-list [List.is_empty] guard). *)
let _global_signal ~weight ~stage_config ~global_consensus_threshold
    ~global_index_stages : indicator_reading =
  if List.is_empty global_index_stages then
    {
      name = "Global Markets";
      signal = `Neutral;
      weight;
      detail = "No global data";
    }
  else
    let signal, detail =
      _global_consensus_signal ~stage_config ~global_consensus_threshold
        ~global_index_stages
    in
    { name = "Global Markets"; signal; weight; detail }

(* ------------------------------------------------------------------ *)
(* Public assembly                                                      *)
(* ------------------------------------------------------------------ *)

let build_indicators_from_callbacks ~config ~(index_stage : Stage.result)
    ~(callbacks : callbacks) : indicator_reading list =
  let { stage_config; indicator_weights = iw; indicator_thresholds = it; _ } =
    config
  in
  [
    _index_stage_signal ~weight:iw.w_index_stage index_stage;
    _ad_line_signal ~weight:iw.w_ad_line ~ad_min_bars:it.ad_min_bars
      ~ad_line_lookback:it.ad_line_lookback
      ~get_cumulative_ad:callbacks.get_cumulative_ad
      ~get_index_close:callbacks.get_index_close;
    _momentum_index_signal ~weight:iw.w_momentum_index
      ~get_ad_momentum_ma:callbacks.get_ad_momentum_ma;
    _nh_nl_signal ~weight:iw.w_nh_nl ~nh_nl_min_bars:it.nh_nl_min_bars
      ~nh_nl_lookback:it.nh_nl_lookback
      ~nh_nl_up_threshold:it.nh_nl_up_threshold
      ~nh_nl_down_threshold:it.nh_nl_down_threshold
      ~get_index_close:callbacks.get_index_close;
    _global_signal ~weight:iw.w_global ~stage_config
      ~global_consensus_threshold:it.global_consensus_threshold
      ~global_index_stages:callbacks.global_index_stages;
  ]

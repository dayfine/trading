open Core
open Types
open Weinstein_types

type config = {
  stage : Stage.config;
  rs : Rs.config;
  volume : Volume.config;
  resistance : Resistance.config;
  breakout_event_lookback : int;
      (** Bars to scan for peak-volume event when detecting a breakout. Default:
          8 (~2 months of weekly bars). *)
  base_lookback_weeks : int;
      (** How far back (in bars) to search for the prior base high. Default: 52
          (~1 year). *)
  base_end_offset_weeks : int;
      (** How many recent bars to exclude from the base search (avoids counting
          the current advance as part of the base). Default: 8. *)
}

let default_config =
  {
    stage = Stage.default_config;
    rs = Rs.default_config;
    volume = Volume.default_config;
    resistance = Resistance.default_config;
    breakout_event_lookback = 8;
    base_lookback_weeks = 52;
    base_end_offset_weeks = 8;
  }

type t = {
  ticker : string;
  stage : Stage.result;
  rs : Rs.result option;
  volume : Volume.result option;
  resistance : Resistance.result option;
  breakout_price : float option;
  prior_stage : stage option;
  as_of_date : Date.t;
}

(** Return the index of the highest-volume bar within the last [lookback] bars.
    Used as a proxy for the breakout event (breakouts should be the loudest
    volume bar in the recent window). Returns [None] if [bars] has fewer than 2
    elements. *)
let _find_peak_volume_idx ~lookback (bars : Daily_price.t list) : int option =
  let n = List.length bars in
  if n < 2 then None
  else
    let start = max 0 (n - lookback) in
    let recent = List.sub bars ~pos:start ~len:(n - start) in
    let max_vol_idx =
      List.foldi recent ~init:(0, 0) ~f:(fun i (best_i, best_v) b ->
          if b.Daily_price.volume > best_v then (i, b.Daily_price.volume)
          else (best_i, best_v))
      |> fst
    in
    Some (start + max_vol_idx)

(** Tail-recursive scan returning the max [high_price] across the slice
    [\[base_start, base_end\)] of [bars]. Returns [None] when the slice is empty
    (no bars fall in the index range).

    Was: List.sub allocated a [base_bars] sub-list, then List.map allocated a
    fresh float list of [high_price]s, then List.max_elt walked it — three
    traversals and two intermediate lists per call. Now: one walk, no
    intermediate. Runs once per universe symbol per Friday screen. *)
let _scan_max_high (bars : Daily_price.t list) ~base_start ~base_end :
    float option =
  let rec loop i best = function
    | [] -> best
    | _ when i >= base_end -> best
    | _ :: rest when i < base_start -> loop (i + 1) best rest
    | (b : Daily_price.t) :: rest ->
        let best' =
          match best with
          | None -> Some b.high_price
          | Some best -> Some (Float.max best b.high_price)
        in
        loop (i + 1) best' rest
  in
  loop 0 None bars

(** Estimate the breakout price: highest high in the prior base region.

    The base region is [base_lookback_weeks] bars back, excluding the most
    recent [base_end_offset_weeks] bars (which belong to the current advance,
    not the base). *)
let _estimate_breakout_price ~base_lookback_weeks ~base_end_offset_weeks
    (bars : Daily_price.t list) : float option =
  let n = List.length bars in
  let base_start = max 0 (n - base_lookback_weeks) in
  let base_end = max 0 (n - base_end_offset_weeks) in
  if base_end <= base_start then None
  else _scan_max_high bars ~base_start ~base_end

let analyze ~(config : config) ~ticker ~bars ~benchmark_bars ~prior_stage
    ~as_of_date : t =
  let stage_result = Stage.classify ~config:config.stage ~bars ~prior_stage in
  let rs_result =
    Rs.analyze ~config:config.rs ~stock_bars:bars ~benchmark_bars
  in
  let breakout_price =
    _estimate_breakout_price ~base_lookback_weeks:config.base_lookback_weeks
      ~base_end_offset_weeks:config.base_end_offset_weeks bars
  in
  (* Find volume confirmation at the peak-volume bar in the recent window *)
  let volume_result =
    match
      _find_peak_volume_idx ~lookback:config.breakout_event_lookback bars
    with
    | None -> None
    | Some event_idx ->
        Volume.analyze_breakout ~config:config.volume ~bars ~event_idx
  in
  (* Map resistance above estimated breakout price *)
  let resistance_result =
    Option.map breakout_price ~f:(fun bp ->
        Resistance.analyze ~config:config.resistance ~bars ~breakout_price:bp
          ~as_of_date)
  in
  {
    ticker;
    stage = stage_result;
    rs = rs_result;
    volume = volume_result;
    resistance = resistance_result;
    breakout_price;
    prior_stage;
    as_of_date;
  }

let is_breakout_candidate (a : t) : bool =
  (* Stage 2 transition from Stage 1, with rising MA *)
  let stage_ok =
    match (a.stage.stage, a.prior_stage) with
    | Stage2 _, Some (Stage1 _) -> true
    | Stage2 { weeks_advancing; late = false }, _ -> weeks_advancing <= 4
    | _ -> false
  in
  (* Volume confirmation: at least Adequate *)
  let volume_ok =
    match a.volume with
    | Some { confirmation = Strong _; _ }
    | Some { confirmation = Adequate _; _ } ->
        true
    | _ -> false
  in
  (* RS not negative_declining *)
  let rs_ok =
    match a.rs with
    | None -> true (* no data — don't disqualify *)
    | Some { trend = Negative_declining; _ } -> false
    | _ -> true
  in
  stage_ok && volume_ok && rs_ok

let is_breakdown_candidate (a : t) : bool =
  (* Stage 4 transition from Stage 3 *)
  match (a.stage.stage, a.prior_stage) with
  | Stage4 _, Some (Stage3 _) -> true
  | Stage4 { weeks_declining }, _ -> weeks_declining <= 4
  | _ -> false

open Core
open Types
open Weinstein_types

type config = {
  stage : Stage.config;
  rs : Rs.config;
  volume : Volume.config;
  resistance : Resistance.config;
}

let default_config =
  {
    stage = Stage.default_config;
    rs = Rs.default_config;
    volume = Volume.default_config;
    resistance = Resistance.default_config;
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

(** Find the most recent bar index where the stock appears to have broken above
    prior resistance (a candidate breakout event). Looks at the last [lookback]
    bars for a significant up-move on the closing bar. *)
let _find_breakout_bar_idx ~lookback (bars : Daily_price.t list) : int option =
  let n = List.length bars in
  if n < 2 then None
  else
    let start = max 0 (n - lookback) in
    let recent = List.sub bars ~pos:start ~len:(n - start) in
    (* Find the bar with the highest volume in recent history — proxy for breakout *)
    let max_vol_idx =
      List.foldi recent ~init:(0, 0) ~f:(fun i (best_i, best_v) b ->
          if b.Daily_price.volume > best_v then (i, b.Daily_price.volume)
          else (best_i, best_v))
      |> fst
    in
    Some (start + max_vol_idx)

(** Estimate breakout price: the highest close in the base period (bars before
    the MA starts rising). *)
let _estimate_breakout_price (bars : Daily_price.t list) : float option =
  match bars with
  | [] -> None
  | _ ->
      (* Use the high of the final completed base region: approximate as
       the 52-week high of bars 9-13 months ago relative to the end *)
      let n = List.length bars in
      let base_start = max 0 (n - 52) in
      let base_end = max 0 (n - 8) in
      if base_end <= base_start then None
      else
        let base_bars =
          List.sub bars ~pos:base_start ~len:(base_end - base_start)
        in
        let max_high =
          List.map base_bars ~f:(fun b -> b.Daily_price.high_price)
          |> List.max_elt ~compare:Float.compare
        in
        max_high

let analyze ~(config : config) ~ticker ~bars ~benchmark_bars ~prior_stage
    ~as_of_date : t =
  let stage_result = Stage.classify ~config:config.stage ~bars ~prior_stage in
  let rs_result =
    Rs.analyze ~config:config.rs ~stock_bars:bars ~benchmark_bars
  in
  let breakout_price = _estimate_breakout_price bars in
  (* Find volume confirmation at the candidate breakout event *)
  let volume_result =
    let lookback = 8 in
    match _find_breakout_bar_idx ~lookback bars with
    | None -> None
    | Some event_idx ->
        Volume.analyze_breakout ~config:config.volume ~bars ~event_idx
  in
  (* Map resistance above estimated breakout price *)
  let resistance_result =
    match breakout_price with
    | None -> None
    | Some bp ->
        Some
          (Resistance.analyze ~config:config.resistance ~bars ~breakout_price:bp
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

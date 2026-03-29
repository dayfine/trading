open Core
open Weinstein_types

type config = {
  stage_config : Stage.config;
  rs_config : Rs.config;
  strong_confidence : float;
  weak_confidence : float;
}

let default_config =
  {
    stage_config = Stage.default_config;
    rs_config = Rs.default_config;
    strong_confidence = 0.6;
    weak_confidence = 0.4;
  }

type result = {
  sector_name : string;
  stage : Stage.result;
  rs : Rs.result option;
  rating : Screener.sector_rating;
  constituent_count : int;
  bullish_constituent_pct : float;
  rationale : string list;
}

(* ------------------------------------------------------------------ *)
(* Internal helpers                                                     *)
(* ------------------------------------------------------------------ *)

(** Compute a 0.0–1.0 confidence score for the sector being bullish. *)
let _sector_confidence ~stage ~rs ~constituent_pct : float =
  let stage_score =
    match stage.Stage.stage with
    | Stage2 { late = false; _ } -> 1.0
    | Stage2 { late = true; _ } -> 0.65
    | Stage1 _ -> 0.4
    | Stage3 _ -> 0.3
    | Stage4 _ -> 0.0
  in
  let rs_score =
    match rs with
    | None -> 0.5 (* no data = neutral *)
    | Some { Rs.trend = Bullish_crossover | Positive_rising; _ } -> 1.0
    | Some { Rs.trend = Positive_flat; _ } -> 0.7
    | Some { Rs.trend = Negative_improving; _ } -> 0.4
    | Some { Rs.trend = Negative_declining | Bearish_crossover; _ } -> 0.0
  in
  (* Weighted combination: stage 40%, RS 35%, constituent breadth 25% *)
  (stage_score *. 0.40) +. (rs_score *. 0.35) +. (constituent_pct *. 0.25)

(** Compute what fraction of constituents are in Stage 2. *)
let _bullish_constituent_pct (analyses : Stock_analysis.t list) : float =
  if List.is_empty analyses then 0.5
  else
    let bullish =
      List.count analyses ~f:(fun a ->
          match a.Stock_analysis.stage.Stage.stage with
          | Stage2 _ -> true
          | _ -> false)
    in
    Float.of_int bullish /. Float.of_int (List.length analyses)

(** Build rationale strings. *)
let _build_rationale ~stage ~rs ~constituent_pct ~rating : string list =
  let stage_msg =
    Printf.sprintf "Sector stage: %s" (show_stage stage.Stage.stage)
  in
  let rs_msg =
    match rs with
    | None -> "Sector RS: no data"
    | Some r -> Printf.sprintf "Sector RS: %s" (show_rs_trend r.Rs.trend)
  in
  let breadth_msg =
    Printf.sprintf "Bullish constituents: %.0f%%" (constituent_pct *. 100.0)
  in
  let rating_msg =
    Printf.sprintf "Rating: %s" (Screener.show_sector_rating rating)
  in
  [ stage_msg; rs_msg; breadth_msg; rating_msg ]

(* ------------------------------------------------------------------ *)
(* Main function                                                        *)
(* ------------------------------------------------------------------ *)

let analyze ~config ~sector_name ~sector_bars ~benchmark_bars
    ~constituent_analyses ~prior_stage : result =
  let stage =
    Stage.classify ~config:config.stage_config ~bars:sector_bars ~prior_stage
  in
  let rs =
    Rs.analyze ~config:config.rs_config ~stock_bars:sector_bars ~benchmark_bars
  in
  let constituent_pct = _bullish_constituent_pct constituent_analyses in
  let confidence = _sector_confidence ~stage ~rs ~constituent_pct in
  let rating =
    if Float.(confidence >= config.strong_confidence) then Screener.Strong
    else if Float.(confidence <= config.weak_confidence) then Screener.Weak
    else Screener.Neutral
  in
  let rationale = _build_rationale ~stage ~rs ~constituent_pct ~rating in
  {
    sector_name;
    stage;
    rs;
    rating;
    constituent_count = List.length constituent_analyses;
    bullish_constituent_pct = constituent_pct;
    rationale;
  }

let sector_context_of (r : result) : Screener.sector_context =
  {
    Screener.sector_name = r.sector_name;
    rating = r.rating;
    stage = r.stage.Stage.stage;
  }

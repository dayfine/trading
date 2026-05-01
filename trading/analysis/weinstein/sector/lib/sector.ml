open Core
open Types
open Weinstein_types

type config = {
  stage_config : Stage.config;
  rs_config : Rs.config;
  strong_confidence : float;
  weak_confidence : float;
  stage_weight : float;
      (** Weight of stage score in overall confidence (0–1). Default: 0.40. *)
  rs_weight : float;
      (** Weight of RS score in overall confidence (0–1). Default: 0.35. *)
  constituent_weight : float;
      (** Weight of constituent breadth score in overall confidence (0–1).
          Default: 0.25. *)
}

let default_config =
  {
    stage_config = Stage.default_config;
    rs_config = Rs.default_config;
    strong_confidence = 0.6;
    weak_confidence = 0.4;
    stage_weight = 0.40;
    rs_weight = 0.35;
    constituent_weight = 0.25;
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
(* Callback bundle — used by panel-backed callers                       *)
(* ------------------------------------------------------------------ *)

type callbacks = { stage : Stage.callbacks; rs : Rs.callbacks }

let callbacks_from_bars ~(config : config) ~(sector_bars : Daily_price.t list)
    ~(benchmark_bars : Daily_price.t list) : callbacks =
  {
    stage =
      Stage.callbacks_from_bars ~config:config.stage_config ~bars:sector_bars;
    rs = Rs.callbacks_from_bars ~stock_bars:sector_bars ~benchmark_bars;
  }

(* ------------------------------------------------------------------ *)
(* Internal helpers                                                     *)
(* ------------------------------------------------------------------ *)

(** Compute a 0.0–1.0 confidence score for the sector being bullish. *)
let _sector_confidence ~config ~stage ~rs ~constituent_pct : float =
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
  (stage_score *. config.stage_weight)
  +. (rs_score *. config.rs_weight)
  +. (constituent_pct *. config.constituent_weight)

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

let _rating_string = function
  | Screener.Strong -> "Strong"
  | Screener.Neutral -> "Neutral"
  | Screener.Weak -> "Weak"

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
  let rating_msg = Printf.sprintf "Rating: %s" (_rating_string rating) in
  [ stage_msg; rs_msg; breadth_msg; rating_msg ]

(** G15-followup (panel-golden cross-platform drift, 2026-05-01): snap
    [confidence] to 4 decimal places before the boundary comparison. macOS libm
    and glibc libm don't guarantee bit-identical results for the
    chained-arithmetic + SMA-of-RS-ratio walk that produces [confidence]; the
    diagnostic in [dev/notes/panel-golden-platform-drift-2026-05-01.md] showed
    XLK's confidence flipping across the 0.6 [strong_confidence] boundary
    between platforms, moving Information Technology between [Strong] and
    [Neutral] and adding / subtracting +10 [w_sector_strong] from constituent
    candidate scores. The quantization is the cheapest fix — sector ratings
    change at the 4th-decimal granularity already (config thresholds are 0.6 /
    0.4 = 1 dp), so 4 dp leaves the per-sector rating semantics unchanged in any
    non-degenerate case while eliminating sub-ULP cross-platform divergence. *)
let _rating_of_confidence ~config ~confidence : Screener.sector_rating =
  let snapped = Float.round_decimal ~decimal_digits:4 confidence in
  if Float.(snapped >= config.strong_confidence) then Screener.Strong
  else if Float.(snapped <= config.weak_confidence) then Screener.Weak
  else Screener.Neutral

(* ------------------------------------------------------------------ *)
(* Main function — callback shape                                       *)
(* ------------------------------------------------------------------ *)

let analyze_with_callbacks ~(config : config) ~sector_name
    ~(callbacks : callbacks) ~(constituent_analyses : Stock_analysis.t list)
    ~prior_stage : result =
  let stage =
    Stage.classify_with_callbacks ~config:config.stage_config
      ~get_ma:callbacks.stage.get_ma ~get_close:callbacks.stage.get_close
      ~prior_stage
  in
  let rs =
    Rs.analyze_with_callbacks ~config:config.rs_config
      ~get_stock_close:callbacks.rs.get_stock_close
      ~get_benchmark_close:callbacks.rs.get_benchmark_close
      ~get_date:callbacks.rs.get_date
  in
  let constituent_pct = _bullish_constituent_pct constituent_analyses in
  let confidence = _sector_confidence ~config ~stage ~rs ~constituent_pct in
  let rating = _rating_of_confidence ~config ~confidence in
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

(* ------------------------------------------------------------------ *)
(* Bar-list wrapper — preserves the existing API                        *)
(* ------------------------------------------------------------------ *)

let analyze ~(config : config) ~sector_name ~sector_bars ~benchmark_bars
    ~constituent_analyses ~prior_stage : result =
  let callbacks = callbacks_from_bars ~config ~sector_bars ~benchmark_bars in
  analyze_with_callbacks ~config ~sector_name ~callbacks ~constituent_analyses
    ~prior_stage

let sector_context_of (r : result) : Screener.sector_context =
  {
    Screener.sector_name = r.sector_name;
    rating = r.rating;
    stage = r.stage.Stage.stage;
  }

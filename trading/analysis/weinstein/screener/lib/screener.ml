open Core
open Weinstein_types

type sector_rating = Strong | Neutral | Weak [@@deriving show, eq]

type sector_context = {
  sector_name : string;
  rating : sector_rating;
  stage : stage;
}

type scoring_weights = {
  w_stage2_breakout : int;
  w_strong_volume : int;
  w_adequate_volume : int;
  w_positive_rs : int;
  w_bullish_rs_crossover : int;
  w_clean_resistance : int;
  w_sector_strong : int;
  w_late_stage2_penalty : int;
}

let default_scoring_weights =
  {
    w_stage2_breakout = 30;
    w_strong_volume = 20;
    w_adequate_volume = 10;
    w_positive_rs = 20;
    w_bullish_rs_crossover = 10;
    w_clean_resistance = 15;
    w_sector_strong = 10;
    w_late_stage2_penalty = -15;
  }

type config = {
  weights : scoring_weights;
  min_grade : grade;
  max_buy_candidates : int;
  max_short_candidates : int;
}

let default_config =
  {
    weights = default_scoring_weights;
    min_grade = C;
    max_buy_candidates = 20;
    max_short_candidates = 10;
  }

type scored_candidate = {
  ticker : string;
  analysis : Stock_analysis.t;
  sector : sector_context;
  grade : grade;
  score : int;
  suggested_entry : float;
  suggested_stop : float;
  risk_pct : float;
  swing_target : float option;
  rationale : string list;
}

type result = {
  buy_candidates : scored_candidate list;
  short_candidates : scored_candidate list;
  watchlist : (string * string) list;
  macro_trend : market_trend;
}

(* ------------------------------------------------------------------ *)
(* Internal helpers                                                     *)
(* ------------------------------------------------------------------ *)

(** Compute a long-side score for a stock analysis. *)
let _score_long ~weights ~sector (a : Stock_analysis.t) : int * string list =
  let w = weights in
  let entries =
    (* Stage 2 breakout (transition from Stage 1) *)
    (match (a.stage.stage, a.prior_stage) with
      | Stage2 _, Some (Stage1 _) ->
          [ (w.w_stage2_breakout, "Stage1→Stage2 breakout") ]
      | Stage2 { weeks_advancing; _ }, _ when weeks_advancing <= 4 ->
          [ (w.w_stage2_breakout / 2, "Early Stage2") ]
      | _ -> [])
    (* Late Stage2 penalty *)
    @ (match a.stage.stage with
      | Stage2 { late = true; _ } ->
          [ (w.w_late_stage2_penalty, "Late Stage2 (penalty)") ]
      | _ -> [])
    (* Volume confirmation *)
    @ (match a.volume with
      | Some { confirmation = Strong _; _ } ->
          [ (w.w_strong_volume, "Strong volume") ]
      | Some { confirmation = Adequate _; _ } ->
          [ (w.w_adequate_volume, "Adequate volume") ]
      | _ -> [])
    (* Relative strength *)
    @ (match a.rs with
      | Some { trend = Bullish_crossover; _ } ->
          [
            (w.w_positive_rs + w.w_bullish_rs_crossover, "RS bullish crossover");
          ]
      | Some { trend = Positive_rising; _ } ->
          [ (w.w_positive_rs, "RS positive & rising") ]
      | Some { trend = Positive_flat; _ } ->
          [ (w.w_positive_rs / 2, "RS positive") ]
      | _ -> [])
    (* Overhead resistance *)
    @ (match a.resistance with
      | Some { quality = Virgin_territory; _ } ->
          [ (w.w_clean_resistance, "Virgin territory") ]
      | Some { quality = Clean; _ } ->
          [ (w.w_clean_resistance, "Clean overhead") ]
      | Some { quality = Moderate_resistance; _ } ->
          [ (w.w_clean_resistance / 2, "Moderate resistance") ]
      | _ -> [])
    (* Sector bonus *)
    @
    match sector.rating with
    | Strong -> [ (w.w_sector_strong, "Strong sector") ]
    | Neutral -> []
    | Weak -> [ (-w.w_sector_strong, "Weak sector (penalty)") ]
  in
  let non_zero = List.filter entries ~f:(fun (pts, _) -> pts <> 0) in
  (List.sum (module Int) non_zero ~f:fst, List.map non_zero ~f:snd)

(** Compute a short-side score for a stock analysis. *)
let _score_short ~weights ~sector (a : Stock_analysis.t) : int * string list =
  let w = weights in
  let entries =
    (* Stage 4 breakdown (transition from Stage 3) *)
    (match (a.stage.stage, a.prior_stage) with
      | Stage4 _, Some (Stage3 _) ->
          [ (w.w_stage2_breakout, "Stage3→Stage4 breakdown") ]
      | Stage4 { weeks_declining }, _ when weeks_declining <= 4 ->
          [ (w.w_stage2_breakout / 2, "Early Stage4") ]
      | _ -> [])
    (* Negative RS is good for shorts *)
    @ (match a.rs with
      | Some { trend = Bearish_crossover; _ } ->
          [
            (w.w_positive_rs + w.w_bullish_rs_crossover, "RS bearish crossover");
          ]
      | Some { trend = Negative_declining; _ } ->
          [ (w.w_positive_rs, "RS negative & declining") ]
      | Some { trend = Negative_improving; _ } ->
          [ (w.w_positive_rs / 2, "RS negative") ]
      | _ -> [])
    (* Weak sector is good for shorts *)
    @
    match sector.rating with
    | Weak -> [ (w.w_sector_strong, "Weak sector") ]
    | Neutral -> []
    | Strong -> [ (-w.w_sector_strong, "Strong sector (penalty)") ]
  in
  let non_zero = List.filter entries ~f:(fun (pts, _) -> pts <> 0) in
  (List.sum (module Int) non_zero ~f:fst, List.map non_zero ~f:snd)

(** Convert score to grade. *)
let _grade_of_score score =
  if score >= 85 then A_plus
  else if score >= 70 then A
  else if score >= 55 then B
  else if score >= 40 then C
  else if score >= 25 then D
  else F

(** Estimate suggested entry (breakout price + 0.5% buffer above round number).
*)
let _suggested_entry breakout_price =
  let raw = breakout_price *. 1.005 in
  (* Round to nearest 0.01 *)
  Float.round_nearest (raw *. 100.0) /. 100.0

(** Estimate stop: 8% below entry (Weinstein's max acceptable risk for initial
    stop). *)
let _suggested_stop entry = entry *. 0.92

(** Estimate swing target using simplified Weinstein swing rule: if we have a
    base, target = breakout + (breakout - base_low). *)
let _swing_target ~breakout ~base_low_opt =
  match base_low_opt with
  | None -> None
  | Some base_low ->
      if Float.(breakout > base_low) then
        Some (breakout +. (breakout -. base_low))
      else None

(** Estimate base low from MA value (proxy: 85% of current MA). *)
let _base_low (a : Stock_analysis.t) : float option =
  match a.stage.ma_value with
  | v when Float.(v > 0.0) -> Some (v *. 0.85)
  | _ -> None

let _build_candidate ~weights:_ ~sector ~(a : Stock_analysis.t) ~score ~reasons
    ~is_short : scored_candidate =
  let breakout =
    Option.value a.breakout_price ~default:(a.stage.ma_value *. 1.05)
  in
  let entry = _suggested_entry breakout in
  let stop_ =
    if is_short then entry *. 1.08 (* short stop above entry *)
    else _suggested_stop entry
  in
  let risk_pct =
    if Float.(entry = 0.0) then 0.0 else Float.abs ((entry -. stop_) /. entry)
  in
  let base_low = _base_low a in
  let swing =
    if is_short then None else _swing_target ~breakout ~base_low_opt:base_low
  in
  {
    ticker = a.ticker;
    analysis = a;
    sector;
    grade = _grade_of_score score;
    score;
    suggested_entry = entry;
    suggested_stop = stop_;
    risk_pct;
    swing_target = swing;
    rationale = reasons;
  }

(** Evaluate long candidates: filter, score, grade, sort, and cap. *)
let _evaluate_longs ~weights ~min_grade ~max_buy_candidates ~candidates
    ~macro_trend : scored_candidate list =
  let buys_active =
    match macro_trend with Bullish | Neutral -> true | Bearish -> false
  in
  if not buys_active then []
  else
    candidates
    |> List.filter_map ~f:(fun (a, sector) ->
        if equal_sector_rating sector.rating Weak then None
        else if not (Stock_analysis.is_breakout_candidate a) then None
        else
          let score, reasons = _score_long ~weights ~sector a in
          let grade = _grade_of_score score in
          if compare_grade grade min_grade < 0 then None
          else
            Some
              (_build_candidate ~weights ~sector ~a ~score ~reasons
                 ~is_short:false))
    |> List.sort ~compare:(fun a b -> Int.compare b.score a.score)
    |> fun l -> List.sub l ~pos:0 ~len:(min max_buy_candidates (List.length l))

(** Evaluate short candidates: filter, score, grade, sort, and cap. *)
let _evaluate_shorts ~weights ~min_grade ~max_short_candidates ~candidates
    ~macro_trend : scored_candidate list =
  let shorts_active =
    match macro_trend with Bearish | Neutral -> true | Bullish -> false
  in
  if not shorts_active then []
  else
    candidates
    |> List.filter_map ~f:(fun (a, sector) ->
        if equal_sector_rating sector.rating Strong then None
        else if not (Stock_analysis.is_breakdown_candidate a) then None
        else
          let score, reasons = _score_short ~weights ~sector a in
          let grade = _grade_of_score score in
          let grade_ok =
            match macro_trend with
            | Bullish -> equal_grade grade A_plus
            | _ -> compare_grade grade min_grade >= 0
          in
          if not grade_ok then None
          else
            Some
              (_build_candidate ~weights ~sector ~a ~score ~reasons
                 ~is_short:true))
    |> List.sort ~compare:(fun a b -> Int.compare b.score a.score)
    |> fun l ->
    List.sub l ~pos:0 ~len:(min max_short_candidates (List.length l))

(** Build watchlist: C/D grade candidates not already in the buy list. *)
let _build_watchlist ~weights ~candidates ~buy_candidates ~held_set ~buys_active
    : (string * string) list =
  if not buys_active then []
  else
    candidates
    |> List.filter_map ~f:(fun (sa, sector) ->
        if Set.mem held_set sa.Stock_analysis.ticker then None
        else if not (Stock_analysis.is_breakout_candidate sa) then None
        else
          let score, _ = _score_long ~weights ~sector sa in
          let grade = _grade_of_score score in
          let in_buy_list =
            List.exists buy_candidates ~f:(fun c ->
                String.(c.ticker = sa.Stock_analysis.ticker))
          in
          if in_buy_list then None
          else if equal_grade grade C || equal_grade grade D then
            Some
              ( sa.Stock_analysis.ticker,
                Printf.sprintf "Grade %s, score %d" (grade_to_string grade)
                  score )
          else None)

(* ------------------------------------------------------------------ *)
(* Main screener                                                        *)
(* ------------------------------------------------------------------ *)

let screen ~config ~macro_trend ~sector_map ~stocks ~held_tickers : result =
  let held_set = String.Set.of_list held_tickers in
  let { weights; min_grade; max_buy_candidates; max_short_candidates } =
    config
  in
  let buys_active =
    match macro_trend with Bullish | Neutral -> true | Bearish -> false
  in
  let candidates =
    List.filter_map stocks ~f:(fun (a : Stock_analysis.t) ->
        if Set.mem held_set a.ticker then None
        else
          let sector =
            Option.value
              (Hashtbl.find sector_map a.ticker)
              ~default:
                {
                  sector_name = "Unknown";
                  rating = Neutral;
                  stage = Stage1 { weeks_in_base = 0 };
                }
          in
          Some (a, sector))
  in
  let buy_candidates =
    _evaluate_longs ~weights ~min_grade ~max_buy_candidates ~candidates
      ~macro_trend
  in
  let short_candidates =
    _evaluate_shorts ~weights ~min_grade ~max_short_candidates ~candidates
      ~macro_trend
  in
  let watchlist =
    _build_watchlist ~weights ~candidates ~buy_candidates ~held_set ~buys_active
  in
  { buy_candidates; short_candidates; watchlist; macro_trend }

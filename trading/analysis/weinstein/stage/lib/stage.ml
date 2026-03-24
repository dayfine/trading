open Core
open Types
open Weinstein_types

(* ------------------------------------------------------------------ *)
(* Config and defaults                                                  *)
(* ------------------------------------------------------------------ *)

type config = {
  ma_period : int;
  ma_weighted : bool;
  slope_threshold : float;
  slope_lookback : int;
  confirm_weeks : int;
  late_stage2_decel : float;
}

let default_config =
  { ma_period = 30
  ; ma_weighted = true
  ; slope_threshold = 0.005
  ; slope_lookback = 4
  ; confirm_weeks = 6
  ; late_stage2_decel = 0.5
  }

(* ------------------------------------------------------------------ *)
(* Result type                                                          *)
(* ------------------------------------------------------------------ *)

type result = {
  stage : stage;
  ma_value : float;
  ma_slope : ma_slope;
  ma_slope_pct : float;
  transition : (stage * stage) option;
  above_ma_count : int;
}

(* ------------------------------------------------------------------ *)
(* Internal helpers                                                     *)
(* ------------------------------------------------------------------ *)

(** Compute moving average values across a price series. Returns a list
    of (date, ma_value) pairs aligned to the last bar of each window. *)
let _compute_ma ~period ~weighted (bars : Daily_price.t list) :
    (Date.t * float) list =
  let n = List.length bars in
  if n < period then []
  else
    List.init (n - period + 1) ~f:(fun i ->
        let window = List.sub bars ~pos:i ~len:period in
        let prices = List.map window ~f:(fun b -> b.Daily_price.adjusted_close) in
        let ma_val =
          if weighted then
            let weight_sum = Float.of_int (period * (period + 1) / 2) in
            let weighted_sum =
              List.foldi prices ~init:0.0 ~f:(fun j acc p ->
                  acc +. (p *. Float.of_int (j + 1)))
            in
            weighted_sum /. weight_sum
          else
            let sum = List.sum (module Float) prices ~f:Fn.id in
            sum /. Float.of_int period
        in
        let date = (List.last_exn window).Daily_price.date in
        (date, ma_val))

(** Classify the MA slope given current and lookback MA values. *)
let _classify_slope ~threshold ~current ~lookback : ma_slope * float =
  if Float.(lookback = 0.0) then (Flat, 0.0)
  else
    let slope_pct = (current -. lookback) /. Float.abs lookback in
    let direction =
      if Float.(slope_pct > threshold) then Rising
      else if Float.(slope_pct < -.threshold) then Declining
      else Flat
    in
    (direction, slope_pct)

(** Count how many of the last [n] bars have close > the corresponding MA
    value. Requires aligned (bar, ma_val) pairs. *)
let _count_above_ma (aligned : (Daily_price.t * float) list) ~n : int =
  let recent = List.rev aligned |> (fun l -> List.sub l ~pos:0 ~len:(min n (List.length l))) in
  List.count recent ~f:(fun (bar, ma_val) ->
      Float.(bar.Daily_price.adjusted_close > ma_val))

(** Detect late Stage 2: MA is still rising but slope has decelerated
    significantly from its recent peak. *)
let _is_late_stage2 ~decel_threshold (ma_values : float list) ~slope_lookback : bool =
  let n = List.length ma_values in
  if n < slope_lookback * 2 then false
  else
    (* Compute slopes over successive [slope_lookback] windows *)
    let recent_ma = List.rev ma_values |> (fun l -> List.sub l ~pos:0 ~len:(slope_lookback * 2)) |> List.rev in
    let old_slope =
      let old_ma = List.nth_exn recent_ma 0 in
      let mid_ma = List.nth_exn recent_ma slope_lookback in
      if Float.(old_ma = 0.0) then 0.0
      else (mid_ma -. old_ma) /. Float.abs old_ma
    in
    let new_slope =
      let mid_ma = List.nth_exn recent_ma slope_lookback in
      let cur_ma = List.last_exn recent_ma in
      if Float.(mid_ma = 0.0) then 0.0
      else (cur_ma -. mid_ma) /. Float.abs mid_ma
    in
    (* Late Stage 2 if old slope was positive and new slope is ≤ decel_threshold fraction of it *)
    Float.(old_slope > 0.0)
    && Float.(new_slope < old_slope *. (1.0 -. decel_threshold))

(** Infer initial stage when no prior_stage is given by examining the
    long-term MA trend. *)
let _infer_initial_stage ~ma_slope ~above_ma_count ~confirm_weeks : stage =
  match ma_slope with
  | Rising ->
    let below = confirm_weeks - above_ma_count in
    if below <= 1 then Stage2 { weeks_advancing = 0; late = false }
    else Stage1 { weeks_in_base = 0 }
  | Declining ->
    if above_ma_count <= 1 then Stage4 { weeks_declining = 0 }
    else Stage3 { weeks_topping = 0 }
  | Flat ->
    (* Conservative default: Stage1 (won't trigger a buy signal) *)
    Stage1 { weeks_in_base = 0 }

(** Advance the stage counter by one week. *)
let _advance_stage (s : stage) : stage =
  match s with
  | Stage1 { weeks_in_base } -> Stage1 { weeks_in_base = weeks_in_base + 1 }
  | Stage2 { weeks_advancing; late } ->
    Stage2 { weeks_advancing = weeks_advancing + 1; late }
  | Stage3 { weeks_topping } -> Stage3 { weeks_topping = weeks_topping + 1 }
  | Stage4 { weeks_declining } -> Stage4 { weeks_declining = weeks_declining + 1 }

(* ------------------------------------------------------------------ *)
(* Main classifier                                                      *)
(* ------------------------------------------------------------------ *)

let classify ~config ~(bars : Daily_price.t list) ~prior_stage : result =
  let { ma_period; ma_weighted; slope_threshold; slope_lookback; confirm_weeks; late_stage2_decel } =
    config
  in
  (* Need at least ma_period bars to compute a meaningful MA *)
  let ma_series = _compute_ma ~period:ma_period ~weighted:ma_weighted bars in
  (* Fall back to safe defaults if insufficient data *)
  if List.is_empty ma_series then
    { stage = Stage1 { weeks_in_base = 0 }
    ; ma_value = 0.0
    ; ma_slope = Flat
    ; ma_slope_pct = 0.0
    ; transition = None
    ; above_ma_count = 0
    }
  else
    let current_ma = snd (List.last_exn ma_series) in
    (* Compute slope: compare current MA to MA [slope_lookback] steps back *)
    let lookback_ma =
      let ma_len = List.length ma_series in
      if ma_len > slope_lookback then
        snd (List.nth_exn ma_series (ma_len - 1 - slope_lookback))
      else
        snd (List.hd_exn ma_series)
    in
    let (ma_slope_dir, ma_slope_pct) =
      _classify_slope ~threshold:slope_threshold ~current:current_ma ~lookback:lookback_ma
    in
    (* Count recent bars above MA *)
    let bars_len = List.length bars in
    let ma_len = List.length ma_series in
    (* Align: bars and ma_series — ma_series starts at index (ma_period - 1) of bars *)
    let aligned =
      let offset = bars_len - ma_len in
      List.mapi ma_series ~f:(fun i (_, mv) ->
          let bar = List.nth_exn bars (offset + i) in
          (bar, mv))
    in
    let above_ma_count = _count_above_ma aligned ~n:confirm_weeks in
    let below_ma_count = (min confirm_weeks ma_len) - above_ma_count in
    (* Detect late Stage 2 *)
    let is_late =
      _is_late_stage2 ~decel_threshold:late_stage2_decel
        (List.map ma_series ~f:snd)
        ~slope_lookback
    in
    (* Classify stage based on MA slope and price position *)
    let new_stage =
      match (ma_slope_dir, prior_stage) with
      (* Rising MA with price mostly above → Stage 2 *)
      | Rising, _ when above_ma_count > below_ma_count ->
        let weeks =
          match prior_stage with
          | Some (Stage2 { weeks_advancing; _ }) -> weeks_advancing + 1
          | _ -> 1
        in
        Stage2 { weeks_advancing = weeks; late = is_late }
      (* Declining MA with price mostly below → Stage 4 *)
      | Declining, _ when below_ma_count > above_ma_count ->
        let weeks =
          match prior_stage with
          | Some (Stage4 { weeks_declining }) -> weeks_declining + 1
          | _ -> 1
        in
        Stage4 { weeks_declining = weeks }
      (* Flat MA: use prior context to disambiguate Stage 1 vs Stage 3 *)
      | Flat, Some prior ->
        (match prior with
         | Stage1 _ | Stage4 _ -> _advance_stage (Stage1 { weeks_in_base = weeks_in_stage prior })
         | Stage2 _ | Stage3 _ -> _advance_stage (Stage3 { weeks_topping = weeks_in_stage prior }))
      (* Rising MA but price not yet mostly above (early transition) *)
      | Rising, Some (Stage1 { weeks_in_base }) ->
        Stage1 { weeks_in_base = weeks_in_base + 1 }
      (* Declining MA but price not yet mostly below (early transition) *)
      | Declining, Some (Stage3 { weeks_topping }) ->
        Stage3 { weeks_topping = weeks_topping + 1 }
      (* No prior stage: infer from MA slope and price position *)
      | _, None ->
        _infer_initial_stage ~ma_slope:ma_slope_dir ~above_ma_count ~confirm_weeks
      (* Catch-all for mixed signals: continue prior or default Stage1 *)
      | _, Some prior -> _advance_stage prior
    in
    let transition =
      match prior_stage with
      | None -> None
      | Some p ->
        if equal_stage (new_stage) (p) then None
        else
          (* Compare by stage number to detect actual transitions *)
          let pn = stage_number p in
          let nn = stage_number new_stage in
          if pn = nn then None else Some (p, new_stage)
    in
    { stage = new_stage
    ; ma_value = current_ma
    ; ma_slope = ma_slope_dir
    ; ma_slope_pct
    ; transition
    ; above_ma_count
    }

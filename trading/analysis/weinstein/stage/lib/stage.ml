open Core
open Types
open Weinstein_types

(* ------------------------------------------------------------------ *)
(* Config and defaults                                                  *)
(* ------------------------------------------------------------------ *)

type ma_type = Sma | Wma | Ema [@@deriving show, eq, sexp]

type config = {
  ma_period : int;
  ma_type : ma_type;
  slope_threshold : float;
  slope_lookback : int;
  confirm_weeks : int;
  late_stage2_decel : float;
}
[@@deriving sexp]

let default_config =
  {
    ma_period = 30;
    ma_type = Wma;
    slope_threshold = 0.005;
    slope_lookback = 4;
    confirm_weeks = 6;
    late_stage2_decel = 0.5;
  }

(* ------------------------------------------------------------------ *)
(* Result type                                                          *)
(* ------------------------------------------------------------------ *)

type result = {
  stage : stage;
  ma_value : float;
  ma_direction : ma_direction;
  ma_slope_pct : float;
  transition : (stage * stage) option;
  above_ma_count : int;
}

(* ------------------------------------------------------------------ *)
(* Private stage helpers                                               *)
(* ------------------------------------------------------------------ *)

let _stage_number = function
  | Stage1 _ -> 1
  | Stage2 _ -> 2
  | Stage3 _ -> 3
  | Stage4 _ -> 4

let _weeks_in_stage = function
  | Stage1 { weeks_in_base } -> weeks_in_base
  | Stage2 { weeks_advancing; _ } -> weeks_advancing
  | Stage3 { weeks_topping } -> weeks_topping
  | Stage4 { weeks_declining } -> weeks_declining

(* ------------------------------------------------------------------ *)
(* Internal helpers                                                     *)
(* ------------------------------------------------------------------ *)

(** Compute moving average values across a price series. Returns a list of
    (date, ma_value) pairs aligned to the last bar of each window. Delegates to
    [Sma.calculate_sma] / [Sma.calculate_weighted_ma] / [Ema.calculate_ema]. *)
let _compute_ma ~period ~ma_type (bars : Daily_price.t list) :
    (Date.t * float) list =
  let data =
    List.map bars ~f:(fun b ->
        Indicator_types.
          { date = b.Daily_price.date; value = b.Daily_price.adjusted_close })
  in
  let result =
    match ma_type with
    | Sma -> Sma.calculate_sma data period
    | Wma -> Sma.calculate_weighted_ma data period
    | Ema -> Ema.calculate_ema data period
  in
  List.map result ~f:(fun iv -> Indicator_types.(iv.date, iv.value))

(** Classify the MA direction given current and lookback MA values. Returns
    [(direction, slope_pct)] where
    [slope_pct = (current - lookback) / |lookback|] (positive = rising, negative
    = declining). *)
let _classify_direction ~threshold ~current ~lookback : ma_direction * float =
  if Float.(lookback = 0.0) then (Flat, 0.0)
  else
    let slope_pct = (current -. lookback) /. Float.abs lookback in
    let direction =
      if Float.(slope_pct > threshold) then Rising
      else if Float.(slope_pct < -.threshold) then Declining
      else Flat
    in
    (direction, slope_pct)

(** Count how many of the last [n] bars have close > the corresponding MA value.
    Requires aligned (bar, ma_val) pairs. *)
let _count_above_ma (aligned : (Daily_price.t * float) list) ~n : int =
  let recent =
    List.rev aligned |> fun l -> List.sub l ~pos:0 ~len:(min n (List.length l))
  in
  List.count recent ~f:(fun (bar, ma_val) ->
      Float.(bar.Daily_price.adjusted_close > ma_val))

(** Detect late Stage 2: MA is still rising but slope has decelerated
    significantly from its recent peak. *)
let _is_late_stage2 ~decel_threshold (ma_values : float list) ~slope_lookback :
    bool =
  let n = List.length ma_values in
  if n < slope_lookback * 2 then false
  else
    let recent_ma =
      List.rev ma_values
      |> (fun l -> List.sub l ~pos:0 ~len:(slope_lookback * 2))
      |> List.rev
    in
    let old_ma = List.nth_exn recent_ma 0 in
    let mid_ma = List.nth_exn recent_ma slope_lookback in
    let cur_ma = List.last_exn recent_ma in
    let old_slope =
      if Float.(old_ma = 0.0) then 0.0
      else (mid_ma -. old_ma) /. Float.abs old_ma
    in
    let new_slope =
      if Float.(mid_ma = 0.0) then 0.0
      else (cur_ma -. mid_ma) /. Float.abs mid_ma
    in
    (* Late Stage 2 if old slope was positive and new slope has decelerated *)
    Float.(old_slope > 0.0)
    && Float.(new_slope < old_slope *. (1.0 -. decel_threshold))

(** Infer initial stage when no prior_stage is given by examining the long-term
    MA trend. *)
let _infer_initial_stage ~ma_direction ~above_ma_count ~confirm_weeks : stage =
  match ma_direction with
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
  | Stage4 { weeks_declining } ->
      Stage4 { weeks_declining = weeks_declining + 1 }

(* ------------------------------------------------------------------ *)
(* Classify helpers                                                     *)
(* ------------------------------------------------------------------ *)

(** Align bars with their corresponding MA values. [ma_series] starts at index
    [(List.length bars - List.length ma_series)] of [bars]. *)
let _align_bars_with_ma (bars : Daily_price.t list)
    (ma_series : (Date.t * float) list) : (Daily_price.t * float) list =
  let offset = List.length bars - List.length ma_series in
  List.mapi ma_series ~f:(fun i (_, mv) ->
      let bar = List.nth_exn bars (offset + i) in
      (bar, mv))

let _next_stage2 prior_stage is_late =
  let weeks =
    match prior_stage with
    | Some (Stage2 { weeks_advancing; _ }) -> weeks_advancing + 1
    | _ -> 1
  in
  Stage2 { weeks_advancing = weeks; late = is_late }

let _next_stage4 prior_stage =
  let weeks =
    match prior_stage with
    | Some (Stage4 { weeks_declining }) -> weeks_declining + 1
    | _ -> 1
  in
  Stage4 { weeks_declining = weeks }

let _classify_flat_ma prior =
  match prior with
  | Stage1 _ | Stage4 _ ->
      _advance_stage (Stage1 { weeks_in_base = _weeks_in_stage prior })
  | Stage2 _ | Stage3 _ ->
      _advance_stage (Stage3 { weeks_topping = _weeks_in_stage prior })

(** Determine the new stage from MA direction, prior stage, and price/MA
    position counts. *)
let _classify_new_stage ~ma_dir ~prior_stage ~above_ma_count ~below_ma_count
    ~is_late ~confirm_weeks : stage =
  match (ma_dir, prior_stage) with
  (* Rising MA with price mostly above → Stage 2 *)
  | Rising, _ when above_ma_count > below_ma_count ->
      _next_stage2 prior_stage is_late
  (* Declining MA with price mostly below → Stage 4 *)
  | Declining, _ when below_ma_count > above_ma_count ->
      _next_stage4 prior_stage
  (* Flat MA: use prior context to disambiguate Stage 1 vs Stage 3 *)
  | Flat, Some prior -> _classify_flat_ma prior
  (* Rising MA but price not yet mostly above (early transition) *)
  | Rising, Some (Stage1 { weeks_in_base }) ->
      Stage1 { weeks_in_base = weeks_in_base + 1 }
  (* Declining MA but price not yet mostly below (early transition) *)
  | Declining, Some (Stage3 { weeks_topping }) ->
      Stage3 { weeks_topping = weeks_topping + 1 }
  (* No prior stage: infer from MA direction and price position *)
  | _, None ->
      _infer_initial_stage ~ma_direction:ma_dir ~above_ma_count ~confirm_weeks
  (* Catch-all for mixed signals: continue prior or default Stage1 *)
  | _, Some prior -> _advance_stage prior

(** Detect a stage number transition between prior and new stage. *)
let _detect_transition ~prior_stage ~new_stage : (stage * stage) option =
  match prior_stage with
  | None -> None
  | Some p ->
      if equal_stage new_stage p then None
      else if _stage_number p = _stage_number new_stage then None
      else Some (p, new_stage)

(** Compute the current MA value, direction, and slope from [ma_series]. Returns
    [(current_ma, direction, slope_pct)]. *)
let _compute_ma_slope ~slope_threshold ~slope_lookback
    (ma_series : (Date.t * float) list) : float * ma_direction * float =
  let current_ma = snd (List.last_exn ma_series) in
  let lookback_ma =
    let n = List.length ma_series in
    if n > slope_lookback then
      snd (List.nth_exn ma_series (n - 1 - slope_lookback))
    else snd (List.hd_exn ma_series)
  in
  let dir, slope_pct =
    _classify_direction ~threshold:slope_threshold ~current:current_ma
      ~lookback:lookback_ma
  in
  (current_ma, dir, slope_pct)

(** Classify stage from a non-empty [ma_series]. All signals are derived from
    the MA and bar alignment computed here. *)
let _classify_with_ma ~config ~(bars : Daily_price.t list) ~prior_stage
    ma_series : result =
  let current_ma, ma_dir, ma_slope_pct =
    _compute_ma_slope ~slope_threshold:config.slope_threshold
      ~slope_lookback:config.slope_lookback ma_series
  in
  let aligned = _align_bars_with_ma bars ma_series in
  let above_ma_count = _count_above_ma aligned ~n:config.confirm_weeks in
  let below_ma_count =
    min config.confirm_weeks (List.length ma_series) - above_ma_count
  in
  let is_late =
    _is_late_stage2 ~decel_threshold:config.late_stage2_decel
      (List.map ma_series ~f:snd)
      ~slope_lookback:config.slope_lookback
  in
  let new_stage =
    _classify_new_stage ~ma_dir ~prior_stage ~above_ma_count ~below_ma_count
      ~is_late ~confirm_weeks:config.confirm_weeks
  in
  let transition = _detect_transition ~prior_stage ~new_stage in
  {
    stage = new_stage;
    ma_value = current_ma;
    ma_direction = ma_dir;
    ma_slope_pct;
    transition;
    above_ma_count;
  }

(* ------------------------------------------------------------------ *)
(* Main classifier                                                      *)
(* ------------------------------------------------------------------ *)

let classify ~config ~(bars : Daily_price.t list) ~prior_stage : result =
  let ma_series =
    _compute_ma ~period:config.ma_period ~ma_type:config.ma_type bars
  in
  if List.is_empty ma_series then
    {
      stage = Stage1 { weeks_in_base = 0 };
      ma_value = 0.0;
      ma_direction = Flat;
      ma_slope_pct = 0.0;
      transition = None;
      above_ma_count = 0;
    }
  else _classify_with_ma ~config ~bars ~prior_stage ma_series

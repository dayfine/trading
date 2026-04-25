open Core
open Types
open Weinstein_types

(* @large-module: Stage classifier holds two parallel entry points sharing
   one set of stage-selection helpers — the bar-list [classify] (legacy) and
   the indicator-callback [classify_with_callbacks] (panel-backed). The
   callback-shape walk-back / depth-bounding helpers have no other home and
   the bar-list wrapper closures have no meaning outside this module. *)

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
(* Internal helpers (shared by callback and bar-list paths)             *)
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
(* Stage selection                                                      *)
(* ------------------------------------------------------------------ *)

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

(* ------------------------------------------------------------------ *)
(* Callback-shaped helpers                                              *)
(*                                                                      *)
(* These read MA / close values through                                 *)
(* [get_ma ~week_offset] / [get_close ~week_offset] callbacks where     *)
(* [week_offset:0] = current week, [1] = previous week, etc.            *)
(* ------------------------------------------------------------------ *)

(** Walk down from [max_off] toward 0 and return the largest offset where
    [get_ma] returns [Some]. Returns [None] only if even [get_ma ~week_offset:0]
    is [None]. Mirrors the bar-list code's [List.hd_exn ma_series] fallback when
    there are fewer MA points than [slope_lookback]. *)
let _largest_defined_offset ~get_ma ~max_off : int option =
  let rec walk off =
    if off < 0 then None
    else
      match get_ma ~week_offset:off with
      | Some _ -> Some off
      | None -> walk (off - 1)
  in
  walk max_off

(** Determine [ma_depth] = number of consecutive defined MA values starting from
    [week_offset:0]. Walks forward from offset 0 and stops at the first [None]
    or at [stop_at] (whichever comes first). [stop_at] caps the walk so we don't
    probe arbitrarily-large offsets — callers pass the largest offset any reader
    will need (typically [max confirm_weeks (2*lookback)]). *)
let _ma_depth ~get_ma ~stop_at : int =
  let rec walk off =
    if off >= stop_at then stop_at
    else
      match get_ma ~week_offset:off with
      | Some _ -> walk (off + 1)
      | None -> off
  in
  walk 0

(** Compute current MA value, direction, and slope_pct from callbacks. Mirrors
    the bar-list [_compute_ma_slope] including the fallback to the oldest
    available MA when [slope_lookback] is too far back. *)
let _compute_ma_slope_callback ~get_ma ~slope_threshold ~slope_lookback
    ~current_ma : ma_direction * float =
  let lookback_off =
    Option.value
      (_largest_defined_offset ~get_ma ~max_off:slope_lookback)
      ~default:0
  in
  let lookback_ma =
    Option.value (get_ma ~week_offset:lookback_off) ~default:current_ma
  in
  _classify_direction ~threshold:slope_threshold ~current:current_ma
    ~lookback:lookback_ma

(** Count, over [week_offset] in [0; min(confirm_weeks, ma_depth) - 1], how many
    weeks have [close > ma]. Returns [(above, examined)] so the caller can
    derive [below_ma_count = examined - above]. Stops early on the first missing
    close or MA at any offset (the caller will treat unscanned offsets as
    not-above). *)
let _count_above_ma_callback ~get_ma ~get_close ~confirm_weeks ~ma_depth :
    int * int =
  let n = min confirm_weeks ma_depth in
  let rec loop off above examined =
    if off >= n then (above, examined)
    else
      match (get_ma ~week_offset:off, get_close ~week_offset:off) with
      | Some ma, Some close ->
          let above' = if Float.(close > ma) then above + 1 else above in
          loop (off + 1) above' (examined + 1)
      | _ -> (above, examined)
  in
  loop 0 0 0

(** Detect late Stage 2 via callbacks. Reads MA at three offsets:
    [old = 2*slope_lookback - 1], [mid = slope_lookback - 1], [cur = 0]. All
    three must be defined; otherwise returns [false] (matches the
    [n < slope_lookback * 2] guard in the bar-list version). *)
let _is_late_stage2_callback ~get_ma ~decel_threshold ~slope_lookback : bool =
  let old_off = (2 * slope_lookback) - 1 in
  let mid_off = slope_lookback - 1 in
  match
    ( get_ma ~week_offset:old_off,
      get_ma ~week_offset:mid_off,
      get_ma ~week_offset:0 )
  with
  | Some old_ma, Some mid_ma, Some cur_ma ->
      let old_slope =
        if Float.(old_ma = 0.0) then 0.0
        else (mid_ma -. old_ma) /. Float.abs old_ma
      in
      let new_slope =
        if Float.(mid_ma = 0.0) then 0.0
        else (cur_ma -. mid_ma) /. Float.abs mid_ma
      in
      Float.(old_slope > 0.0)
      && Float.(new_slope < old_slope *. (1.0 -. decel_threshold))
  | _ -> false

(* ------------------------------------------------------------------ *)
(* Default result for the empty / no-MA case                            *)
(* ------------------------------------------------------------------ *)

let _stage1_default_result : result =
  {
    stage = Stage1 { weeks_in_base = 0 };
    ma_value = 0.0;
    ma_direction = Flat;
    ma_slope_pct = 0.0;
    transition = None;
    above_ma_count = 0;
  }

(* ------------------------------------------------------------------ *)
(* Main classifier — callback shape                                     *)
(* ------------------------------------------------------------------ *)

(** Build the result record from already-computed signals. Pulled out of
    [classify_with_callbacks] so the latter stays a flat sequence of
    let-bindings. *)
let _build_result ~current_ma ~ma_dir ~ma_slope_pct ~prior_stage ~above_ma_count
    ~below_ma_count ~is_late ~confirm_weeks : result =
  let new_stage =
    _classify_new_stage ~ma_dir ~prior_stage ~above_ma_count ~below_ma_count
      ~is_late ~confirm_weeks
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

(** Body of [classify_with_callbacks] after the [get_ma ~week_offset:0] guard.
    Computes the four signals (slope, ma_depth, above-ma count, late) and
    assembles the result record. *)
let _classify_signals ~config ~get_ma ~get_close ~prior_stage ~current_ma :
    result =
  let ma_dir, ma_slope_pct =
    _compute_ma_slope_callback ~get_ma ~slope_threshold:config.slope_threshold
      ~slope_lookback:config.slope_lookback ~current_ma
  in
  let stop_at = max config.confirm_weeks (2 * config.slope_lookback) in
  let ma_depth = _ma_depth ~get_ma ~stop_at in
  let above_ma_count, examined =
    _count_above_ma_callback ~get_ma ~get_close
      ~confirm_weeks:config.confirm_weeks ~ma_depth
  in
  let below_ma_count = examined - above_ma_count in
  let is_late =
    _is_late_stage2_callback ~get_ma ~decel_threshold:config.late_stage2_decel
      ~slope_lookback:config.slope_lookback
  in
  _build_result ~current_ma ~ma_dir ~ma_slope_pct ~prior_stage ~above_ma_count
    ~below_ma_count ~is_late ~confirm_weeks:config.confirm_weeks

let classify_with_callbacks ~config ~get_ma ~get_close ~prior_stage : result =
  match get_ma ~week_offset:0 with
  | None -> _stage1_default_result
  | Some current_ma ->
      _classify_signals ~config ~get_ma ~get_close ~prior_stage ~current_ma

(* ------------------------------------------------------------------ *)
(* Callback bundle — used by panel-backed callers                       *)
(*                                                                      *)
(* PR-D introduces this record so that callers like                     *)
(* [Stock_analysis.analyze_with_callbacks] can thread Stage's callbacks *)
(* through their own callback bundles uniformly. The bar-list           *)
(* [callbacks_from_bars] constructor centralises the wrapper plumbing   *)
(* (precompute MA series + index closures over arrays) into one place,  *)
(* eliminating duplication across [classify] and any wrapper that wants *)
(* to delegate to [classify_with_callbacks].                            *)
(* ------------------------------------------------------------------ *)

type callbacks = {
  get_ma : week_offset:int -> float option;
  get_close : week_offset:int -> float option;
}

(* ------------------------------------------------------------------ *)
(* Bar-list wrapper — preserves the existing API                        *)
(*                                                                      *)
(* The wrapper precomputes the full MA series + closes once, then       *)
(* delegates to [classify_with_callbacks]. Behaviour is bit-identical   *)
(* to the bar-list path: the same MA values feed the slope, above-MA    *)
(* count, and late-Stage-2 reads.                                       *)
(* ------------------------------------------------------------------ *)

(** Build a [get_ma] closure over a precomputed MA-value array, indexed in
    chronological order (oldest at index 0, newest at the end). [week_offset:0]
    returns the newest MA value; [week_offset:k] returns [k] weeks back; offsets
    past the array's depth return [None]. *)
let _make_get_ma_from_array (ma_values : float array) :
    week_offset:int -> float option =
  let n = Array.length ma_values in
  fun ~week_offset ->
    let idx = n - 1 - week_offset in
    if idx < 0 || idx >= n then None else Some ma_values.(idx)

(** Build a [get_close] closure over a bar array, using [adjusted_close] (the
    same field [_compute_ma] uses, so MA and close come from one source). *)
let _make_get_close_from_bars (bars : Daily_price.t array) :
    week_offset:int -> float option =
  let n = Array.length bars in
  fun ~week_offset ->
    let idx = n - 1 - week_offset in
    if idx < 0 || idx >= n then None
    else Some bars.(idx).Daily_price.adjusted_close

let callbacks_from_bars ~config ~(bars : Daily_price.t list) : callbacks =
  let ma_series =
    _compute_ma ~period:config.ma_period ~ma_type:config.ma_type bars
  in
  let ma_values = List.map ma_series ~f:snd |> Array.of_list in
  let bar_array = Array.of_list bars in
  {
    get_ma = _make_get_ma_from_array ma_values;
    get_close = _make_get_close_from_bars bar_array;
  }

let classify ~config ~(bars : Daily_price.t list) ~prior_stage : result =
  let { get_ma; get_close } = callbacks_from_bars ~config ~bars in
  (* The original wrapper short-circuited on an empty MA series; the callback
     entry already does that via [get_ma ~week_offset:0 = None], so this is
     equivalent and keeps a single early-return. *)
  classify_with_callbacks ~config ~get_ma ~get_close ~prior_stage

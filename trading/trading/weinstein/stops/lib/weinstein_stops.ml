open Core
open Trading_base.Types

type stop_state =
  | Initial of {
      stop_level : float;
      reference_level : float;
          (** Support floor (long) or resistance ceiling (short) at entry *)
    }
  | Trailing of {
      stop_level : float;
      last_correction_extreme : float;
      last_trend_extreme : float;
      ma_at_last_adjustment : float;
      correction_count : int;
    }
  | Tightened of {
      stop_level : float;
      last_correction_extreme : float;
      reason : string;
    }
[@@deriving show, eq]

type stop_event =
  | Stop_hit of { trigger_price : float; stop_level : float }
  | Stop_raised of { old_level : float; new_level : float; reason : string }
  | Entered_tightening of { reason : string }
  | No_change
[@@deriving show, eq]

type config = {
  round_number_nudge : float;
  min_correction_pct : float;
  tighten_on_flat_ma : bool;
  ma_flat_threshold : float;
}
[@@deriving show, eq]

let default_config =
  {
    round_number_nudge = 0.125;
    min_correction_pct = 0.08;
    tighten_on_flat_ma = true;
    ma_flat_threshold = 0.002;
  }

(* ---- Nudge functions ---- *)

(* Round numbers and half-dollars attract heavy order flow, so stops placed right
   at those levels are more likely to be triggered by noise. We step just outside
   them when the raw stop lands within [config.round_number_nudge] of a level.
   The nearest half-dollar (or whole dollar) is used as the reference point. *)

let _nearest_half price =
  let floor_half = Float.round_down (price /. 0.5) *. 0.5 in
  let ceil_half = floor_half +. 0.5 in
  if Float.( < ) (Float.abs (price -. ceil_half)) (Float.abs (price -. floor_half))
  then ceil_half
  else floor_half

(* For longs, nudge the stop below the nearest level; for shorts, above. *)
let nudge_round_number ~config ~side price =
  let nudge = config.round_number_nudge in
  let candidate = _nearest_half price in
  if Float.( <= ) (Float.abs (price -. candidate)) nudge then
    match side with
    | Long when Float.( >= ) price candidate -> candidate -. nudge
    | Short when Float.( <= ) price candidate -> candidate +. nudge
    | _ -> price
  else price

(* ---- Stop level extraction ---- *)

let get_stop_level = function
  | Initial { stop_level; _ } -> stop_level
  | Trailing { stop_level; _ } -> stop_level
  | Tightened { stop_level; _ } -> stop_level

(* ---- Stop hit check ---- *)

let check_stop_hit ~state ~side ~bar =
  let stop_level = get_stop_level state in
  match side with
  | Long -> Float.( <= ) bar.Types.Daily_price.low_price stop_level
  | Short -> Float.( >= ) bar.Types.Daily_price.high_price stop_level

(* ---- Initial stop computation ---- *)

let compute_initial_stop ~config ~side ~reference_level =
  (* Half the min-correction threshold: places the initial stop modestly inside
     the reference level without using the full correction distance, which would
     be too loose for an entry stop. *)
  let delta = config.min_correction_pct /. 2.0 in
  let raw_stop =
    match side with
    | Long -> reference_level *. (1.0 -. delta)
    | Short -> reference_level *. (1.0 +. delta)
  in
  Initial { stop_level = nudge_round_number ~config ~side raw_stop; reference_level }

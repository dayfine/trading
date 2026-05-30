open Core
open Weinstein_types

(* Dual-MA early Stage-2 admission (default-off). The fast confirmation MA is a
   simple moving average of recent closes, read self-contained from the
   [get_close] callback so no new panel callback is needed. *)

(** Simple moving average of the [period] closes ending [off] weeks back. Reads
    closes at offsets [off .. off + period - 1] via [get_close]; returns [None]
    if any one of those closes is missing (insufficient history for a full
    window). *)
let _fast_ma ~get_close ~period ~off : float option =
  let rec loop i sum =
    if i >= period then Some (sum /. Float.of_int period)
    else
      match get_close ~week_offset:(off + i) with
      | Some c -> loop (i + 1) (sum +. c)
      | None -> None
  in
  if period <= 0 then None else loop 0 0.0

(** Whether the fast MA is rising from [back] to [current]. Mirrors the rising
    branch of [Stage]'s [_classify_direction]:
    [slope_pct = (current - back) / |back|], rising iff [slope_pct > threshold],
    and never rising when [back = 0.0]. Kept local so this module stays
    independent of [Stage]'s internals. *)
let _is_rising ~threshold ~current ~back : bool =
  if Float.(back = 0.0) then false
  else
    let slope_pct = (current -. back) /. Float.abs back in
    Float.(slope_pct > threshold)

(** Fast MA rising from [back] to [current] AND price [close] above it — the
    early-admission condition once all three reads are present. *)
let _admit ~slope_threshold ~current ~back ~close : bool =
  _is_rising ~threshold:slope_threshold ~current ~back && Float.(close > current)

let compute ~get_close ~early_admission_ma_period ~slope_threshold
    ~slope_lookback : bool =
  match early_admission_ma_period with
  | None -> false
  | Some fast_p -> (
      match
        ( _fast_ma ~get_close ~period:fast_p ~off:0,
          _fast_ma ~get_close ~period:fast_p ~off:slope_lookback,
          get_close ~week_offset:0 )
      with
      | Some current, Some back, Some close ->
          _admit ~slope_threshold ~current ~back ~close
      | _ -> false)

let apply ~early_admit ~prior_stage ~(standard_stage : stage) : stage =
  if not early_admit then standard_stage
  else
    match (standard_stage, prior_stage) with
    | Stage1 _, _ -> Stage2 { weeks_advancing = 0; late = false }
    | Stage2 _, _ -> standard_stage
    | (Stage3 _ | Stage4 _), Some (Stage2 { weeks_advancing; late }) ->
        Stage2 { weeks_advancing = weeks_advancing + 1; late }
    | (Stage3 _ | Stage4 _), _ -> standard_stage

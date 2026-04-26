open Core
open Types
open Weinstein_types

(* ------------------------------------------------------------------ *)
(* Config and defaults                                                  *)
(* ------------------------------------------------------------------ *)

type config = {
  lookback_bars : int;
  strong_threshold : float;
  adequate_threshold : float;
  pullback_contraction : float;
}

let default_config =
  {
    lookback_bars = 4;
    strong_threshold = 2.0;
    adequate_threshold = 1.5;
    pullback_contraction = 0.25;
  }

(* ------------------------------------------------------------------ *)
(* Result type                                                          *)
(* ------------------------------------------------------------------ *)

type result = {
  confirmation : volume_confirmation;
  event_volume : int;
  avg_volume : float;
  volume_ratio : float;
}

(* ------------------------------------------------------------------ *)
(* Callback bundle and constructors                                     *)
(* ------------------------------------------------------------------ *)

type callbacks = { get_volume : week_offset:int -> float option }

(** Build a [week_offset]-indexed float lookup over a chronologically-ordered
    [Daily_price.t list]. [week_offset:0] returns the newest bar's volume;
    offsets past available depth return [None]. Volumes are encoded as floats to
    match the panel encoding ([Volume_panel : Bigarray.float64]). *)
let _make_get_volume_from_bars (bars : Daily_price.t list) :
    week_offset:int -> float option =
  let arr = Array.of_list bars in
  let n = Array.length arr in
  fun ~week_offset ->
    let idx = n - 1 - week_offset in
    if idx < 0 || idx >= n then None
    else Some (Float.of_int arr.(idx).Daily_price.volume)

let callbacks_from_bars ~(bars : Daily_price.t list) : callbacks =
  { get_volume = _make_get_volume_from_bars bars }

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let average_volume ~bars ~n : float =
  if n <= 0 || List.is_empty bars then 0.0
  else
    let recent = List.drop bars (max 0 (List.length bars - n)) in
    let total =
      List.sum (module Int) recent ~f:(fun b -> b.Daily_price.volume)
    in
    Float.of_int total /. Float.of_int (List.length recent)

let _classify_confirmation ~strong_threshold ~adequate_threshold ratio :
    volume_confirmation =
  if Float.(ratio >= strong_threshold) then Strong ratio
  else if Float.(ratio >= adequate_threshold) then Adequate ratio
  else Weak ratio

(** Read the prior [lookback_bars] volumes at offsets
    [event_offset+1 .. event_offset+lookback_bars] from the callbacks. Returns
    [None] if any of those offsets is undefined (insufficient history). *)
let _read_prior_volumes ~get_volume ~event_offset ~lookback_bars :
    float list option =
  let rec loop k acc =
    if k > lookback_bars then Some (List.rev acc)
    else
      match get_volume ~week_offset:(event_offset + k) with
      | None -> None
      | Some v -> loop (k + 1) (v :: acc)
  in
  loop 1 []

let _result_of_volumes ~config ~event_volume_f ~prior_vols : result option =
  let avg_vol =
    List.fold prior_vols ~init:0.0 ~f:( +. )
    /. Float.of_int (List.length prior_vols)
  in
  if Float.(avg_vol = 0.0) then None
  else
    let ratio = event_volume_f /. avg_vol in
    let confirmation =
      _classify_confirmation ~strong_threshold:config.strong_threshold
        ~adequate_threshold:config.adequate_threshold ratio
    in
    Some
      {
        confirmation;
        event_volume = Int.of_float event_volume_f;
        avg_volume = avg_vol;
        volume_ratio = ratio;
      }

(* ------------------------------------------------------------------ *)
(* Callback-shaped public entry                                         *)
(* ------------------------------------------------------------------ *)

(** Compose the event-volume read with the prior-volume read into a result.
    Returns [None] when either read fails or the baseline is degenerate. *)
let _result_at_offset ~config ~callbacks ~event_offset ~event_volume_f :
    result option =
  Option.bind
    (_read_prior_volumes ~get_volume:callbacks.get_volume ~event_offset
       ~lookback_bars:config.lookback_bars) ~f:(fun prior_vols ->
      _result_of_volumes ~config ~event_volume_f ~prior_vols)

let analyze_breakout_with_callbacks ~(config : config) ~(callbacks : callbacks)
    ~event_offset : result option =
  if event_offset < 0 then None
  else
    Option.bind (callbacks.get_volume ~week_offset:event_offset)
      ~f:(fun event_volume_f ->
        _result_at_offset ~config ~callbacks ~event_offset ~event_volume_f)

(* ------------------------------------------------------------------ *)
(* Bar-list wrapper — preserves the existing API                        *)
(* ------------------------------------------------------------------ *)

let analyze_breakout ~config ~bars ~event_idx : result option =
  let n = List.length bars in
  if event_idx < 0 || event_idx >= n then None
  else
    let event_offset = n - 1 - event_idx in
    let callbacks = callbacks_from_bars ~bars in
    analyze_breakout_with_callbacks ~config ~callbacks ~event_offset

let is_pullback_confirmed ~config ~breakout_volume ~pullback_volume : bool =
  if breakout_volume <= 0 then false
  else
    let ratio = Float.of_int pullback_volume /. Float.of_int breakout_volume in
    Float.(ratio <= config.pullback_contraction)

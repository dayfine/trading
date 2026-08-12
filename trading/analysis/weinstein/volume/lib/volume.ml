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
  if
    Float.(avg_vol = 0.0)
    || (not (Float.is_finite avg_vol))
    || not (Float.is_finite event_volume_f)
  then None
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
(* Book §4.2 breakout confirmation — both sanctioned branches           *)
(* ------------------------------------------------------------------ *)

(** Read [count] consecutive volumes at offsets
    [start_offset .. start_offset + count - 1]. [None] when any offset is
    undefined (insufficient history) or [count <= 0]. *)
let _read_window ~get_volume ~start_offset ~count : float list option =
  if count <= 0 then None
  else
    let rec loop k acc =
      if k >= count then Some (List.rev acc)
      else
        match get_volume ~week_offset:(start_offset + k) with
        | None -> None
        | Some v -> loop (k + 1) (v :: acc)
    in
    loop 0 []

(** Arithmetic mean of a non-empty float list. *)
let _mean_of (vs : float list) : float =
  List.fold vs ~init:0.0 ~f:( +. ) /. Float.of_int (List.length vs)

(** Mean of [vs]; [None] when [vs] is empty or the mean is not a usable positive
    baseline (zero / non-finite volumes carry no signal). *)
let _positive_mean (vs : float list) : float option =
  if List.is_empty vs then None
  else
    let m = _mean_of vs in
    Option.some_if (Float.is_finite m && Float.(m > 0.0)) m

(** Branch (a)'s measured quantity — the event bar's volume over the average of
    the prior [lookback_bars] bars. Reuses {!analyze_breakout_with_callbacks}'s
    ratio so the spike branch and the screen-time confirmation grade can never
    drift. [None] = branch (a) could not be evaluated. *)
let _spike_ratio ~config ~callbacks ~event_offset : float option =
  Option.map (analyze_breakout_with_callbacks ~config ~callbacks ~event_offset)
    ~f:(fun r -> r.volume_ratio)

(** "with at least some increase on breakout week" — the event bar's volume
    exceeds the bar immediately before it. [false] when either read is
    undefined: the build-up branch may only confirm on evidence it has. *)
let _increase_on_event_bar ~get_volume ~event_offset : bool =
  match
    ( get_volume ~week_offset:event_offset,
      get_volume ~week_offset:(event_offset + 1) )
  with
  | Some event_v, Some prior_v -> Float.(event_v > prior_v)
  | _ -> false

(** Branch (b) — "volume build-up over 3-4 weeks that is >= 2x average of prior
    several weeks, with at least some increase on breakout week". The build-up
    window is the event bar plus the [lookback_bars - 1] bars before it (default
    4 = the book's "3-4 weeks"); the baseline is the equally-sized window before
    that (the book's "prior several weeks"). Both windows are sized off the same
    configurable [lookback_bars], so the branch carries no hidden constant. *)
let _buildup_multiple ~config ~callbacks ~event_offset : float option =
  let get_volume = callbacks.get_volume in
  let window = config.lookback_bars in
  let buildup =
    _read_window ~get_volume ~start_offset:event_offset ~count:window
  and baseline =
    _read_window ~get_volume ~start_offset:(event_offset + window) ~count:window
  in
  match
    ( Option.bind buildup ~f:_positive_mean,
      Option.bind baseline ~f:_positive_mean )
  with
  | Some buildup_avg, Some baseline_avg -> Some (buildup_avg /. baseline_avg)
  | _ -> None

type breakout_confirmation =
  | Spike of float
  | Buildup of float
  | Unconfirmed of {
      spike_ratio : float option;
      buildup_multiple : float option;
    }
[@@deriving show, eq]

(** Branch (b)'s full verdict for an already-measured [multiple]: it clears the
    threshold {i and} the event bar itself shows some increase. *)
let _buildup_confirms ~config ~callbacks ~event_offset ~multiple =
  Float.(multiple >= config.strong_threshold)
  && _increase_on_event_bar ~get_volume:callbacks.get_volume ~event_offset

(* Branch precedence: (a) is checked first so a bar clearing BOTH branches is
   reported as the spike — the book's headline case, and the one
   [analyze_breakout]'s [confirmation] grade already names. The verdict itself
   is branch-agnostic ([confirms_breakout] below), so precedence is a labelling
   choice, never a behaviour one. *)
let _classify_of ~config ~callbacks ~event_offset ~spike_ratio ~buildup_multiple
    =
  match (spike_ratio, buildup_multiple) with
  | Some r, _ when Float.(r >= config.strong_threshold) -> Some (Spike r)
  | _, Some m
    when _buildup_confirms ~config ~callbacks ~event_offset ~multiple:m ->
      Some (Buildup m)
  | None, None -> None
  | _ -> Some (Unconfirmed { spike_ratio; buildup_multiple })

let classify_breakout ~(config : config) ~(callbacks : callbacks) ~event_offset
    : breakout_confirmation option =
  if event_offset < 0 then None
  else
    _classify_of ~config ~callbacks ~event_offset
      ~spike_ratio:(_spike_ratio ~config ~callbacks ~event_offset)
      ~buildup_multiple:(_buildup_multiple ~config ~callbacks ~event_offset)

let confirms_breakout ~(config : config) ~(callbacks : callbacks) ~event_offset
    : bool option =
  Option.map (classify_breakout ~config ~callbacks ~event_offset) ~f:(function
    | Spike _ | Buildup _ -> true
    | Unconfirmed _ -> false)

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

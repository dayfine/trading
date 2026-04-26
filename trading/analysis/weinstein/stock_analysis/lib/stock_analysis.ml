open Core
open Types
open Weinstein_types

(* @large-module: Stock_analysis holds two parallel entry points sharing the
   same Stage / RS / Volume / Resistance composition — the bar-list [analyze]
   (legacy) and the indicator-callback [analyze_with_callbacks] (panel-backed).
   The callback path threads {!Stage.callbacks}, {!Rs.callbacks},
   {!Volume.callbacks}, and {!Resistance.callbacks} through a nested
   {!callbacks} record; the bar-list wrapper builds those bundles via the
   corresponding [*.callbacks_from_bars] constructors. *)

type config = {
  stage : Stage.config;
  rs : Rs.config;
  volume : Volume.config;
  resistance : Resistance.config;
  breakout_event_lookback : int;
      (** Bars to scan for peak-volume event when detecting a breakout. Default:
          8 (~2 months of weekly bars). *)
  base_lookback_weeks : int;
      (** How far back (in bars) to search for the prior base high. Default: 52
          (~1 year). *)
  base_end_offset_weeks : int;
      (** How many recent bars to exclude from the base search (avoids counting
          the current advance as part of the base). Default: 8. *)
}

let default_config =
  {
    stage = Stage.default_config;
    rs = Rs.default_config;
    volume = Volume.default_config;
    resistance = Resistance.default_config;
    breakout_event_lookback = 8;
    base_lookback_weeks = 52;
    base_end_offset_weeks = 8;
  }

type t = {
  ticker : string;
  stage : Stage.result;
  rs : Rs.result option;
  volume : Volume.result option;
  resistance : Resistance.result option;
  breakout_price : float option;
  prior_stage : stage option;
  as_of_date : Date.t;
}

(* ------------------------------------------------------------------ *)
(* Callback bundle — used by panel-backed callers                       *)
(* ------------------------------------------------------------------ *)

type callbacks = {
  get_high : week_offset:int -> float option;
      (** Bar high at [week_offset] weeks back. Used by the breakout-price scan
          over the prior-base window. *)
  get_volume : week_offset:int -> float option;
      (** Bar volume at [week_offset] weeks back, encoded as a float (matches
          the panel encoding). Used by the peak-volume scan over the recent
          window. *)
  stage : Stage.callbacks;  (** Nested Stage callbacks. *)
  rs : Rs.callbacks;  (** Nested RS callbacks. *)
  volume : Volume.callbacks;  (** Nested Volume callbacks. *)
  resistance : Resistance.callbacks;  (** Nested Resistance callbacks. *)
}

(* ------------------------------------------------------------------ *)
(* Callback-shaped breakout-price scan                                  *)
(* ------------------------------------------------------------------ *)

(** Combine a running maximum with a fresh sample. *)
let _max_opt (best : float option) (h : float) : float option =
  match best with None -> Some h | Some b -> Some (Float.max b h)

(** Walk back from [week_offset = base_end_offset .. base_lookback - 1] reading
    [get_high] at each offset. Returns the maximum defined high. Stops the walk
    at the first [None] (treated as "no more bars"). Returns [None] when the
    range is empty or no bar produced a defined high. *)
let _scan_max_high_callback ~get_high ~base_end_offset ~base_lookback :
    float option =
  if base_end_offset >= base_lookback then None
  else
    let rec loop off best =
      if off >= base_lookback then best
      else
        match get_high ~week_offset:off with
        | None -> best
        | Some h -> loop (off + 1) (_max_opt best h)
    in
    loop base_end_offset None

(* ------------------------------------------------------------------ *)
(* Callback-shaped peak-volume scan                                     *)
(* ------------------------------------------------------------------ *)

(** Count how many of the [lookback] newest bars are defined. Walks newest →
    oldest and stops at the first [None]: bars older than the first hole are
    effectively absent, matching the bar-list's
    [List.sub bars ~pos:(max 0 (n - lookback))] which slices contiguous tails.
*)
let _count_defined ~get_volume ~lookback : int =
  let rec walk off n =
    if off >= lookback then n
    else
      match get_volume ~week_offset:off with
      | None -> n
      | Some _ -> walk (off + 1) (n + 1)
  in
  walk 0 0

(** Update [(best_off, best_vol)] with the sample read at [off]. Returns the
    updated pair plus a flag indicating whether the walk should continue
    ([true]) or stop ([false], when [get_volume] returned [None]). Strict [>]
    keeps the first-encountered maximum on ties. *)
let _peak_step ~get_volume ~off ~best_off ~best_vol : (int * float) * bool =
  match get_volume ~week_offset:off with
  | None -> ((best_off, best_vol), false)
  | Some v when Float.(v > best_vol) -> ((off, v), true)
  | Some _ -> ((best_off, best_vol), true)

(** Find the [week_offset] in [0 .. defined - 1] with the highest [get_volume].
    Scans oldest → newest (offset [defined-1] down to [0]) so that on ties the
    older bar wins — matching the bar-list [_find_peak_volume_idx], where
    [List.foldi] starts from the oldest [recent] bar with init [(0, 0)] and a
    strict [>] comparison keeps the first occurrence of the max. *)
let _peak_offset_in ~get_volume ~defined : int =
  let rec loop off best_off best_vol =
    if off < 0 then best_off
    else
      let (best_off', best_vol'), continue =
        _peak_step ~get_volume ~off ~best_off ~best_vol
      in
      if not continue then best_off' else loop (off - 1) best_off' best_vol'
  in
  loop (defined - 1) (defined - 1) Float.neg_infinity

(** Find the [week_offset] of the peak-volume bar within the last [lookback]
    bars. Returns [None] when fewer than two bars are defined (matches the
    bar-list [_find_peak_volume_idx]'s [if n < 2 then None] guard). The returned
    offset is the offset from the current week back to the peak. *)
let _find_peak_volume_offset_callback ~get_volume ~lookback : int option =
  let defined = _count_defined ~get_volume ~lookback in
  if defined < 2 then None else Some (_peak_offset_in ~get_volume ~defined)

(* ------------------------------------------------------------------ *)
(* Bar-list helpers used by the wrapper to build [callbacks]            *)
(* ------------------------------------------------------------------ *)

(** Build a [get_high] closure over a bar array. Mirrors the indexing rules used
    elsewhere: [week_offset:0] = newest bar; offsets past depth return [None].
*)
let _make_get_high_from_bars (bars : Daily_price.t array) :
    week_offset:int -> float option =
  let n = Array.length bars in
  fun ~week_offset ->
    let idx = n - 1 - week_offset in
    if idx < 0 || idx >= n then None else Some bars.(idx).Daily_price.high_price

(** Build a [get_volume] closure over a bar array. Encodes the integer volume as
    float to match the panel encoding ([Volume_panel : Bigarray.float64]). *)
let _make_get_volume_from_bars (bars : Daily_price.t array) :
    week_offset:int -> float option =
  let n = Array.length bars in
  fun ~week_offset ->
    let idx = n - 1 - week_offset in
    if idx < 0 || idx >= n then None
    else Some (Float.of_int bars.(idx).Daily_price.volume)

let callbacks_from_bars ~(config : config) ~(bars : Daily_price.t list)
    ~(benchmark_bars : Daily_price.t list) : callbacks =
  let bars_arr = Array.of_list bars in
  {
    get_high = _make_get_high_from_bars bars_arr;
    get_volume = _make_get_volume_from_bars bars_arr;
    stage = Stage.callbacks_from_bars ~config:config.stage ~bars;
    rs = Rs.callbacks_from_bars ~stock_bars:bars ~benchmark_bars;
    volume = Volume.callbacks_from_bars ~bars;
    resistance = Resistance.callbacks_from_bars ~bars;
  }

(* ------------------------------------------------------------------ *)
(* Volume / Resistance via callbacks                                    *)
(* ------------------------------------------------------------------ *)

let _volume_result ~(config : config) ~(volume_callbacks : Volume.callbacks)
    ~peak_offset_opt : Volume.result option =
  match peak_offset_opt with
  | None -> None
  | Some peak_offset ->
      Volume.analyze_breakout_with_callbacks ~config:config.volume
        ~callbacks:volume_callbacks ~event_offset:peak_offset

let _resistance_result ~(config : config)
    ~(resistance_callbacks : Resistance.callbacks) ~as_of_date ~breakout_price :
    Resistance.result option =
  Option.map breakout_price ~f:(fun bp ->
      Resistance.analyze_with_callbacks ~config:config.resistance
        ~callbacks:resistance_callbacks ~breakout_price:bp ~as_of_date)

(* ------------------------------------------------------------------ *)
(* Main analyzer — callback shape                                       *)
(* ------------------------------------------------------------------ *)

let analyze_with_callbacks ~(config : config) ~ticker ~(callbacks : callbacks)
    ~prior_stage ~as_of_date : t =
  let stage_result =
    Stage.classify_with_callbacks ~config:config.stage
      ~get_ma:callbacks.stage.get_ma ~get_close:callbacks.stage.get_close
      ~prior_stage
  in
  let rs_result =
    Rs.analyze_with_callbacks ~config:config.rs
      ~get_stock_close:callbacks.rs.get_stock_close
      ~get_benchmark_close:callbacks.rs.get_benchmark_close
      ~get_date:callbacks.rs.get_date
  in
  let breakout_price =
    _scan_max_high_callback ~get_high:callbacks.get_high
      ~base_end_offset:config.base_end_offset_weeks
      ~base_lookback:config.base_lookback_weeks
  in
  let peak_offset_opt =
    _find_peak_volume_offset_callback ~get_volume:callbacks.get_volume
      ~lookback:config.breakout_event_lookback
  in
  let volume_result =
    _volume_result ~config ~volume_callbacks:callbacks.volume ~peak_offset_opt
  in
  let resistance_result =
    _resistance_result ~config ~resistance_callbacks:callbacks.resistance
      ~as_of_date ~breakout_price
  in
  {
    ticker;
    stage = stage_result;
    rs = rs_result;
    volume = volume_result;
    resistance = resistance_result;
    breakout_price;
    prior_stage;
    as_of_date;
  }

(* ------------------------------------------------------------------ *)
(* Bar-list wrapper — preserves the existing API                        *)
(* ------------------------------------------------------------------ *)

let analyze ~(config : config) ~ticker ~bars ~benchmark_bars ~prior_stage
    ~as_of_date : t =
  let callbacks = callbacks_from_bars ~config ~bars ~benchmark_bars in
  analyze_with_callbacks ~config ~ticker ~callbacks ~prior_stage ~as_of_date

(* ------------------------------------------------------------------ *)
(* Candidate predicates                                                 *)
(* ------------------------------------------------------------------ *)

let is_breakout_candidate (a : t) : bool =
  (* Stage 2 transition from Stage 1, with rising MA *)
  let stage_ok =
    match (a.stage.stage, a.prior_stage) with
    | Stage2 _, Some (Stage1 _) -> true
    | Stage2 { weeks_advancing; late = false }, _ -> weeks_advancing <= 4
    | _ -> false
  in
  (* Volume confirmation: at least Adequate *)
  let volume_ok =
    match a.volume with
    | Some { confirmation = Strong _; _ }
    | Some { confirmation = Adequate _; _ } ->
        true
    | _ -> false
  in
  (* RS not negative_declining *)
  let rs_ok =
    match a.rs with
    | None -> true (* no data — don't disqualify *)
    | Some { trend = Negative_declining; _ } -> false
    | _ -> true
  in
  stage_ok && volume_ok && rs_ok

let is_breakdown_candidate (a : t) : bool =
  (* Stage 4 transition from Stage 3 *)
  match (a.stage.stage, a.prior_stage) with
  | Stage4 _, Some (Stage3 _) -> true
  | Stage4 { weeks_declining }, _ -> weeks_declining <= 4
  | _ -> false

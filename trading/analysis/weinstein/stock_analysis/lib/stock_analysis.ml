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
  support : Support.result option;
  breakout_price : float option;
  breakdown_price : float option;
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
  get_split_factor : week_offset:int -> float option;
      (** Per-bar [adjusted_close / close_price]; see [stock_analysis.mli] for
          the truncation semantics. [None] disables truncation. *)
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

(** Combine a running minimum with a fresh sample. Mirror of [_max_opt]. *)
let _min_opt (best : float option) (l : float) : float option =
  match best with None -> Some l | Some b -> Some (Float.min b l)

(** Per-bar split-jump threshold: the smallest [factor_at_off / factor_at_off-1]
    ratio (in either direction) that we treat as a split rather than a dividend
    / continuous-adjustment drift. A split causes a discrete multiplicative jump
    in [adjusted_close / close_price] between consecutive bars (e.g., a forward
    four-for-one split creates a 4x jump; a five-for- four reverse split creates
    a 1.25x jump); dividends create only gradual drift. The smallest real-world
    split is around 5:4 (a one-quarter jump); the largest dividend drift over a
    couple of weeks is well under one- twentieth. The threshold below sits
    safely between the two. *)
let _split_jump_threshold = 0.20

(** [true] when bars at [off] and [off-1] sit in the same price space — i.e.,
    the per-bar split factor didn't jump by more than [_split_jump_threshold].
    Used to truncate the breakout / breakdown scans at the most recent split
    boundary: a [false] here means a split occurred between [off] (older) and
    [off-1] (newer), so any further-back bars belong to the pre-split price
    space and would leak into the scan. When either factor is unavailable the
    comparison is a no-op (returns [true] — keep walking) so that fixtures
    without raw / adjusted-close metadata behave as before. *)
let _no_split_between ~get_split_factor ~off : bool =
  if off <= 0 then true
  else
    match
      ( get_split_factor ~week_offset:off,
        get_split_factor ~week_offset:(off - 1) )
    with
    | None, _ | _, None -> true
    | Some f_old, Some f_new
      when Float.( <= ) f_old 0.0 || Float.( <= ) f_new 0.0 ->
        true
    | Some f_old, Some f_new ->
        Float.( < ) (Float.abs ((f_old /. f_new) -. 1.0)) _split_jump_threshold

(** Walk back from [week_offset = base_end_offset .. base_lookback - 1] reading
    [get_high] at each offset. Returns the maximum defined high. Stops the walk
    at the first [None] (treated as "no more bars") OR at the first offset whose
    per-bar split factor jumps materially relative to its more-recent neighbour
    (a split occurred between [off] and [off-1]; everything older belongs to the
    pre-split price space). Returns [None] when the range is empty or no bar
    produced a defined high. *)
let _scan_max_high_callback ~get_high ~get_split_factor ~base_end_offset
    ~base_lookback : float option =
  if base_end_offset >= base_lookback then None
  else
    let rec loop off best =
      if off >= base_lookback then best
      else if not (_no_split_between ~get_split_factor ~off) then best
      else
        match get_high ~week_offset:off with
        | None -> best
        | Some h -> loop (off + 1) (_max_opt best h)
    in
    loop base_end_offset None

(** Mirror of {!_scan_max_high_callback} for the short-side cascade: walks
    [bar_offset = base_end_offset .. base_lookback - 1] reading [get_low] at
    each offset and returns the {b minimum} defined low. The base low is the
    short-side analogue of the breakout price.

    Note: [get_low] is consumed via the Resistance callback bundle, which uses
    [~bar_offset] rather than [~week_offset]. Both indexing conventions mean
    "offset from the newest bar"; only the labelled-arg name differs.

    Same split-boundary truncation as the max-high scan: stops at the first
    offset whose [get_split_factor] jumps relative to its more-recent neighbour.
*)
let _scan_min_low_callback ~get_low ~get_split_factor ~base_end_offset
    ~base_lookback : float option =
  if base_end_offset >= base_lookback then None
  else
    let rec loop off best =
      if off >= base_lookback then best
      else if not (_no_split_between ~get_split_factor ~off) then best
      else
        match get_low ~bar_offset:off with
        | None -> best
        | Some l -> loop (off + 1) (_min_opt best l)
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

(** Build a [get_split_factor] closure: per-bar [adjusted_close / close_price].
    Returns [None] for offsets outside the array AND for bars whose raw close is
    non-positive (avoiding a div-by-zero / sign flip). *)
let _make_get_split_factor_from_bars (bars : Daily_price.t array) :
    week_offset:int -> float option =
  let n = Array.length bars in
  fun ~week_offset ->
    let idx = n - 1 - week_offset in
    if idx < 0 || idx >= n then None
    else
      let bar = bars.(idx) in
      if Float.( <= ) bar.Daily_price.close_price 0.0 then None
      else Some (bar.Daily_price.adjusted_close /. bar.Daily_price.close_price)

let callbacks_from_bars ~(config : config) ~(bars : Daily_price.t list)
    ~(benchmark_bars : Daily_price.t list) : callbacks =
  let bars_arr = Array.of_list bars in
  {
    get_high = _make_get_high_from_bars bars_arr;
    get_volume = _make_get_volume_from_bars bars_arr;
    get_split_factor = _make_get_split_factor_from_bars bars_arr;
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

(** Compute the short-side mirror of [_resistance_result]: support density below
    [breakdown_price]. Reuses [resistance_callbacks] (same per-bar fields, only
    the comparison flips inside [Support.analyze_with_callbacks]). Reuses
    [config.resistance] so the same defaults govern both directions. *)
let _support_result ~(config : config)
    ~(resistance_callbacks : Resistance.callbacks) ~as_of_date ~breakdown_price
    : Support.result option =
  Option.map breakdown_price ~f:(fun bp ->
      Support.analyze_with_callbacks ~config:config.resistance
        ~callbacks:resistance_callbacks ~breakdown_price:bp ~as_of_date)

(* ------------------------------------------------------------------ *)
(* Main analyzer — callback shape                                       *)
(* ------------------------------------------------------------------ *)

(** Compute [(breakout_price, breakdown_price)] from the prior-base window
    callbacks. Both scans share the same window bounds and the same split-
    boundary truncation guard ([get_split_factor]). *)
let _breakout_and_breakdown_prices ~(config : config) ~(callbacks : callbacks) :
    float option * float option =
  let breakout =
    _scan_max_high_callback ~get_high:callbacks.get_high
      ~get_split_factor:callbacks.get_split_factor
      ~base_end_offset:config.base_end_offset_weeks
      ~base_lookback:config.base_lookback_weeks
  in
  let breakdown =
    _scan_min_low_callback ~get_low:callbacks.resistance.get_low
      ~get_split_factor:callbacks.get_split_factor
      ~base_end_offset:config.base_end_offset_weeks
      ~base_lookback:config.base_lookback_weeks
  in
  (breakout, breakdown)

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
  let breakout_price, breakdown_price =
    _breakout_and_breakdown_prices ~config ~callbacks
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
  let support_result =
    _support_result ~config ~resistance_callbacks:callbacks.resistance
      ~as_of_date ~breakdown_price
  in
  {
    ticker;
    stage = stage_result;
    rs = rs_result;
    volume = volume_result;
    resistance = resistance_result;
    support = support_result;
    breakout_price;
    breakdown_price;
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

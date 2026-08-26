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
  continuation : Continuation.config option;
      (** When [Some cfg], the continuation-buy detector runs; when [None]
          (default), it is skipped. See .mli for full semantics. *)
  overhead_supply : Resistance_supply.config option; [@sexp.default None]
      (** Continuous overhead-supply score (resistance-v2); [None] = off. See
          .mli. *)
  virgin_crossing_readmission : bool; [@sexp.default false]
      (** resistance-v2 lever (a); [false] = off (bit-identical). See .mli. *)
  entry_anchor_local_range_weeks : int; [@sexp.default 0]
      (** Ticket-level local-range entry anchor (default [0] = off). When [> 0],
          {!local_range_top} is the split-safe max high over the last
          [entry_anchor_local_range_weeks] bars; [0] leaves it [None]
          (bit-identical). See .mli. *)
  entry_freshness_basis : Entry_freshness.basis;
      [@sexp.default Entry_freshness.Ma_cross]
      (** F1 — which event starts the Stage-2 admission clock. [Ma_cross]
          (default) is today's MA-cross window, bit-identical. See .mli. *)
  require_breakout_volume : bool; [@sexp.default true]
      (** F5 — whether {!is_breakout_candidate} requires screen-time volume
          confirmation. [true] (default) is today's gate, bit-identical. See
          .mli. *)
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
    continuation = None;
    overhead_supply = None;
    virgin_crossing_readmission = false;
    entry_anchor_local_range_weeks = 0;
    entry_freshness_basis = Entry_freshness.Ma_cross;
    require_breakout_volume = true;
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
  local_range_top : float option;
      (** Ticket-level local-range entry anchor: the split-safe maximum high
          over the last [config.entry_anchor_local_range_weeks] bars, or [None]
          when that knob is [0] (the default) or no defined high exists in the
          window. Read {i only} by the screener to anchor
          {!Screener.suggested_entry}; never feeds admission, grading, or stage
          classification. See .mli. *)
  prior_stage : stage option;
  continuation : Continuation.result option;
  supply : Resistance_supply.result option;
      (** Continuous overhead-supply score from the precomputed resistance
          sketch (resistance-v2). [None] when [config.overhead_supply = None]
          (default — feature off) OR when the callback bundle's [get_sketch]
          returned [None] OR when no breakout price could be determined.
          [Some r] carries [r.score] in [0, 1] (0 = virgin, 1 = heavy recent
          supply) consumed by the screener's long-side scoring weight. *)
  virgin_readmission : bool;  (** resistance-v2 lever (a); see .mli. *)
  range_top_freshness : bool option;
      (** F1 — the armed admission clock's verdict. [None] under the default
          [Ma_cross] basis ("no opinion" — admission keeps its pre-F1 MA-cross
          window verbatim); [Some live] under [Range_top_breakout]. See .mli. *)
  require_breakout_volume : bool;
      (** F5 — [config.require_breakout_volume] carried onto the analysis so
          {!is_breakout_candidate} (which sees only [t]) can honour it. [true]
          (default) keeps the screen-time volume gate. See .mli. *)
  current_close : float option;
      (** Most recent (offset-0) weekly close; see .mli. *)
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
  get_sketch : unit -> Resistance_supply.sketch option;
      (** Warehouse resistance sketch for (symbol, as_of); [None] off the
          snapshot path. See .mli. Consumed only when [overhead_supply] armed.
      *)
  stage : Stage.callbacks;  (** Nested Stage callbacks. *)
  rs : Rs.callbacks;  (** Nested RS callbacks. *)
  volume : Volume.callbacks;  (** Nested Volume callbacks. *)
  resistance : Resistance.callbacks;  (** Nested Resistance callbacks. *)
}

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

(* Return [adjusted_close / close_price] for [bar], or [None] when [close_price]
   is non-positive (avoids div-by-zero / sign flips on bad bars). *)
let _split_factor_of_bar (bar : Daily_price.t) =
  if Float.( <= ) bar.Daily_price.close_price 0.0 then None
  else Some (bar.Daily_price.adjusted_close /. bar.Daily_price.close_price)

(** Build a [get_split_factor] closure: per-bar [adjusted_close / close_price].
    Returns [None] for offsets outside the array AND for bars whose raw close is
    non-positive (avoiding a div-by-zero / sign flip). *)
let _make_get_split_factor_from_bars (bars : Daily_price.t array) :
    week_offset:int -> float option =
  let n = Array.length bars in
  fun ~week_offset ->
    let idx = n - 1 - week_offset in
    if idx < 0 || idx >= n then None else _split_factor_of_bar bars.(idx)

let callbacks_from_bars ~(config : config) ~(bars : Daily_price.t list)
    ~(benchmark_bars : Daily_price.t list) : callbacks =
  let bars_arr = Array.of_list bars in
  {
    get_high = _make_get_high_from_bars bars_arr;
    get_volume = _make_get_volume_from_bars bars_arr;
    get_split_factor = _make_get_split_factor_from_bars bars_arr;
    (* Bar-list / live CSV path has no warehouse sketch (stays v1). *)
    get_sketch = (fun () -> None);
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

(** Build a {!Continuation.callbacks} bundle from this module's callbacks (Stage
    \+ Resistance sub-bundles + our own [get_high]). [get_low] adapts the
    Resistance callback's [~bar_offset] naming to Continuation's [~week_offset]
    — both indices mean "offset back from the newest bar" in weekly cadence. *)
let _continuation_callbacks_of (callbacks : callbacks) : Continuation.callbacks
    =
  {
    get_ma = callbacks.stage.get_ma;
    get_close = callbacks.stage.get_close;
    get_high = callbacks.get_high;
    get_low =
      (fun ~week_offset -> callbacks.resistance.get_low ~bar_offset:week_offset);
  }

(** Run the continuation detector when [config.continuation = Some cfg]; return
    [None] otherwise (feature off). *)
let _continuation_result ~(config : config) ~(callbacks : callbacks) :
    Continuation.result option =
  Option.map config.continuation ~f:(fun cont_cfg ->
      let cont_callbacks = _continuation_callbacks_of callbacks in
      Continuation.analyze_with_callbacks ~config:cont_cfg
        ~callbacks:cont_callbacks)

(* ------------------------------------------------------------------ *)
(* Main analyzer — callback shape                                       *)
(* ------------------------------------------------------------------ *)

(** Compute [(breakout_price, breakdown_price)] from the prior-base window
    callbacks. Both scans share the same window bounds and the same split-
    boundary truncation guard ([get_split_factor]). *)
let _breakout_and_breakdown_prices ~(config : config) ~(callbacks : callbacks) :
    float option * float option =
  let breakout =
    Stock_analysis_scans.scan_max_high ~get_high:callbacks.get_high
      ~get_split_factor:callbacks.get_split_factor
      ~base_end_offset:config.base_end_offset_weeks
      ~base_lookback:config.base_lookback_weeks
  in
  let breakdown =
    Stock_analysis_scans.scan_min_low ~get_low:callbacks.resistance.get_low
      ~get_split_factor:callbacks.get_split_factor
      ~base_end_offset:config.base_end_offset_weeks
      ~base_lookback:config.base_lookback_weeks
  in
  (breakout, breakdown)

(** Ticket-level local-range entry anchor: the split-safe maximum high over the
    most recent [config.entry_anchor_local_range_weeks] bars (offsets
    [0 .. weeks - 1], i.e. including the current bar — the "current trading
    range" the book anchors the buy-stop above). Returns [None] when the knob is
    [0] (feature off, bit-identical) so no unused work runs. Reuses the same
    {!Stock_analysis_scans.scan_max_high} walk as the breakout scan (identical
    split-boundary truncation), differing only in the window bounds. *)
let _local_range_top ~(config : config) ~(callbacks : callbacks) : float option
    =
  if config.entry_anchor_local_range_weeks <= 0 then None
  else
    Stock_analysis_scans.scan_max_high ~get_high:callbacks.get_high
      ~get_split_factor:callbacks.get_split_factor ~base_end_offset:0
      ~base_lookback:config.entry_anchor_local_range_weeks

(* @large-function: record-assembly coordinator — threads the 8 sub-analysis
   results into the single 16-field [t]; splitting scatters the one-shot
   assembly with no readability gain. *)
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
  let local_range_top = _local_range_top ~config ~callbacks in
  let current_close = callbacks.stage.get_close ~week_offset:0 in
  let range_top_freshness =
    Entry_freshness.range_top_freshness ~basis:config.entry_freshness_basis
      ~ma_direction:stage_result.ma_direction ~ma_value:stage_result.ma_value
      ~local_range_top ~current_close
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
  let continuation = _continuation_result ~config ~callbacks in
  let supply, virgin_readmission =
    Stock_analysis_supply.results ~overhead_supply:config.overhead_supply
      ~virgin_crossing_readmission:config.virgin_crossing_readmission
      ~get_sketch:callbacks.get_sketch ~breakout_price
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
    local_range_top;
    prior_stage;
    continuation;
    supply;
    virgin_readmission;
    range_top_freshness;
    require_breakout_volume = config.require_breakout_volume;
    current_close;
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

(** Initial-breakout arm (pre-existing): Stage1→Stage2 transition, or fresh
    Stage2 with [weeks_advancing ≤ early_stage2_max_weeks]. Mature Stage2
    symbols (the cascade's blind spot per
    dev/notes/capital-recycling-framing-2026-05-06.md) are rejected by this arm
    but admitted by the continuation arm when enabled. [early_stage2_max_weeks]
    is the early-Stage2 admission window (default 4 at the public boundary). *)
let _initial_breakout_arm ~early_stage2_max_weeks (a : t) : bool =
  match (a.stage.stage, a.prior_stage) with
  | Stage2 _, Some (Stage1 _) -> true
  | Stage2 { weeks_advancing; late = false }, _ ->
      weeks_advancing <= early_stage2_max_weeks
  | _ -> false

(** F1 range-top arm: the armed clock's admission test. Admits a non-late
    Stage-2 name whose breakout setup is live at the ticket anchor
    ({!Entry_freshness.range_top_freshness}); the MA-cross age is not consulted.
    The Stage-2 restriction is spine item 2 (buy only in Stage 2) and [late] is
    still excluded — F1 moves the clock, it does not widen the stage gate. *)
let _range_top_arm (a : t) : bool =
  match (a.stage.stage, a.range_top_freshness) with
  | Stage2 { late = false; _ }, Some setup_live -> setup_live
  | _ -> false

(** F1 replaces, never widens: under the default [Ma_cross] basis
    [range_top_freshness] is [None] and the pre-F1 initial-breakout arm runs
    verbatim (bit-identical); under [Range_top_breakout] the range-top arm is
    used {i instead of} the MA-cross window, not in disjunction with it. The
    continuation and virgin-readmission arms are untouched either way. *)
let _freshness_arm ~early_stage2_max_weeks (a : t) : bool =
  match a.range_top_freshness with
  | None -> _initial_breakout_arm ~early_stage2_max_weeks a
  | Some _ -> _range_top_arm a

(** Continuation-buy arm (Interpretation B of issue #889). Active only when
    [a.continuation = Some r] (the detector ran AND found a hit). Restricted to
    symbols currently in Stage 2 — the book's continuation pattern only fires
    inside an existing Stage 2 advance. *)
let _continuation_arm (a : t) : bool =
  match (a.continuation, a.stage.stage) with
  | Some { is_continuation = true; _ }, Stage2 _ -> true
  | _ -> false

(** Virgin-crossing re-admission arm (resistance-v2 lever (a), Weinstein's "new
    high ground" breakout): a Stage-2 survivor past the staleness window is
    re-admitted when [a.virgin_readmission] is set (armed AND virgin). See .mli.
*)
let _virgin_readmission_arm (a : t) : bool =
  match a.stage.stage with Stage2 _ -> a.virgin_readmission | _ -> false

type breakout_rejection = Stage_setup | Breakout_volume | Rs_declining
[@@deriving sexp, eq, show]

(* Three independent gates, reported first-failing in the order below — see the
   .mli, which owns the contract. F5 ([require_breakout_volume = false]) waives
   the volume gate only, relocating that spine item-3 check to the fill week
   where [Volume_eject_runner] enforces it. *)
let breakout_candidate_rejection ?(early_stage2_max_weeks = 4) (a : t) :
    breakout_rejection option =
  let stage_ok =
    _freshness_arm ~early_stage2_max_weeks a
    || _continuation_arm a || _virgin_readmission_arm a
  in
  let volume_ok =
    (not a.require_breakout_volume)
    ||
    match a.volume with
    | Some { confirmation = Strong _ | Adequate _; _ } -> true
    | Some _ | None -> false
  in
  (* [Positive_declining] joins this gate on the same authority as
     [Negative_declining] — book §4.4 Ch. 4, "don't ever buy that stock". It is
     unreachable unless [Rs.config.enable_positive_declining] is armed. *)
  let rs_ok =
    match a.rs with
    | Some { trend = Negative_declining | Positive_declining; _ } -> false
    | Some _ | None -> true
  in
  if not stage_ok then Some Stage_setup
  else if not volume_ok then Some Breakout_volume
  else if not rs_ok then Some Rs_declining
  else None

let is_breakout_candidate ?(early_stage2_max_weeks = 4) (a : t) : bool =
  Option.is_none (breakout_candidate_rejection ~early_stage2_max_weeks a)

let is_breakdown_candidate (a : t) : bool =
  (* Stage 4 transition from Stage 3 *)
  match (a.stage.stage, a.prior_stage) with
  | Stage4 _, Some (Stage3 _) -> true
  | Stage4 { weeks_declining }, _ -> weeks_declining <= 4
  | _ -> false

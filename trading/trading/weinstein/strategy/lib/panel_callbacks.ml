(* @large-module: panel-shaped callback constructors for the eight strategy
   callees (Stage / Rs / Volume / Resistance / Stock_analysis / Sector /
   Macro / Support_floor) plus PR-D's cache-aware Stage path. Splitting
   the per-callee constructors into sibling modules would force a cycle
   (Sector / Macro / Stock_analysis re-call the Stage constructor) so they
   live together, sharing the helpers above. *)

(** Panel-shaped callback bundles for the Weinstein strategy callees.

    See {!Panel_callbacks_intf} (panel_callbacks.mli) for the public contract.
    Implementation note: every constructor delegates the indicator math to the
    same kernels the bar-list [callbacks_from_bars] paths use
    ({!Sma.calculate_sma}, {!Ema.calculate_ema}, {!Relative_strength}'s SMA), so
    the resulting callback bundles produce bit-identical analyses for the same
    underlying floats. The win is allocational: no {!Daily_price.t} record is
    ever materialised. *)

open Core
module Bar_panels = Data_panel.Bar_panels
module Snapshot_bar_views = Snapshot_runtime.Snapshot_bar_views
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks

(* ------------------------------------------------------------------ *)
(* Helpers shared by all constructors                                   *)
(* ------------------------------------------------------------------ *)

(** Build a [week_offset]-indexed float lookup over a chronologically-ordered
    [float array]. [week_offset:0] returns the newest entry; offsets past the
    array's depth return [None]. Mirrors {!Stage._make_get_ma_from_array}'s
    indexing rule so panel-shaped and bar-list-shaped callbacks see the same
    offsets for the same underlying data. *)
let _get_from_float_array (arr : float array) : week_offset:int -> float option
    =
  let n = Array.length arr in
  fun ~week_offset ->
    let idx = n - 1 - week_offset in
    if idx < 0 || idx >= n then None else Some arr.(idx)

(** Build a [week_offset]-indexed [Date.t] lookup; same indexing as
    {!_get_from_float_array}. *)
let _get_date_from_array (arr : Date.t array) : week_offset:int -> Date.t option
    =
  let n = Array.length arr in
  fun ~week_offset ->
    let idx = n - 1 - week_offset in
    if idx < 0 || idx >= n then None else Some arr.(idx)

(** Compute the MA series over [closes : float array] using the same kernel
    {!Stage._compute_ma} feeds into {!Sma.calculate_sma} /
    [calculate_weighted_ma] / {!Ema.calculate_ema}. Returns just the MA values
    (the dates are realigned at the indexing boundary by the caller). *)
let _ma_values_of_closes ~(config : Stage.config) ~closes
    ~(dates : Date.t array) : float array =
  if Array.length closes = 0 then [||]
  else
    let series =
      Array.to_list closes
      |> List.mapi ~f:(fun i v ->
          Indicator_types.{ date = dates.(i); value = v })
    in
    let result =
      match config.ma_type with
      | Sma -> Sma.calculate_sma series config.ma_period
      | Wma -> Sma.calculate_weighted_ma series config.ma_period
      | Ema -> Ema.calculate_ema series config.ma_period
    in
    List.map result ~f:(fun iv -> iv.Indicator_types.value) |> Array.of_list

(* ------------------------------------------------------------------ *)
(* Stage                                                                *)
(* ------------------------------------------------------------------ *)

(** Build the inline [get_ma] from the view's closes (current allocational path;
    one allocation per call). Used as the cache-miss fallback and the
    bar-list-only path. *)
let _inline_get_ma ~(config : Stage.config) ~(weekly : Bar_panels.weekly_view) :
    week_offset:int -> float option =
  let ma_values =
    _ma_values_of_closes ~config ~closes:weekly.closes ~dates:weekly.dates
  in
  _get_from_float_array ma_values

(** Cap the cached [get_ma] by view depth: the bar-list path computes MA over
    the truncated weekly view's closes (yielding [view.n - period + 1] values),
    so any deeper offsets must read [None] for parity. *)
let _capped_get_ma ~(cached_values : float array) ~(end_idx : int)
    ~(view_ma_depth : int) : week_offset:int -> float option =
  let n = Array.length cached_values in
  fun ~week_offset ->
    let idx = end_idx - week_offset in
    let in_view = week_offset >= 0 && week_offset < view_ma_depth in
    let in_array = idx >= 0 && idx < n in
    if in_view && in_array then Some cached_values.(idx) else None

(** Try to build [get_ma] from the cache; return [None] on miss (empty view, no
    values for this key, or view's last date not in the cached dates array). *)
let _cached_get_ma ~(cache : Weekly_ma_cache.t) ~(symbol : string)
    ~(config : Stage.config) ~(weekly : Bar_panels.weekly_view) :
    (week_offset:int -> float option) option =
  if weekly.n = 0 then None
  else
    let values, dates =
      Weekly_ma_cache.ma_values_for cache ~symbol ~ma_type:config.ma_type
        ~period:config.ma_period
    in
    let target_date = weekly.dates.(weekly.n - 1) in
    let view_ma_depth = max 0 (weekly.n - config.ma_period + 1) in
    Option.map (Weekly_ma_cache.locate_date dates target_date)
      ~f:(fun end_idx ->
        _capped_get_ma ~cached_values:values ~end_idx ~view_ma_depth)

(** Try the cache; on miss fall back to inline. The cache-aware path requires
    both a registered cache AND a symbol to key on; either being [None]
    short-circuits to inline. *)
let _stage_get_ma ?ma_cache ?symbol ~(config : Stage.config)
    ~(weekly : Bar_panels.weekly_view) () : week_offset:int -> float option =
  match (ma_cache, symbol) with
  | Some cache, Some symbol -> (
      match _cached_get_ma ~cache ~symbol ~config ~weekly with
      | Some f -> f
      | None -> _inline_get_ma ~config ~weekly)
  | _ -> _inline_get_ma ~config ~weekly

let stage_callbacks_of_weekly_view ?ma_cache ?symbol ~(config : Stage.config)
    ~(weekly : Bar_panels.weekly_view) () : Stage.callbacks =
  let get_ma = _stage_get_ma ?ma_cache ?symbol ~config ~weekly () in
  { get_ma; get_close = _get_from_float_array weekly.closes }

(* ------------------------------------------------------------------ *)
(* Rs — date-aligned join, then index into aligned arrays               *)
(* ------------------------------------------------------------------ *)

(** Join [stock] and [benchmark] views on date and return parallel arrays of
    aligned (date, stock_close, benchmark_close). Only dates present in both
    views contribute (matches {!Rs._align_bars_for_wrapper}'s map+filter
    semantics). The two views are already chronologically ordered (oldest first)
    and same-cadence weekly buckets, so the alignment is a single pass. *)
let _aligned_arrays ~(stock : Bar_panels.weekly_view)
    ~(benchmark : Bar_panels.weekly_view) :
    Date.t array * float array * float array =
  let bench_map =
    Array.foldi benchmark.dates ~init:Date.Map.empty ~f:(fun i m d ->
        Map.set m ~key:d ~data:benchmark.closes.(i))
  in
  let n = stock.n in
  let dates = Array.create ~len:n stock.dates.(0) in
  let stock_closes = Array.create ~len:n 0.0 in
  let bench_closes = Array.create ~len:n 0.0 in
  let count = ref 0 in
  for i = 0 to n - 1 do
    let d = stock.dates.(i) in
    match Map.find bench_map d with
    | None -> ()
    | Some bc ->
        let k = !count in
        dates.(k) <- d;
        stock_closes.(k) <- stock.closes.(i);
        bench_closes.(k) <- bc;
        Int.incr count
  done;
  let take a = Array.sub a ~pos:0 ~len:!count in
  if n = 0 then ([||], [||], [||])
  else (take dates, take stock_closes, take bench_closes)

let rs_callbacks_of_weekly_views ~(stock : Bar_panels.weekly_view)
    ~(benchmark : Bar_panels.weekly_view) : Rs.callbacks =
  let dates, stock_closes, bench_closes = _aligned_arrays ~stock ~benchmark in
  {
    get_stock_close = _get_from_float_array stock_closes;
    get_benchmark_close = _get_from_float_array bench_closes;
    get_date = _get_date_from_array dates;
  }

(* ------------------------------------------------------------------ *)
(* Volume — week-offset indexing over the view's [volumes] array        *)
(* ------------------------------------------------------------------ *)

let volume_callbacks_of_weekly_view ~(weekly : Bar_panels.weekly_view) :
    Volume.callbacks =
  { get_volume = _get_from_float_array weekly.volumes }

(* ------------------------------------------------------------------ *)
(* Resistance — bar-offset indexing over highs / lows / dates           *)
(* ------------------------------------------------------------------ *)

(** Build a [bar_offset]-indexed lookup over a generic array; offset 0 is the
    newest entry. Mirrors {!_get_from_float_array} but parameterised over
    closure name (Resistance uses [bar_offset], Stage / Stock_analysis use
    [week_offset]). *)
let _get_by_bar_offset (arr : 'a array) : bar_offset:int -> 'a option =
  let n = Array.length arr in
  fun ~bar_offset ->
    let idx = n - 1 - bar_offset in
    if idx < 0 || idx >= n then None else Some arr.(idx)

let resistance_callbacks_of_weekly_view ~(weekly : Bar_panels.weekly_view) :
    Resistance.callbacks =
  {
    get_high = _get_by_bar_offset weekly.highs;
    get_low = _get_by_bar_offset weekly.lows;
    get_date = _get_by_bar_offset weekly.dates;
    n_bars = weekly.n;
  }

(* ------------------------------------------------------------------ *)
(* Stock_analysis — bundle of high/volume + nested Stage/Rs/Volume/Resistance *)
(* ------------------------------------------------------------------ *)

(** Per-bar split-adjustment factor lookup over a weekly view's [closes]
    (adjusted) and [raw_closes] (unadjusted). Returns [None] when [raw_closes]
    is empty (e.g., the empty weekly_view) or when the raw close at this offset
    is non-positive. The factor stays constant across spans without splits and
    changes at split boundaries — used by
    {!Stock_analysis._scan_max_high_callback} / [_scan_min_low_callback] to
    truncate the lookback window at the most recent split (G14). *)
let _split_factor_of_weekly_view (weekly : Bar_panels.weekly_view) :
    week_offset:int -> float option =
  let n = Array.length weekly.raw_closes in
  let m = Array.length weekly.closes in
  fun ~week_offset ->
    if n <> m then None
    else
      let idx = n - 1 - week_offset in
      if idx < 0 || idx >= n then None
      else
        let raw = weekly.raw_closes.(idx) in
        if Float.( <= ) raw 0.0 then None else Some (weekly.closes.(idx) /. raw)

let stock_analysis_callbacks_of_weekly_views ?ma_cache ?stock_symbol
    ~(config : Stock_analysis.config) ~(stock : Bar_panels.weekly_view)
    ~(benchmark : Bar_panels.weekly_view) () : Stock_analysis.callbacks =
  {
    get_high = _get_from_float_array stock.highs;
    get_volume = _get_from_float_array stock.volumes;
    get_split_factor = _split_factor_of_weekly_view stock;
    stage =
      stage_callbacks_of_weekly_view ?ma_cache ?symbol:stock_symbol
        ~config:config.stage ~weekly:stock ();
    rs = rs_callbacks_of_weekly_views ~stock ~benchmark;
    volume = volume_callbacks_of_weekly_view ~weekly:stock;
    resistance = resistance_callbacks_of_weekly_view ~weekly:stock;
  }

(* ------------------------------------------------------------------ *)
(* Sector — pure delegation to nested Stage + Rs callbacks              *)
(* ------------------------------------------------------------------ *)

let sector_callbacks_of_weekly_views ?ma_cache ?sector_symbol
    ~(config : Sector.config) ~(sector : Bar_panels.weekly_view)
    ~(benchmark : Bar_panels.weekly_view) () : Sector.callbacks =
  {
    stage =
      stage_callbacks_of_weekly_view ?ma_cache ?symbol:sector_symbol
        ~config:config.stage_config ~weekly:sector ();
    rs = rs_callbacks_of_weekly_views ~stock:sector ~benchmark;
  }

(* ------------------------------------------------------------------ *)
(* Macro — primary index Stage + close samples + cumulative A-D + ad MA *)
(* ------------------------------------------------------------------ *)

(** Cumulative A-D fold using the same int-then-float boundary as
    {!Macro._build_cumulative_ad_array}. Preserved verbatim per PR-F's invariant
    — running sum is [int], converted to float at the array boundary only. *)
let _build_cumulative_ad_array (ad_bars : Macro.ad_bar list) : float array =
  let _, rev_acc =
    List.fold ad_bars ~init:(0, []) ~f:(fun (running, acc) bar ->
        let running = running + bar.advancing - bar.declining in
        (running, running :: acc))
  in
  rev_acc |> List.rev |> Array.of_list |> Array.map ~f:Float.of_int

(** Momentum-MA scalar using the same int-then-float boundary as
    {!Macro._compute_momentum_ma_scalar}. *)
let _compute_momentum_ma_scalar ~momentum_period (ad_bars : Macro.ad_bar list) :
    float option =
  if List.is_empty ad_bars then None
  else
    let nets =
      List.map ad_bars ~f:(fun (b : Macro.ad_bar) -> b.advancing - b.declining)
    in
    let n = List.length nets in
    let period = min momentum_period n in
    let recent_nets =
      List.rev nets |> (fun l -> List.sub l ~pos:0 ~len:period) |> List.rev
    in
    let sum = List.sum (module Int) recent_nets ~f:Fn.id in
    Some (Float.of_int sum /. Float.of_int period)

let _get_ad_momentum_ma (ma : float option) : week_offset:int -> float option =
 fun ~week_offset -> if week_offset = 0 then ma else None

(* Globals are passed as (label, view); the cache is keyed by symbol, not
   label. The strategy's per-symbol global passes are small (~3 globals)
   so the lost cache hit is negligible vs the universe-wide screener loop;
   pass-through is intentionally bar-list-only (cache-miss path). *)
let _named_global_stage ?ma_cache (config : Macro.config)
    ((name, view) : string * Bar_panels.weekly_view) : string * Stage.callbacks
    =
  ( name,
    stage_callbacks_of_weekly_view ?ma_cache ~config:config.stage_config
      ~weekly:view () )

let macro_callbacks_of_weekly_views ?ma_cache ?index_symbol
    ~(config : Macro.config) ~(index : Bar_panels.weekly_view)
    ~(globals : (string * Bar_panels.weekly_view) list)
    ~(ad_bars : Macro.ad_bar list) () : Macro.callbacks =
  let cum_ad_arr = _build_cumulative_ad_array ad_bars in
  let ma_scalar =
    _compute_momentum_ma_scalar
      ~momentum_period:config.indicator_thresholds.momentum_period ad_bars
  in
  {
    index_stage =
      stage_callbacks_of_weekly_view ?ma_cache ?symbol:index_symbol
        ~config:config.stage_config ~weekly:index ();
    get_index_close = _get_from_float_array index.closes;
    get_cumulative_ad = _get_from_float_array cum_ad_arr;
    get_ad_momentum_ma = _get_ad_momentum_ma ma_scalar;
    global_index_stages =
      List.map globals ~f:(_named_global_stage ?ma_cache config);
  }

(* ------------------------------------------------------------------ *)
(* Support floor — daily view with day_offset:0 = NEWEST                *)
(* ------------------------------------------------------------------ *)

(** {!Support_floor.callbacks} use the convention day_offset:0 = newest bar in
    the eligible window. Our {!Bar_panels.daily_view} is laid out the other way
    (index 0 = oldest, n_days-1 = newest). The closure does the index flip. *)
let support_floor_callbacks_of_daily_view (view : Bar_panels.daily_view) :
    Weinstein_stops.callbacks =
  let n = view.n_days in
  let lookup f ~day_offset =
    if day_offset < 0 || day_offset >= n then None
    else
      let idx = n - 1 - day_offset in
      Some (f idx)
  in
  {
    get_high = lookup (fun i -> view.highs.(i));
    get_low = lookup (fun i -> view.lows.(i));
    get_close = lookup (fun i -> view.closes.(i));
    get_date =
      (fun ~day_offset ->
        if day_offset < 0 || day_offset >= n then None
        else Some view.dates.(n - 1 - day_offset));
    n_days = n;
  }

(* ------------------------------------------------------------------ *)
(* Snapshot-views constructors (Phase F.3.c)                            *)
(* ------------------------------------------------------------------ *)
(* Parallel constructors that take a {!Snapshot_callbacks.t} and fetch
   the underlying bar view via {!Snapshot_bar_views.weekly_view_for} /
   [daily_view_for] before delegating to the corresponding
   [*_of_*_view] constructor above. The fetched [Snapshot_bar_views]
   view types are type-equal to {!Bar_panels.weekly_view} /
   [daily_view] (declared via [type =] in [snapshot_bar_views.mli]),
   so the delegation requires no per-call adapter. Output is
   bit-identical to the panel-backed path on the same underlying bar
   history (parity test:
   {!Test_panel_callbacks.Test_snapshot_parity}).

   Phase F.3 plan: callers migrate from
   [Bar_reader.weekly_view_for ... |> Panel_callbacks.X_of_weekly_view]
   to [Panel_callbacks.X_of_snapshot_views ~cb ~symbol ~n ~as_of],
   which folds the view fetch into the callback construction. After
   every caller migrates, the [*_of_*_view] constructors above can be
   removed in F.3 deletion. *)

let stage_callbacks_of_snapshot_views ?ma_cache ~(config : Stage.config)
    ~(cb : Snapshot_callbacks.t) ~symbol ~n ~as_of () : Stage.callbacks =
  let weekly = Snapshot_bar_views.weekly_view_for cb ~symbol ~n ~as_of in
  stage_callbacks_of_weekly_view ?ma_cache ~symbol ~config ~weekly ()

let rs_callbacks_of_snapshot_views ~(cb : Snapshot_callbacks.t) ~stock_symbol
    ~benchmark_symbol ~n ~as_of : Rs.callbacks =
  let stock =
    Snapshot_bar_views.weekly_view_for cb ~symbol:stock_symbol ~n ~as_of
  in
  let benchmark =
    Snapshot_bar_views.weekly_view_for cb ~symbol:benchmark_symbol ~n ~as_of
  in
  rs_callbacks_of_weekly_views ~stock ~benchmark

let volume_callbacks_of_snapshot_views ~(cb : Snapshot_callbacks.t) ~symbol ~n
    ~as_of : Volume.callbacks =
  let weekly = Snapshot_bar_views.weekly_view_for cb ~symbol ~n ~as_of in
  volume_callbacks_of_weekly_view ~weekly

let resistance_callbacks_of_snapshot_views ~(cb : Snapshot_callbacks.t) ~symbol
    ~n ~as_of : Resistance.callbacks =
  let weekly = Snapshot_bar_views.weekly_view_for cb ~symbol ~n ~as_of in
  resistance_callbacks_of_weekly_view ~weekly

let stock_analysis_callbacks_of_snapshot_views ?ma_cache
    ~(config : Stock_analysis.config) ~(cb : Snapshot_callbacks.t) ~stock_symbol
    ~benchmark_symbol ~n ~as_of () : Stock_analysis.callbacks =
  let stock =
    Snapshot_bar_views.weekly_view_for cb ~symbol:stock_symbol ~n ~as_of
  in
  let benchmark =
    Snapshot_bar_views.weekly_view_for cb ~symbol:benchmark_symbol ~n ~as_of
  in
  stock_analysis_callbacks_of_weekly_views ?ma_cache ~stock_symbol ~config
    ~stock ~benchmark ()

let sector_callbacks_of_snapshot_views ?ma_cache ~(config : Sector.config)
    ~(cb : Snapshot_callbacks.t) ~sector_symbol ~benchmark_symbol ~n ~as_of () :
    Sector.callbacks =
  let sector =
    Snapshot_bar_views.weekly_view_for cb ~symbol:sector_symbol ~n ~as_of
  in
  let benchmark =
    Snapshot_bar_views.weekly_view_for cb ~symbol:benchmark_symbol ~n ~as_of
  in
  sector_callbacks_of_weekly_views ?ma_cache ~sector_symbol ~config ~sector
    ~benchmark ()

let macro_callbacks_of_snapshot_views ?ma_cache ~(config : Macro.config)
    ~(cb : Snapshot_callbacks.t) ~index_symbol
    ~(globals : (string * string) list) ~(ad_bars : Macro.ad_bar list) ~n ~as_of
    () : Macro.callbacks =
  let index =
    Snapshot_bar_views.weekly_view_for cb ~symbol:index_symbol ~n ~as_of
  in
  let global_views =
    List.filter_map globals ~f:(fun (label, symbol) ->
        let view = Snapshot_bar_views.weekly_view_for cb ~symbol ~n ~as_of in
        if view.n = 0 then None else Some (label, view))
  in
  macro_callbacks_of_weekly_views ?ma_cache ~index_symbol ~config ~index
    ~globals:global_views ~ad_bars ()

let support_floor_callbacks_of_snapshot_views ~(cb : Snapshot_callbacks.t)
    ~symbol ~as_of ~lookback ~calendar : Weinstein_stops.callbacks =
  let view =
    Snapshot_bar_views.daily_view_for cb ~symbol ~as_of ~lookback ~calendar
  in
  support_floor_callbacks_of_daily_view view

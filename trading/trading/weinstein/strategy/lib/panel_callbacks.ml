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

let stage_callbacks_of_weekly_view ~(config : Stage.config)
    ~(weekly : Bar_panels.weekly_view) : Stage.callbacks =
  let ma_values =
    _ma_values_of_closes ~config ~closes:weekly.closes ~dates:weekly.dates
  in
  {
    get_ma = _get_from_float_array ma_values;
    get_close = _get_from_float_array weekly.closes;
  }

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
(* Stock_analysis — bundle of high/volume + nested Stage/Rs             *)
(* ------------------------------------------------------------------ *)

let stock_analysis_callbacks_of_weekly_views ~(config : Stock_analysis.config)
    ~(stock : Bar_panels.weekly_view) ~(benchmark : Bar_panels.weekly_view) :
    Stock_analysis.callbacks =
  {
    get_high = _get_from_float_array stock.highs;
    get_volume = _get_from_float_array stock.volumes;
    stage = stage_callbacks_of_weekly_view ~config:config.stage ~weekly:stock;
    rs = rs_callbacks_of_weekly_views ~stock ~benchmark;
  }

(* ------------------------------------------------------------------ *)
(* Sector — pure delegation to nested Stage + Rs callbacks              *)
(* ------------------------------------------------------------------ *)

let sector_callbacks_of_weekly_views ~(config : Sector.config)
    ~(sector : Bar_panels.weekly_view) ~(benchmark : Bar_panels.weekly_view) :
    Sector.callbacks =
  {
    stage =
      stage_callbacks_of_weekly_view ~config:config.stage_config ~weekly:sector;
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

let _named_global_stage (config : Macro.config)
    ((name, view) : string * Bar_panels.weekly_view) : string * Stage.callbacks
    =
  (name, stage_callbacks_of_weekly_view ~config:config.stage_config ~weekly:view)

let macro_callbacks_of_weekly_views ~(config : Macro.config)
    ~(index : Bar_panels.weekly_view)
    ~(globals : (string * Bar_panels.weekly_view) list)
    ~(ad_bars : Macro.ad_bar list) : Macro.callbacks =
  let cum_ad_arr = _build_cumulative_ad_array ad_bars in
  let ma_scalar =
    _compute_momentum_ma_scalar
      ~momentum_period:config.indicator_thresholds.momentum_period ad_bars
  in
  {
    index_stage =
      stage_callbacks_of_weekly_view ~config:config.stage_config ~weekly:index;
    get_index_close = _get_from_float_array index.closes;
    get_cumulative_ad = _get_from_float_array cum_ad_arr;
    get_ad_momentum_ma = _get_ad_momentum_ma ma_scalar;
    global_index_stages = List.map globals ~f:(_named_global_stage config);
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

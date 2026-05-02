open Core
module Snapshot = Data_panel_snapshot.Snapshot
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema

(* Window sizes Phase B uses for the indicator computations. Locked to the
   schema-field naming so any drift between schema and pipeline is loud. *)
let _ema_period = 50
let _sma_period = 50
let _atr_period = 14
let _rsi_period = 14
let _stage_weekly_lookback = 60
let _rs_weekly_lookback = 100

let _stage_to_float (stage : Weinstein_types.stage) =
  match stage with
  | Stage1 _ -> 1.0
  | Stage2 _ -> 2.0
  | Stage3 _ -> 3.0
  | Stage4 _ -> 4.0

(* Walk an array left-to-right summing the last [period] entries up to and
   including index [i]. Mirrors the EMA warmup pattern used by [Sma_kernel] —
   one [acc := !acc +. v] step per window slot — so a scalar reference written
   the same way is bit-identical. *)
let _sma_at ~closes ~period ~i =
  if i + 1 < period then Float.nan
  else
    let acc = ref 0.0 in
    for k = 0 to period - 1 do
      let v = closes.(i - k) in
      acc := !acc +. v
    done;
    !acc /. Float.of_int period

(* Standard EMA recurrence built up in one pass to index [i] inclusive. The
   first [period - 1] cells are NaN; cell [period - 1] is the simple mean of
   the first [period] closes (warmup seed); each subsequent cell is the
   recurrence [alpha * close + (1 - alpha) * prev]. The whole prefix is rebuilt
   per call — Phase B is offline and per-day; Phase C will memoize. *)
let _ema_at ~closes ~period ~i =
  if i + 1 < period then Float.nan
  else
    let alpha = 2.0 /. (Float.of_int period +. 1.0) in
    let one_minus_a = 1.0 -. alpha in
    let prev = ref Float.nan in
    let warmup_end = period - 1 in
    let warmup_sum = ref 0.0 in
    for k = 0 to warmup_end do
      warmup_sum := !warmup_sum +. closes.(k)
    done;
    prev := !warmup_sum /. Float.of_int period;
    for t = period to i do
      let new_v = closes.(t) in
      let p = !prev in
      prev := (alpha *. new_v) +. (one_minus_a *. p)
    done;
    !prev

(* Wilder True Range for column [t] in panel-shape arrays. [t = 0] is undefined
   (no prior close). NaNs in any input propagate. *)
let _true_range ~highs ~lows ~closes ~t =
  if t = 0 then Float.nan
  else
    let h = highs.(t) in
    let l = lows.(t) in
    let prev_c = closes.(t - 1) in
    let r1 = h -. l in
    let r2 = Float.abs (h -. prev_c) in
    let r3 = Float.abs (l -. prev_c) in
    Float.max r1 (Float.max r2 r3)

(* Wilder ATR at column [i]. NaN until [i = period]; seeded as the simple mean
   of TR over the first window, then the Wilder recurrence. Mirrors the
   reference shape in [Atr_kernel]. *)
let _atr_at ~highs ~lows ~closes ~period ~i =
  if i < period then Float.nan
  else
    let prev = ref Float.nan in
    let seed_sum = ref 0.0 in
    for k = 1 to period do
      seed_sum := !seed_sum +. _true_range ~highs ~lows ~closes ~t:k
    done;
    prev := !seed_sum /. Float.of_int period;
    let p_minus = Float.of_int (period - 1) in
    let p_f = Float.of_int period in
    for t = period + 1 to i do
      let tr = _true_range ~highs ~lows ~closes ~t in
      let prev_atr = !prev in
      prev := ((prev_atr *. p_minus) +. tr) /. p_f
    done;
    !prev

(* Wilder RSI at column [i]. Same warmup-then-recurrence shape as ATR. *)
let _rsi_at ~closes ~period ~i =
  if i < period then Float.nan
  else
    let avg_gain = ref 0.0 in
    let avg_loss = ref 0.0 in
    for k = 1 to period do
      let diff = closes.(k) -. closes.(k - 1) in
      let g = Float.max diff 0.0 in
      let l = Float.max (Float.neg diff) 0.0 in
      avg_gain := !avg_gain +. g;
      avg_loss := !avg_loss +. l
    done;
    avg_gain := !avg_gain /. Float.of_int period;
    avg_loss := !avg_loss /. Float.of_int period;
    let p_minus = Float.of_int (period - 1) in
    let p_f = Float.of_int period in
    for t = period + 1 to i do
      let diff = closes.(t) -. closes.(t - 1) in
      let g = Float.max diff 0.0 in
      let l = Float.max (Float.neg diff) 0.0 in
      avg_gain := ((!avg_gain *. p_minus) +. g) /. p_f;
      avg_loss := ((!avg_loss *. p_minus) +. l) /. p_f
    done;
    let g = !avg_gain in
    let l = !avg_loss in
    let rs = g /. l in
    if not (Float.is_finite rs) then 100.0 else 100.0 -. (100.0 /. (1.0 +. rs))

(* Aggregate the prefix [bars[0..i]] into weekly bars. Re-aggregates per call
   for simplicity — Phase B accepts the offline cost in exchange for parity
   with the runtime path that uses the same conversion. Phase C will memoize. *)
let _weekly_prefix ~bars ~i =
  let prefix = List.take bars (i + 1) in
  Time_period.Conversion.daily_to_weekly ~include_partial_week:true prefix

let _stage_value_for_prefix ~bars ~i =
  let weekly = _weekly_prefix ~bars ~i in
  let recent =
    let n = List.length weekly in
    if n <= _stage_weekly_lookback then weekly
    else List.drop weekly (n - _stage_weekly_lookback)
  in
  match recent with
  | [] -> Float.nan
  | _ ->
      let result =
        Stage.classify ~config:Stage.default_config ~bars:recent
          ~prior_stage:None
      in
      _stage_to_float result.stage

let _rs_value_for_prefix ~bars ~i ~benchmark_bars =
  let stock_weekly = _weekly_prefix ~bars ~i in
  let stock_recent =
    let n = List.length stock_weekly in
    if n <= _rs_weekly_lookback then stock_weekly
    else List.drop stock_weekly (n - _rs_weekly_lookback)
  in
  let last_date =
    match List.last stock_recent with
    | None -> None
    | Some (b : Types.Daily_price.t) -> Some b.date
  in
  match last_date with
  | None -> Float.nan
  | Some cutoff ->
      let bench_weekly =
        Time_period.Conversion.daily_to_weekly ~include_partial_week:true
          benchmark_bars
        |> List.filter ~f:(fun (b : Types.Daily_price.t) ->
            Date.( <= ) b.date cutoff)
      in
      let bench_recent =
        let n = List.length bench_weekly in
        if n <= _rs_weekly_lookback then bench_weekly
        else List.drop bench_weekly (n - _rs_weekly_lookback)
      in
      let result =
        Rs.analyze ~config:Rs.default_config ~stock_bars:stock_recent
          ~benchmark_bars:bench_recent
      in
      Option.value_map result ~default:Float.nan ~f:(fun (r : Rs.result) ->
          r.current_normalized)

(* Macro confidence from the benchmark's own bars only. A-D and global-index
   data are not threaded in Phase B — see plan §C1. *)
let _macro_value_for_prefix ~benchmark_bars ~cutoff =
  let bench_weekly =
    Time_period.Conversion.daily_to_weekly ~include_partial_week:true
      benchmark_bars
    |> List.filter ~f:(fun (b : Types.Daily_price.t) ->
        Date.( <= ) b.date cutoff)
  in
  let bench_recent =
    let n = List.length bench_weekly in
    if n <= _stage_weekly_lookback then bench_weekly
    else List.drop bench_weekly (n - _stage_weekly_lookback)
  in
  match bench_recent with
  | [] -> Float.nan
  | _ ->
      let result =
        Macro.analyze ~config:Macro.default_config ~index_bars:bench_recent
          ~ad_bars:[] ~global_index_bars:[] ~prior_stage:None ~prior:None
      in
      result.confidence

let _value_for_field ~field ~closes ~highs ~lows ~i ~bars ~bars_arr ~date
    ~benchmark_bars =
  match (field : Snapshot_schema.field) with
  | EMA_50 -> _ema_at ~closes ~period:_ema_period ~i
  | SMA_50 -> _sma_at ~closes ~period:_sma_period ~i
  | ATR_14 -> _atr_at ~highs ~lows ~closes ~period:_atr_period ~i
  | RSI_14 -> _rsi_at ~closes ~period:_rsi_period ~i
  | Stage -> _stage_value_for_prefix ~bars ~i
  | RS_line -> (
      match benchmark_bars with
      | None -> Float.nan
      | Some bench -> _rs_value_for_prefix ~bars ~i ~benchmark_bars:bench)
  | Macro_composite -> (
      match benchmark_bars with
      | None -> Float.nan
      | Some bench -> _macro_value_for_prefix ~benchmark_bars:bench ~cutoff:date
      )
  | Open -> bars_arr.(i).Types.Daily_price.open_price
  | High -> bars_arr.(i).Types.Daily_price.high_price
  | Low -> bars_arr.(i).Types.Daily_price.low_price
  | Close -> bars_arr.(i).Types.Daily_price.close_price
  | Volume -> Float.of_int bars_arr.(i).Types.Daily_price.volume
  | Adjusted_close -> bars_arr.(i).Types.Daily_price.adjusted_close

let _row_for_day ~symbol ~schema ~bars ~bars_arr ~closes ~highs ~lows ~i
    ~benchmark_bars =
  let date = bars_arr.(i).Types.Daily_price.date in
  let values =
    Array.of_list_map schema.Snapshot_schema.fields ~f:(fun field ->
        _value_for_field ~field ~closes ~highs ~lows ~i ~bars ~bars_arr ~date
          ~benchmark_bars)
  in
  Snapshot.create ~schema ~symbol ~date ~values

let build_for_symbol ~symbol ~bars ~schema ?benchmark_bars () =
  if String.is_empty symbol then
    Status.error_invalid_argument
      "Snapshot_pipeline.build_for_symbol: empty symbol"
  else
    let bars_arr = Array.of_list bars in
    let n = Array.length bars_arr in
    if n = 0 then Ok []
    else
      let closes =
        Array.map bars_arr ~f:(fun (b : Types.Daily_price.t) ->
            b.adjusted_close)
      in
      let highs =
        Array.map bars_arr ~f:(fun (b : Types.Daily_price.t) -> b.high_price)
      in
      let lows =
        Array.map bars_arr ~f:(fun (b : Types.Daily_price.t) -> b.low_price)
      in
      let rows =
        List.init n ~f:(fun i ->
            _row_for_day ~symbol ~schema ~bars ~bars_arr ~closes ~highs ~lows ~i
              ~benchmark_bars)
      in
      Result.all rows

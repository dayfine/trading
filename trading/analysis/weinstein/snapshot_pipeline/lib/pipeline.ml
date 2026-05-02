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

(* Per-day scalar indicators are computed by [Indicator_arrays] in a single
   forward pass; per-day weekly prefixes are computed by [Weekly_prefix] in a
   single forward pass. Both replace the prior recompute-from-zero shape that
   gave the writer O(N^2) per-symbol cost. *)

(* ------------------------------------------------------------------ *)
(* Stage / RS / Macro per-day values. Each takes the precomputed      *)
(* weekly prefix and runs the analyser on a tail slice. The analysers *)
(* themselves are O(lookback) so the total work stays O(N).           *)
(* ------------------------------------------------------------------ *)

let _stage_value ~weekly_prefix ~day_idx =
  let recent =
    Weekly_prefix.window_for_day weekly_prefix ~day_idx
      ~lookback:_stage_weekly_lookback
  in
  match recent with
  | [] -> Float.nan
  | _ ->
      let result =
        Stage.classify ~config:Stage.default_config ~bars:recent
          ~prior_stage:None
      in
      _stage_to_float result.stage

(* Slice [arr[0..upto]] (inclusive) into a chronological-oldest-first list,
   keeping only the last [lookback] entries. [upto < 0] yields the empty list.
   Used to feed the analysers their lookback window without re-walking the
   full benchmark prefix per call. *)
let _bench_window arr ~upto ~lookback =
  if upto < 0 then []
  else
    let start = Int.max 0 (upto - lookback + 1) in
    let acc = ref [] in
    for k = upto downto start do
      acc := arr.(k) :: !acc
    done;
    !acc

(* Largest index [k] in [arr] such that [arr.(k).date <= cutoff], or [-1] if
   all dates exceed [cutoff]. [arr] is sorted chronologically (the
   [daily_to_weekly] output is). Linear scan from a monotone start pointer
   so the writer's running cost across all daily calls is O(M) total. *)
let _advance_bench_idx arr ~from_idx ~cutoff =
  let n = Array.length arr in
  let i = ref from_idx in
  while !i + 1 < n && Date.( <= ) arr.(!i + 1).Types.Daily_price.date cutoff do
    incr i
  done;
  !i

let _rs_value ~weekly_prefix ~day_idx ~bench_weekly_arr ~bench_idx =
  let stock_recent =
    Weekly_prefix.window_for_day weekly_prefix ~day_idx
      ~lookback:_rs_weekly_lookback
  in
  match stock_recent with
  | [] -> Float.nan
  | _ ->
      let bench_recent =
        _bench_window bench_weekly_arr ~upto:bench_idx
          ~lookback:_rs_weekly_lookback
      in
      let result =
        Rs.analyze ~config:Rs.default_config ~stock_bars:stock_recent
          ~benchmark_bars:bench_recent
      in
      Option.value_map result ~default:Float.nan ~f:(fun (r : Rs.result) ->
          r.current_normalized)

(* Macro confidence from the benchmark's own bars only. A-D and global-index
   data are not threaded in Phase B — see plan §C1. *)
let _macro_value ~bench_weekly_arr ~bench_idx =
  let bench_recent =
    _bench_window bench_weekly_arr ~upto:bench_idx
      ~lookback:_stage_weekly_lookback
  in
  match bench_recent with
  | [] -> Float.nan
  | _ ->
      let result =
        Macro.analyze ~config:Macro.default_config ~index_bars:bench_recent
          ~ad_bars:[] ~global_index_bars:[] ~prior_stage:None ~prior:None
      in
      result.confidence

(* ------------------------------------------------------------------ *)
(* Per-row materialisation. Indicator arrays are precomputed once     *)
(* outside the [List.init] loop, so [_value_for_field] is now O(1)    *)
(* per cell.                                                          *)
(* ------------------------------------------------------------------ *)

(* Bundle of precomputed per-day arrays threaded through the row builder.
   Field names mirror [Snapshot_schema.field] so the lookup in
   [_value_for_field] stays one line per field. *)
type _precomputed = {
  ema : float array;
  sma : float array;
  atr : float array;
  rsi : float array;
  stage : float array;
  rs : float array;
  macro : float array;
}

let _value_for_field ~field ~precomputed ~bars_arr ~i =
  match (field : Snapshot_schema.field) with
  | EMA_50 -> precomputed.ema.(i)
  | SMA_50 -> precomputed.sma.(i)
  | ATR_14 -> precomputed.atr.(i)
  | RSI_14 -> precomputed.rsi.(i)
  | Stage -> precomputed.stage.(i)
  | RS_line -> precomputed.rs.(i)
  | Macro_composite -> precomputed.macro.(i)
  | Open -> bars_arr.(i).Types.Daily_price.open_price
  | High -> bars_arr.(i).Types.Daily_price.high_price
  | Low -> bars_arr.(i).Types.Daily_price.low_price
  | Close -> bars_arr.(i).Types.Daily_price.close_price
  | Volume -> Float.of_int bars_arr.(i).Types.Daily_price.volume
  | Adjusted_close -> bars_arr.(i).Types.Daily_price.adjusted_close

let _row_for_day ~symbol ~schema ~precomputed ~bars_arr ~i =
  let date = bars_arr.(i).Types.Daily_price.date in
  let values =
    Array.of_list_map schema.Snapshot_schema.fields ~f:(fun field ->
        _value_for_field ~field ~precomputed ~bars_arr ~i)
  in
  Snapshot.create ~schema ~symbol ~date ~values

(* Resolve the usable benchmark index for daily index [i]. Returns [-1] when
   the benchmark hasn't started yet (its earliest date is after [cutoff]). *)
let _usable_bench_idx arr ~bench_idx ~cutoff =
  if Array.length arr = 0 then -1
  else if Date.( > ) arr.(0).Types.Daily_price.date cutoff then -1
  else bench_idx

(* Compute the per-day weekly-derived value arrays. When [benchmark_bars] is
   [None], [rs] and [macro] stay all-NaN — matching the prior pipeline.
   When supplied, the benchmark's weekly aggregate is computed once and a
   monotone index pointer ([bench_idx]) advances with the daily cutoff so
   the analysers see a [bench_recent] window of bounded length per call. *)
let _compute_weekly_arrays ~bars_arr ~weekly_prefix ~benchmark_bars =
  let n = Array.length bars_arr in
  let stage = Array.create ~len:n Float.nan in
  let rs = Array.create ~len:n Float.nan in
  let macro = Array.create ~len:n Float.nan in
  let bench_weekly_arr =
    Option.map benchmark_bars ~f:(fun bench ->
        Time_period.Conversion.daily_to_weekly ~include_partial_week:true bench
        |> Array.of_list)
  in
  let bench_idx = ref (-1) in
  for i = 0 to n - 1 do
    stage.(i) <- _stage_value ~weekly_prefix ~day_idx:i;
    Option.iter bench_weekly_arr ~f:(fun arr ->
        let cutoff = bars_arr.(i).Types.Daily_price.date in
        bench_idx :=
          _advance_bench_idx arr ~from_idx:(Int.max 0 !bench_idx) ~cutoff;
        let usable_idx = _usable_bench_idx arr ~bench_idx:!bench_idx ~cutoff in
        rs.(i) <-
          _rs_value ~weekly_prefix ~day_idx:i ~bench_weekly_arr:arr
            ~bench_idx:usable_idx;
        macro.(i) <- _macro_value ~bench_weekly_arr:arr ~bench_idx:usable_idx)
  done;
  (stage, rs, macro)

let _compute_precomputed ~bars_arr ~benchmark_bars =
  let closes =
    Array.map bars_arr ~f:(fun (b : Types.Daily_price.t) -> b.adjusted_close)
  in
  let highs =
    Array.map bars_arr ~f:(fun (b : Types.Daily_price.t) -> b.high_price)
  in
  let lows =
    Array.map bars_arr ~f:(fun (b : Types.Daily_price.t) -> b.low_price)
  in
  let ema = Indicator_arrays.ema ~closes ~period:_ema_period in
  let sma = Indicator_arrays.sma ~closes ~period:_sma_period in
  let atr = Indicator_arrays.atr ~highs ~lows ~closes ~period:_atr_period in
  let rsi = Indicator_arrays.rsi ~closes ~period:_rsi_period in
  let weekly_prefix = Weekly_prefix.build bars_arr in
  let stage, rs, macro =
    _compute_weekly_arrays ~bars_arr ~weekly_prefix ~benchmark_bars
  in
  { ema; sma; atr; rsi; stage; rs; macro }

let build_for_symbol ~symbol ~bars ~schema ?benchmark_bars () =
  if String.is_empty symbol then
    Status.error_invalid_argument
      "Snapshot_pipeline.build_for_symbol: empty symbol"
  else
    let bars_arr = Array.of_list bars in
    let n = Array.length bars_arr in
    if n = 0 then Ok []
    else
      let precomputed = _compute_precomputed ~bars_arr ~benchmark_bars in
      let rows =
        List.init n ~f:(fun i ->
            _row_for_day ~symbol ~schema ~precomputed ~bars_arr ~i)
      in
      Result.all rows

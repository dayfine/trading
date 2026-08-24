open Core
module Bar = Types.Daily_price

type params = {
  breakout_lookback_weeks : int;
  min_vol_ratio : float;
  base_band_pct : float;
  fwd_weeks : int;
}

let _default_breakout_lookback_weeks = 26
let _default_min_vol_ratio = 1.5
let _default_base_band_pct = 15.0
let _default_fwd_weeks = 52
let _percent_scale = 100.0

let default_params =
  {
    breakout_lookback_weeks = _default_breakout_lookback_weeks;
    min_vol_ratio = _default_min_vol_ratio;
    base_band_pct = _default_base_band_pct;
    fwd_weeks = _default_fwd_weeks;
  }

type features = {
  prior_high : float;
  vol_ratio : float;
  ma30 : float;
  base_weeks : int;
  stage : Weinstein_types.stage;
}

type forward_run = {
  fwd_max_close : float;
  fwd_run_pct : float;
  weeks_to_max : int;
}

type breakout = {
  week_date : Date.t;
  close : float;
  features : features;
  forward : forward_run;
}

let index_for_date ~bars ~(date : Date.t) =
  Array.findi bars ~f:(fun _ (b : Bar.t) -> Date.( >= ) b.date date)
  |> Option.map ~f:fst

let stage_label : Weinstein_types.stage -> string = function
  | Stage1 _ -> "Stage1"
  | Stage2 _ -> "Stage2"
  | Stage3 _ -> "Stage3"
  | Stage4 _ -> "Stage4"

let _is_stage2 : Weinstein_types.stage -> bool = function
  | Stage2 _ -> true
  | Stage1 _ | Stage3 _ | Stage4 _ -> false

(* Start of the trailing window [idx - lookback, idx - 1]. Callers gate on
   [_has_full_window] first, so this is >= 0 wherever it is used. *)
let _window_lo ~params ~idx = idx - params.breakout_lookback_weeks

let _has_full_window ~params ~bars ~idx =
  idx >= 0 && idx < Array.length bars && _window_lo ~params ~idx >= 0

let _fold_window ~params ~bars ~idx ~init ~f =
  let acc = ref init in
  for j = _window_lo ~params ~idx to idx - 1 do
    acc := f !acc bars.(j)
  done;
  !acc

let _prior_high ~params ~bars ~idx =
  _fold_window ~params ~bars ~idx ~init:Float.neg_infinity
    ~f:(fun acc (b : Bar.t) -> Float.max acc b.high_price)

let _vol_ratio ~params ~bars ~idx =
  let total =
    _fold_window ~params ~bars ~idx ~init:0.0 ~f:(fun acc (b : Bar.t) ->
        acc +. Float.of_int b.volume)
  in
  let mean = total /. Float.of_int params.breakout_lookback_weeks in
  if Float.( <= ) mean 0.0 then Float.nan
  else Float.of_int bars.(idx).Bar.volume /. mean

let _median (xs : float array) =
  if Array.is_empty xs then Float.nan
  else
    let sorted = Array.copy xs in
    Array.sort sorted ~compare:Float.compare;
    let n = Array.length sorted in
    if n % 2 = 1 then sorted.(n / 2)
    else (sorted.((n / 2) - 1) +. sorted.(n / 2)) /. 2.0

(* Walk back from [idx - 1] while each close stays within [±base_band_pct] of
   one fixed reference — the median close over the trailing window. Stops at the
   first week outside the band, or at bar 0. *)
let _base_weeks ~params ~bars ~idx =
  let lo = _window_lo ~params ~idx in
  let closes = Array.init (idx - lo) ~f:(fun k -> bars.(lo + k).Bar.close_price) in
  let median = _median closes in
  if Float.is_nan median then 0
  else
    let tolerance =
      Float.abs (median *. params.base_band_pct /. _percent_scale)
    in
    let in_band j = Float.( <= ) (Float.abs (bars.(j).Bar.close_price -. median)) tolerance in
    let j = ref (idx - 1) in
    while !j >= 0 && in_band !j do
      decr j
    done;
    idx - 1 - !j

let _classify ~stage_config ~bars ~idx =
  let prefix = Array.sub bars ~pos:0 ~len:(idx + 1) |> Array.to_list in
  Stage.classify ~config:stage_config ~bars:prefix ~prior_stage:None

let features_at ~params ~stage_config ~bars ~idx =
  if not (_has_full_window ~params ~bars ~idx) then None
  else
    let result = _classify ~stage_config ~bars ~idx in
    Some
      {
        prior_high = _prior_high ~params ~bars ~idx;
        vol_ratio = _vol_ratio ~params ~bars ~idx;
        ma30 = result.Stage.ma_value;
        base_weeks = _base_weeks ~params ~bars ~idx;
        stage = result.Stage.stage;
      }

let _no_forward_run =
  { fwd_max_close = Float.nan; fwd_run_pct = Float.nan; weeks_to_max = 0 }

let forward_run_at ~params ~bars ~idx =
  let last = Int.min (Array.length bars - 1) (idx + params.fwd_weeks) in
  if last <= idx then _no_forward_run
  else
    let best = ref (idx + 1) in
    for j = idx + 2 to last do
      if Float.( > ) bars.(j).Bar.close_price bars.(!best).Bar.close_price then
        best := j
    done;
    let fwd_max_close = bars.(!best).Bar.close_price in
    let close = bars.(idx).Bar.close_price in
    let fwd_run_pct =
      if Float.( <= ) close 0.0 then Float.nan
      else ((fwd_max_close /. close) -. 1.0) *. _percent_scale
    in
    { fwd_max_close; fwd_run_pct; weeks_to_max = !best - idx }

(* The cheap decision-time gate: a new high versus the trailing window, plus
   volume confirmation. Evaluated before the classifier so [Stage.classify] runs
   only at the handful of candidate weeks per symbol. *)
let _passes_price_volume_gate ~params ~bars ~idx =
  _has_full_window ~params ~bars ~idx
  && Float.( > ) bars.(idx).Bar.close_price (_prior_high ~params ~bars ~idx)
  && Float.( >= ) (_vol_ratio ~params ~bars ~idx) params.min_vol_ratio

let _breakout_at ~params ~stage_config ~bars ~idx =
  match features_at ~params ~stage_config ~bars ~idx with
  | Some features when _is_stage2 features.stage ->
      Some
        {
          week_date = bars.(idx).Bar.date;
          close = bars.(idx).Bar.close_price;
          features;
          forward = forward_run_at ~params ~bars ~idx;
        }
  | Some _ | None -> None

let scan ~params ~stage_config ~bars =
  List.range 0 (Array.length bars)
  |> List.filter ~f:(fun idx -> _passes_price_volume_gate ~params ~bars ~idx)
  |> List.filter_map ~f:(fun idx -> _breakout_at ~params ~stage_config ~bars ~idx)

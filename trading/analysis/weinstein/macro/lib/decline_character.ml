open Core
open Types

type t = Slow_grind | Fast_v | Not_declining [@@deriving show, eq, sexp]

type config = {
  ad_lead_max_drawdown_pct : float;
  rate_lookback_weeks : int;
  slow_grind_max_rate_pct : float;
  fast_v_min_rate_pct : float;
  weeks_below_ma_slow_grind : int;
  trailing_high_lookback_weeks : int;
}
[@@deriving sexp]

let default_config =
  {
    ad_lead_max_drawdown_pct = 0.10;
    rate_lookback_weeks = 4;
    slow_grind_max_rate_pct = 0.04;
    fast_v_min_rate_pct = 0.08;
    weeks_below_ma_slow_grind = 8;
    trailing_high_lookback_weeks = 52;
  }

(* The most recent index close, or [None] when there are no bars. *)
let _current_close (bars : Daily_price.t list) : float option =
  List.last bars |> Option.map ~f:(fun b -> b.Daily_price.close_price)

(* Drawdown over the trailing [lookback] bars as a positive fraction
   [(close_lookback - close_now) / close_lookback]; negative when the index
   rose. [None] when there are too few bars or the reference close is
   non-positive. Lookahead-free: reads only the last bar and the bar [lookback]
   weeks earlier. *)
let _trailing_drawdown_pct (bars : Daily_price.t list) ~(lookback : int) :
    float option =
  let n = List.length bars in
  if n <= lookback then None
  else
    let arr = Array.of_list bars in
    let close i = arr.(i).Daily_price.close_price in
    let now = close (n - 1) and ref_close = close (n - 1 - lookback) in
    if Float.( <= ) ref_close 0.0 then None
    else Some ((ref_close -. now) /. ref_close)

(* Drawdown of the current close from the highest close over the trailing
   [lookback] window (current bar inclusive), as a positive fraction. [None]
   when there are no bars or the peak is non-positive. *)
let _drawdown_from_trailing_high (bars : Daily_price.t list) ~(lookback : int) :
    float option =
  match List.last bars with
  | None -> None
  | Some last ->
      let window = List.drop bars (Int.max 0 (List.length bars - lookback)) in
      let peak =
        List.fold window ~init:0.0 ~f:(fun acc b ->
            Float.max acc b.Daily_price.close_price)
      in
      if Float.( <= ) peak 0.0 then None
      else Some ((peak -. last.Daily_price.close_price) /. peak)

(* Consecutive most-recent weeks whose close is below [ma_value]. Counts back
   from the latest bar and stops at the first bar at/above the MA. *)
let _weeks_below_ma (bars : Daily_price.t list) ~(ma_value : float) : int =
  List.rev bars
  |> List.take_while ~f:(fun b ->
      Float.( < ) b.Daily_price.close_price ma_value)
  |> List.length

(* The current "A-D Line" indicator signal from the macro result, if present. *)
let _ad_line_signal (macro : Macro.result) :
    [ `Bullish | `Bearish | `Neutral ] option =
  List.find macro.Macro.indicators ~f:(fun r ->
      String.equal r.Macro.name "A-D Line")
  |> Option.map ~f:(fun r -> r.Macro.signal)

(* The A-D line is "leading" the index lower when breadth is bearish while the
   index has not yet broken far from its trailing high. Weinstein's
   distribution-lead signature (book Ch. 8). A missing/Neutral/Bullish A-D
   reading is "not leading". *)
let _ad_line_is_leading (macro : Macro.result) (bars : Daily_price.t list)
    ~(config : config) : bool =
  match _ad_line_signal macro with
  | Some `Bearish -> (
      match
        _drawdown_from_trailing_high bars
          ~lookback:config.trailing_high_lookback_weeks
      with
      | Some dd -> Float.( <= ) dd config.ad_lead_max_drawdown_pct
      | None -> false)
  | Some (`Bullish | `Neutral) | None -> false

(* Is a decline in progress at all? The MA must be falling and the current
   close below it. A rising/flat MA or a close above the MA is [Not_declining].
*)
let _is_declining (macro : Macro.result) (bars : Daily_price.t list) : bool =
  let stage = macro.Macro.index_stage in
  match stage.Stage.ma_direction with
  | Weinstein_types.Declining -> (
      match _current_close bars with
      | Some close -> Float.( < ) close stage.Stage.ma_value
      | None -> false)
  | Weinstein_types.Rising | Weinstein_types.Flat -> false

let _is_slow_grind (macro : Macro.result) (bars : Daily_price.t list)
    ~(config : config) ~(rate_pct : float) : bool =
  let leading = _ad_line_is_leading macro bars ~config in
  let grind_below_ma =
    _weeks_below_ma bars ~ma_value:macro.Macro.index_stage.Stage.ma_value
    >= config.weeks_below_ma_slow_grind
    && Float.( < ) rate_pct config.slow_grind_max_rate_pct
  in
  leading || grind_below_ma

let classify ~(config : config) ~(macro : Macro.result)
    ~(index_bars : Daily_price.t list) : t =
  if not (_is_declining macro index_bars) then Not_declining
  else
    let rate_pct =
      Option.value
        (_trailing_drawdown_pct index_bars ~lookback:config.rate_lookback_weeks)
        ~default:0.0
    in
    if _is_slow_grind macro index_bars ~config ~rate_pct then Slow_grind
    else if
      (not (_ad_line_is_leading macro index_bars ~config))
      && Float.( > ) rate_pct config.fast_v_min_rate_pct
    then Fast_v
    else Not_declining

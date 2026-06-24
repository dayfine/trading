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
  fast_v_ignores_ma_filter : bool; [@sexp.default false]
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
    fast_v_ignores_ma_filter = false;
  }

(* The most recent index close, or [None] when there are no bars. *)
let _current_close (bars : Daily_price.t list) : float option =
  List.last bars |> Option.map ~f:(fun b -> b.Daily_price.close_price)

(* Positive drawdown [(reference - now) / reference] given a [reference] and
   [now] close; negative when the index rose. [None] when [reference] is
   non-positive. A single-[if] helper so its callers stay flat. *)
let _drawdown_fraction ~(reference : float) ~(now : float) : float option =
  if Float.( <= ) reference 0.0 then None
  else Some ((reference -. now) /. reference)

(* Drawdown over the trailing [lookback] bars as a positive fraction relative to
   the close [lookback] weeks earlier. [None] when there are too few bars or the
   reference close is non-positive. Lookahead-free: reads only the last bar and
   the bar [lookback] weeks earlier. *)
let _trailing_drawdown_pct (bars : Daily_price.t list) ~(lookback : int) :
    float option =
  let n = List.length bars in
  if n <= lookback then None
  else
    let arr = Array.of_list bars in
    let close i = arr.(i).Daily_price.close_price in
    _drawdown_fraction
      ~reference:(close (n - 1 - lookback))
      ~now:(close (n - 1))

(* Highest close over the trailing [lookback] window (current bar inclusive). *)
let _trailing_peak_close (bars : Daily_price.t list) ~(lookback : int) : float =
  let window = List.drop bars (Int.max 0 (List.length bars - lookback)) in
  List.fold window ~init:0.0 ~f:(fun acc b ->
      Float.max acc b.Daily_price.close_price)

(* Drawdown of the current close from the highest close over the trailing
   [lookback] window, as a positive fraction. [None] when there are no bars or
   the peak is non-positive. *)
let _drawdown_from_trailing_high (bars : Daily_price.t list) ~(lookback : int) :
    float option =
  match _current_close bars with
  | None -> None
  | Some now ->
      _drawdown_fraction ~reference:(_trailing_peak_close bars ~lookback) ~now

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

(* A trailing-high drawdown shallow enough that breadth is judged to be leading
   price lower (the index has not yet broken far from its high). *)
let _within_lead_band ~(config : config) (dd : float) : bool =
  Float.( <= ) dd config.ad_lead_max_drawdown_pct

(* The A-D line is "leading" the index lower when breadth is bearish while the
   index has not yet broken far from its trailing high. Weinstein's
   distribution-lead signature (book Ch. 8). A missing/Neutral/Bullish A-D
   reading is "not leading". *)
let _ad_line_is_leading (macro : Macro.result) (bars : Daily_price.t list)
    ~(config : config) : bool =
  match _ad_line_signal macro with
  | Some (`Bullish | `Neutral) | None -> false
  | Some `Bearish ->
      _drawdown_from_trailing_high bars
        ~lookback:config.trailing_high_lookback_weeks
      |> Option.exists ~f:(_within_lead_band ~config)

(* Is a decline in progress at all? The MA must be falling and the current
   close below it. A rising/flat MA or a close above the MA is [Not_declining].
*)
let _is_declining (macro : Macro.result) (bars : Daily_price.t list) : bool =
  let stage = macro.Macro.index_stage in
  match stage.Stage.ma_direction with
  | Weinstein_types.Rising | Weinstein_types.Flat -> false
  | Weinstein_types.Declining ->
      _current_close bars
      |> Option.exists ~f:(fun close -> Float.( < ) close stage.Stage.ma_value)

let _is_slow_grind (macro : Macro.result) (bars : Daily_price.t list)
    ~(config : config) ~(rate_pct : float) : bool =
  let leading = _ad_line_is_leading macro bars ~config in
  let grind_below_ma =
    _weeks_below_ma bars ~ma_value:macro.Macro.index_stage.Stage.ma_value
    >= config.weeks_below_ma_slow_grind
    && Float.( < ) rate_pct config.slow_grind_max_rate_pct
  in
  leading || grind_below_ma

(* A fast-V shock: breadth is NOT leading the decline (no distribution warning)
   and the recent rate-of-decline is steep. *)
let _is_fast_v (macro : Macro.result) (bars : Daily_price.t list)
    ~(config : config) ~(rate_pct : float) : bool =
  (not (_ad_line_is_leading macro bars ~config))
  && Float.( > ) rate_pct config.fast_v_min_rate_pct

(* The trailing rate-of-decline drawdown as a positive fraction (0.0 when there
   are too few bars). Shared by the decline-in-progress and pre-decline paths. *)
let _rate_pct (bars : Daily_price.t list) ~(config : config) : float =
  Option.value
    (_trailing_drawdown_pct bars ~lookback:config.rate_lookback_weeks)
    ~default:0.0

(* Classify a decline already known to be in progress. Kept separate from
   {!classify} so neither function carries a nested [else]. *)
let _classify_declining (macro : Macro.result) (bars : Daily_price.t list)
    ~(config : config) : t =
  let rate_pct = _rate_pct bars ~config in
  match _is_slow_grind macro bars ~config ~rate_pct with
  | true -> Slow_grind
  | false ->
      if _is_fast_v macro bars ~config ~rate_pct then Fast_v else Not_declining

(* The [fast_v_ignores_ma_filter] arming-speed path, evaluated only when no
   decline is in progress by the MA test. Returns [Fast_v] on rate alone (the
   gap-down the weekly-MA confirmation lags); never [Slow_grind] (a slow grind
   presupposes weeks-below-a-falling-MA, i.e. a decline in progress). *)
let _classify_pre_decline_fast_v (macro : Macro.result)
    (bars : Daily_price.t list) ~(config : config) : t =
  let rate_pct = _rate_pct bars ~config in
  if _is_fast_v macro bars ~config ~rate_pct then Fast_v else Not_declining

let classify ~(config : config) ~(macro : Macro.result)
    ~(index_bars : Daily_price.t list) : t =
  if _is_declining macro index_bars then
    _classify_declining macro index_bars ~config
  else if config.fast_v_ignores_ma_filter then
    _classify_pre_decline_fast_v macro index_bars ~config
  else Not_declining

(** Post-exit continuation metrics. See [post_exit.mli]. *)

open Core

type horizon_result = {
  horizon_weeks : int;
  continuation_pct : float;
  post_exit_max_favorable_pct : float;
  post_exit_max_adverse_pct : float;
}
[@@deriving show, eq, sexp]

(** Number of calendar days a horizon of [h] weeks spans. *)
let _days_of_weeks h = h * 7

(** The all-zero result for [horizon_weeks] (empty window, or non-positive exit
    price). *)
let _zero_result horizon_weeks =
  {
    horizon_weeks;
    continuation_pct = 0.0;
    post_exit_max_favorable_pct = 0.0;
    post_exit_max_adverse_pct = 0.0;
  }

(** Bars on/after [exit_date], sorted ascending by date. The [exit_date] bar is
    retained (inclusive lower bound). *)
let _bars_after ~exit_date bars =
  bars
  |> List.filter ~f:(fun (b : Types.Daily_price.t) ->
      Date.( >= ) b.date exit_date)
  |> List.sort
       ~compare:(fun (a : Types.Daily_price.t) (b : Types.Daily_price.t) ->
         Date.compare a.date b.date)

(** Bars from [forward] (ascending, all [>= exit_date]) whose date is within
    [horizon_weeks * 7] days of [exit_date], inclusive. *)
let _window_for ~exit_date ~horizon_weeks forward =
  let last = Date.add_days exit_date (_days_of_weeks horizon_weeks) in
  List.filter forward ~f:(fun (b : Types.Daily_price.t) ->
      Date.( <= ) b.date last)

(** [(max high, min low)] over a non-empty bar [window]. *)
let _high_low window =
  let highs =
    List.map window ~f:(fun (b : Types.Daily_price.t) -> b.high_price)
  in
  let lows =
    List.map window ~f:(fun (b : Types.Daily_price.t) -> b.low_price)
  in
  (List.reduce_exn highs ~f:Float.max, List.reduce_exn lows ~f:Float.min)

(** Signed pct from [exit_price] to [price]:
    [(price - exit_price) / exit_price]. *)
let _pct ~exit_price price = (price -. exit_price) /. exit_price

(** [(continuation, favourable, adverse)] pct, direction-adjusted: favourable is
    in the trade's direction, adverse against it; short mirrors around the exit
    price. Mirrors [Exit_audit_capture._excursions], forward from the exit. *)
let _directional ~(side : Trading_base.Types.position_side) ~pct ~last_close
    ~max_high ~min_low =
  match side with
  | Trading_base.Types.Long -> (pct last_close, pct max_high, pct min_low)
  (* Short: favourable is a drop, adverse a rise — mirror around exit. *)
  | Trading_base.Types.Short -> (-.pct last_close, -.pct min_low, -.pct max_high)

(** [horizon_result] over a NON-EMPTY [window] of post-exit bars. *)
let _result_of_window ~side ~exit_price ~horizon_weeks window =
  let max_high, min_low = _high_low window in
  let last_close = (List.last_exn window).close_price in
  let continuation, favorable, adverse =
    _directional ~side ~pct:(_pct ~exit_price) ~last_close ~max_high ~min_low
  in
  {
    horizon_weeks;
    continuation_pct = continuation;
    post_exit_max_favorable_pct = favorable;
    post_exit_max_adverse_pct = adverse;
  }

(** [horizon_result] for one horizon over the [exit_date]-anchored [forward]
    bars. All-zero when the window is empty. *)
let _result_for ~side ~exit_price ~exit_date ~horizon_weeks forward =
  match _window_for ~exit_date ~horizon_weeks forward with
  | [] -> _zero_result horizon_weeks
  | window -> _result_of_window ~side ~exit_price ~horizon_weeks window

let post_exit_metrics ~(side : Trading_base.Types.position_side) ~exit_price
    ~exit_date ~bars ~horizons_weeks =
  if Float.( <= ) exit_price 0.0 then List.map horizons_weeks ~f:_zero_result
  else
    let forward = _bars_after ~exit_date bars in
    List.map horizons_weeks ~f:(fun horizon_weeks ->
        _result_for ~side ~exit_price ~exit_date ~horizon_weeks forward)

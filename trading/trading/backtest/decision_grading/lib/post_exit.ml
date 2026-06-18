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

(** Bars on/after [exit_date], sorted ascending by date. The [exit_date] bar is
    retained (inclusive lower bound). *)
let _bars_after ~exit_date bars =
  bars
  |> List.filter ~f:(fun (b : Types.Daily_price.t) ->
      Date.( >= ) b.date exit_date)
  |> List.sort
       ~compare:(fun (a : Types.Daily_price.t) (b : Types.Daily_price.t) ->
         Date.compare a.date b.date)

(** Bars from [forward] (already ascending, all [>= exit_date]) whose date is
    within [horizon_weeks * 7] days of [exit_date], inclusive. *)
let _window_for ~exit_date ~horizon_weeks forward =
  let last = Date.add_days exit_date (_days_of_weeks horizon_weeks) in
  List.filter forward ~f:(fun (b : Types.Daily_price.t) ->
      Date.( <= ) b.date last)

(** Signed pct from [exit_price] to [price]:
    [(price - exit_price) / exit_price]. *)
let _pct ~exit_price price = (price -. exit_price) /. exit_price

(** [horizon_result] for a single horizon over the [exit_date]-anchored
    [forward] bars. Mirrors [Exit_audit_capture._excursions]: favourable is in
    the trade's direction, adverse against it, short side mirrored around
    [exit_price]. Returns the all-[0.0] result when the window is empty. *)
let _result_for ~(side : Trading_base.Types.position_side) ~exit_price
    ~exit_date ~horizon_weeks forward =
  let zero =
    {
      horizon_weeks;
      continuation_pct = 0.0;
      post_exit_max_favorable_pct = 0.0;
      post_exit_max_adverse_pct = 0.0;
    }
  in
  match _window_for ~exit_date ~horizon_weeks forward with
  | [] -> zero
  | window ->
      let last = List.last_exn window in
      let max_high =
        List.map window ~f:(fun (b : Types.Daily_price.t) -> b.high_price)
        |> List.reduce_exn ~f:Float.max
      in
      let min_low =
        List.map window ~f:(fun (b : Types.Daily_price.t) -> b.low_price)
        |> List.reduce_exn ~f:Float.min
      in
      let pct = _pct ~exit_price in
      let continuation, favorable, adverse =
        match side with
        | Trading_base.Types.Long ->
            (pct last.close_price, pct max_high, pct min_low)
        (* Short: favourable is a drop, adverse a rise — mirror around exit. *)
        | Trading_base.Types.Short ->
            (-.pct last.close_price, -.pct min_low, -.pct max_high)
      in
      {
        horizon_weeks;
        continuation_pct = continuation;
        post_exit_max_favorable_pct = favorable;
        post_exit_max_adverse_pct = adverse;
      }

let post_exit_metrics ~(side : Trading_base.Types.position_side) ~exit_price
    ~exit_date ~bars ~horizons_weeks =
  if Float.( <= ) exit_price 0.0 then
    List.map horizons_weeks ~f:(fun horizon_weeks ->
        {
          horizon_weeks;
          continuation_pct = 0.0;
          post_exit_max_favorable_pct = 0.0;
          post_exit_max_adverse_pct = 0.0;
        })
  else
    let forward = _bars_after ~exit_date bars in
    List.map horizons_weeks ~f:(fun horizon_weeks ->
        _result_for ~side ~exit_price ~exit_date ~horizon_weeks forward)

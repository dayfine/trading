(** Forward-return counterfactual for the decision-audit — see
    [counterfactual.mli]. *)

open Core
module SR = Screen_record
module PE = Decision_grading.Post_exit
module Bar_reader = Weinstein_strategy.Bar_reader

(* Extra weekly bars fetched beyond the horizon so the horizon window's last bar
   is covered even when weekly aggregation lands a bar slightly past the day
   boundary — mirrors [decision_grading_bin._horizon_buffer_weeks]. *)
let _horizon_buffer_weeks = 3

(* Days spanned by one weekly bar's horizon week. *)
let _days_per_week = 7

type candidate_forward = {
  symbol : string;
  side : Trading_base.Types.position_side;
  is_funded : bool;
  screen_date : Date.t;
  reason_skipped : Backtest.Trade_audit.skip_reason option;
  forward_return_pct : float option;
  score : int;
  rs_value : float option;
  volume_ratio : float option;
  weeks_advancing : int option;
}
[@@deriving sexp]

(* A candidate stripped of its funded/near-miss origin, so both sides fold
   through the same forward-return path. [reason_skipped] is [None] for funded
   entries. *)
type _candidate = {
  c_symbol : string;
  c_side : Trading_base.Types.position_side;
  c_is_funded : bool;
  c_reason_skipped : Backtest.Trade_audit.skip_reason option;
  c_score : int;
  c_rs_value : float option;
  c_volume_ratio : float option;
  c_weeks_advancing : int option;
}

let _of_funded (e : SR.funded_entry) : _candidate =
  {
    c_symbol = e.symbol;
    (* [funded_entry] does not carry [side]. The audit lens is long-dominated
       and the near-miss path (which carries [side]) covers short sign-handling;
       default the funded side to [Long] for the forward-return sign. *)
    c_side = Trading_base.Types.Long;
    c_is_funded = true;
    c_reason_skipped = None;
    c_score = e.score;
    c_rs_value = e.rs_value;
    c_volume_ratio = e.volume_ratio;
    c_weeks_advancing = e.weeks_advancing;
  }

let _of_near_miss (n : SR.near_miss) : _candidate =
  {
    c_symbol = n.symbol;
    c_side = n.side;
    c_is_funded = false;
    c_reason_skipped = Some n.reason_skipped;
    c_score = n.score;
    c_rs_value = n.rs_value;
    c_volume_ratio = n.volume_ratio;
    c_weeks_advancing = n.weeks_advancing;
  }

(** Union of a screen's funded ∪ near-miss candidates, deduplicating a symbol
    that appears on both sides toward the funded entry. *)
let _candidates_of_screen (s : SR.t) : _candidate list =
  let funded = List.map s.funded ~f:_of_funded in
  let funded_symbols =
    String.Set.of_list (List.map funded ~f:(fun c -> c.c_symbol))
  in
  let near =
    List.filter_map s.near_misses ~f:(fun n ->
        if Set.mem funded_symbols n.symbol then None else Some (_of_near_miss n))
  in
  funded @ near

(** Base price = close of the first bar at/after [screen_date]. [None] when no
    such bar exists (symbol absent from the warehouse, or all bars precede the
    screen). *)
let _base_price ~screen_date (bars : Types.Daily_price.t list) : float option =
  bars
  |> List.filter ~f:(fun (b : Types.Daily_price.t) ->
      Date.( >= ) b.date screen_date)
  |> List.min_elt
       ~compare:(fun (a : Types.Daily_price.t) (b : Types.Daily_price.t) ->
         Date.compare a.date b.date)
  |> Option.map ~f:(fun (b : Types.Daily_price.t) -> b.close_price)

(** Signed forward return of one candidate from [screen_date] over
    [horizon_weeks], reusing {!PE.post_exit_metrics}'s [continuation_pct] with
    the screen-date base price standing in for the exit price. [None] when the
    symbol has no bar at/after the screen date. *)
let _forward_return ~bar_reader ~screen_date ~horizon_weeks (c : _candidate) :
    float option =
  let as_of = Date.add_days screen_date (horizon_weeks * _days_per_week) in
  let bars =
    Bar_reader.weekly_bars_for bar_reader ~symbol:c.c_symbol
      ~n:(horizon_weeks + _horizon_buffer_weeks)
      ~as_of
  in
  match _base_price ~screen_date bars with
  | None -> None
  | Some base ->
      PE.post_exit_metrics ~side:c.c_side ~exit_price:base
        ~exit_date:screen_date ~bars ~horizons_weeks:[ horizon_weeks ]
      |> List.hd
      |> Option.map ~f:(fun (r : PE.horizon_result) -> r.continuation_pct)

let _forward_of_candidate ~bar_reader ~screen_date ~horizon_weeks
    (c : _candidate) : candidate_forward =
  {
    symbol = c.c_symbol;
    side = c.c_side;
    is_funded = c.c_is_funded;
    screen_date;
    reason_skipped = c.c_reason_skipped;
    forward_return_pct =
      _forward_return ~bar_reader ~screen_date ~horizon_weeks c;
    score = c.c_score;
    rs_value = c.c_rs_value;
    volume_ratio = c.c_volume_ratio;
    weeks_advancing = c.c_weeks_advancing;
  }

let compute (records : SR.t list) ~bar_reader ~horizon_weeks :
    candidate_forward list =
  List.concat_map records ~f:(fun (s : SR.t) ->
      _candidates_of_screen s
      |> List.map
           ~f:
             (_forward_of_candidate ~bar_reader ~screen_date:s.screen_date
                ~horizon_weeks))

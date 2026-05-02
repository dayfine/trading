open Core
open Types

type per_pick_outcome = {
  symbol : string;
  pick_date : Date.t;
  suggested_entry : float;
  suggested_stop : float;
  entry_filled_at : float;
  entry_filled_date : Date.t;
  max_favorable : float;
  max_adverse : float;
  final_price : float;
  final_date : Date.t;
  pct_return_horizon : float;
  stop_triggered : bool;
  max_drawdown_within_horizon : float;
  winner : bool;
}
[@@deriving sexp, eq, show]

type aggregate = {
  horizon_days : int;
  total_picks : int;
  winners : int;
  losers : int;
  stopped_out : int;
  avg_return_pct : float;
  avg_winner_return_pct : float;
  avg_loser_return_pct : float;
  best_pick : string;
  worst_pick : string;
}
[@@deriving sexp, eq, show]

type adj_bar = {
  date : Date.t;
  adj_open : float;
  adj_high : float;
  adj_low : float;
  adj_close : float;
}
(** Adjusted-price view of a single bar. We scale [open]/[high]/[low] by the
    ratio [adjusted_close / close_price] so all prices live in the same
    split-adjusted space as [adjusted_close]. *)

let _is_close_to_zero x = Float.( <. ) (Float.abs x) 1e-12

let _adjust_bar (b : Daily_price.t) : adj_bar =
  (* Scale OHL by the adjusted_close / close ratio. If close_price is ~0 (a
     pathological input), fall back to the raw values rather than producing
     NaN — the caller will just see uncorrected prices. *)
  let ratio =
    if _is_close_to_zero b.close_price then 1.0
    else b.adjusted_close /. b.close_price
  in
  {
    date = b.date;
    adj_open = b.open_price *. ratio;
    adj_high = b.high_price *. ratio;
    adj_low = b.low_price *. ratio;
    adj_close = b.adjusted_close;
  }

let _bars_in_window ~(pick_date : Date.t) ~(horizon_days : int)
    (bars : Daily_price.t list) : adj_bar list =
  let end_date = Date.add_days pick_date horizon_days in
  bars
  |> List.filter ~f:(fun (b : Daily_price.t) ->
      Date.( > ) b.date pick_date && Date.( <= ) b.date end_date)
  |> List.sort ~compare:(fun (a : Daily_price.t) (b : Daily_price.t) ->
      Date.compare a.date b.date)
  |> List.map ~f:_adjust_bar

(** Find the first bar whose [adj_high] reaches [entry]; the fill price is
    [max entry adj_open] (gap-fill rule). *)
let _find_entry_fill ~(entry : float) (bars : adj_bar list) :
    (adj_bar * float) option =
  List.find_map bars ~f:(fun b ->
      if Float.( >=. ) b.adj_high entry then
        let fill_price = Float.max entry b.adj_open in
        Some (b, fill_price)
      else None)

(** Return only the bars at and after the entry bar. *)
let _bars_from_entry ~(entry_date : Date.t) (bars : adj_bar list) : adj_bar list
    =
  List.filter bars ~f:(fun b -> Date.( >= ) b.date entry_date)

type tracking = {
  max_favorable : float;
  max_adverse : float;
  highest_close_so_far : float;
  max_drawdown : float;
  stop_triggered : bool;
}
(** Tracking state during the post-entry walk. *)

let _initial_tracking ~entry_fill =
  {
    max_favorable = entry_fill;
    max_adverse = entry_fill;
    highest_close_so_far = entry_fill;
    max_drawdown = 0.0;
    stop_triggered = false;
  }

let _update_tracking ~stop ~bar t =
  let max_favorable = Float.max t.max_favorable bar.adj_high in
  let max_adverse = Float.min t.max_adverse bar.adj_low in
  let highest_close_so_far = Float.max t.highest_close_so_far bar.adj_close in
  let drawdown_now =
    if Float.( <=. ) highest_close_so_far 0.0 then 0.0
    else (bar.adj_close -. highest_close_so_far) /. highest_close_so_far
  in
  let max_drawdown = Float.min t.max_drawdown drawdown_now in
  let stop_triggered = t.stop_triggered || Float.( <=. ) bar.adj_low stop in
  {
    max_favorable;
    max_adverse;
    highest_close_so_far;
    max_drawdown;
    stop_triggered;
  }

let _walk_post_entry ~entry_fill ~stop (bars : adj_bar list) : tracking =
  List.fold bars ~init:(_initial_tracking ~entry_fill) ~f:(fun acc bar ->
      _update_tracking ~stop ~bar acc)

let _unfilled_outcome ~(c : Weekly_snapshot.candidate) ~(pick_date : Date.t) :
    per_pick_outcome =
  {
    symbol = c.symbol;
    pick_date;
    suggested_entry = c.entry;
    suggested_stop = c.stop;
    entry_filled_at = Float.nan;
    entry_filled_date = pick_date;
    max_favorable = Float.nan;
    max_adverse = Float.nan;
    final_price = Float.nan;
    final_date = pick_date;
    pct_return_horizon = Float.nan;
    stop_triggered = false;
    max_drawdown_within_horizon = Float.nan;
    winner = false;
  }

let _filled_outcome ~(c : Weekly_snapshot.candidate) ~(pick_date : Date.t)
    ~(entry_bar : adj_bar) ~(entry_fill : float) ~(post : adj_bar list)
    ~(tracking : tracking) : per_pick_outcome =
  let final_bar =
    match List.last post with Some b -> b | None -> entry_bar
  in
  let pct_return_horizon =
    (final_bar.adj_close -. entry_fill) /. entry_fill
  in
  {
    symbol = c.symbol;
    pick_date;
    suggested_entry = c.entry;
    suggested_stop = c.stop;
    entry_filled_at = entry_fill;
    entry_filled_date = entry_bar.date;
    max_favorable = tracking.max_favorable;
    max_adverse = tracking.max_adverse;
    final_price = final_bar.adj_close;
    final_date = final_bar.date;
    pct_return_horizon;
    stop_triggered = tracking.stop_triggered;
    max_drawdown_within_horizon = tracking.max_drawdown;
    winner = Float.( >. ) pct_return_horizon 0.0;
  }

let _trace_window ~(pick_date : Date.t) ~(c : Weekly_snapshot.candidate)
    (window : adj_bar list) : per_pick_outcome =
  match _find_entry_fill ~entry:c.entry window with
  | None -> _unfilled_outcome ~c ~pick_date
  | Some (entry_bar, entry_fill) ->
      let post = _bars_from_entry ~entry_date:entry_bar.date window in
      let tracking = _walk_post_entry ~entry_fill ~stop:c.stop post in
      _filled_outcome ~c ~pick_date ~entry_bar ~entry_fill ~post ~tracking

let _trace_one ~(pick_date : Date.t) ~(horizon_days : int)
    ~(bars : Daily_price.t list option) (c : Weekly_snapshot.candidate) :
    per_pick_outcome =
  match bars with
  | None -> _unfilled_outcome ~c ~pick_date
  | Some raw_bars ->
      let window = _bars_in_window ~pick_date ~horizon_days raw_bars in
      _trace_window ~pick_date ~c window

let _is_filled (o : per_pick_outcome) = not (Float.is_nan o.entry_filled_at)

let _avg (xs : float list) : float =
  match xs with
  | [] -> Float.nan
  | _ ->
      let n = List.length xs in
      List.fold xs ~init:0.0 ~f:( +. ) /. Float.of_int n

let _aggregate ~(horizon_days : int) (outcomes : per_pick_outcome list) :
    aggregate =
  let total_picks = List.length outcomes in
  let filled = List.filter outcomes ~f:_is_filled in
  let winners_l = List.filter filled ~f:(fun o -> o.winner) in
  let losers_l = List.filter filled ~f:(fun o -> not o.winner) in
  let stopped_out =
    List.count outcomes ~f:(fun o -> _is_filled o && o.stop_triggered)
  in
  let avg_return_pct =
    _avg (List.map filled ~f:(fun o -> o.pct_return_horizon))
  in
  let avg_winner_return_pct =
    _avg (List.map winners_l ~f:(fun o -> o.pct_return_horizon))
  in
  let avg_loser_return_pct =
    _avg (List.map losers_l ~f:(fun o -> o.pct_return_horizon))
  in
  let best_pick =
    match
      List.max_elt filled ~compare:(fun a b ->
          Float.compare a.pct_return_horizon b.pct_return_horizon)
    with
    | Some o -> o.symbol
    | None -> ""
  in
  let worst_pick =
    match
      List.min_elt filled ~compare:(fun a b ->
          Float.compare a.pct_return_horizon b.pct_return_horizon)
    with
    | Some o -> o.symbol
    | None -> ""
  in
  {
    horizon_days;
    total_picks;
    winners = List.length winners_l;
    losers = List.length losers_l;
    stopped_out;
    avg_return_pct;
    avg_winner_return_pct;
    avg_loser_return_pct;
    best_pick;
    worst_pick;
  }

let trace_picks ~(picks : Weekly_snapshot.t)
    ~(bars : Daily_price.t list String.Map.t) ~(horizon_days : int) :
    per_pick_outcome list * aggregate =
  let outcomes =
    List.map picks.long_candidates ~f:(fun c ->
        _trace_one ~pick_date:picks.date ~horizon_days
          ~bars:(Map.find bars c.symbol) c)
  in
  (outcomes, _aggregate ~horizon_days outcomes)

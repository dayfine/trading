(** Aggregator over a list of optimal round-trips.

    See [optimal_summary.mli] for the API contract. *)

open Core

type _dd_state = { peak : float; max_drawdown : float }
(** Drawdown state — peak equity seen so far + max drawdown fraction. *)

let _initial_dd_state ~starting_cash =
  { peak = starting_cash; max_drawdown = 0.0 }

(** Apply one equity reading to the drawdown state. *)
let _step_dd (state : _dd_state) (equity : float) : _dd_state =
  let peak = Float.max state.peak equity in
  let drawdown =
    if Float.(peak <= 0.0) then 0.0 else (peak -. equity) /. peak
  in
  { peak; max_drawdown = Float.max state.max_drawdown drawdown }

(** Compute MaxDD over the equity curve formed by accumulating round-trip P&L in
    [exit_week] order. Round-trips with the same exit_week are grouped — the
    equity curve advances once per Friday, not once per round-trip. *)
let _max_drawdown_pct ~(starting_cash : float)
    (round_trips : Optimal_types.optimal_round_trip list) : float =
  let by_friday =
    round_trips
    |> List.sort ~compare:(fun (a : Optimal_types.optimal_round_trip) b ->
        Date.compare a.exit_week b.exit_week)
    |> List.group
         ~break:(fun
             (a : Optimal_types.optimal_round_trip)
             (b : Optimal_types.optimal_round_trip)
           -> not (Date.equal a.exit_week b.exit_week))
  in
  let _, final_state =
    List.fold by_friday
      ~init:(starting_cash, _initial_dd_state ~starting_cash)
      ~f:(fun (equity, dd_state) group ->
        let group_pnl =
          List.sum (module Float) group ~f:(fun rt -> rt.pnl_dollars)
        in
        let new_equity = equity +. group_pnl in
        (new_equity, _step_dd dd_state new_equity))
  in
  final_state.max_drawdown

(** Sum of positive P&L (winners). *)
let _gross_profit (round_trips : Optimal_types.optimal_round_trip list) : float
    =
  List.sum
    (module Float)
    round_trips
    ~f:(fun rt -> if Float.(rt.pnl_dollars > 0.0) then rt.pnl_dollars else 0.0)

(** Absolute sum of negative P&L (losers). *)
let _gross_loss (round_trips : Optimal_types.optimal_round_trip list) : float =
  List.sum
    (module Float)
    round_trips
    ~f:(fun rt ->
      if Float.(rt.pnl_dollars < 0.0) then Float.abs rt.pnl_dollars else 0.0)

let summarize ~(starting_cash : float) ~(variant : Optimal_types.variant_label)
    (round_trips : Optimal_types.optimal_round_trip list) :
    Optimal_types.optimal_summary =
  let total_round_trips = List.length round_trips in
  let winners =
    List.count round_trips ~f:(fun rt -> Float.(rt.pnl_dollars > 0.0))
  in
  let losers =
    List.count round_trips ~f:(fun rt -> Float.(rt.pnl_dollars < 0.0))
  in
  let total_pnl =
    List.sum (module Float) round_trips ~f:(fun rt -> rt.pnl_dollars)
  in
  let total_return_pct =
    if Float.(starting_cash <= 0.0) then 0.0 else total_pnl /. starting_cash
  in
  let win_rate_pct =
    if total_round_trips = 0 then 0.0
    else Float.of_int winners /. Float.of_int total_round_trips
  in
  let avg_r_multiple =
    if total_round_trips = 0 then 0.0
    else
      List.sum (module Float) round_trips ~f:(fun rt -> rt.r_multiple)
      /. Float.of_int total_round_trips
  in
  let gross_profit = _gross_profit round_trips in
  let gross_loss = _gross_loss round_trips in
  let profit_factor =
    if Float.(gross_loss <= 0.0) then Float.infinity
    else gross_profit /. gross_loss
  in
  let max_drawdown_pct = _max_drawdown_pct ~starting_cash round_trips in
  {
    total_round_trips;
    winners;
    losers;
    total_return_pct;
    win_rate_pct;
    avg_r_multiple;
    profit_factor;
    max_drawdown_pct;
    variant;
  }

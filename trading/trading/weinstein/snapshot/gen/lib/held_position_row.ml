open Core
module Bar_reader = Weinstein_strategy.Bar_reader
module Weekly_snapshot = Weinstein_snapshot.Weekly_snapshot

(* Current close for a held symbol as of the run date: the last daily bar's
   close. Falls back to the entry price when the symbol has no resident bars, so
   an un-priced position still renders a sensible (zero-unrealized) row. Returns
   the daily series too — [Stop_recompute.for_held_long] needs it. *)
let _current_price bar_reader ~as_of ~entry_price symbol =
  let daily = Bar_reader.daily_bars_for bar_reader ~symbol ~as_of in
  match List.last daily with
  | Some (bar : Types.Daily_price.t) -> (bar.close_price, daily)
  | None -> (entry_price, daily)

let _unrealized_pct ~entry_price ~current_price =
  if Float.equal entry_price 0.0 then 0.0
  else (current_price -. entry_price) /. entry_price *. 100.0

let enrich bar_reader ~(config : Weinstein_strategy.config) ~as_of
    (p : Live_portfolio.position) : Weekly_snapshot.held_position =
  let current_price, daily =
    _current_price bar_reader ~as_of ~entry_price:p.entry_price p.symbol
  in
  {
    symbol = p.symbol;
    entered = p.entry_date;
    stop = p.stop_price;
    status = "Holding";
    shares = p.shares;
    entry_price = p.entry_price;
    current_price;
    unrealized_pct = _unrealized_pct ~entry_price:p.entry_price ~current_price;
    recommended_stop =
      Stop_recompute.for_held_long ~stops_config:config.stops_config
        ~initial_stop_buffer:config.initial_stop_buffer
        ~entry_price:current_price ~bars:daily ~as_of;
  }

let long_market_value held =
  List.sum
    (module Float)
    held
    ~f:(fun (h : Weekly_snapshot.held_position) ->
      Float.of_int h.shares *. h.current_price)

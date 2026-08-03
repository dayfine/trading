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

(* The pre-4c.b view: a fresh support floor recomputed from this week's bars,
   with no memory of where the stop has been. Used for a holding that carries no
   [stop_state] — i.e. every portfolio.sexp written before item 4c.b — so an
   un-threaded book renders exactly as it did before. *)
let _recomputed ~(config : Weinstein_strategy.config) ~current_price ~daily
    ~as_of =
  ( "Holding",
    Stop_recompute.for_held_long ~stops_config:config.stops_config
      ~initial_stop_buffer:config.initial_stop_buffer ~entry_price:current_price
      ~bars:daily ~as_of )

(* The threaded view (item 4c.b): the carried state advanced through the weeks
   since it was last updated. The status line becomes the machine's own
   description — which state arm, and how many times the stop has ratcheted —
   so the report says what the stop IS rather than what a recomputation WOULD
   be. A weekly close through the stop reports the exit instead. *)
let _threaded bar_reader ~(config : Weinstein_strategy.config) ~as_of ~symbol
    ~prior =
  let weekly_bars =
    Bar_reader.weekly_bars_for bar_reader ~symbol ~n:config.lookback_bars ~as_of
  in
  match
    Stop_thread.advance ~stops_config:config.stops_config
      ~stage_config:config.stage_config ~weekly_bars ~prior
  with
  | Stop_thread.Holding track ->
      (Stop_track.label track, Some (Stop_track.level track))
  | Triggered { week; stop_level; _ } ->
      ( sprintf "STOP HIT %s (weekly close below $%.2f)" (Date.to_string week)
          stop_level,
        Some stop_level )

let enrich bar_reader ~(config : Weinstein_strategy.config) ~as_of
    (p : Live_portfolio.position) : Weekly_snapshot.held_position =
  let current_price, daily =
    _current_price bar_reader ~as_of ~entry_price:p.entry_price p.symbol
  in
  let status, recommended_stop =
    match p.stop_state with
    | None -> _recomputed ~config ~current_price ~daily ~as_of
    | Some prior -> _threaded bar_reader ~config ~as_of ~symbol:p.symbol ~prior
  in
  {
    symbol = p.symbol;
    entered = p.entry_date;
    stop = p.stop_price;
    status;
    shares = p.shares;
    entry_price = p.entry_price;
    current_price;
    unrealized_pct = _unrealized_pct ~entry_price:p.entry_price ~current_price;
    recommended_stop;
  }

let enrich_all bar_reader ~config ~as_of positions =
  let held = List.map positions ~f:(enrich bar_reader ~config ~as_of) in
  let tickers =
    List.map held ~f:(fun (h : Weekly_snapshot.held_position) -> h.symbol)
  in
  (held, tickers)

let long_market_value held =
  List.sum
    (module Float)
    held
    ~f:(fun (h : Weekly_snapshot.held_position) ->
      Float.of_int h.shares *. h.current_price)

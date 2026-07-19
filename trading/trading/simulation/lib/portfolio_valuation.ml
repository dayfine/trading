(** Portfolio mark-to-market valuation. See [portfolio_valuation.mli]. *)

open Core

(* Cache an authoritative price for [symbol] in [last_known_prices], returning
   the price for fluent chaining. *)
let _cache_price last_known_prices ~symbol price =
  Hashtbl.set last_known_prices ~key:symbol ~data:price;
  price

(* Tier 2: ask the adapter for the most recent prior bar; cache the close. *)
let _from_adapter adapter ~symbol ~date last_known_prices =
  Trading_simulation_data.Market_data_adapter.get_previous_bar adapter ~symbol
    ~date
  |> Option.map ~f:(fun prev ->
      _cache_price last_known_prices ~symbol prev.Types.Daily_price.close_price)

(* Tier 3: read from this run's cache. No mutation. *)
let _from_cache last_known_prices ~symbol =
  Hashtbl.find last_known_prices symbol

(* Tier 4: avg cost basis (zero-unrealized assumption). Records a fallback
   event and caches the value so repeated misses don't double-count. *)
let _from_avg_cost ~pos ~last_known_prices ~valuation_failure_count =
  incr valuation_failure_count;
  let avg_cost = Trading_portfolio.Calculations.avg_cost_of_position pos in
  _cache_price last_known_prices ~symbol:pos.Trading_portfolio.Types.symbol
    avg_cost

(** Resolve a held position's price via the chain of tiers (adapter → cache →
    avg-cost). Returns [None] only when [pos.symbol] is already in [today_set];
    otherwise always [Some (symbol, price)]. *)
let _resolve_price ~adapter ~date ~today_set ~last_known_prices
    ~valuation_failure_count (pos : Trading_portfolio.Types.portfolio_position)
    =
  let symbol = pos.symbol in
  if Set.mem today_set symbol then None
  else
    let from_adapter_or_cache =
      Option.first_some
        (_from_adapter adapter ~symbol ~date last_known_prices)
        (_from_cache last_known_prices ~symbol)
    in
    let price =
      match from_adapter_or_cache with
      | Some p -> p
      | None -> _from_avg_cost ~pos ~last_known_prices ~valuation_failure_count
    in
    Some (symbol, price)

(* Update the cache with today's authoritative bars (tier 1). *)
let _update_cache_with_today_bars last_known_prices today_prices =
  List.iter today_prices ~f:(fun (sym, p) ->
      Hashtbl.set last_known_prices ~key:sym ~data:p)

(** Build a [(symbol, close_price)] alist covering every held position. *)
let _prices_for_held_positions ~adapter ~date ~portfolio ~today_bars
    ~last_known_prices ~valuation_failure_count =
  let today_prices =
    List.map today_bars ~f:(fun bar ->
        (bar.Trading_engine.Types.symbol, bar.close_price))
  in
  _update_cache_with_today_bars last_known_prices today_prices;
  let today_set = today_prices |> List.map ~f:fst |> String.Set.of_list in
  let fallback_prices =
    List.filter_map portfolio.Trading_portfolio.Portfolio.positions
      ~f:
        (_resolve_price ~adapter ~date ~today_set ~last_known_prices
           ~valuation_failure_count)
  in
  today_prices @ fallback_prices

(* List held symbols for use in diagnostic messages. *)
let _held_symbols (portfolio : Trading_portfolio.Portfolio.t) : string list =
  List.map portfolio.positions ~f:(fun p -> p.Trading_portfolio.Types.symbol)

(* Unreachable in healthy runs: the four-tier chain in [_resolve_price]
   guarantees every held position has a price (today's bar, adapter
   forward-fill, run cache, or avg-cost last-resort). If [portfolio_value]
   still reports a missing price, the chain's invariant is broken — fail loud
   with a diagnostic naming the held symbols and the date.

   Prior behaviour silently substituted [portfolio.current_cash] here, which
   corrupted [equity_curve.csv] (NAV flatlined to cash-only during the gap and
   silently masked the underlying issue). See
   memory/project_simulator_nav_fallback_bug.md. *)
let _fail_loud_on_missing_mark ~date ~portfolio err =
  failwithf
    "Portfolio_valuation.compute: price-resolution chain produced no valid \
     mark for one or more held positions on %s — equity-curve corruption \
     avoided by failing loud. Held symbols: [%s]. Underlying calculations \
     error: %s"
    (Date.to_string date)
    (String.concat ~sep:"; " (_held_symbols portfolio))
    (Status.show err) ()

let compute ~adapter ~date ~portfolio ~today_bars ~last_known_prices
    ~valuation_failure_count =
  let prices =
    _prices_for_held_positions ~adapter ~date ~portfolio ~today_bars
      ~last_known_prices ~valuation_failure_count
  in
  match
    (* Equity nets borrowed long-margin debt (margin M1b-2): NAV / drawdown must
       see [equity_cash = current_cash - long_margin_debit], not raw cash. Equal
       to [current_cash] under a cash account, so pre-M1b NAV is bit-identical. *)
    Trading_portfolio.Calculations.portfolio_value
      portfolio.Trading_portfolio.Portfolio.positions
      (Trading_portfolio.Portfolio_margin.equity_cash portfolio)
      prices
  with
  | Ok value -> value
  | Error err -> _fail_loud_on_missing_mark ~date ~portfolio err

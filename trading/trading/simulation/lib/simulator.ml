(* @large-module: simulation engine orchestrates strategy dispatch, order execution, and multi-step stepping *)
(** Simulation engine for backtesting trading strategies *)

open Core
include Trading_simulation_types.Simulator_types

(** Internal: compute metrics by running all step-based computers *)
let _compute_metrics ~computers ~config ~steps =
  List.fold computers ~init:Trading_simulation_types.Metric_types.empty
    ~f:(fun acc (computer : any_metric_computer) ->
      Trading_simulation_types.Metric_types.merge acc
        (computer.run ~config ~steps))

(** Internal: compute derived metrics from base metrics.

    Derived computers are folded in list order — each sees the accumulated
    metrics from prior computers. This means callers must list them in
    dependency order. Currently sufficient (only CalmarRatio depends on CAGR +
    MaxDrawdown). If multi-layer dependencies arise, replace with topological
    sort over the [depends_on] declarations. *)
let _compute_derived ~derived_computers ~config ~base_metrics =
  List.fold derived_computers ~init:base_metrics
    ~f:(fun acc (dc : derived_metric_computer) ->
      Trading_simulation_types.Metric_types.merge acc
        (dc.compute ~config ~base_metrics:acc))

(** {1 Dependencies} *)

type dependencies = {
  symbols : string list;
  data_dir : Fpath.t;
  strategy : (module Trading_strategy.Strategy_interface.STRATEGY);
  engine : Trading_engine.Engine.t;
  order_manager : Trading_orders.Manager.order_manager;
  market_data_adapter : Trading_simulation_data.Market_data_adapter.t;
  metric_suite : metric_suite;
  benchmark_symbol : string option;
      (** Optional symbol whose adjusted-close % change provides the per-step
          benchmark return populated on [step_result.benchmark_return]. The
          benchmark does not need to be in [symbols] — bars are fetched
          independently via [market_data_adapter]. When [None] the field is left
          as [None] on every step (default; preserves prior behaviour). *)
  stale_hold_policy : Stale_hold.config;
  stale_hold_log : Stale_hold.Log.t;
}

let create_deps ~symbols ~data_dir ~strategy ~commission
    ?(metric_suite = { computers = []; derived = [] }) ?benchmark_symbol
    ?market_data_adapter ?(stale_hold_policy = Stale_hold.default_config)
    ?stale_hold_log ?(slippage_bps = 0) () =
  let engine_config = { Trading_engine.Types.commission; slippage_bps } in
  let engine = Trading_engine.Engine.create engine_config in
  let order_manager = Trading_orders.Manager.create () in
  let market_data_adapter =
    match market_data_adapter with
    | Some adapter -> adapter
    | None -> Trading_simulation_data.Market_data_adapter.create ~data_dir
  in
  let stale_hold_log =
    Option.value stale_hold_log ~default:(Stale_hold.Log.create ())
  in
  {
    symbols;
    data_dir;
    strategy;
    engine;
    order_manager;
    market_data_adapter;
    metric_suite;
    benchmark_symbol;
    stale_hold_policy;
    stale_hold_log;
  }

(** {1 Simulator State} *)

type step_outcome = Stepped of t * step_result | Completed of run_result

and t = {
  config : config;
  deps : dependencies;
  current_date : Date.t;
  portfolio : Trading_portfolio.Portfolio.t;
  positions : Trading_strategy.Position.t String.Map.t;
  step_history : step_result list;  (** Accumulated steps in reverse order *)
  last_known_prices : float String.Table.t;
      (** Per-symbol last-resolved close price. Populated whenever
          [_prices_for_held_positions] resolves a price for a held symbol
          (today's bar OR adapter forward-fill). Consulted as the third fallback
          if both today's bar and [get_previous_bar] fail — covers held symbols
          whose bar dataset has gaps the adapter cannot reach (M&A delisting +
          dataset edge, survivor-bias purges). Reference-shared across all
          per-step copies of [t]. *)
  valuation_failure_count : int ref;
      (** Counter incremented each time [_resolve_price] fell through to the
          avg-cost last-resort (the cache was also empty for a held symbol).
          Should remain [0] in healthy runs; printed at end of [run]. *)
}

(** {1 Creation} *)

let create ~config ~deps =
  if Date.(config.end_date <= config.start_date) then
    let msg =
      Printf.sprintf "end_date (%s) must be after start_date (%s)"
        (Date.to_string config.end_date)
        (Date.to_string config.start_date)
    in
    Error (Status.invalid_argument_error msg)
  else
    let portfolio =
      Trading_portfolio.Portfolio.create ~initial_cash:config.initial_cash ()
    in
    Ok
      {
        config;
        deps;
        current_date = config.start_date;
        portfolio;
        positions = String.Map.empty;
        step_history = [];
        last_known_prices = String.Table.create ();
        valuation_failure_count = ref 0;
      }

(** {1 Running} *)

let _submit_orders t orders =
  let _ = Trading_orders.Manager.submit_orders t.deps.order_manager orders in
  orders

let _is_complete t = Date.( >= ) t.current_date t.config.end_date

(** Convert Daily_price to engine price_bar *)
let _to_price_bar (symbol : string) (daily_price : Types.Daily_price.t) :
    Trading_engine.Types.price_bar =
  {
    Trading_engine.Types.symbol;
    open_price = daily_price.open_price;
    high_price = daily_price.high_price;
    low_price = daily_price.low_price;
    close_price = daily_price.close_price;
  }

(** Per-step benchmark return for the configured benchmark symbol, if any. We
    use [adjusted_close] (split- and dividend-adjusted) to keep returns
    comparable across the simulation window; this matches the convention used by
    [Antifragility_computer]'s synthetic tests, which feed in raw percent
    returns. Returns [None] when no benchmark is configured, or when either
    today's bar or the prior trading day's bar is missing for the benchmark. *)
let _compute_benchmark_return t : float option =
  let%bind.Option symbol = t.deps.benchmark_symbol in
  let adapter = t.deps.market_data_adapter in
  let date = t.current_date in
  let%bind.Option curr =
    Trading_simulation_data.Market_data_adapter.get_price adapter ~symbol ~date
  in
  let%bind.Option prev =
    Trading_simulation_data.Market_data_adapter.get_previous_bar adapter ~symbol
      ~date
  in
  let prev_close = prev.Types.Daily_price.adjusted_close in
  if Float.(prev_close <= 0.0) then None
  else
    let curr_close = curr.Types.Daily_price.adjusted_close in
    Some ((curr_close -. prev_close) /. prev_close *. 100.0)

(** Get all price bars for today using market data adapter *)
let _get_today_bars t =
  let get_bar symbol =
    Trading_simulation_data.Market_data_adapter.get_price
      t.deps.market_data_adapter ~symbol ~date:t.current_date
    |> Option.map ~f:(_to_price_bar symbol)
  in
  List.filter_map t.deps.symbols ~f:get_bar

(** Resolve a held position's price for today, populating + consulting
    [last_known_prices] as a third-tier fallback after today's bar and the
    adapter's forward-fill via [get_previous_bar]. The avg-cost last-resort
    fires only when none of the three sources knows a price — equivalent to
    "value the position at cost basis," i.e., assume zero unrealized P&L for
    that position. Increments [valuation_failure_count] in the avg-cost branch.

    Returns [None] only when [pos.symbol] is already in [today_set] (the caller
    covers it via [today_prices]); otherwise always returns
    [Some (symbol, price)] so the downstream [Calculations.portfolio_value] is
    guaranteed to succeed. *)
let _resolve_price ~adapter ~date ~today_set ~last_known_prices
    ~valuation_failure_count (pos : Trading_portfolio.Types.portfolio_position)
    =
  let symbol = pos.symbol in
  if Set.mem today_set symbol then None
  else
    let cache p =
      Hashtbl.set last_known_prices ~key:symbol ~data:p;
      p
    in
    let price =
      match
        Trading_simulation_data.Market_data_adapter.get_previous_bar adapter
          ~symbol ~date
      with
      | Some prev -> cache prev.Types.Daily_price.close_price
      | None -> (
          match Hashtbl.find last_known_prices symbol with
          | Some cached -> cached
          | None ->
              incr valuation_failure_count;
              cache (Trading_portfolio.Calculations.avg_cost_of_position pos))
    in
    Some (symbol, price)

(** Build a [(symbol, close_price)] alist covering every position in
    [portfolio]. Today's bar (from [today_bars]) is preferred; for any held
    symbol with no bar today, fall back to the adapter's [get_previous_bar]
    forward-fill, then to [last_known_prices] cache, then to the position's avg
    cost basis (zero-unrealized assumption). The cache + avg-cost fallback were
    added to fix the silent-cash-only valuation bug that previously corrupted
    the [equity_curve.csv] daily-derivative metrics whenever any held symbol's
    bar dataset had a gap. See [dev/notes/cell-e-15y-full-window-2026-05-10.md].
*)
let _prices_for_held_positions ~adapter ~date ~portfolio ~today_bars
    ~last_known_prices ~valuation_failure_count =
  let today_prices =
    List.map today_bars ~f:(fun bar ->
        (bar.Trading_engine.Types.symbol, bar.close_price))
  in
  List.iter today_prices ~f:(fun (sym, p) ->
      Hashtbl.set last_known_prices ~key:sym ~data:p);
  let today_set = today_prices |> List.map ~f:fst |> String.Set.of_list in
  let fallback_prices =
    List.filter_map portfolio.Trading_portfolio.Portfolio.positions
      ~f:
        (_resolve_price ~adapter ~date ~today_set ~last_known_prices
           ~valuation_failure_count)
  in
  today_prices @ fallback_prices

(** Compute total portfolio value (cash + position market values). With the
    cache + avg-cost fallback in [_prices_for_held_positions], every held
    position now has a price, so [Calculations.portfolio_value] should always
    return [Ok]. The legacy cash-only fallback is preserved as defense-in-depth:
    if anything regresses (e.g., a future field is added that causes the calc to
    fail for an unrelated reason), we still log it instead of silently
    corrupting the curve. *)
let _compute_portfolio_value ~adapter ~date ~portfolio ~today_bars
    ~last_known_prices ~valuation_failure_count =
  let prices =
    _prices_for_held_positions ~adapter ~date ~portfolio ~today_bars
      ~last_known_prices ~valuation_failure_count
  in
  match
    Trading_portfolio.Calculations.portfolio_value
      portfolio.Trading_portfolio.Portfolio.positions portfolio.current_cash
      prices
  with
  | Ok value -> value
  | Error _ ->
      incr valuation_failure_count;
      portfolio.current_cash

(** Extract trades from execution reports *)
let _extract_trades reports =
  List.concat_map reports ~f:(fun report -> report.Trading_engine.Types.trades)

(** Create get_price function for strategy *)
let _make_get_price t : Trading_strategy.Strategy_interface.get_price_fn =
 fun symbol ->
  Trading_simulation_data.Market_data_adapter.get_price
    t.deps.market_data_adapter ~symbol ~date:t.current_date

(** Create get_indicator function for strategy *)
let _make_get_indicator t : Trading_strategy.Strategy_interface.get_indicator_fn
    =
 fun symbol indicator_name period cadence ->
  Trading_simulation_data.Market_data_adapter.get_indicator
    t.deps.market_data_adapter ~symbol ~indicator_name ~period ~cadence
    ~date:t.current_date

(** True if the strategy should be called today given the configured cadence. *)
let _should_call_strategy t =
  Trading_simulation_data.Time_series.is_period_end
    ~cadence:t.config.strategy_cadence t.current_date

(** Call strategy and get transitions, or skip and return [] on non-cadence
    days. *)
let _call_strategy t =
  if not (_should_call_strategy t) then Ok []
  else
    let (module S) = t.deps.strategy in
    let get_price = _make_get_price t in
    let get_indicator = _make_get_indicator t in
    let open Result.Let_syntax in
    let portfolio : Trading_strategy.Portfolio_view.t =
      {
        cash = t.portfolio.Trading_portfolio.Portfolio.current_cash;
        positions = t.positions;
      }
    in
    let%bind output = S.on_market_close ~get_price ~get_indicator ~portfolio in
    Ok output.transitions

(** Find position by symbol and state *)
let _find_position_by_symbol_state positions ~symbol ~state_match =
  Map.to_alist positions
  |> List.find_map ~f:(fun (id, pos) ->
      if
        String.equal pos.Trading_strategy.Position.symbol symbol
        && state_match (Trading_strategy.Position.get_state pos)
      then Some (id, pos)
      else None)

let _no_risk_params =
  Trading_strategy.Position.
    { stop_loss_price = None; take_profit_price = None; max_hold_days = None }

(** Apply a fill to a position (works for both entry and exit fills). *)
let _apply_fill ~date ~position ~trade ~is_entry =
  let open Result.Let_syntax in
  let open Trading_strategy.Position in
  let qty = trade.Trading_base.Types.quantity in
  let price = trade.Trading_base.Types.price in
  let fill_kind =
    if is_entry then EntryFill { filled_quantity = qty; fill_price = price }
    else ExitFill { filled_quantity = qty; fill_price = price }
  in
  let fill_trans = { position_id = position.id; date; kind = fill_kind } in
  let%bind pos = apply_transition position fill_trans in
  let complete_kind =
    if is_entry then EntryComplete { risk_params = _no_risk_params }
    else ExitComplete
  in
  let complete_trans = { position_id = pos.id; date; kind = complete_kind } in
  apply_transition pos complete_trans

let _is_entering_state = function
  | Trading_strategy.Position.Entering _ -> true
  | _ -> false

let _is_exiting_state = function
  | Trading_strategy.Position.Exiting _ -> true
  | _ -> false

let _find_fill_target acc symbol =
  let try_find state_match is_entry =
    _find_position_by_symbol_state acc ~symbol ~state_match
    |> Option.map ~f:(fun (id, pos) -> (id, pos, is_entry))
  in
  match try_find _is_entering_state true with
  | Some _ as r -> r
  | None -> try_find _is_exiting_state false

(** Update positions from trades. *)
let _update_positions_from_trades ~date ~positions ~trades =
  let open Result.Let_syntax in
  List.fold_result trades ~init:positions ~f:(fun acc trade ->
      let symbol = trade.Trading_base.Types.symbol in
      match _find_fill_target acc symbol with
      | Some (id, pos, is_entry) ->
          let%bind updated = _apply_fill ~date ~position:pos ~trade ~is_entry in
          Ok (Map.set acc ~key:id ~data:updated)
      | None -> Ok acc)

let _apply_trigger_exit acc trans =
  let open Result.Let_syntax in
  match Map.find acc trans.Trading_strategy.Position.position_id with
  | None -> Ok acc
  | Some pos ->
      let%bind updated = Trading_strategy.Position.apply_transition pos trans in
      Ok (Map.set acc ~key:trans.position_id ~data:updated)

(** Apply transitions to positions *)
let _apply_transitions ~positions ~transitions =
  let open Result.Let_syntax in
  List.fold_result transitions ~init:positions ~f:(fun acc trans ->
      match trans.Trading_strategy.Position.kind with
      | CreateEntering _ ->
          let%bind pos = Trading_strategy.Position.create_entering trans in
          Ok (Map.set acc ~key:pos.id ~data:pos)
      | TriggerExit _ -> _apply_trigger_exit acc trans
      | _ -> Ok acc)

(** Build run_result from accumulated state.

    [final_portfolio] is the simulator's last full
    {!Trading_portfolio.Portfolio.t}; it is exposed on the result so reconciler
    writers (which need lots / avg-cost / per-symbol position details) read it
    directly rather than reconstructing from the skinny per-step
    [Portfolio_summary] retained on [steps]. *)
let _build_run_result t =
  let steps = List.rev t.step_history in
  let base_metrics =
    _compute_metrics ~computers:t.deps.metric_suite.computers ~config:t.config
      ~steps
  in
  let metrics =
    _compute_derived ~derived_computers:t.deps.metric_suite.derived
      ~config:t.config ~base_metrics
  in
  if !(t.valuation_failure_count) > 0 then
    eprintf
      "WARN: %d held-position price resolutions fell through to avg-cost \
       fallback (zero unrealized assumption). Run still produced a valid \
       portfolio_value series; review valuation_failure_count for cache \
       coverage gaps.\n\
       %!"
      !(t.valuation_failure_count);
  { steps; final_portfolio = t.portfolio; metrics }

(* Apply trades one at a time, skipping any that fail (e.g. insufficient
   cash). Returns the updated portfolio and the list of accepted trades. *)
let _apply_trades_best_effort portfolio trades =
  List.fold trades ~init:(portfolio, []) ~f:(fun (portfolio, accepted) trade ->
      match Trading_portfolio.Portfolio.apply_single_trade portfolio trade with
      | Ok p -> (p, accepted @ [ trade ])
      | Error _ -> (portfolio, accepted))

(* Split-handling helpers extracted to {!Split_handler}. *)

(** Apply split detection, update market state, and record stale-held positions.
    Returns the post-split portfolio, positions, today's bars, and the split
    events (needed for [step_result.splits_applied]). *)
let _prepare_market_state t =
  let split_events =
    Split_handler.detect_for_held_positions ~adapter:t.deps.market_data_adapter
      ~date:t.current_date ~portfolio:t.portfolio
  in
  let portfolio = Split_handler.apply_events t.portfolio split_events in
  let positions = Split_handler.apply_to_positions t.positions split_events in
  let today_bars = _get_today_bars t in
  (* Record stale-held positions (symbols without bars for K+ days) into
     the per-run log. Detector only — no force-close; see [Stale_hold].
     Runs only on bar-bearing days so weekend/holiday gaps don't trigger
     false-positives every Saturday. *)
  if not (List.is_empty today_bars) then
    List.iter
      (Stale_hold.detect_stale ~adapter:t.deps.market_data_adapter
         ~date:t.current_date ~portfolio ~today_bars
         ~config:t.deps.stale_hold_policy)
      ~f:(Stale_hold.Log.record t.deps.stale_hold_log);
  Trading_engine.Engine.update_market t.deps.engine today_bars;
  (portfolio, positions, today_bars, split_events)

(** Process one day: execute pending orders, call strategy, generate new orders,
    and assemble the [step_result]. Returns the next simulator state paired with
    this day's [step_result]. *)
let _process_step_day t ~portfolio ~positions ~today_bars ~split_events =
  let open Result.Let_syntax in
  let%bind execution_reports =
    Trading_engine.Engine.process_orders t.deps.engine t.deps.order_manager
  in
  let all_trades = _extract_trades execution_reports in
  let portfolio, trades = _apply_trades_best_effort portfolio all_trades in
  let%bind positions =
    _update_positions_from_trades ~date:t.current_date ~positions ~trades
  in
  let%bind transitions = _call_strategy { t with portfolio; positions } in
  let%bind positions = _apply_transitions ~positions ~transitions in
  let%bind orders =
    Order_generator.transitions_to_orders ~current_date:t.current_date
      ~positions transitions
  in
  let portfolio_value =
    _compute_portfolio_value ~adapter:t.deps.market_data_adapter
      ~date:t.current_date ~portfolio ~today_bars
      ~last_known_prices:t.last_known_prices
      ~valuation_failure_count:t.valuation_failure_count
  in
  (* Project to skinny per-step summary — see [Portfolio_summary.t] for the
     memory-pressure rationale (Fix B in
     dev/notes/15y-memory-cliff-2026-05-08.md). *)
  let portfolio_summary =
    Trading_simulation_types.Portfolio_summary.of_portfolio portfolio
      ~position_value_total:(portfolio_value -. portfolio.current_cash)
  in
  let step_result =
    {
      date = t.current_date;
      portfolio = portfolio_summary;
      portfolio_value;
      trades;
      orders_submitted = _submit_orders t orders;
      splits_applied = split_events;
      benchmark_return = _compute_benchmark_return t;
      had_market_bars = not (List.is_empty today_bars);
    }
  in
  let t' =
    {
      t with
      current_date = Date.add_days t.current_date 1;
      portfolio;
      positions;
      step_history = step_result :: t.step_history;
    }
  in
  return (Stepped (t', step_result))

let step t =
  if _is_complete t then Ok (Completed (_build_run_result t))
  else
    let portfolio, positions, today_bars, split_events =
      _prepare_market_state t
    in
    _process_step_day t ~portfolio ~positions ~today_bars ~split_events

let get_config t = t.config

let run t =
  let rec loop t =
    match step t with
    | Error e -> Error e
    | Ok (Completed result) -> Ok result
    | Ok (Stepped (t', _)) -> loop t'
  in
  loop t

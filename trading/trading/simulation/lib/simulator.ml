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
}

let create_deps ~symbols ~data_dir ~strategy ~commission
    ?(metric_suite = { computers = []; derived = [] }) ?benchmark_symbol () =
  let engine_config = { Trading_engine.Types.commission } in
  let engine = Trading_engine.Engine.create engine_config in
  let order_manager = Trading_orders.Manager.create () in
  let market_data_adapter =
    Trading_simulation_data.Market_data_adapter.create ~data_dir
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

(** Compute total portfolio value (cash + position market values). *)
let _compute_portfolio_value ~portfolio ~today_bars =
  let prices =
    List.map today_bars ~f:(fun bar ->
        (bar.Trading_engine.Types.symbol, bar.close_price))
  in
  match
    Trading_portfolio.Calculations.portfolio_value
      portfolio.Trading_portfolio.Portfolio.positions portfolio.current_cash
      prices
  with
  | Ok value -> value
  | Error _ -> portfolio.current_cash

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

(** Build run_result from accumulated state *)
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
  { steps; metrics }

(* Apply trades one at a time, skipping any that fail (e.g. insufficient
   cash). Returns the updated portfolio and the list of accepted trades. *)
let _apply_trades_best_effort portfolio trades =
  List.fold trades ~init:(portfolio, []) ~f:(fun (portfolio, accepted) trade ->
      match Trading_portfolio.Portfolio.apply_single_trade portfolio trade with
      | Ok p -> (p, accepted @ [ trade ])
      | Error _ -> (portfolio, accepted))

(* Detect a split for [symbol] between the prior trading day's bar and
   today's bar. Returns [Some event] when both bars exist and the detector
   fires, otherwise [None]. Pure with respect to the adapter's cache. *)
let _detect_split_for_held_symbol ~adapter ~date ~symbol =
  let curr =
    Trading_simulation_data.Market_data_adapter.get_price adapter ~symbol ~date
  in
  let prev =
    Trading_simulation_data.Market_data_adapter.get_previous_bar adapter ~symbol
      ~date
  in
  let%bind.Option curr = curr in
  let%bind.Option prev = prev in
  let%map.Option factor = Types.Split_detector.detect_split ~prev ~curr () in
  { Trading_portfolio.Split_event.symbol; date; factor }

(* For every symbol currently held in [portfolio], compare the prior
   trading day's bar against the current day's bar and return the list of
   detected split events. Symbols with no current bar (weekends/holidays)
   or no prior bar (first appearance) yield no event. Order follows
   [portfolio.positions] (sorted by symbol). *)
let _detect_splits_for_held_positions t =
  let adapter = t.deps.market_data_adapter in
  let date = t.current_date in
  List.filter_map t.portfolio.Trading_portfolio.Portfolio.positions
    ~f:(fun (pos : Trading_portfolio.Types.portfolio_position) ->
      _detect_split_for_held_symbol ~adapter ~date ~symbol:pos.symbol)

(* Apply each detected split event to [portfolio] in order. Pure: returns
   the updated portfolio with all events folded in. *)
let _apply_split_events portfolio events =
  List.fold events ~init:portfolio ~f:(fun acc event ->
      Trading_portfolio.Split_event.apply_to_portfolio event acc)

(* Apply a split factor to a strategy-side [Position.t]'s share-count and
   per-share-price fields. Long-only path: [Holding.quantity] multiplies by
   [factor] and [Holding.entry_price] divides by [factor], preserving total
   cost basis. [Exiting] mirrors the same scaling on its share-count fields
   ([quantity], [target_quantity], [filled_quantity]) and per-share-price
   fields ([entry_price], [exit_price]). [Entering] (in-flight entry order)
   and [Closed] (historical) pass through unchanged: an entry order spanning
   a split is exotic and out of scope for the broker-model fix; closed
   positions have no live state to scale.

   Pure: returns a new [Position.t] with [state] replaced. The position's
   [id], [symbol], [side], [entry_reasoning], [exit_reason], [last_updated],
   and [portfolio_lot_ids] are unchanged. *)
let _apply_split_to_position (factor : float)
    (pos : Trading_strategy.Position.t) : Trading_strategy.Position.t =
  let open Trading_strategy.Position in
  let new_state =
    match pos.state with
    | Holding { quantity; entry_price; entry_date; risk_params } ->
        Holding
          {
            quantity = quantity *. factor;
            entry_price = entry_price /. factor;
            entry_date;
            risk_params;
          }
    | Exiting
        {
          quantity;
          entry_price;
          entry_date;
          target_quantity;
          exit_price;
          filled_quantity;
          started_date;
        } ->
        Exiting
          {
            quantity = quantity *. factor;
            entry_price = entry_price /. factor;
            entry_date;
            target_quantity = target_quantity *. factor;
            exit_price = exit_price /. factor;
            filled_quantity = filled_quantity *. factor;
            started_date;
          }
    | (Entering _ | Closed _) as s -> s
  in
  { pos with state = new_state }

(* Apply detected split events to the strategy-side [Position.t] map. Each
   event matches positions by symbol; multiple positions on the same symbol
   (lots reopened after a prior close) all get scaled. Order matches
   [_apply_split_events]: events are folded in detection order. Pure. *)
let _apply_splits_to_positions
    (positions : Trading_strategy.Position.t String.Map.t)
    (events : Trading_portfolio.Split_event.t list) :
    Trading_strategy.Position.t String.Map.t =
  List.fold events ~init:positions ~f:(fun acc event ->
      Map.map acc ~f:(fun pos ->
          if String.equal pos.Trading_strategy.Position.symbol event.symbol then
            _apply_split_to_position event.factor pos
          else pos))

let step t =
  if _is_complete t then Ok (Completed (_build_run_result t))
  else
    let open Result.Let_syntax in
    (* Detect splits first; then scale BOTH the broker portfolio and the
       strategy-side [Position.t] map in lockstep — see the helper docs. *)
    let split_events = _detect_splits_for_held_positions t in
    let portfolio = _apply_split_events t.portfolio split_events in
    let positions = _apply_splits_to_positions t.positions split_events in
    let today_bars = _get_today_bars t in
    Trading_engine.Engine.update_market t.deps.engine today_bars;
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
    let step_result =
      {
        date = t.current_date;
        portfolio;
        portfolio_value = _compute_portfolio_value ~portfolio ~today_bars;
        trades;
        orders_submitted = _submit_orders t orders;
        splits_applied = split_events;
        benchmark_return = _compute_benchmark_return t;
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

let get_config t = t.config

let run t =
  let rec loop t =
    match step t with
    | Error e -> Error e
    | Ok (Completed result) -> Ok result
    | Ok (Stepped (t', _)) -> loop t'
  in
  loop t

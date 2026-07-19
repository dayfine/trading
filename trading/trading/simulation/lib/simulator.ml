(* @large-module: simulation engine orchestrates strategy dispatch, order execution, and multi-step stepping *)
(** Simulation engine for backtesting trading strategies *)

open Core
include Trading_simulation_types.Simulator_types

(** {1 Dependencies} *)

type dependencies = {
  symbols : string list;
  data_dir : Fpath.t;
  strategy : (module Trading_strategy.Strategy_interface.STRATEGY);
  engine : Trading_engine.Engine.t;
  order_manager : Trading_orders.Manager.order_manager;
  market_data_adapter : Trading_simulation_data.Market_data_adapter.t;
  metric_suite : metric_suite;
  benchmark_symbol : string option;  (** See .mli. *)
  stale_hold_policy : Stale_hold.config;
  stale_hold_log : Stale_hold.Log.t;
  margin_config : Trading_portfolio.Margin_config.t;  (** See .mli. *)
  initial_long_margin_req : float;  (** See .mli. Margin M1b-2 leverage dial. *)
  long_margin_rate_annual_pct : float;
      (** See .mli. Margin M1b-2 debit rate. *)
  exempt_closing_trades_from_cash_floor : bool;  (** See .mli. *)
  on_trade_fill : (Trading_base.Types.trade -> Trading_base.Types.trade) option;
  active_through_for : (string -> Core.Date.t option) option;  (** See .mli. *)
}

let create_deps ~symbols ~data_dir ~strategy ~commission
    ?(metric_suite = { computers = []; derived = [] }) ?benchmark_symbol
    ?market_data_adapter ?(stale_hold_policy = Stale_hold.default_config)
    ?stale_hold_log ?(slippage_bps = 0)
    ?(margin_config = Trading_portfolio.Margin_config.default_config)
    ?(initial_long_margin_req = 1.0) ?(long_margin_rate_annual_pct = 0.0)
    ?(exempt_closing_trades_from_cash_floor = false) ?on_trade_fill
    ?active_through_for () =
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
    margin_config;
    initial_long_margin_req;
    long_margin_rate_annual_pct;
    exempt_closing_trades_from_cash_floor;
    on_trade_fill;
    active_through_for;
  }

(* See .mli. Win #4 point-in-time pruning. *)
let prune_symbols_by_active_through ~symbols ~active_through_for
    ~fold_start_date =
  let keep s =
    match active_through_for s with
    | None -> true
    | Some d -> Core.Date.( <= ) fold_start_date d
  in
  List.filter symbols ~f:keep

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
      (** Per-symbol last-resolved close, used as the third fallback for
          [_resolve_price]. Reference-shared across per-step copies of [t]. *)
  order_links : string String.Table.t;
      (** order_id -> position_id for the orders currently in flight (recorded
          at generation, consumed by {!Fill_router} for exact fill routing).
          Cleared and repopulated on each generation pass; reference-shared
          across per-step copies of [t]. *)
  valuation_failure_count : int ref;
      (** Counter for fallback-to-avg-cost valuations; [0] in healthy runs. *)
}

(** {1 Creation} *)

(* Win #4: prune the per-step bar-fetch universe once, up front. [None]
   active_through_for preserves baselines. *)
let _maybe_prune_deps ~fold_start_date deps =
  match deps.active_through_for with
  | None -> deps
  | Some f ->
      let symbols =
        prune_symbols_by_active_through ~symbols:deps.symbols
          ~active_through_for:f ~fold_start_date
      in
      { deps with symbols }

let _build_initial_state ~config ~deps =
  let deps = _maybe_prune_deps ~fold_start_date:config.start_date deps in
  let portfolio =
    Trading_portfolio.Portfolio.create ~initial_cash:config.initial_cash
      ~exempt_closing_trades_from_cash_floor:
        deps.exempt_closing_trades_from_cash_floor ()
  in
  {
    config;
    deps;
    current_date = config.start_date;
    portfolio;
    positions = String.Map.empty;
    step_history = [];
    last_known_prices = String.Table.create ();
    order_links = String.Table.create ();
    valuation_failure_count = ref 0;
  }

let _date_range_error_of ~config =
  let msg =
    Printf.sprintf "end_date (%s) must be after start_date (%s)"
      (Date.to_string config.end_date)
      (Date.to_string config.start_date)
  in
  Status.invalid_argument_error msg

let create ~config ~deps =
  if Date.(config.end_date <= config.start_date) then
    Error (_date_range_error_of ~config)
  else Ok (_build_initial_state ~config ~deps)

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

(** Per-step benchmark return for the configured benchmark symbol, computed from
    [adjusted_close]. [None] when no benchmark or either bar is missing. *)
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

(** Extract fills, re-stamped with the simulated [date] (G1;
    {!Fill_date_stamp}). *)
let _extract_trades ~date reports =
  List.concat_map reports ~f:(fun report -> report.Trading_engine.Types.trades)
  |> List.map ~f:(Fill_date_stamp.restamp ~date)

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

let _is_holding_state = function
  | Trading_strategy.Position.Holding _ -> true
  | _ -> false

(* Count [Holding] positions = those still under stop evaluation; surfaced as
   [run_result.n_stop_eligible_positions] for the divergence guard (#1553). *)
let _count_stop_eligible positions =
  Map.count positions ~f:(fun pos ->
      _is_holding_state (Trading_strategy.Position.get_state pos))

(* Fill routing (which position receives a fill trade, by symbol + state +
   side) lives in {!Fill_router}. Closed positions are strategy-invisible and
   contribute 0 to valuation; audit trails live in [Trade_audit] / [Stop_log] /
   [final_portfolio.positions]. *)

let _apply_trigger_exit acc trans =
  let open Result.Let_syntax in
  match Map.find acc trans.Trading_strategy.Position.position_id with
  | None -> Ok acc
  | Some pos ->
      let%bind updated = Trading_strategy.Position.apply_transition pos trans in
      Ok
        (Fill_router.set_or_drop_if_closed acc ~key:trans.position_id
           ~data:updated)

(** Apply transitions to positions. [CancelEntry] is delegated to
    {!Cancel_handler.apply_to_positions}; the rest are inline. *)
let _apply_transitions ~positions ~transitions =
  let open Result.Let_syntax in
  List.fold_result transitions ~init:positions ~f:(fun acc trans ->
      match trans.Trading_strategy.Position.kind with
      | CreateEntering _ ->
          let%bind pos = Trading_strategy.Position.create_entering trans in
          Ok (Map.set acc ~key:pos.id ~data:pos)
      | TriggerExit _ | TriggerPartialExit _ -> _apply_trigger_exit acc trans
      | CancelEntry _ -> Cancel_handler.apply_to_positions acc trans
      | _ -> Ok acc)

(** Build run_result from accumulated state. [final_portfolio] is the full
    {!Trading_portfolio.Portfolio.t} so reconciler writers read it directly. *)
let _build_run_result t =
  let steps = List.rev t.step_history in
  let base_metrics =
    Simulator_metrics.compute_base ~computers:t.deps.metric_suite.computers
      ~config:t.config ~steps
  in
  let metrics =
    Simulator_metrics.compute_derived
      ~derived_computers:t.deps.metric_suite.derived ~config:t.config
      ~base_metrics
  in
  if !(t.valuation_failure_count) > 0 then
    eprintf
      "WARN: %d held-position price resolutions fell through to avg-cost \
       fallback (zero unrealized assumption). Run still produced a valid \
       portfolio_value series; review valuation_failure_count for cache \
       coverage gaps.\n\
       %!"
      !(t.valuation_failure_count);
  {
    steps;
    final_portfolio = t.portfolio;
    n_stop_eligible_positions = _count_stop_eligible t.positions;
    metrics;
  }

(** Apply split detection, update market state, record stale-held positions, and
    (when configured, default-off) force-exit stale/delisted positions at their
    last close. Returns the post-split / post-force-exit portfolio, positions,
    today's bars, split events, and the realised force-exit trades (merged into
    the step's [trades] by the caller; see {!Stale_exit_runner}). *)
let _prepare_market_state t =
  let split_events =
    Split_handler.detect_for_held_positions ~adapter:t.deps.market_data_adapter
      ~date:t.current_date ~portfolio:t.portfolio
  in
  let portfolio = Split_handler.apply_events t.portfolio split_events in
  let positions = Split_handler.apply_to_positions t.positions split_events in
  let today_bars = _get_today_bars t in
  if not (List.is_empty today_bars) then
    List.iter
      (Stale_hold.detect_stale ~adapter:t.deps.market_data_adapter
         ~date:t.current_date ~portfolio ~today_bars
         ~config:t.deps.stale_hold_policy)
      ~f:(Stale_hold.Log.record t.deps.stale_hold_log);
  let portfolio, positions, stale_exit_trades =
    Stale_exit_runner.tick ~adapter:t.deps.market_data_adapter
      ~config:t.deps.stale_hold_policy ~commission:t.config.commission
      ~date:t.current_date ~today_bars ~portfolio ~positions
  in
  Trading_engine.Engine.update_market t.deps.engine today_bars;
  (portfolio, positions, today_bars, split_events, stale_exit_trades)

(** Build the per-step [step_result]. Projection to the skinny
    [Portfolio_summary] mirrors Fix B from
    [dev/notes/15y-memory-cliff-2026-05-08.md]. *)
let _build_step_result t ~portfolio ~portfolio_value ~trades ~orders ~today_bars
    ~split_events =
  let portfolio_summary =
    Trading_simulation_types.Portfolio_summary.of_portfolio portfolio
      ~position_value_total:
        (portfolio_value
        -. Trading_portfolio.Portfolio_margin.equity_cash portfolio)
  in
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

(* Execute pending orders, apply fills, and route rejected fills through
   {!Cancel_handler}. Returns post-fill (portfolio, positions, accepted). *)
let _process_fills_and_cancels t ~portfolio ~positions =
  let open Result.Let_syntax in
  let%bind execution_reports =
    Trading_engine.Engine.process_orders t.deps.engine t.deps.order_manager
  in
  let all_trades = _extract_trades ~date:t.current_date execution_reports in
  let portfolio, trades, rejected_trades =
    Cancel_handler.apply_trades_best_effort ?on_trade_fill:t.deps.on_trade_fill
      ~initial_long_margin_req:t.deps.initial_long_margin_req portfolio
      all_trades
  in
  let%bind positions =
    Fill_router.update_positions_from_trades ~order_links:t.order_links
      ~date:t.current_date ~positions ~trades ()
  in
  let cancel_transitions =
    Cancel_handler.transitions_for_rejected_trades ~date:t.current_date
      ~positions ~rejected_trades
  in
  let%bind positions =
    _apply_transitions ~positions ~transitions:cancel_transitions
  in
  (* Exit-side mirror (#1553): an [Exiting] position whose exit fill was rejected
     would otherwise stay stuck forever (stops only re-evaluate [Holding]).
     Revert it to [Holding] so the stop re-fires next cycle. *)
  let positions =
    Cancel_handler.revert_rejected_exits ~date:t.current_date ~positions
      ~rejected_trades
  in
  Ok (portfolio, positions, trades)

(** Process one day: execute pending orders, call strategy, generate new orders,
    and assemble the [step_result]. Returns the next simulator state paired with
    this day's [step_result]. *)
let _process_step_day t ~portfolio ~positions ~today_bars ~split_events
    ~stale_exit_trades =
  let open Result.Let_syntax in
  let%bind portfolio, positions, fill_trades =
    _process_fills_and_cancels t ~portfolio ~positions
  in
  (* Surface the already-realised stale force-exits in this step's trades. *)
  let trades = stale_exit_trades @ fill_trades in
  let%bind strategy_transitions =
    _call_strategy { t with portfolio; positions }
  in
  let portfolio, transitions =
    Margin_runner.tick ~margin_config:t.deps.margin_config
      ~long_margin_rate_annual_pct:t.deps.long_margin_rate_annual_pct ~portfolio
      ~positions ~today_bars ~date:t.current_date ~strategy_transitions
  in
  let%bind positions = _apply_transitions ~positions ~transitions in
  let%bind orders, order_links =
    Order_generator.transitions_to_orders ~current_date:t.current_date
      ~positions transitions
  in
  (* Day orders: each generation pass replaces the in-flight link set. *)
  Hashtbl.clear t.order_links;
  List.iter order_links ~f:(fun (order_id, position_id) ->
      Hashtbl.set t.order_links ~key:order_id ~data:position_id);
  let portfolio_value =
    Portfolio_valuation.compute ~adapter:t.deps.market_data_adapter
      ~date:t.current_date ~portfolio ~today_bars
      ~last_known_prices:t.last_known_prices
      ~valuation_failure_count:t.valuation_failure_count
  in
  let step_result =
    _build_step_result t ~portfolio ~portfolio_value ~trades ~orders ~today_bars
      ~split_events
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
    let portfolio, positions, today_bars, split_events, stale_exit_trades =
      _prepare_market_state t
    in
    _process_step_day t ~portfolio ~positions ~today_bars ~split_events
      ~stale_exit_trades

let get_config t = t.config

let run t =
  let rec loop t =
    match step t with
    | Error e -> Error e
    | Ok (Completed result) -> Ok result
    | Ok (Stepped (t', _)) -> loop t'
  in
  loop t

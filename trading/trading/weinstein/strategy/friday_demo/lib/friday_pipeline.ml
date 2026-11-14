open Core
open Friday_trace
module WS = Weinstein_strategy
module WSC = WS.Weinstein_strategy_config
module WSM = WS.Weinstein_strategy_macro
module Bar_reader = WS.Bar_reader
module Audit_recorder = WS.Audit_recorder
module State = WS.Weinstein_strategy_state

type inputs = {
  config : WSC.config;
  bar_reader : Bar_reader.t;
  ticker_sectors : (string, string) Hashtbl.t;
  portfolio : Trading_strategy.Portfolio_view.t;
}

(* How many weekly closes the inputs stage shows per stock. *)
let _recent_weeks = 4

let price_on bar_reader date symbol =
  match
    List.last (Bar_reader.daily_bars_for bar_reader ~symbol ~as_of:date)
  with
  | Some (bar : Types.Daily_price.t) when Date.equal bar.date date -> Some bar
  | _ -> None

(* [Weinstein_strategy] re-declares the config record in its own signature, so
   its entry points typed against that record take the same config across its
   sexp. *)
let _strategy_config (c : WSC.config) : WS.config =
  WS.config_of_sexp (WSC.sexp_of_config c)

let strategy (i : inputs) ~state =
  WS.make_with_state ~ticker_sectors:i.ticker_sectors ~bar_reader:i.bar_reader
    ~state
    (_strategy_config i.config)

let _no_indicator _symbol _name _period _cadence = None

let warm_up (i : inputs) ~fridays =
  let state = State.init ~initial_stop_states:String.Map.empty in
  let (module S) = strategy i ~state in
  List.iter fridays ~f:(fun date ->
      match
        S.on_market_close
          ~get_price:(price_on i.bar_reader date)
          ~get_indicator:_no_indicator ~portfolio:i.portfolio
      with
      | Ok _ -> ()
      | Error e ->
          failwithf "warm-up on %s: %s" (Date.to_string date) (Status.show e) ());
  state

(* ------------------------------------------------------------------ *)
(* Stages 1-4, for display: copies of the state, the screen's functions *)
(* ------------------------------------------------------------------ *)

let _weekly_view (i : inputs) ~date symbol =
  Bar_reader.weekly_view_for i.bar_reader ~symbol ~n:i.config.lookback_bars
    ~as_of:date

let _last_closes (view : Snapshot_runtime.Snapshot_bar_views.weekly_view) =
  let len = min _recent_weeks view.n in
  Array.to_list (Array.sub view.closes ~pos:(view.n - len) ~len)

let _volume_ratio weekly =
  Volume.analyze_breakout_with_callbacks ~config:Volume.default_config
    ~callbacks:(WS.Panel_callbacks.volume_callbacks_of_weekly_view ~weekly)
    ~event_offset:0
  |> Option.map ~f:(fun (r : Volume.result) -> r.volume_ratio)

(* The two calls the screen's Phase 1 makes per stock. *)
let _classify (i : inputs) ~prior_stage ~weekly ticker =
  let callbacks =
    WS.Panel_callbacks.stage_callbacks_of_weekly_view
      ?ma_cache:(Bar_reader.ma_cache i.bar_reader)
      ~symbol:ticker ~config:i.config.stage_config ~weekly ()
  in
  Stage.classify_with_callbacks ~config:i.config.stage_config
    ~get_ma:callbacks.get_ma ~get_close:callbacks.get_close ~prior_stage

let _survivors ?sector_map (i : inputs) ~(state : State.t) ~date () =
  WS.survivors_for_screening ?sector_map
    ~config:(_strategy_config i.config)
    ~bar_reader:i.bar_reader
    ~prior_stages:(Hashtbl.copy state.prior_stages)
    ~current_date:date ()
  |> List.map ~f:(fun (ticker, _view, _stage) -> ticker)
  |> String.Set.of_list

let _ticker_row (i : inputs) ~(state : State.t) ~date ~staged ~analysed ticker :
    ticker_row =
  let weekly = _weekly_view i ~date ticker in
  let prior_stage = Hashtbl.find state.prior_stages ticker in
  {
    ticker;
    sector = Hashtbl.find i.ticker_sectors ticker;
    recent_closes = _last_closes weekly;
    volume_ratio = _volume_ratio weekly;
    prior_stage;
    stage = _classify i ~prior_stage ~weekly ticker;
    pre_screen =
      (if Set.mem analysed ticker then Analysed
       else if Set.mem staged ticker then Sector_blocked
       else Not_stage_2_or_4);
  }

let _sector_map (i : inputs) ~(state : State.t) ~date ~index_view
    ~ticker_sectors =
  WS.Macro_inputs.build_sector_map_of_snapshot_views
    ?ma_cache:(Bar_reader.ma_cache i.bar_reader)
    ~stage_config:i.config.stage_config ~lookback_bars:i.config.lookback_bars
    ~sector_etfs:i.config.sector_etfs
    ~cb:(Bar_reader.snapshot_callbacks i.bar_reader)
    ~as_of:date
    ~sector_prior_stages:(Hashtbl.copy state.sector_prior_stages)
    ~index_view ~ticker_sectors ()

(* Rate each ETF by mapping it to its own sector, so a sector shows up even
   when no stock in the universe belongs to it. *)
let _sector_rows (i : inputs) ~state ~date ~index_view =
  let etfs = Hashtbl.create (module String) in
  List.iter i.config.sector_etfs ~f:(fun (etf, sector_name) ->
      Hashtbl.set etfs ~key:etf ~data:sector_name);
  let by_etf = _sector_map i ~state ~date ~index_view ~ticker_sectors:etfs in
  List.map i.config.sector_etfs ~f:(fun (etf, sector_name) ->
      { sector_name; etf; context = Hashtbl.find by_etf etf })

let _display_stages (i : inputs) ~state ~date ~index_view =
  let sector_map =
    _sector_map i ~state ~date ~index_view ~ticker_sectors:i.ticker_sectors
  in
  let staged = _survivors i ~state ~date () in
  let analysed = _survivors ~sector_map i ~state ~date () in
  ( List.map i.config.universe ~f:(_ticker_row i ~state ~date ~staged ~analysed),
    _sector_rows i ~state ~date ~index_view )

(* ------------------------------------------------------------------ *)
(* Stages 3 and 5-9: the strategy's own Friday calls, read back         *)
(* ------------------------------------------------------------------ *)

let _macro (i : inputs) ~(state : State.t) ~date ~index_view =
  let ad_series =
    WS.Ad_series_cache.of_weekly_ad_bars
      ~momentum_period:
        i.config.macro_config.indicator_thresholds.momentum_period []
  in
  WSM.run_macro_only ~config:i.config ~ad_series ~prior_macro:state.prior_macro
    ~prior_macro_result:state.prior_macro_result ~bar_reader:i.bar_reader
    ~prior_stages:state.prior_stages ~current_date:date ~index_view ()

let _halted (state : State.t) =
  match
    Portfolio_risk.Force_liquidation.Peak_tracker.halt_state state.peak_tracker
  with
  | Halted -> true
  | Active -> false

let _screen (i : inputs) ~(state : State.t) ~date ~index_view ~macro
    ~audit_recorder =
  WSM.entry_transitions_if_active ~pending_entry_e:state.pending_entry_e
    ~suspended_tickets:state.suspended_tickets ~fold_start_date:None
    ~universe_membership_at:None ~halted:(_halted state) ~is_screening_day:true
    ~macro_result_opt:(Some macro) ~config:i.config
    ~stop_states:state.stop_states
    ~last_stop_out_dates:state.last_stop_out_dates ~bar_reader:i.bar_reader
    ~prior_stages:state.prior_stages
    ~sector_prior_stages:state.sector_prior_stages
    ~ticker_sectors:i.ticker_sectors
    ~get_price:(price_on i.bar_reader date)
    ~portfolio:i.portfolio ~current_date:date ~index_view ~audit_recorder

(* Run the screen with a recorder that keeps the cascade event and the entry
   events the strategy emits anyway. *)
let _screen_and_capture i ~state ~date ~index_view ~macro =
  let cascade = ref None in
  let entries = ref [] in
  let audit_recorder =
    {
      Audit_recorder.noop with
      capture_candidates = true;
      record_cascade_summary = (fun e -> cascade := Some e);
      record_entry = (fun e -> entries := e :: !entries);
    }
  in
  let transitions = _screen i ~state ~date ~index_view ~macro ~audit_recorder in
  (transitions, !cascade, List.rev !entries)

let _installed_stop ~(entries : Audit_recorder.entry_event list) position_id =
  List.find entries ~f:(fun e -> String.equal e.position_id position_id)
  |> Option.map ~f:(fun (e : Audit_recorder.entry_event) -> e.installed_stop)

let _order ~symbol ~side ~quantity ~trigger ~stop =
  { symbol; side; quantity; trigger; stop }

let _order_of ~entries (t : Trading_strategy.Position.transition) =
  let stop = _installed_stop ~entries t.position_id in
  match t.kind with
  | CreateEntering { symbol; side; target_quantity; entry_price; _ } ->
      Some
        (_order ~symbol ~side ~quantity:target_quantity ~trigger:entry_price
           ~stop)
  | _ -> None

let _setup (i : inputs) date =
  let portfolio_value =
    Trading_strategy.Portfolio_view.portfolio_value i.portfolio
      ~get_price:(price_on i.bar_reader date)
  in
  { date; config = i.config; cash = i.portfolio.cash; portfolio_value }

let _drops_and_decisions = function
  | Some (e : Audit_recorder.cascade_event) -> (e.drops, e.decisions)
  | None -> ([], [])

let run (i : inputs) ~state date : t =
  let index_view = _weekly_view i ~date i.config.indices.primary in
  let tickers, sectors = _display_stages i ~state ~date ~index_view in
  let macro = _macro i ~state ~date ~index_view in
  let transitions, cascade, entries =
    _screen_and_capture i ~state ~date ~index_view ~macro
  in
  let drops, decisions = _drops_and_decisions cascade in
  let walk =
    Friday_selection.walk_rows i.config ~bar_reader:i.bar_reader ~date ~macro
      ~cash:i.portfolio.cash ~entries decisions
  in
  {
    setup = _setup i date;
    tickers;
    macro;
    sectors;
    cascade = drops;
    ranking = Friday_selection.ranking i.config ~date ~walk drops;
    walk;
    orders = List.filter_map transitions ~f:(_order_of ~entries);
  }

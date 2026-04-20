(** Tiered loader_strategy path — see [tiered_runner.mli]. *)

open Core
open Trading_simulation

type input = {
  data_dir_fpath : Fpath.t;
  ticker_sectors : (string, string) Hashtbl.t;
  ad_bars : Macro.ad_bar list;
  config : Weinstein_strategy.config;
  all_symbols : string list;
}

let tier_op_to_phase (op : Bar_loader.tier_op) : Trace.Phase.t =
  match op with
  | Promote_to_summary -> Trace.Phase.Promote_summary
  | Promote_to_full -> Trace.Phase.Promote_full
  | Demote_op -> Trace.Phase.Demote

let _make_trace_hook ?trace () : Bar_loader.trace_hook =
  let record :
      'a. tier_op:Bar_loader.tier_op -> symbols:int -> (unit -> 'a) -> 'a =
   fun ~tier_op ~symbols f ->
    let phase = tier_op_to_phase tier_op in
    Trace.record ?trace ~symbols_in:symbols phase f
  in
  { record }

let _create_bar_loader (input : input) ?trace () =
  let trace_hook = _make_trace_hook ?trace () in
  Bar_loader.create ~data_dir:input.data_dir_fpath
    ~sector_map:input.ticker_sectors ~universe:input.all_symbols ~trace_hook ()

let _promote_universe_metadata loader (input : input) ~as_of =
  match
    Bar_loader.promote loader ~symbols:input.all_symbols
      ~to_:Bar_loader.Metadata_tier ~as_of
  with
  | Ok () -> ()
  | Error e ->
      (* A partial load is acceptable per [promote]'s contract, but a hard
         load error indicates a broken data directory — surface rather than
         silently miss. The Legacy path fails at the same logical moment. *)
      failwith
        (sprintf
           "Backtest.Tiered_runner: loader failed during Metadata promote: %s"
           (Status.show e))

(** [_full_candidate_limit config] caps how many Shadow_screener candidates the
    Tiered wrapper promotes to Full on a single Friday. Matches the inner
    screener's own post-rank cut so we don't Full-promote more than the strategy
    would consider. *)
let _full_candidate_limit (config : Weinstein_strategy.config) =
  config.screening_config.max_buy_candidates
  + config.screening_config.max_short_candidates

let _make_wrapper_config (input : input) ~loader ~stop_log :
    Tiered_strategy_wrapper.config =
  {
    bar_loader = loader;
    universe = input.all_symbols;
    screening_config = input.config.screening_config;
    full_candidate_limit = _full_candidate_limit input.config;
    stop_log;
    primary_index = input.config.indices.primary;
  }

let _make_simulator (input : input) ~loader ~stop_log ~start_date ~end_date
    ~warmup_days ~initial_cash ~commission =
  let inner_strategy =
    Weinstein_strategy.make ~ad_bars:input.ad_bars
      ~ticker_sectors:input.ticker_sectors input.config
  in
  let wrapper_config = _make_wrapper_config input ~loader ~stop_log in
  let strategy =
    Tiered_strategy_wrapper.wrap ~config:wrapper_config inner_strategy
  in
  let warmup_start = Date.add_days start_date (-warmup_days) in
  let metric_suite = Metric_computers.default_metric_suite () in
  let sim_deps =
    Simulator.create_deps ~symbols:input.all_symbols
      ~data_dir:input.data_dir_fpath ~strategy ~commission ~metric_suite ()
  in
  let sim_config =
    Simulator.
      {
        start_date = warmup_start;
        end_date;
        initial_cash;
        commission;
        strategy_cadence = Types.Cadence.Daily;
      }
  in
  match Simulator.create ~config:sim_config ~deps:sim_deps with
  | Ok s -> s
  | Error e ->
      failwith
        (sprintf "Backtest.Tiered_runner: failed to create simulator: %s"
           (Status.show e))

let _run_simulator sim =
  match Simulator.run sim with
  | Ok r -> r
  | Error e ->
      failwith
        (sprintf "Backtest.Tiered_runner: simulation failed: %s" (Status.show e))

let run ~input ~start_date ~end_date ~warmup_days ~initial_cash ~commission
    ?trace () =
  let loader = _create_bar_loader input ?trace () in
  let as_of = end_date in
  let n_all_symbols = List.length input.all_symbols in
  Trace.record ?trace ~symbols_in:n_all_symbols ~symbols_out:n_all_symbols
    Trace.Phase.Load_bars (fun () ->
      _promote_universe_metadata loader input ~as_of);
  let stats = Bar_loader.stats loader in
  eprintf
    "Tiered loader: Metadata=%d Summary=%d Full=%d after bulk Metadata promote\n\
     %!"
    stats.metadata stats.summary stats.full;
  let stop_log = Stop_log.create () in
  let sim =
    _make_simulator input ~loader ~stop_log ~start_date ~end_date ~warmup_days
      ~initial_cash ~commission
  in
  let sim_result =
    Trace.record ?trace ~symbols_in:n_all_symbols Trace.Phase.Fill (fun () ->
        _run_simulator sim)
  in
  let final_stats = Bar_loader.stats loader in
  eprintf
    "Tiered loader: Metadata=%d Summary=%d Full=%d at end of simulator run\n%!"
    final_stats.metadata final_stats.summary final_stats.full;
  (sim_result, stop_log)

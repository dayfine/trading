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
  (* Benchmark must match the Runner's primary index so Summary-tier RS line
     computation can find the benchmark's bars. Bar_loader's default "SPY" is
     not present in the parity fixtures (GSPC.INDX is the primary), so without
     this threading every Summary promote fails silently and the Friday cycle
     is a no-op on the parity scenario. *)
  Bar_loader.create ~data_dir:input.data_dir_fpath
    ~sector_map:input.ticker_sectors ~universe:input.all_symbols
    ~benchmark_symbol:input.config.indices.primary ~trace_hook ()

(** Max per-symbol Metadata-promote failure messages to emit on stderr before
    collapsing into a summary count. A universe where every symbol fails (e.g. a
    misconfigured [data_dir]) would otherwise spam N lines; capping here keeps
    logs useful without hiding the "many failures" signal. *)
let _max_logged_metadata_failures = 10

(** [_promote_one_metadata] single-symbol Metadata promote, returning either
    [None] on success or [Some (symbol, status)] on failure. Extracted so the
    outer loop in [promote_universe_metadata] stays a flat [List.filter_map]. *)
let _promote_one_metadata loader ~as_of symbol =
  match
    Bar_loader.promote loader ~symbols:[ symbol ] ~to_:Bar_loader.Metadata_tier
      ~as_of
  with
  | Ok () -> None
  | Error e -> Some (symbol, e)

(** [_log_metadata_failure (symbol, e)] — single-failure stderr line with the
    "continuing" marker that ops uses to distinguish tolerated missing-CSV
    failures from genuine bugs. *)
let _log_metadata_failure (symbol, e) =
  eprintf
    "Tiered_runner: metadata promote failed for %s: %s (continuing; \
     Legacy-equivalent missing-CSV tolerance)\n\
     %!"
    symbol (Status.show e)

(** [_log_metadata_failures failures ~n_total] — logs the first
    [_max_logged_metadata_failures] per-symbol messages, an ellipsis if the list
    exceeded the cap, and a "[n_failed] of [n_total]" summary line when any
    symbol failed. Side-effectful; no-op when [failures] is empty. *)
let _log_metadata_failures failures ~n_total =
  let n_failed = List.length failures in
  List.take failures _max_logged_metadata_failures
  |> List.iter ~f:_log_metadata_failure;
  if n_failed > _max_logged_metadata_failures then
    eprintf "Tiered_runner: ... and %d more metadata promote failures\n%!"
      (n_failed - _max_logged_metadata_failures);
  if n_failed > 0 then
    eprintf "Tiered_runner: %d of %d symbols failed metadata promote\n%!"
      n_failed n_total

(** Bulk-promote [input.all_symbols] to [Metadata_tier], tolerating per-symbol
    load failures to match Legacy's silent missing-CSV behaviour.

    [Bar_loader.promote]'s contract (see the docstring in [bar_loader.mli] on
    [val promote]) returns the first per-symbol error encountered, e.g. a single
    missing CSV causes [Error]. The Legacy path's simulator silently skips any
    symbol whose [data.csv] is absent, so a [failwith] here would introduce a
    real divergence: identical fixtures + identical universe would give Tiered a
    raise on first missing CSV while Legacy runs the backtest without that
    symbol.

    Implementation: iterate per-symbol with single-symbol [promote] calls so we
    can collect {e every} failure rather than stopping at the first. The
    Metadata tier does not fire the trace hook (see the [promote] match arm for
    [Metadata_tier] in [bar_loader.ml]), so per-symbol batching is
    observationally equivalent to the batch call at the tier / trace layer.

    Never raises on per-symbol failure. Never raises if every symbol fails, e.g.
    a misconfigured [data_dir] — the symmetry with Legacy (which would simply
    produce an empty backtest in that case) is the whole point. Callers can
    still observe the tier counts via [Bar_loader.stats] after return. *)
let promote_universe_metadata loader (input : input) ~as_of =
  let failures =
    List.filter_map input.all_symbols ~f:(_promote_one_metadata loader ~as_of)
  in
  _log_metadata_failures failures ~n_total:(List.length input.all_symbols)

(** [_full_candidate_limit config] caps how many Shadow_screener candidates the
    Tiered wrapper promotes to Full on a single Friday. Matches the inner
    screener's own post-rank cut so we don't Full-promote more than the strategy
    would consider. *)
let _full_candidate_limit (config : Weinstein_strategy.config) =
  config.screening_config.max_buy_candidates
  + config.screening_config.max_short_candidates

(** [_always_loaded_symbols config] — the symbols whose [get_price] is passed
    through unconditionally by the Tiered wrapper's throttle: the primary index
    (day-of-week detection + benchmark), every sector ETF (sector map
    construction on Fridays), and every global index (global consensus
    indicator). At most a dozen symbols — none contribute meaningful memory
    pressure. *)
let _always_loaded_symbols (config : Weinstein_strategy.config) =
  let sector_etf_symbols = List.map config.sector_etfs ~f:fst in
  let global_index_symbols = List.map config.indices.global ~f:fst in
  String.Set.of_list
    ((config.indices.primary :: sector_etf_symbols) @ global_index_symbols)

let _make_wrapper_config (input : input) ~loader ~bar_history ~warmup_start
    ~stop_log : Tiered_strategy_wrapper.config =
  {
    bar_loader = loader;
    bar_history;
    universe = input.all_symbols;
    always_loaded_symbols = _always_loaded_symbols input.config;
    screening_config = input.config.screening_config;
    full_candidate_limit = _full_candidate_limit input.config;
    seed_warmup_start = warmup_start;
    stop_log;
    primary_index = input.config.indices.primary;
  }

let _make_simulator (input : input) ~loader ~stop_log ~start_date ~end_date
    ~warmup_days ~initial_cash ~commission =
  (* Allocate a shared Bar_history — passed to the inner strategy (so it reads
     from and writes into this buffer instead of a fresh one) and to the
     wrapper (so the wrapper can seed it from loader Full bars on promotion).
     This is the integration seam Option b-seed relies on. *)
  let bar_history = Weinstein_strategy.Bar_history.create () in
  let warmup_start = Date.add_days start_date (-warmup_days) in
  let inner_strategy =
    Weinstein_strategy.make ~ad_bars:input.ad_bars
      ~ticker_sectors:input.ticker_sectors ~bar_history input.config
  in
  let wrapper_config =
    _make_wrapper_config input ~loader ~bar_history ~warmup_start ~stop_log
  in
  let strategy =
    Tiered_strategy_wrapper.wrap ~config:wrapper_config inner_strategy
  in
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
      promote_universe_metadata loader input ~as_of);
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

(** Tiered loader_strategy path — see [tiered_runner.mli]. *)

open Core

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

let run ~(input : input) ~start_date:_ ~end_date ~warmup_days:_ ~initial_cash:_
    ~commission:_ ?trace () =
  let loader = _create_bar_loader input ?trace () in
  (* Bulk-promote at the backtest end date. The Metadata-tier semantics are
     "last close on or before as_of" — for the pre-simulator bootstrap this
     is the most information-rich snapshot the loader can hold without
     walking the timeline. 3f-part3b will re-promote per-symbol at each
     simulator step [as_of = current bar date]. *)
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
  failwith
    "Backtest.Tiered_runner: simulator-cycle step not yet implemented (lands \
     in 3f-part3b of the backtest-tiered-loader plan). The pre-simulator \
     Metadata promote succeeded and emitted its Load_bars trace phase, so the \
     trace up to this point is usable for debugging. Pass \
     loader_strategy=Legacy or omit the argument to run the existing path."

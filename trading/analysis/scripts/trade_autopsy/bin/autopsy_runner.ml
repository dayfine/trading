(** autopsy_runner — driver for the trade-autopsy diagnostic.

    Re-runs {!Per_symbol_stage_strategy_lib.Single_symbol_backtest} for the
    canonical 12-symbol panel over 1998-01-01 → 2025-12-31, feeds each symbol's
    [(weekly_bars, trades)] tuple through
    {!Trade_autopsy_lib.Trade_autopsy.classify_trades}, and writes:

    - [autopsy.sexp] — structured per-trade autopsy records + per-symbol
      breakdowns + aggregate mode summary, suitable for downstream OCaml
      consumption.
    - The Markdown report to stdout (caller redirects to
      [dev/notes/trade-autopsy-<date>.md]).

    All thresholds come from {!Trade_autopsy_lib.Trade_autopsy_config.default}
    unless the [-config-overrides] flag is used. *)

open Core
module Backtest = Per_symbol_stage_strategy_lib.Single_symbol_backtest
module Signal = Per_symbol_stage_strategy_lib.Stage_signal
module Walk_step = Per_symbol_stage_strategy_lib.Walk_step
module Autopsy = Trade_autopsy_lib.Trade_autopsy
module Config = Trade_autopsy_lib.Trade_autopsy_config

(* Canonical 12-symbol panel from dispatch brief 2026-05-29. *)
let _default_symbols =
  [
    "SPY";
    "XLK";
    "XLF";
    "XLI";
    "XLV";
    "XLE";
    "XLP";
    "XLY";
    "XLU";
    "XLB";
    "XLRE";
    "XLC";
  ]

let _initial_cash = 1_000_000.0

(* ------------------------------------------------------------------ *)
(* Weekly bar loading (replicates Single_symbol_backtest internals)   *)
(* ------------------------------------------------------------------ *)

(* The strategy module's [run] returns trades but NOT the weekly bar
   series. We load the bars separately so we can pass them to the autopsy
   classifier. Same daily→weekly conversion the strategy used. *)
let _load_weekly_bars ~data_dir ~symbol ~end_date =
  let open Result.Let_syntax in
  let%bind storage = Csv.Csv_storage.create ~data_dir symbol in
  let%bind daily = Csv.Csv_storage.get storage ~end_date () in
  Ok (Time_period.Conversion.daily_to_weekly ~include_partial_week:false daily)

(* ------------------------------------------------------------------ *)
(* Per-symbol run                                                      *)
(* ------------------------------------------------------------------ *)

type _symbol_run = {
  symbol : string;
  trades : Walk_step.trade list;
  weekly_bars : Types.Daily_price.t list;
  autopsies : Autopsy.trade_autopsy list;
  breakdown : Autopsy.per_symbol_breakdown;
}

let _run_one_symbol ~data_dir ~start_date ~end_date ~config symbol =
  let open Result.Let_syntax in
  let%bind backtest_result =
    Backtest.run ~data_dir ~symbol ~start_date ~end_date
      ~initial_cash:_initial_cash ~variant:Signal.Long_only ()
  in
  let%bind weekly_bars = _load_weekly_bars ~data_dir ~symbol ~end_date in
  let in_window =
    List.filter weekly_bars ~f:(fun b ->
        Date.( >= ) b.Types.Daily_price.date start_date)
  in
  let autopsies =
    Autopsy.classify_trades ~config ~symbol ~weekly_bars:in_window
      ~trades:backtest_result.trades
  in
  let breakdown = Autopsy.breakdown_for_symbol ~symbol autopsies in
  Ok
    {
      symbol;
      trades = backtest_result.trades;
      weekly_bars = in_window;
      autopsies;
      breakdown;
    }

(* Markdown rendering lives in {!Autopsy_report} — a sibling module in this
   same [bin/] directory, kept out of this file to hold [autopsy_runner.ml]
   under the file-length soft limit. *)

(* ------------------------------------------------------------------ *)
(* Sexp output                                                         *)
(* ------------------------------------------------------------------ *)

let _autopsies_sexp_of_run r =
  Sexp.List (List.map r.autopsies ~f:Autopsy.sexp_of_trade_autopsy)

let _run_sexp r =
  Sexp.List
    [
      Sexp.Atom r.symbol;
      Autopsy.sexp_of_per_symbol_breakdown r.breakdown;
      _autopsies_sexp_of_run r;
    ]

let _aggregate_sexp aggregate_summary =
  Sexp.List
    [
      Sexp.Atom "aggregate_summary";
      Sexp.List (List.map aggregate_summary ~f:Autopsy.sexp_of_mode_summary);
    ]

let _structured_output ~runs ~aggregate_summary =
  let per_symbol_sexp = List.map runs ~f:_run_sexp in
  Sexp.List
    [
      _aggregate_sexp aggregate_summary;
      Sexp.List [ Sexp.Atom "per_symbol"; Sexp.List per_symbol_sexp ];
    ]

let _write_sexp ~out_path sexp =
  Out_channel.with_file out_path ~f:(fun oc ->
      Out_channel.output_string oc (Sexp.to_string_hum sexp))

(* ------------------------------------------------------------------ *)
(* CLI                                                                 *)
(* ------------------------------------------------------------------ *)

(* Try to run a single symbol; print the error (if any) and turn it into an
   Option so [List.filter_map] can drop failed symbols. *)
let _try_run_symbol ~data_dir_fp ~start_date ~end_date ~config sym =
  match
    _run_one_symbol ~data_dir:data_dir_fp ~start_date ~end_date ~config sym
  with
  | Ok r -> Some r
  | Error e ->
      eprintf "skipping %s: %s\n%!" sym (Status.show e);
      None

let _maybe_write_sexp ~out_sexp ~runs ~aggregate_summary =
  match out_sexp with
  | None -> ()
  | Some path ->
      _write_sexp ~out_path:path (_structured_output ~runs ~aggregate_summary)

let _emit_report ~start_date ~end_date ~runs ~aggregate_summary ~out_sexp =
  _maybe_write_sexp ~out_sexp ~runs ~aggregate_summary;
  let breakdowns = List.map runs ~f:(fun r -> r.breakdown) in
  let autopsies = List.concat_map runs ~f:(fun r -> r.autopsies) in
  print_endline
    (Autopsy_report.render ~start_date ~end_date ~breakdowns ~aggregate_summary
       ~autopsies)

let _execute ~data_dir ~start_date ~end_date ~symbols ~out_sexp =
  let config = Config.default in
  let data_dir_fp = Fpath.v data_dir in
  let runs =
    List.filter_map symbols
      ~f:(_try_run_symbol ~data_dir_fp ~start_date ~end_date ~config)
  in
  if List.is_empty runs then
    failwith "No symbols completed — nothing to report."
  else
    let all_autopsies = List.concat_map runs ~f:(fun r -> r.autopsies) in
    let aggregate_summary = Autopsy.summarize all_autopsies in
    _emit_report ~start_date ~end_date ~runs ~aggregate_summary ~out_sexp

let _cmd =
  Command.basic
    ~summary:
      "Trade-autopsy classifier — gain-capture failure-mode breakdown for the \
       per-symbol Weinstein stage strategy"
    (let%map_open.Command data_dir =
       flag "-data-dir" (required string)
         ~doc:
           "PATH Root of the daily-price CSV shard tree (e.g. \
            /workspaces/trading-1/data)"
     and start_date =
       flag "-start"
         (optional_with_default (Date.of_string "1998-01-01") date)
         ~doc:"DATE Inclusive run start (default 1998-01-01)"
     and end_date =
       flag "-end"
         (optional_with_default (Date.of_string "2025-12-31") date)
         ~doc:"DATE Inclusive run end (default 2025-12-31)"
     and symbols_arg =
       flag "-symbols" (optional string)
         ~doc:
           "CSV Comma-separated symbol list (default SPY + 11 SPDR sector ETFs)"
     and out_sexp =
       flag "-out-sexp" (optional string)
         ~doc:
           "PATH Write structured autopsy.sexp to this path (default: do not \
            write)"
     in
     fun () ->
       let symbols =
         match symbols_arg with
         | None -> _default_symbols
         | Some s -> String.split s ~on:',' |> List.map ~f:String.strip
       in
       _execute ~data_dir ~start_date ~end_date ~symbols ~out_sexp)

let () = Command_unix.run _cmd

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

(* ------------------------------------------------------------------ *)
(* Markdown rendering                                                  *)
(* ------------------------------------------------------------------ *)

let _fmt_pct v = sprintf "%+7.2f%%" (v *. 100.0)
let _fmt_pct_abs v = sprintf "%6.2f%%" (Float.abs v *. 100.0)

(* Per-symbol failure-mode row: symbol | # trades | stage3_fp missed | late
   reentry missed | late stage2 missed | stop_out_whipsaw missed. *)
let _render_breakdown_row (b : Autopsy.per_symbol_breakdown) =
  sprintf "| %s | %d | %s | %s | %s | %s |" b.symbol b.num_trades
    (_fmt_pct b.stage3_false_positive_missed_gain)
    (_fmt_pct b.late_reentry_missed_gain)
    (_fmt_pct b.late_stage2_admission_missed_gain)
    (_fmt_pct b.stop_out_whipsaw_missed_gain)

let _render_breakdown_table breakdowns =
  let header =
    "| Symbol | # trades | Stage3 false-positive total | Late re-entry total | \
     Late Stage2 admission total | Stop-out whipsaw total |"
  in
  let divider = "|---|---|---|---|---|---|" in
  let rows = List.map breakdowns ~f:_render_breakdown_row in
  String.concat ~sep:"\n" (header :: divider :: rows)

let _render_aggregate_row (s : Autopsy.mode_summary) =
  sprintf "| %s | %d | %s | %s |" s.mode_name s.trade_count
    (_fmt_pct s.total_missed_gain_pct)
    (_fmt_pct s.avg_missed_gain_pct)

let _render_aggregate_table summary =
  let header =
    "| Failure mode | # trades flagged | Total missed gain | Avg missed gain \
     (per flagged trade) |"
  in
  let divider = "|---|---|---|---|" in
  let rows = List.map summary ~f:_render_aggregate_row in
  String.concat ~sep:"\n" (header :: divider :: rows)

(* Exit-reason histogram across all autopsies — a sanity check the autopsy
   schema covers the input strategy's exit mechanics. *)
let _exit_reason_label = function
  | Autopsy.Stage3_exit -> "Stage3_exit"
  | Stage1_cover_short -> "Stage1_cover_short"
  | End_of_period -> "End_of_period"
  | Stop_out -> "Stop_out"
  | Stage4_decline -> "Stage4_decline"
  | Laggard_rotation -> "Laggard_rotation"

let _render_exit_reason_histogram autopsies =
  let table =
    List.fold autopsies
      ~init:(Map.empty (module String))
      ~f:(fun acc a ->
        let key = _exit_reason_label a.Autopsy.exit_reason in
        Map.update acc key ~f:(function None -> 1 | Some n -> n + 1))
  in
  let rows =
    Map.to_alist table |> List.map ~f:(fun (k, v) -> sprintf "| %s | %d |" k v)
  in
  String.concat ~sep:"\n" ("| Exit reason | Count |" :: "|---|---|" :: rows)

let _render_report ~start_date ~end_date ~runs ~aggregate_summary =
  let breakdowns = List.map runs ~f:(fun r -> r.breakdown) in
  let breakdown_table = _render_breakdown_table breakdowns in
  let aggregate_table = _render_aggregate_table aggregate_summary in
  let all_autopsies = List.concat_map runs ~f:(fun r -> r.autopsies) in
  let exit_histogram = _render_exit_reason_histogram all_autopsies in
  let intro =
    sprintf
      "Per-symbol Weinstein stage strategy: %d trades over %d symbols × (%s to \
       %s). Failure modes classified per\n\
       [dev/notes/next-session-priorities-2026-05-29.md] §P3. Thresholds: \
       Stage 3 recovery ≥ 5%% within 12 weeks; late re-entry > 8 weeks AND \
       missed gain ≥ 10%%; late Stage-2 admission > 8 weeks past prior \
       cyclical low (12-week lookback); stop-out whipsaw 4 weeks / 5%% (inert \
       under this strategy)."
      (List.length all_autopsies)
      (List.length runs)
      (Date.to_string start_date)
      (Date.to_string end_date)
  in
  String.concat ~sep:"\n\n"
    [
      sprintf "# Trade autopsy — %s to %s"
        (Date.to_string start_date)
        (Date.to_string end_date);
      intro;
      "## Per-symbol failure-mode breakdown";
      "Each cell is the SUM of [missed_gain_pct] across trades for that symbol \
       that the failure-mode flag matched. Positive values = missed upside \
       (strategy exited too early or admitted too late). Modes are INDEPENDENT \
       classifications — one trade can flag more than one mode.";
      breakdown_table;
      "## Aggregate ranking";
      "Total missed gain across all 12 symbols × 27y. The mode with the \
       largest [Total missed gain] dominates and is the priority candidate for \
       a targeted fix.";
      aggregate_table;
      "## Exit-reason histogram (sanity check)";
      "Distribution of exit reasons across all classified trades. Should be \
       dominated by [Stage3_exit] (canonical Stage 2→3 transition) with a \
       small [End_of_period] tail (one per symbol whose window closes with an \
       open position). [Stop_out], [Stage4_decline], and [Laggard_rotation] \
       should all be ZERO under this strategy.";
      exit_histogram;
    ]

(* ------------------------------------------------------------------ *)
(* Sexp output                                                         *)
(* ------------------------------------------------------------------ *)

let _structured_output ~runs ~aggregate_summary =
  let per_symbol =
    List.map runs ~f:(fun r ->
        ( r.symbol,
          r.breakdown,
          List.map r.autopsies ~f:(fun a -> Autopsy.sexp_of_trade_autopsy a)
          |> Sexp.List ))
  in
  let per_symbol_sexp =
    List.map per_symbol ~f:(fun (sym, brk, autopsies_sexp) ->
        Sexp.List
          [
            Sexp.Atom sym;
            Autopsy.sexp_of_per_symbol_breakdown brk;
            autopsies_sexp;
          ])
  in
  Sexp.List
    [
      Sexp.List
        [
          Sexp.Atom "aggregate_summary";
          Sexp.List (List.map aggregate_summary ~f:Autopsy.sexp_of_mode_summary);
        ];
      Sexp.List [ Sexp.Atom "per_symbol"; Sexp.List per_symbol_sexp ];
    ]

let _write_sexp ~out_path sexp =
  Out_channel.with_file out_path ~f:(fun oc ->
      Out_channel.output_string oc (Sexp.to_string_hum sexp))

(* ------------------------------------------------------------------ *)
(* CLI                                                                 *)
(* ------------------------------------------------------------------ *)

let _execute ~data_dir ~start_date ~end_date ~symbols ~out_sexp =
  let config = Config.default in
  let data_dir_fp = Fpath.v data_dir in
  let runs =
    List.filter_map symbols ~f:(fun sym ->
        match
          _run_one_symbol ~data_dir:data_dir_fp ~start_date ~end_date ~config
            sym
        with
        | Ok r -> Some r
        | Error e ->
            eprintf "skipping %s: %s\n%!" sym (Status.show e);
            None)
  in
  if List.is_empty runs then
    failwith "No symbols completed — nothing to report."
  else
    let all_autopsies = List.concat_map runs ~f:(fun r -> r.autopsies) in
    let aggregate_summary = Autopsy.summarize all_autopsies in
    (match out_sexp with
    | None -> ()
    | Some path ->
        _write_sexp ~out_path:path (_structured_output ~runs ~aggregate_summary));
    print_endline
      (_render_report ~start_date ~end_date ~runs ~aggregate_summary)

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

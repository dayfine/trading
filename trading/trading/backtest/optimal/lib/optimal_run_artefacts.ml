open Core

(* --------------------------------------------------------------- *)
(* On-disk sexp shapes                                              *)
(* --------------------------------------------------------------- *)

type _actual_sexp_shape = {
  total_return_pct : float;
  total_trades : float;
  win_rate : float;
  sharpe_ratio : float;
  max_drawdown_pct : float;
  avg_holding_days : float;
  unrealized_pnl : float;
}
[@@deriving sexp] [@@sexp.allow_extra_fields]
(** Mirrors [Backtest.Scenarios.Scenario_runner.actual] — re-declared locally so
    we can [@@deriving sexp] over the same field set. *)

type _summary_sexp_shape = {
  start_date : Date.t;
  end_date : Date.t;
  universe_size : int;
  initial_cash : float;
  final_portfolio_value : float;
}
[@@deriving sexp] [@@sexp.allow_extra_fields]
(** Mirrors [Backtest.Summary.t]'s on-disk fields. [allow_extra_fields]
    tolerates the [metrics] / [n_steps] / [n_round_trips] fields we don't
    consume here. *)

(* --------------------------------------------------------------- *)
(* Per-file loaders                                                 *)
(* --------------------------------------------------------------- *)

let _load_actual_sexp ~output_dir : _actual_sexp_shape =
  let path = Filename.concat output_dir "actual.sexp" in
  if not (Sys_unix.file_exists_exn path) then
    failwithf "Missing actual.sexp at %s" path ();
  _actual_sexp_shape_of_sexp (Sexp.load_sexp path)

let _load_summary_sexp ~output_dir : _summary_sexp_shape =
  let path = Filename.concat output_dir "summary.sexp" in
  if not (Sys_unix.file_exists_exn path) then
    failwithf "Missing summary.sexp at %s" path ();
  _summary_sexp_shape_of_sexp (Sexp.load_sexp path)

(** Parse one trades.csv line. Format set by [Backtest.Result_writer]:
    [symbol,entry_date,exit_date,days_held,entry_price,exit_price,quantity,
     pnl_dollars,pnl_percent,entry_stop,exit_stop,exit_trigger]. Columns after
    [pnl_percent] are read but discarded — the renderer only consumes the first
    9. *)
let _parse_trade_row line : Trading_simulation.Metrics.trade_metrics option =
  match String.split line ~on:',' with
  | symbol :: entry_date :: exit_date :: days_held :: entry_price :: exit_price
    :: quantity :: pnl_dollars :: pnl_percent :: _stop_fields -> (
      try
        Some
          {
            symbol;
            entry_date = Date.of_string entry_date;
            exit_date = Date.of_string exit_date;
            days_held = Int.of_string days_held;
            entry_price = Float.of_string entry_price;
            exit_price = Float.of_string exit_price;
            quantity = Float.of_string quantity;
            pnl_dollars = Float.of_string pnl_dollars;
            pnl_percent = Float.of_string pnl_percent;
          }
      with exn ->
        eprintf "optimal_strategy: skipping malformed trade row (%s)\n%!"
          (Exn.to_string exn);
        None)
  | _ -> None

let _load_trades ~output_dir : Trading_simulation.Metrics.trade_metrics list =
  let path = Filename.concat output_dir "trades.csv" in
  if not (Sys_unix.file_exists_exn path) then []
  else
    let lines = In_channel.read_lines path in
    match lines with
    | [] -> []
    | _header :: rows -> List.filter_map rows ~f:_parse_trade_row

(** Harvest one [(symbol, reason)] pair per alternative-skip across the audit.
    Renders the [skip_reason] variant via its sexp atom name. Renderer attaches
    these inline against missed-trade rows; missing audit ⇒ empty list ⇒ rows
    render without reason annotations. *)
let _load_cascade_rejections ~output_dir : (string * string) list =
  let path = Filename.concat output_dir "trade_audit.sexp" in
  if not (Sys_unix.file_exists_exn path) then []
  else
    try
      let blob =
        Backtest.Trade_audit.audit_blob_of_sexp (Sexp.load_sexp path)
      in
      List.concat_map blob.audit_records
        ~f:(fun (rec_ : Backtest.Trade_audit.audit_record) ->
          List.map rec_.entry.alternatives_considered
            ~f:(fun (alt : Backtest.Trade_audit.alternative_candidate) ->
              let reason =
                Sexp.to_string
                  (Backtest.Trade_audit.sexp_of_skip_reason alt.reason_skipped)
              in
              (alt.symbol, reason)))
    with exn ->
      eprintf "optimal_strategy: failed to read trade_audit.sexp (%s)\n%!"
        (Exn.to_string exn);
      []

(* --------------------------------------------------------------- *)
(* Public bundle                                                    *)
(* --------------------------------------------------------------- *)

type actual_run_inputs = {
  scenario_name : string;
  start_date : Date.t;
  end_date : Date.t;
  universe_size : int;
  initial_cash : float;
  final_portfolio_value : float;
  trades : Trading_simulation.Metrics.trade_metrics list;
  cascade_rejections : (string * string) list;
  win_rate_pct : float;
  sharpe_ratio : float;
  max_drawdown_pct : float;
}

let _scenario_name_of_dir dir =
  let basename = Filename.basename dir in
  if String.is_empty basename then dir else basename

let load ~output_dir : actual_run_inputs =
  let actual = _load_actual_sexp ~output_dir in
  let summary = _load_summary_sexp ~output_dir in
  let trades = _load_trades ~output_dir in
  let cascade_rejections = _load_cascade_rejections ~output_dir in
  {
    scenario_name = _scenario_name_of_dir output_dir;
    start_date = summary.start_date;
    end_date = summary.end_date;
    universe_size = summary.universe_size;
    initial_cash = summary.initial_cash;
    final_portfolio_value = summary.final_portfolio_value;
    trades;
    cascade_rejections;
    win_rate_pct = actual.win_rate;
    sharpe_ratio = actual.sharpe_ratio;
    max_drawdown_pct = actual.max_drawdown_pct;
  }

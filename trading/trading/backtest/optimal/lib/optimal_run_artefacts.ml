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

(** Parse the [side] column. [Backtest.Result_writer] emits [LONG] for a
    Buy→Sell round-trip and [SHORT] for a Sell→Buy round-trip. The
    [trade_metrics.side] field stores the entry-leg side, so [LONG]→[Buy] and
    [SHORT]→[Sell]. Any unknown label falls back to [Buy] to keep parsing
    permissive against pre-G2 trades.csv files that omit the column. *)
let _parse_side = function
  | "LONG" -> Trading_base.Types.Buy
  | "SHORT" -> Trading_base.Types.Sell
  | _ -> Trading_base.Types.Buy

(** Build a [trade_metrics] from already-parsed string cells. Common builder
    shared by the post-G2 [(symbol, side, …)] layout and the legacy
    [(symbol, …)] layout, so adding new columns in one place doesn't require
    chasing two parser branches. *)
let _trade_metrics_of_strings ~symbol ~side ~entry_date ~exit_date ~days_held
    ~entry_price ~exit_price ~quantity ~pnl_dollars ~pnl_percent :
    Trading_simulation.Metrics.trade_metrics =
  {
    symbol;
    side = _parse_side side;
    entry_date = Date.of_string entry_date;
    exit_date = Date.of_string exit_date;
    days_held = Int.of_string days_held;
    entry_price = Float.of_string entry_price;
    exit_price = Float.of_string exit_price;
    quantity = Float.of_string quantity;
    pnl_dollars = Float.of_string pnl_dollars;
    pnl_percent = Float.of_string pnl_percent;
  }

(** Match a post-G2 row layout ([symbol,side,…] with [side] = [LONG]/[SHORT]).
    Returns [None] when [cells] doesn't have the post-G2 column count or the
    second cell isn't a valid side tag. *)
let _match_post_g2_row cells : Trading_simulation.Metrics.trade_metrics option =
  match cells with
  | symbol
    :: ("LONG" as side)
    :: entry_date :: exit_date :: days_held :: entry_price :: exit_price
    :: quantity :: pnl_dollars :: pnl_percent :: _stop_fields
  | symbol
    :: ("SHORT" as side)
    :: entry_date :: exit_date :: days_held :: entry_price :: exit_price
    :: quantity :: pnl_dollars :: pnl_percent :: _stop_fields ->
      Some
        (_trade_metrics_of_strings ~symbol ~side ~entry_date ~exit_date
           ~days_held ~entry_price ~exit_price ~quantity ~pnl_dollars
           ~pnl_percent)
  | _ -> None

(** Match a legacy (pre-G2) row layout: [symbol,entry_date,…]. Defaults [side]
    to [Buy] preserving the historical long-only semantics. *)
let _match_legacy_row cells : Trading_simulation.Metrics.trade_metrics option =
  match cells with
  | symbol :: entry_date :: exit_date :: days_held :: entry_price :: exit_price
    :: quantity :: pnl_dollars :: pnl_percent :: _stop_fields ->
      Some
        (_trade_metrics_of_strings ~symbol ~side:"LONG" ~entry_date ~exit_date
           ~days_held ~entry_price ~exit_price ~quantity ~pnl_dollars
           ~pnl_percent)
  | _ -> None

(** Parse one trades.csv line. Tolerates the post-G2 [(symbol,side,…)] layout
    and the legacy [(symbol,…)] layout — see {!_match_post_g2_row} and
    {!_match_legacy_row}. Conversion exceptions surface as a warning + [None].
*)
let _parse_trade_row line : Trading_simulation.Metrics.trade_metrics option =
  let cells = String.split line ~on:',' in
  try
    match _match_post_g2_row cells with
    | Some _ as t -> t
    | None -> _match_legacy_row cells
  with exn ->
    eprintf "optimal_strategy: skipping malformed trade row (%s)\n%!"
      (Exn.to_string exn);
    None

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

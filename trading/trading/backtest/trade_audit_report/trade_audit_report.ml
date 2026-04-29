(** Trade-audit markdown renderer. See [.mli] for the contract. *)

open Core
module TA = Backtest.Trade_audit
module Stop_log = Backtest.Stop_log

module Trade_audit_ratings = Trade_audit_ratings
(** Re-export the per-trade-rating + analysis library so external callers can
    reach it via [Trade_audit_report.Trade_audit_ratings]. The library wrap
    suppresses the auto-generated alias when a same-named entry module exists,
    so we re-export here explicitly. *)

(* Types ------------------------------------------------------------------ *)

type scenario_header = {
  scenario_name : string option;
  period_start : Date.t option;
  period_end : Date.t option;
  universe_size : int option;
  total_round_trips : int;
  winners : int;
  losers : int;
  win_rate_pct : float;
  total_realized_return_pct : float;
}
[@@deriving sexp]

type best_worst = {
  best : (string * Date.t * float) option;
  worst : (string * Date.t * float) option;
}
[@@deriving sexp]

type per_trade_row = {
  symbol : string;
  entry_date : Date.t;
  exit_date : Date.t;
  days_held : int;
  side : Trading_base.Types.position_side;
  entry_price : float;
  exit_price : float;
  pnl_dollars : float;
  pnl_percent : float;
  exit_trigger : string;
  entry_stage : Weinstein_types.stage option;
  entry_rs_trend : Weinstein_types.rs_trend option;
  entry_macro_trend : Weinstein_types.market_trend option;
  cascade_grade : Weinstein_types.grade option;
  cascade_score : int option;
}
[@@deriving sexp]

type analysis = {
  ratings : Trade_audit_ratings.rating list;
  behavioral : Trade_audit_ratings.behavioral_metrics;
  weinstein : Trade_audit_ratings.weinstein_aggregate;
  decision_quality : Trade_audit_ratings.decision_quality_matrix;
}
[@@deriving sexp]

type t = {
  header : scenario_header;
  best_worst : best_worst;
  rows : per_trade_row list;
  analysis : analysis option;
}
[@@deriving sexp]

(* Render ----------------------------------------------------------------- *)

let _audit_index audit =
  List.fold audit
    ~init:(Map.empty (module String))
    ~f:(fun acc (record : TA.audit_record) ->
      let key =
        record.entry.symbol ^ "|" ^ Date.to_string record.entry.entry_date
      in
      Map.set acc ~key ~data:record)

let _exit_trigger_label (trigger : Stop_log.exit_trigger) =
  match trigger with
  | Stop_loss _ -> "stop_loss"
  | Take_profit _ -> "take_profit"
  | Signal_reversal _ -> "signal_reversal"
  | Time_expired _ -> "time_expired"
  | Underperforming _ -> "underperforming"
  | Portfolio_rebalancing -> "rebalancing"

let _row_of_trade audit_idx (trade : Trading_simulation.Metrics.trade_metrics) :
    per_trade_row =
  let key = trade.symbol ^ "|" ^ Date.to_string trade.entry_date in
  let audit = Map.find audit_idx key in
  let entry = Option.map audit ~f:(fun (r : TA.audit_record) -> r.entry) in
  let exit_ = Option.bind audit ~f:(fun (r : TA.audit_record) -> r.exit_) in
  let side =
    Option.value_map entry ~default:Trading_base.Types.Long ~f:(fun e -> e.side)
  in
  let exit_trigger =
    match exit_ with Some e -> _exit_trigger_label e.exit_trigger | None -> ""
  in
  {
    symbol = trade.symbol;
    entry_date = trade.entry_date;
    exit_date = trade.exit_date;
    days_held = trade.days_held;
    side;
    entry_price = trade.entry_price;
    exit_price = trade.exit_price;
    pnl_dollars = trade.pnl_dollars;
    pnl_percent = trade.pnl_percent;
    exit_trigger;
    entry_stage = Option.map entry ~f:(fun e -> e.stage);
    entry_rs_trend = Option.bind entry ~f:(fun e -> e.rs_trend);
    entry_macro_trend = Option.map entry ~f:(fun e -> e.macro_trend);
    cascade_grade = Option.map entry ~f:(fun e -> e.cascade_grade);
    cascade_score = Option.map entry ~f:(fun e -> e.cascade_score);
  }

let _compare_rows (a : per_trade_row) (b : per_trade_row) =
  match Date.compare a.entry_date b.entry_date with
  | 0 -> String.compare a.symbol b.symbol
  | c -> c

let _compute_best_worst (rows : per_trade_row list) : best_worst =
  let to_triple (r : per_trade_row) = (r.symbol, r.entry_date, r.pnl_percent) in
  match rows with
  | [] -> { best = None; worst = None }
  | _ ->
      let best =
        List.max_elt rows ~compare:(fun a b ->
            Float.compare a.pnl_percent b.pnl_percent)
        |> Option.map ~f:to_triple
      in
      let worst =
        List.min_elt rows ~compare:(fun a b ->
            Float.compare a.pnl_percent b.pnl_percent)
        |> Option.map ~f:to_triple
      in
      { best; worst }

let _derived_period (rows : per_trade_row list) =
  let starts = List.map rows ~f:(fun r -> r.entry_date) in
  let ends = List.map rows ~f:(fun r -> r.exit_date) in
  ( List.min_elt starts ~compare:Date.compare,
    List.max_elt ends ~compare:Date.compare )

let _compute_header ~scenario_name ~period_start ~period_end ~universe_size
    ~rows =
  let total_round_trips = List.length rows in
  let winners =
    List.count rows ~f:(fun (r : per_trade_row) -> Float.(r.pnl_dollars > 0.0))
  in
  let losers = total_round_trips - winners in
  let win_rate_pct =
    if total_round_trips = 0 then 0.0
    else Float.of_int winners /. Float.of_int total_round_trips *. 100.0
  in
  let total_realized_return_pct =
    List.fold rows ~init:0.0 ~f:(fun acc r -> acc +. r.pnl_percent)
  in
  let derived_start, derived_end = _derived_period rows in
  let period_start =
    match period_start with Some _ -> period_start | None -> derived_start
  in
  let period_end =
    match period_end with Some _ -> period_end | None -> derived_end
  in
  {
    scenario_name;
    period_start;
    period_end;
    universe_size;
    total_round_trips;
    winners;
    losers;
    win_rate_pct;
    total_realized_return_pct;
  }

let _compute_analysis ~config ~trade_audit ~trades : analysis option =
  let ratings =
    Trade_audit_ratings.rate_all ~config ~audit:trade_audit ~trades
  in
  if List.is_empty ratings then None
  else
    let behavioral =
      Trade_audit_ratings.behavioral_metrics_of ~config ~ratings
        ~audit:trade_audit ~trades
    in
    let weinstein =
      Trade_audit_ratings.weinstein_aggregate_of ~config ~ratings
        ~audit:trade_audit
    in
    let decision_quality =
      Trade_audit_ratings.decision_quality_matrix_of ~ratings
    in
    Some { ratings; behavioral; weinstein; decision_quality }

let render ?scenario_name ?period_start ?period_end ?universe_size
    ?(ratings_config = Trade_audit_ratings.default_config) ~trade_audit ~trades
    () : t =
  let audit_idx = _audit_index trade_audit in
  let rows =
    List.map trades ~f:(_row_of_trade audit_idx)
    |> List.sort ~compare:_compare_rows
  in
  let header =
    _compute_header ~scenario_name ~period_start ~period_end ~universe_size
      ~rows
  in
  let best_worst = _compute_best_worst rows in
  let analysis =
    _compute_analysis ~config:ratings_config ~trade_audit ~trades
  in
  { header; best_worst; rows; analysis }

(* Markdown formatting ---------------------------------------------------- *)

let _stage_label (s : Weinstein_types.stage) =
  match s with
  | Stage1 _ -> "Stage1"
  | Stage2 _ -> "Stage2"
  | Stage3 _ -> "Stage3"
  | Stage4 _ -> "Stage4"

let _rs_trend_label (rs : Weinstein_types.rs_trend) =
  match rs with
  | Bullish_crossover -> "Bullish_xover"
  | Positive_rising -> "Pos_rising"
  | Positive_flat -> "Pos_flat"
  | Negative_improving -> "Neg_improving"
  | Negative_declining -> "Neg_declining"
  | Bearish_crossover -> "Bearish_xover"

let _macro_label (m : Weinstein_types.market_trend) =
  match m with
  | Bullish -> "Bullish"
  | Bearish -> "Bearish"
  | Neutral -> "Neutral"

let _side_label (s : Trading_base.Types.position_side) =
  match s with Long -> "Long" | Short -> "Short"

let _opt_label f = function Some v -> f v | None -> "—"
let _opt_int = function Some i -> Int.to_string i | None -> "—"
let _opt_date = function Some d -> Date.to_string d | None -> "—"
let _opt_string = function Some s -> s | None -> "—"
let _fmt_float_2 v = sprintf "%.2f" v
let _fmt_pct v = sprintf "%+.2f%%" v
let _fmt_pct_unsigned v = sprintf "%.1f%%" v

let _format_header (h : scenario_header) : string list =
  let title =
    sprintf "# Trade audit \xe2\x80\x94 %s" (_opt_string h.scenario_name)
  in
  [
    title;
    "";
    sprintf "- Period: %s \xe2\x86\x92 %s" (_opt_date h.period_start)
      (_opt_date h.period_end);
    sprintf "- Universe: %s" (_opt_int h.universe_size);
    sprintf "- Total round-trips: %d" h.total_round_trips;
    sprintf "- Winners: %d / %d (%s)" h.winners h.total_round_trips
      (_fmt_pct_unsigned h.win_rate_pct);
    sprintf "- Total realized return (sum of pnl%%): %s"
      (_fmt_pct h.total_realized_return_pct);
    "";
  ]

let _format_aggregate (bw : best_worst) : string list =
  let fmt_triple = function
    | None -> "—"
    | Some (sym, d, pct) ->
        sprintf "%s %s \xe2\x86\x92 %s" sym (Date.to_string d) (_fmt_pct pct)
  in
  [
    "## Aggregate summary";
    "";
    sprintf "- Best trade: %s" (fmt_triple bw.best);
    sprintf "- Worst trade: %s" (fmt_triple bw.worst);
    "";
  ]

let _row_cells (r : per_trade_row) =
  [
    r.symbol;
    Date.to_string r.entry_date;
    _side_label r.side;
    _fmt_float_2 r.entry_price;
    Date.to_string r.exit_date;
    _fmt_float_2 r.exit_price;
    Int.to_string r.days_held;
    _fmt_float_2 r.pnl_dollars;
    _fmt_pct r.pnl_percent;
    (if String.is_empty r.exit_trigger then "—" else r.exit_trigger);
    _opt_label _stage_label r.entry_stage;
    _opt_label _rs_trend_label r.entry_rs_trend;
    _opt_label _macro_label r.entry_macro_trend;
    _opt_label Weinstein_types.grade_to_string r.cascade_grade;
    _opt_int r.cascade_score;
  ]

let _format_row r =
  let cells = _row_cells r in
  "| " ^ String.concat ~sep:" | " cells ^ " |"

let _format_table_header () =
  [
    "| symbol | entry_date | side | entry_px | exit_date | exit_px | days | \
     pnl_$ | pnl_% | exit_trigger | stage | rs | macro | grade | score |";
    "|---|---|---|---:|---|---:|---:|---:|---:|---|---|---|---|---|---:|";
  ]

let _format_table (rows : per_trade_row list) : string list =
  let head = "## Per-trade table" :: "" :: _format_table_header () in
  let body =
    if List.is_empty rows then [ "_No trades._" ]
    else List.map rows ~f:_format_row
  in
  head @ body @ [ "" ]

let _format_analysis (a : analysis) : string list =
  Trade_audit_ratings.format_per_trade_extras ~ratings:a.ratings
  @ Trade_audit_ratings.format_behavioral_section a.behavioral
  @ Trade_audit_ratings.format_weinstein_section a.weinstein
  @ Trade_audit_ratings.format_decision_quality_section a.decision_quality

let to_markdown (t : t) : string =
  let core_lines =
    _format_header t.header
    @ _format_aggregate t.best_worst
    @ _format_table t.rows
  in
  let analysis_lines =
    match t.analysis with Some a -> _format_analysis a | None -> []
  in
  String.concat ~sep:"\n" (core_lines @ analysis_lines) ^ "\n"

(* Loader ----------------------------------------------------------------- *)

(** Map the CSV [side] column ([LONG] / [SHORT]) emitted by
    [Backtest.Result_writer] back to the [Trading_base.Types.side] of the
    round-trip's entry leg. Unknown labels fall back to [Buy] so pre-G2
    trades.csv files (with no [side] column) keep parsing. *)
let _parse_side = function
  | "LONG" -> Trading_base.Types.Buy
  | "SHORT" -> Trading_base.Types.Sell
  | _ -> Trading_base.Types.Buy

(** Build a [trade_metrics] from already-parsed string cells. Shared by the
    post-G2 (with [side]) and legacy (no [side]) parser branches in
    {!_read_trades_csv} so the field list lives in one place. *)
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

(** Match a post-G2 row layout (13 columns; [side] = [LONG]/[SHORT]). *)
let _match_post_g2_csv_row cells :
    Trading_simulation.Metrics.trade_metrics option =
  match cells with
  | [
      symbol;
      ("LONG" as side);
      entry_date;
      exit_date;
      days_held;
      entry_price;
      exit_price;
      quantity;
      pnl_dollars;
      pnl_percent;
      _entry_stop;
      _exit_stop;
      _exit_trigger;
    ]
  | [
      symbol;
      ("SHORT" as side);
      entry_date;
      exit_date;
      days_held;
      entry_price;
      exit_price;
      quantity;
      pnl_dollars;
      pnl_percent;
      _entry_stop;
      _exit_stop;
      _exit_trigger;
    ] ->
      Some
        (_trade_metrics_of_strings ~symbol ~side ~entry_date ~exit_date
           ~days_held ~entry_price ~exit_price ~quantity ~pnl_dollars
           ~pnl_percent)
  | _ -> None

(** Match a legacy (pre-G2) 12-column row layout. Defaults [side] to [Buy]. *)
let _match_legacy_csv_row cells :
    Trading_simulation.Metrics.trade_metrics option =
  match cells with
  | [
   symbol;
   entry_date;
   exit_date;
   days_held;
   entry_price;
   exit_price;
   quantity;
   pnl_dollars;
   pnl_percent;
   _entry_stop;
   _exit_stop;
   _exit_trigger;
  ] ->
      Some
        (_trade_metrics_of_strings ~symbol ~side:"LONG" ~entry_date ~exit_date
           ~days_held ~entry_price ~exit_price ~quantity ~pnl_dollars
           ~pnl_percent)
  | _ -> None

(** Read trades.csv. Tolerates both the post-G2 (13-column, with [side]) and
    legacy (12-column, no [side]) layouts. The disambiguator is whether the
    second cell is a [LONG]/[SHORT] tag (post-G2) or a date (legacy). Legacy
    rows default to [side = Buy] preserving the historical long-only semantics.
*)
let _parse_trades_csv_line path line :
    Trading_simulation.Metrics.trade_metrics option =
  if String.is_empty (String.strip line) then None
  else
    let cells = String.split line ~on:',' in
    match _match_post_g2_csv_row cells with
    | Some _ as t -> t
    | None -> (
        match _match_legacy_csv_row cells with
        | Some _ as t -> t
        | None -> failwithf "Unexpected trades.csv row in %s: %s" path line ())

let _read_trades_csv path : Trading_simulation.Metrics.trade_metrics list =
  let ic = In_channel.create path in
  let lines = In_channel.input_lines ic in
  In_channel.close ic;
  match lines with
  | [] -> failwithf "trades.csv at %s is empty" path ()
  | _header :: rest -> List.filter_map rest ~f:(_parse_trades_csv_line path)

type _summary_meta = {
  start_date : Date.t;
  end_date : Date.t;
  universe_size : int;
}
[@@deriving sexp] [@@sexp.allow_extra_fields]
(** Minimal shape of [summary.sexp] needed for the report header — we only pull
    the run-window + universe-size fields, ignoring the rest via
    [@@sexp.allow_extra_fields]. The canonical record [Summary.t] writes far
    more (e.g. metrics) and exposes [sexp_of_t] only; round-tripping through
    this local shape avoids depending on a parser that does not exist on the
    producer side. *)

let _load_summary_meta path : _summary_meta option =
  if not (Sys_unix.file_exists_exn path) then None
  else try Some (_summary_meta_of_sexp (Sexp.load_sexp path)) with _ -> None

let load ~scenario_dir : t =
  let trades_path = Filename.concat scenario_dir "trades.csv" in
  if not (Sys_unix.file_exists_exn trades_path) then
    failwithf "Missing trades.csv in %s" scenario_dir ();
  let trades = _read_trades_csv trades_path in
  let audit_path = Filename.concat scenario_dir "trade_audit.sexp" in
  let trade_audit =
    if Sys_unix.file_exists_exn audit_path then
      TA.audit_records_of_sexp (Sexp.load_sexp audit_path)
    else []
  in
  let summary =
    _load_summary_meta (Filename.concat scenario_dir "summary.sexp")
  in
  let scenario_name =
    let bn = Filename.basename scenario_dir in
    if String.is_empty bn then None else Some bn
  in
  let period_start = Option.map summary ~f:(fun s -> s.start_date) in
  let period_end = Option.map summary ~f:(fun s -> s.end_date) in
  let universe_size = Option.map summary ~f:(fun s -> s.universe_size) in
  render ?scenario_name ?period_start ?period_end ?universe_size ~trade_audit
    ~trades ()

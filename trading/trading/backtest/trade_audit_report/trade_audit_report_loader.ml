(** Disk loaders for the trade-audit report (trades.csv, trade_audit.sexp,
    summary.sexp). See [.mli]. *)

open Core
module TA = Backtest.Trade_audit
module Csv_schema = Backtest.Trades_csv_schema

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
    {!read_trades_csv} so the field list lives in one place. [position_id] is
    resolved by the caller from the header-derived schema — [None] for the
    legacy layout, which has no such column. *)
let _trade_metrics_of_strings ~symbol ~side ~entry_date ~exit_date ~days_held
    ~entry_price ~exit_price ~quantity ~pnl_dollars ~pnl_percent ~position_id :
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
    position_id;
  }

(** Match a post-G2 row layout (≥13 columns; [side] = [LONG]/[SHORT]). The head
    13 columns carry the canonical metrics + side + stop columns; trailing
    columns (added by M5.2e: entry_stage, entry_volume_ratio,
    stop_initial_distance_pct, stop_trigger_kind, days_to_first_stop_trigger,
    screener_score_at_entry; and by future schema additions) are tolerated and
    otherwise ignored.

    The one trailing column this loader does consume is [position_id], which the
    caller resolves by name against the file's header (see
    {!Backtest.Trades_csv_schema}) rather than by a hardcoded index — appending
    further columns must not shift what gets read. *)
let _match_post_g2_csv_row ~position_id cells :
    Trading_simulation.Metrics.trade_metrics option =
  match cells with
  | symbol
    :: (("LONG" | "SHORT") as side)
    :: entry_date :: exit_date :: days_held :: entry_price :: exit_price
    :: quantity :: pnl_dollars :: pnl_percent :: _entry_stop :: _exit_stop
    :: _exit_trigger :: _rest ->
      Some
        (_trade_metrics_of_strings ~symbol ~side ~entry_date ~exit_date
           ~days_held ~entry_price ~exit_price ~quantity ~pnl_dollars
           ~pnl_percent ~position_id)
  | _ -> None

(* The legacy layout predates the [position_id] column entirely, so there is no
   cell to read. Resolved through {!Csv_schema.legacy} rather than written as a
   bare [None] so the absence stays a statement about the layout, checkable
   against the schema, instead of an incidental omission. *)
let _legacy_position_id cells =
  Csv_schema.position_id_of_cells Csv_schema.legacy cells

(** Match a legacy (pre-G2) row layout — leading 12 columns with no [side];
    trailing columns ignored for the same forward-compat reason as the post-G2
    matcher. Defaults [side] to [Buy]. [position_id] is [None] by construction,
    so {!_find_audit} falls back to date proximity for these rows. *)
let _match_legacy_csv_row cells :
    Trading_simulation.Metrics.trade_metrics option =
  match cells with
  | symbol :: entry_date :: exit_date :: days_held :: entry_price :: exit_price
    :: quantity :: pnl_dollars :: pnl_percent :: _entry_stop :: _exit_stop
    :: _exit_trigger :: _rest ->
      Some
        (_trade_metrics_of_strings ~symbol ~side:"LONG" ~entry_date ~exit_date
           ~days_held ~entry_price ~exit_price ~quantity ~pnl_dollars
           ~pnl_percent
           ~position_id:(_legacy_position_id cells))
  | _ -> None

(** Read trades.csv. Tolerates both the post-G2 (13-column, with [side]) and
    legacy (12-column, no [side]) layouts. The disambiguator is whether the
    second cell is a [LONG]/[SHORT] tag (post-G2) or a date (legacy). Legacy
    rows default to [side = Buy] preserving the historical long-only semantics.
*)
let _parse_trades_csv_line ~schema path line :
    Trading_simulation.Metrics.trade_metrics option =
  if String.is_empty (String.strip line) then None
  else
    let cells = String.split line ~on:',' in
    let position_id = Csv_schema.position_id_of_cells schema cells in
    match _match_post_g2_csv_row ~position_id cells with
    | Some _ as t -> t
    | None -> (
        match _match_legacy_csv_row cells with
        | Some _ as t -> t
        | None -> failwithf "Unexpected trades.csv row in %s: %s" path line ())

let read_trades_csv path : Trading_simulation.Metrics.trade_metrics list =
  let ic = In_channel.create path in
  let lines = In_channel.input_lines ic in
  In_channel.close ic;
  match lines with
  | [] -> failwithf "trades.csv at %s is empty" path ()
  | header :: rest ->
      let schema = Csv_schema.of_header_line header in
      List.filter_map rest ~f:(_parse_trades_csv_line ~schema path)

type summary_meta = {
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

let load_summary_meta path : summary_meta option =
  if not (Sys_unix.file_exists_exn path) then None
  else try Some (summary_meta_of_sexp (Sexp.load_sexp path)) with _ -> None

let load_trade_audit audit_path : TA.audit_record list =
  if Sys_unix.file_exists_exn audit_path then begin
    let sexp = Sexp.load_sexp audit_path in
    (* The runner persists a full [audit_blob] envelope ([audit_records] +
       [cascade_summaries]); older runs persisted a bare [audit_record list].
       Parse as a blob first and fall back to the bare list so both on-disk
       formats load. *)
    try (TA.audit_blob_of_sexp sexp).audit_records
    with _ -> TA.audit_records_of_sexp sexp
  end
  else []

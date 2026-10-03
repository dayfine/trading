(** Trade-audit markdown renderer. See [.mli] for the contract. *)

open Core
module TA = Backtest.Trade_audit
module Stop_log = Backtest.Stop_log
module Split_safe = Backtest.Split_safe_metric

module Trade_audit_ratings = Trade_audit_ratings
(** Re-export the per-trade-rating + analysis library so external callers can
    reach it via [Trade_audit_report.Trade_audit_ratings]. The library wrap
    suppresses the auto-generated alias when a same-named entry module exists,
    so we re-export here explicitly. *)

module Trade_score = Trade_score
(** Same re-export treatment for the composite trade-quality score. *)

include Trade_audit_report_types
module Loader = Trade_audit_report_loader

(* Render ----------------------------------------------------------------- *)

(** Max calendar-day gap tolerated when joining a [trades.csv] round-trip to its
    audit record. The audit [entry_date] is the Friday decision date; the
    round-trip [entry_date] is the actual fill (next trading day), so the two
    differ by 1-3 days across a weekend. A week is wide enough to bridge that
    without cross-matching a distinct re-entry of the same symbol. *)
let _audit_join_tolerance_days = 7

type _audit_index = {
  by_position_id : (string, TA.audit_record, String.comparator_witness) Map.t;
      (** [entry.position_id] → record. The exact join: immune to any
          decision→fill date gap. Position ids are unique per strategy position,
          so at most one record lands per key. *)
  by_symbol : (string, TA.audit_record list, String.comparator_witness) Map.t;
      (** symbol → records, for the date-proximity fallback below. *)
}

let _audit_index audit =
  List.fold audit
    ~init:
      {
        by_position_id = Map.empty (module String);
        by_symbol = Map.empty (module String);
      }
    ~f:(fun acc (record : TA.audit_record) ->
      {
        by_position_id =
          Map.set acc.by_position_id ~key:record.entry.position_id ~data:record;
        by_symbol =
          Map.add_multi acc.by_symbol ~key:record.entry.symbol ~data:record;
      })

(* Find the audit record for [symbol] whose decision date is closest to the
   round-trip [entry_date], within tolerance. Returns [None] when the symbol has
   no audit record or the nearest one is too far away.

   Fallback only — see {!_find_audit}. This symmetric nearest-date scan is the
   silent misattribution PR #2317 retired for the in-process path: on async
   (resting-order) configs a ticket can fill arbitrarily long after the decision
   that placed it, so a row either misses its record entirely or attaches a
   distinct re-entry of the same symbol. It is retained (exactly as
   {!Trade_context} retains its own date path) for rows that carry no position
   id — legacy trades.csv layouts, and post-G2 rows whose cell is empty. *)
let _find_audit_by_date audit_idx ~symbol ~entry_date =
  match Map.find audit_idx.by_symbol symbol with
  | None -> None
  | Some records ->
      List.filter_map records ~f:(fun (r : TA.audit_record) ->
          let gap = Int.abs (Date.diff r.entry.entry_date entry_date) in
          if gap <= _audit_join_tolerance_days then Some (gap, r) else None)
      |> List.min_elt ~compare:(fun (g1, _) (g2, _) -> Int.compare g1 g2)
      |> Option.map ~f:snd

(* Prefer the exact [position_id] join; fall back to date proximity when the
   round-trip carries no position id, or one no audit record claims. Mirrors
   [Trade_context._lookup_audit_for_trade]'s preference order so the offline
   report and the in-process pipeline agree on which record belongs to a row. *)
let _find_audit audit_idx ~position_id ~symbol ~entry_date =
  match Option.bind position_id ~f:(Map.find audit_idx.by_position_id) with
  | Some _ as record -> record
  | None -> _find_audit_by_date audit_idx ~symbol ~entry_date

let _exit_trigger_label (trigger : Stop_log.exit_trigger) =
  match trigger with
  | Stop_loss _ -> "stop_loss"
  | Take_profit _ -> "take_profit"
  | Signal_reversal _ -> "signal_reversal"
  | Time_expired _ -> "time_expired"
  | Underperforming _ -> "underperforming"
  | Portfolio_rebalancing -> "rebalancing"
  | Strategy_signal { label; _ } -> label
  | End_of_period -> "end_of_period"

let _row_of_trade audit_idx (trade : Trading_simulation.Metrics.trade_metrics) :
    per_trade_row =
  let audit =
    _find_audit audit_idx ~position_id:trade.position_id ~symbol:trade.symbol
      ~entry_date:trade.entry_date
  in
  let entry = Option.map audit ~f:(fun (r : TA.audit_record) -> r.entry) in
  let exit_ = Option.bind audit ~f:(fun (r : TA.audit_record) -> r.exit_) in
  let execution =
    Option.bind audit ~f:(fun (r : TA.audit_record) -> r.execution)
  in
  let side =
    Option.value_map entry ~default:Trading_base.Types.Long ~f:(fun e -> e.side)
  in
  (* Enriched exit wins; otherwise fall back to the reason-only
     [external_exit] captured for exits generated outside the strategy's
     audit stream (margin_call, stage3_force_exit, ...) — see
     Trade_audit.external_exit_decision (#2076). *)
  let exit_trigger =
    match exit_ with
    | Some e -> _exit_trigger_label e.exit_trigger
    | None ->
        Option.bind audit ~f:(fun (r : TA.audit_record) -> r.external_exit)
        |> Option.value_map ~default:""
             ~f:(fun (x : TA.external_exit_decision) ->
               _exit_trigger_label x.exit_trigger)
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
    fill_vs_trigger_pct =
      Option.map execution ~f:(fun (e : TA.execution_faithfulness) ->
          e.fill_vs_trigger_pct);
    faithful =
      Option.map execution ~f:(fun (e : TA.execution_faithfulness) ->
          e.faithful);
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

let _compute_analysis ~config ~closes_lookup ~trade_audit ~trades :
    analysis option =
  let ratings =
    Trade_audit_ratings.rate_all ~closes_lookup ~config ~audit:trade_audit
      ~trades ()
  in
  if List.is_empty ratings then None
  else
    let behavioral =
      Trade_audit_ratings.behavioral_metrics_of ~config ~ratings
        ~audit:trade_audit ~trades
    in
    let weinstein =
      Trade_audit_ratings.weinstein_aggregate_of ~closes_lookup ~config ~ratings
        ~audit:trade_audit ()
    in
    let decision_quality =
      Trade_audit_ratings.decision_quality_matrix_of ~audit:trade_audit ~ratings
    in
    Some { ratings; behavioral; weinstein; decision_quality }

(* The basis tag lives on the entry decision, so the population is the audit
   records themselves — not the joined round-trips. An entry still open at
   end-of-run exercised [split_safe_floors] exactly as much as a closed one;
   counting over [rows] would drop it and understate the denominator. *)
let _compute_split_safe_tally (trade_audit : TA.audit_record list) =
  List.map trade_audit ~f:(fun (r : TA.audit_record) ->
      r.entry.split_safe_basis)
  |> Split_safe.tally_of_bases

let render ?scenario_name ?period_start ?period_end ?universe_size
    ?(ratings_config = Trade_audit_ratings.default_config)
    ?(closes_lookup = fun ~symbol:_ ~as_of:_ -> []) ~trade_audit ~trades () : t
    =
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
    _compute_analysis ~config:ratings_config ~closes_lookup ~trade_audit ~trades
  in
  let split_safe_tally = _compute_split_safe_tally trade_audit in
  { header; best_worst; rows; analysis; split_safe_tally }

let to_markdown = Trade_audit_report_markdown.to_markdown

let load ?closes_lookup ~scenario_dir () : t =
  let trades_path = Filename.concat scenario_dir "trades.csv" in
  if not (Sys_unix.file_exists_exn trades_path) then
    failwithf "Missing trades.csv in %s" scenario_dir ();
  let trades = Loader.read_trades_csv trades_path in
  let trade_audit =
    Loader.load_trade_audit (Filename.concat scenario_dir "trade_audit.sexp")
  in
  let summary =
    Loader.load_summary_meta (Filename.concat scenario_dir "summary.sexp")
  in
  let scenario_name =
    let bn = Filename.basename scenario_dir in
    if String.is_empty bn then None else Some bn
  in
  let period_start =
    Option.map summary ~f:(fun (s : Loader.summary_meta) -> s.start_date)
  in
  let period_end =
    Option.map summary ~f:(fun (s : Loader.summary_meta) -> s.end_date)
  in
  let universe_size =
    Option.map summary ~f:(fun (s : Loader.summary_meta) -> s.universe_size)
  in
  render ?scenario_name ?period_start ?period_end ?universe_size ?closes_lookup
    ~trade_audit ~trades ()

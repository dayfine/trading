(** [decision_grading] — grade a backtest's exits by their post-exit outcome.

    Reads a scenario output directory (the shape {!Backtest.Result_writer.write}
    produces — [trades.csv] + [trade_audit.sexp] + [summary.sexp]) via
    {!Trade_audit_report.load}, fetches the weekly bars that printed {b after}
    each exit from a snapshot warehouse, and for every round-trip computes:

    - {!Decision_grading.Post_exit} continuation at each requested horizon,
    - the {!Decision_grading.Grade.exit_grade} at the grade horizon ([Premature]
      / [Good_exit] / [Neutral]),
    - the {!Decision_grading.Grade.entry_capture_ratio} (fraction of in-trade
      peak realized) when the trade has a matching audit MFE.

    It then rolls the graded trades up {b by exit reason}
    ({!Decision_grading.Aggregate}) and emits a markdown table — the repeatable
    form of the one-off [trade-forensics-2026-06-12] finding (which exit kinds
    add value, which destroy it).

    This is a read-only analysis lens: it changes no strategy behaviour.

    Usage:
    {[
      decision_grading --scenario-dir <dir> --snapshot-dir <dir>
        [--horizons 4,13,26] [--grade-horizon 13] [--out report.md]
    ]}

    [--scenario-dir] is required (the backtest output to grade).
    [--snapshot-dir] is required (the warehouse the post-exit bars are read from
    — same warehouse the run was produced against). [--horizons] is the
    comma-separated week horizons to measure continuation over (default
    [4,13,26]). [--grade-horizon] selects which of those horizons the
    {!Grade.exit_grade} verdict is taken at (default [13] = one quarter).
    [--out], when given, writes the markdown there; otherwise it goes to stdout.
*)

open Core
module TAR = Trade_audit_report
module DG = Decision_grading
module Bar_reader = Weinstein_strategy.Bar_reader
module Daily_panels = Snapshot_runtime.Daily_panels
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest

let _default_horizons = [ 4; 13; 26 ]
let _default_grade_horizon = 13

(* Days spanned by one weekly bar's horizon week. *)
let _days_per_week = 7

(* Extra weekly bars fetched beyond the max horizon so the window's last bar is
   covered even when weekly aggregation lands a bar slightly past the boundary. *)
let _horizon_buffer_weeks = 3

(* [trades.csv]'s [pnl_percent] is stored scaled by 100 (20.0 = +20%); divide to
   recover the fraction the grading libs use. *)
let _pct_scale = 100.0

(* Daily_panels LRU cache budget for the post-exit bar reads. The lens fetches a
   handful of weeks per closed trade, so a modest cap suffices. *)
let _cache_mb = 512

let _usage () =
  eprintf
    "Usage: decision_grading --scenario-dir <dir> --snapshot-dir <dir> \
     [--horizons 4,13,26] [--grade-horizon 13] [--out report.md]\n";
  Stdlib.exit 1

type _parse_acc = {
  mutable scenario_dir : string option;
  mutable snapshot_dir : string option;
  mutable horizons : int list option;
  mutable grade_horizon : int option;
  mutable out_path : string option;
}

let _parse_horizons s =
  match
    Or_error.try_with (fun () ->
        String.split s ~on:','
        |> List.map ~f:(fun x -> Int.of_string (String.strip x)))
  with
  | Ok hs when (not (List.is_empty hs)) && List.for_all hs ~f:(fun h -> h > 0)
    ->
      hs
  | _ ->
      eprintf "--horizons requires comma-separated positive ints, got %S\n" s;
      Stdlib.exit 1

let _parse_flag args =
  let acc =
    {
      scenario_dir = None;
      snapshot_dir = None;
      horizons = None;
      grade_horizon = None;
      out_path = None;
    }
  in
  let rec loop = function
    | [] -> acc
    | "--scenario-dir" :: p :: rest ->
        acc.scenario_dir <- Some p;
        loop rest
    | "--snapshot-dir" :: p :: rest ->
        acc.snapshot_dir <- Some p;
        loop rest
    | "--horizons" :: s :: rest ->
        acc.horizons <- Some (_parse_horizons s);
        loop rest
    | "--grade-horizon" :: s :: rest ->
        acc.grade_horizon <- Some (_parse_horizons s |> List.hd_exn);
        loop rest
    | "--out" :: p :: rest ->
        acc.out_path <- Some p;
        loop rest
    | _ -> _usage ()
  in
  loop args

(** Build a snapshot-backed [Bar_reader.t] over [snapshot_dir]. Exits the
    process on a missing/corrupt manifest or panel-open failure (the "warehouse
    not built" failure mode surfaces immediately). *)
let _bar_reader_of_snapshot ~snapshot_dir =
  let manifest_path = Filename.concat snapshot_dir "manifest.sexp" in
  let manifest =
    match Snapshot_manifest.read ~path:manifest_path with
    | Ok m -> m
    | Error err ->
        eprintf "decision_grading: cannot read %s: %s\n" manifest_path
          (Status.show err);
        Stdlib.exit 1
  in
  let panels =
    match
      Daily_panels.create ~snapshot_dir ~manifest ~max_cache_mb:_cache_mb
    with
    | Ok p -> p
    | Error err ->
        eprintf "decision_grading: Daily_panels.create failed: %s\n"
          (Status.show err);
        Stdlib.exit 1
  in
  Bar_reader.of_snapshot_views (Snapshot_callbacks.of_daily_panels panels)

(** Ground-truth exit-reason lookup read straight from [trades.csv]'s
    [exit_trigger] column, keyed by [(symbol, entry_date, exit_date)].

    {!Trade_audit_report}'s [per_trade_row.exit_trigger] is derived from the
    {b audit record}'s exit trigger and is blank whenever the audit's
    [exit_decision] is absent — which it is for [laggard_rotation] /
    [stage3_force_exit] exits in pre-#1506 runs. The CSV column carries the real
    label for every trade, so the lens (whose whole point is separating these
    reasons) reads it directly. *)
let _exit_reason_lookup ~scenario_dir =
  let tbl = Hashtbl.Poly.create () in
  let path = Filename.concat scenario_dir "trades.csv" in
  let rows =
    In_channel.read_lines path
    |> List.filter ~f:(fun l -> not (String.is_empty l))
    |> List.map ~f:(fun l -> String.split l ~on:',')
  in
  (match rows with
  | header :: data ->
      let idx name =
        List.findi header ~f:(fun _ h -> String.equal h name)
        |> Option.map ~f:fst
      in
      let col_symbol = idx "symbol" in
      let col_entry = idx "entry_date" in
      let col_exit = idx "exit_date" in
      let col_trigger = idx "exit_trigger" in
      let get row i = Option.bind i ~f:(fun i -> List.nth row i) in
      List.iter data ~f:(fun row ->
          match
            ( get row col_symbol,
              get row col_entry,
              get row col_exit,
              get row col_trigger )
          with
          | Some sym, Some ed, Some xd, Some trig ->
              Hashtbl.set tbl
                ~key:(sym, Date.of_string ed, Date.of_string xd)
                ~data:trig
          | _ -> ())
  | [] -> ());
  tbl

(** Map [(symbol, entry_date) -> mfe_pct] from the report's per-trade ratings,
    so a trade's in-trade peak (a fraction of entry price) is available for the
    capture ratio. Trades without a matching audit record are absent. *)
let _mfe_lookup (report : TAR.t) =
  let tbl = Hashtbl.Poly.create () in
  Option.iter report.analysis ~f:(fun (a : TAR.analysis) ->
      List.iter a.ratings ~f:(fun (r : TAR.Trade_audit_ratings.rating) ->
          Hashtbl.set tbl ~key:(r.symbol, r.entry_date) ~data:r.mfe_pct));
  tbl

(** Continuation at [grade_horizon] from a post-exit result list, or [0.0] when
    that horizon is absent. *)
let _continuation_at ~grade_horizon post_exit =
  List.find_map post_exit ~f:(fun (h : DG.Post_exit.horizon_result) ->
      if h.horizon_weeks = grade_horizon then Some h.continuation_pct else None)
  |> Option.value ~default:0.0

(** Grade one round-trip row into a {!DG.Aggregate.graded_trade}. *)
let _grade_row ~bar_reader ~mfe_lookup ~exit_reason_lookup ~horizons
    ~grade_config ~grade_horizon (row : TAR.per_trade_row) :
    DG.Aggregate.graded_trade =
  let max_horizon =
    List.max_elt horizons ~compare:Int.compare |> Option.value ~default:0
  in
  let as_of = Date.add_days row.exit_date (max_horizon * _days_per_week) in
  let bars =
    Bar_reader.weekly_bars_for bar_reader ~symbol:row.symbol
      ~n:(max_horizon + _horizon_buffer_weeks)
      ~as_of
  in
  let post_exit =
    DG.Post_exit.post_exit_metrics ~side:row.side ~exit_price:row.exit_price
      ~exit_date:row.exit_date ~bars ~horizons_weeks:horizons
  in
  let realized_pnl_pct = row.pnl_percent /. _pct_scale in
  let entry_capture_ratio =
    Option.bind
      (Hashtbl.find mfe_lookup (row.symbol, row.entry_date))
      ~f:(fun mfe ->
        DG.Grade.entry_capture_ratio ~realized_pnl_pct ~max_favorable_pct:mfe)
  in
  let exit_reason =
    Hashtbl.find exit_reason_lookup (row.symbol, row.entry_date, row.exit_date)
    |> Option.value ~default:row.exit_trigger
  in
  let exit_reason =
    if String.is_empty exit_reason then "unlabeled" else exit_reason
  in
  {
    DG.Aggregate.exit_reason;
    realized_pnl_pct;
    continuation_pct = _continuation_at ~grade_horizon post_exit;
    exit_grade = DG.Grade.grade_exit ~config:grade_config ~post_exit;
    entry_capture_ratio;
  }

let _header (report : TAR.t) ~grade_horizon ~n =
  let date_opt = Option.value_map ~default:"?" ~f:Date.to_string in
  Printf.sprintf
    "# Decision-grading report%s\n\n\
     Period: %s .. %s | round-trips graded: %d | grade horizon: %dw\n\n\
     Net value-add = realized − counterfactual-if-held (positive = the exits \
     helped). %% premature = gave up a winner; %% good exit = dodged a drop.\n\n"
    (Option.value_map report.header.scenario_name ~default:"" ~f:(fun s ->
         " — " ^ s))
    (date_opt report.header.period_start)
    (date_opt report.header.period_end)
    n grade_horizon

let () =
  let acc = _parse_flag (List.tl_exn (Array.to_list (Sys.get_argv ()))) in
  let scenario_dir =
    Option.value_or_thunk acc.scenario_dir ~default:(fun () ->
        eprintf "--scenario-dir is required\n";
        _usage ())
  in
  let snapshot_dir =
    Option.value_or_thunk acc.snapshot_dir ~default:(fun () ->
        eprintf "--snapshot-dir is required\n";
        _usage ())
  in
  let horizons = Option.value acc.horizons ~default:_default_horizons in
  let grade_horizon =
    Option.value acc.grade_horizon ~default:_default_grade_horizon
  in
  let grade_config =
    { DG.Grade.default_config with grade_horizon_weeks = grade_horizon }
  in
  let report = TAR.load ~scenario_dir in
  let bar_reader = _bar_reader_of_snapshot ~snapshot_dir in
  let mfe_lookup = _mfe_lookup report in
  let exit_reason_lookup = _exit_reason_lookup ~scenario_dir in
  eprintf "decision_grading: grading %d round-trips from %s\n%!"
    (List.length report.rows) scenario_dir;
  let graded =
    List.map report.rows
      ~f:
        (_grade_row ~bar_reader ~mfe_lookup ~exit_reason_lookup ~horizons
           ~grade_config ~grade_horizon)
  in
  let groups = DG.Aggregate.aggregate_by_exit_reason graded in
  let markdown =
    _header report ~grade_horizon ~n:(List.length graded)
    ^ DG.Aggregate.to_markdown groups
  in
  match acc.out_path with
  | Some path ->
      Out_channel.write_all path ~data:markdown;
      eprintf "decision_grading: wrote %s\n%!" path
  | None -> print_string markdown

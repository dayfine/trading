(** [laggard_cf] — did laggard-rotation pay? (Phase 5 paired counterfactual)

    For a scenario output dir, computes — per horizon — whether the names bought
    with laggard-rotation's freed cash beat the laggards it sold, forward over
    that horizon. Reads [trades.csv] for the laggard exits and the new entries,
    fetches forward bars from a snapshot warehouse, computes each side's
    {!Decision_grading.Post_exit} forward return, pairs them per rotation event
    ({!Decision_grading.Laggard_cf}), and renders the summary.

    Read-only analysis lens — no strategy behaviour change.

    Usage:
    {[
      laggard_cf --scenario-dir <dir> --snapshot-dir <dir>
        [--horizons 4,13,26] [--alloc-window-days 10] [--out report.md]
    ]} *)

open Core
module DG = Decision_grading
module Bar_reader = Weinstein_strategy.Bar_reader
module Daily_panels = Snapshot_runtime.Daily_panels
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest

let _default_horizons = [ 4; 13; 26 ]

(* Trading days the freed cash may take to redeploy: a rotation frees cash on the
   Friday decision tick; the funded entries fill over the following sessions, so
   a ~2-week window catches them. *)
let _default_alloc_window_days = 10
let _days_per_week = 7
let _horizon_buffer_weeks = 3
let _cache_mb = 512

let _usage () =
  eprintf
    "Usage: laggard_cf --scenario-dir <dir> --snapshot-dir <dir> [--horizons \
     4,13,26] [--alloc-window-days 10] [--out report.md]\n";
  Stdlib.exit 1

type _acc = {
  mutable scenario_dir : string option;
  mutable snapshot_dir : string option;
  mutable horizons : int list option;
  mutable alloc_window_days : int option;
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
      alloc_window_days = None;
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
    | "--alloc-window-days" :: s :: rest ->
        acc.alloc_window_days <- Some (Int.of_string s);
        loop rest
    | "--out" :: p :: rest ->
        acc.out_path <- Some p;
        loop rest
    | _ -> _usage ()
  in
  loop args

let _bar_reader_of_snapshot ~snapshot_dir =
  let manifest_path = Filename.concat snapshot_dir "manifest.sexp" in
  let manifest =
    match Snapshot_manifest.read ~path:manifest_path with
    | Ok m -> m
    | Error err ->
        eprintf "laggard_cf: cannot read %s: %s\n" manifest_path
          (Status.show err);
        Stdlib.exit 1
  in
  let panels =
    match
      Daily_panels.create ~snapshot_dir ~manifest ~max_cache_mb:_cache_mb
    with
    | Ok p -> p
    | Error err ->
        eprintf "laggard_cf: Daily_panels.create failed: %s\n" (Status.show err);
        Stdlib.exit 1
  in
  Bar_reader.of_snapshot_views (Snapshot_callbacks.of_daily_panels panels)

(* One round-trip's fields the counterfactual needs. *)
type _row = {
  symbol : string;
  side : Trading_base.Types.position_side;
  entry_date : Date.t;
  entry_price : float;
  exit_date : Date.t;
  exit_price : float;
  exit_trigger : string;
}

let _side_of_string = function
  | "SHORT" -> Trading_base.Types.Short
  | _ -> Trading_base.Types.Long

(* Read [trades.csv] into [_row]s, by header name (robust to column drift). *)
let _read_rows ~scenario_dir =
  let path = Filename.concat scenario_dir "trades.csv" in
  let lines =
    In_channel.read_lines path
    |> List.filter ~f:(fun l -> not (String.is_empty l))
  in
  match List.map lines ~f:(fun l -> String.split l ~on:',') with
  | [] -> []
  | header :: data ->
      let idx name =
        List.findi header ~f:(fun _ h -> String.equal h name)
        |> Option.map ~f:fst
      in
      let i_sym = idx "symbol" and i_side = idx "side" in
      let i_ed = idx "entry_date" and i_xd = idx "exit_date" in
      let i_ep = idx "entry_price" and i_xp = idx "exit_price" in
      let i_trig = idx "exit_trigger" in
      let get row i = Option.bind i ~f:(fun i -> List.nth row i) in
      List.filter_map data ~f:(fun row ->
          match
            ( get row i_sym,
              get row i_side,
              get row i_ed,
              get row i_xd,
              get row i_ep,
              get row i_xp,
              get row i_trig )
          with
          | Some s, Some side, Some ed, Some xd, Some ep, Some xp, Some trig ->
              Some
                {
                  symbol = s;
                  side = _side_of_string side;
                  entry_date = Date.of_string ed;
                  entry_price = Float.of_string ep;
                  exit_date = Date.of_string xd;
                  exit_price = Float.of_string xp;
                  exit_trigger = trig;
                }
          | _ -> None)

(* Forward return from [price] at [date] over [horizon_weeks], via the same
   Post_exit continuation the rest of the lens uses. *)
let _forward ~bar_reader ~horizon_weeks (symbol : string) ~side ~price ~date =
  let as_of = Date.add_days date (horizon_weeks * _days_per_week) in
  let bars =
    Bar_reader.weekly_bars_for bar_reader ~symbol
      ~n:(horizon_weeks + _horizon_buffer_weeks)
      ~as_of
  in
  DG.Post_exit.post_exit_metrics ~side ~exit_price:price ~exit_date:date ~bars
    ~horizons_weeks:[ horizon_weeks ]
  |> List.hd
  |> Option.value_map ~default:0.0 ~f:(fun (h : DG.Post_exit.horizon_result) ->
      h.continuation_pct)

let _summary_for ~bar_reader ~alloc_window_days ~horizon_weeks rows =
  let laggard_exits =
    List.filter_map rows ~f:(fun r ->
        if String.equal r.exit_trigger "laggard_rotation" then
          Some
            ( r.symbol,
              r.exit_date,
              _forward ~bar_reader ~horizon_weeks r.symbol ~side:r.side
                ~price:r.exit_price ~date:r.exit_date )
        else None)
  in
  let entries =
    List.map rows ~f:(fun r ->
        ( r.entry_date,
          _forward ~bar_reader ~horizon_weeks r.symbol ~side:r.side
            ~price:r.entry_price ~date:r.entry_date ))
  in
  DG.Laggard_cf.build_events ~alloc_window_days ~laggard_exits ~entries
  |> DG.Laggard_cf.summarize

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
  let alloc_window_days =
    Option.value acc.alloc_window_days ~default:_default_alloc_window_days
  in
  let rows = _read_rows ~scenario_dir in
  let bar_reader = _bar_reader_of_snapshot ~snapshot_dir in
  eprintf "laggard_cf: %d round-trips, alloc window %dd\n%!" (List.length rows)
    alloc_window_days;
  let sections =
    List.map horizons ~f:(fun h ->
        let s =
          _summary_for ~bar_reader ~alloc_window_days ~horizon_weeks:h rows
        in
        DG.Laggard_cf.to_markdown ~horizon_weeks:h s)
  in
  let header =
    Printf.sprintf
      "# Laggard-rotation paired counterfactual — %s\n\n\
       Alloc window: %d days. Forward returns are Post_exit continuation from \
       each price/date.\n\n"
      (Filename.basename scenario_dir)
      alloc_window_days
  in
  let markdown = header ^ String.concat ~sep:"\n" sections in
  match acc.out_path with
  | Some path ->
      Out_channel.write_all path ~data:markdown;
      eprintf "laggard_cf: wrote %s\n%!" path
  | None -> print_string markdown

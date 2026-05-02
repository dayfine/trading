(** [trace_picks] CLI — render a {!Forward_trace} report from a pick file.

    Usage: trace_picks --pick-file PATH --bars-dir PATH --horizon DAYS

    Reads the weekly snapshot from [--pick-file], loads daily bars for each long
    candidate from [--bars-dir] (CSV-storage layout), traces forward [--horizon]
    calendar days, and prints both the per-pick outcome list and the aggregate
    to stdout as sexp. *)

open Core
open Weinstein_snapshot

let _read_snapshot path : Weekly_snapshot.t =
  match Snapshot_reader.read_from_file path with
  | Ok t -> t
  | Error err ->
      eprintf "Failed to read snapshot %s: %s\n" path (Status.show err);
      exit 1

let _load_bars_for_symbol ~bars_dir symbol : Types.Daily_price.t list =
  match Csv.Csv_storage.create ~data_dir:(Fpath.v bars_dir) symbol with
  | Error _ -> []
  | Ok storage -> (
      match Csv.Csv_storage.get storage () with
      | Error _ -> []
      | Ok bars -> bars)

let _bars_for_picks ~bars_dir (picks : Weekly_snapshot.t) :
    Types.Daily_price.t list String.Map.t =
  List.fold picks.long_candidates ~init:String.Map.empty
    ~f:(fun acc (c : Weekly_snapshot.candidate) ->
      if Map.mem acc c.symbol then acc
      else
        Map.set acc ~key:c.symbol
          ~data:(_load_bars_for_symbol ~bars_dir c.symbol))

let _print_report (outcomes, aggregate) =
  let outcomes_sexp =
    Sexp.List (List.map outcomes ~f:Forward_trace.sexp_of_per_pick_outcome)
  in
  let report_sexp =
    Sexp.List
      [
        Sexp.List
          [ Sexp.Atom "aggregate"; Forward_trace.sexp_of_aggregate aggregate ];
        Sexp.List [ Sexp.Atom "outcomes"; outcomes_sexp ];
      ]
  in
  print_endline (Sexp.to_string_hum report_sexp)

let _run ~pick_file ~bars_dir ~horizon_days () =
  let picks = _read_snapshot pick_file in
  let bars = _bars_for_picks ~bars_dir picks in
  let report = Forward_trace.trace_picks ~picks ~bars ~horizon_days in
  _print_report report

let command =
  Command.basic
    ~summary:
      "Render a forward-trace report from a weekly snapshot pick file. Prints \
       per-pick outcomes + aggregate as sexp."
    (let%map_open.Command pick_file =
       flag "--pick-file"
         (required Filename_unix.arg_type)
         ~doc:"PATH Path to the weekly snapshot sexp file"
     and bars_dir =
       flag "--bars-dir"
         (required Filename_unix.arg_type)
         ~doc:"PATH Path to the CSV-storage bars directory"
     and horizon_days =
       flag "--horizon" (required int)
         ~doc:"DAYS Calendar-day horizon to trace forward from the pick date"
     in
     fun () -> _run ~pick_file ~bars_dir ~horizon_days ())

let () = Command_unix.run command

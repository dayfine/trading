(** [public_picks_summary] CLI — print the price-free public summary of one
    weekly snapshot ({!Public_summary.render}) to stdout.

    Usage: [public_picks_summary <pick-file> [-config-path PATH]]

    [-config-path] names the overrides file the record was generated with, for
    the summary's header line (default {!Public_summary.default_config_path}).
    Exits [1] when the snapshot cannot be read or has the wrong schema version,
    [2] on a usage error. *)

open Core
open Weinstein_snapshot

let _usage () =
  eprintf "Usage: public_picks_summary <pick-file> [-config-path PATH]\n";
  exit 2

let _run ?config_path pick_path =
  match Snapshot_reader.read_from_file pick_path with
  | Ok snap -> print_string (Public_summary.render ?config_path snap)
  | Error err ->
      eprintf "Failed to read snapshot %s: %s\n" pick_path (Status.show err);
      exit 1

let () =
  match Sys.get_argv () |> Array.to_list with
  | [ _; pick_path ] -> _run pick_path
  | [ _; pick_path; "-config-path"; config_path ] -> _run ~config_path pick_path
  | _ -> _usage ()

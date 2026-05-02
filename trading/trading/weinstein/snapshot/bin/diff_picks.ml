(** [diff_picks] CLI — render a {!Pick_diff} between two weekly snapshots.

    Usage: [diff_picks <v1.sexp> <v2.sexp>]

    Reads two weekly snapshots from disk and prints the cross-version pick diff
    to stdout as a sexp. Exits non-zero on read errors or when the snapshots are
    from different dates. *)

open Core
open Weinstein_snapshot

let _read_snapshot path : Weekly_snapshot.t =
  match Snapshot_reader.read_from_file path with
  | Ok t -> t
  | Error err ->
      eprintf "Failed to read snapshot %s: %s\n" path (Status.show err);
      exit 1

let _run v1_path v2_path =
  let v1 = _read_snapshot v1_path in
  let v2 = _read_snapshot v2_path in
  match Pick_diff.diff ~v1 ~v2 with
  | Error err ->
      eprintf "Diff failed: %s\n" (Status.show err);
      exit 1
  | Ok diff -> print_endline (Sexp.to_string_hum (Pick_diff.sexp_of_t diff))

let () =
  match Sys.get_argv () |> Array.to_list with
  | _ :: v1_path :: v2_path :: _ -> _run v1_path v2_path
  | _ ->
      eprintf "Usage: diff_picks <v1.sexp> <v2.sexp>\n";
      exit 2

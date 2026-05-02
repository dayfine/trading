(** [render_weekly_report] CLI — render a weekly snapshot as Markdown.

    Usage: [render_weekly_report <pick-file>]

    Reads a single weekly snapshot from disk, renders it via
    {!Report_renderer.render}, and prints the Markdown to stdout. Exits non-zero
    on read or schema-version errors. *)

open Core
open Weinstein_snapshot

let _read_snapshot path : Weekly_snapshot.t =
  match Snapshot_reader.read_from_file path with
  | Ok t -> t
  | Error err ->
      eprintf "Failed to read snapshot %s: %s\n" path (Status.show err);
      exit 1

let _run pick_path =
  let snap = _read_snapshot pick_path in
  print_string (Report_renderer.render snap)

let () =
  match Sys.get_argv () |> Array.to_list with
  | _ :: pick_path :: _ -> _run pick_path
  | _ ->
      eprintf "Usage: render_weekly_report <pick-file>\n";
      exit 2

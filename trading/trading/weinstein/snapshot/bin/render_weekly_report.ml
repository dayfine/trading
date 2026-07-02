(** [render_weekly_report] CLI — render a weekly snapshot as Markdown.

    Usage: [render_weekly_report <pick-file> [-long-limit N] [-short-limit N]]

    Reads a single weekly snapshot from disk, renders it via
    {!Report_renderer.render}, and prints the Markdown to stdout. The optional
    [-long-limit] / [-short-limit] flags cap the candidate tables (default
    {!Report_renderer.default_long_display_limit} /
    {!Report_renderer.default_short_display_limit}) — e.g. [-long-limit 5] to
    surface a book-sized list. Exits non-zero on read or schema-version errors,
    or [2] on a usage error. *)

open Core
open Weinstein_snapshot

let _read_snapshot path : Weekly_snapshot.t =
  match Snapshot_reader.read_from_file path with
  | Ok t -> t
  | Error err ->
      eprintf "Failed to read snapshot %s: %s\n" path (Status.show err);
      exit 1

let _run pick_path ~long_limit ~short_limit =
  let snap = _read_snapshot pick_path in
  print_string (Report_renderer.render ?long_limit ?short_limit snap)

let _usage () =
  eprintf
    "Usage: render_weekly_report <pick-file> [-long-limit N] [-short-limit N]\n";
  exit 2

(* Parse [-long-limit N] / [-short-limit N] from the args after the positional
   pick-file. Any unrecognised flag or missing value is a usage error. *)
let rec _parse_flags args ~long_limit ~short_limit =
  match args with
  | [] -> (long_limit, short_limit)
  | "-long-limit" :: n :: rest ->
      _parse_flags rest ~long_limit:(Some (Int.of_string n)) ~short_limit
  | "-short-limit" :: n :: rest ->
      _parse_flags rest ~long_limit ~short_limit:(Some (Int.of_string n))
  | _ -> _usage ()

let () =
  match Sys.get_argv () |> Array.to_list with
  | _ :: pick_path :: flags ->
      let long_limit, short_limit =
        _parse_flags flags ~long_limit:None ~short_limit:None
      in
      _run pick_path ~long_limit ~short_limit
  | _ -> _usage ()

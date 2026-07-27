(** [render_weekly_report] CLI — render a weekly snapshot as Markdown or HTML.

    Usage:
    [render_weekly_report <pick-file> [-html] [-html-out PATH] [-data-dir PATH]
     [-long-limit N] [-short-limit N]]

    Reads a single weekly snapshot from disk, renders it, and prints the result
    to stdout.

    Markdown ({!Report_renderer.render}) is the default, so the pre-existing
    invocation is unchanged. [-html] switches to the self-contained HTML page
    ({!Html_report_renderer.render}) — inline CSS, inline SVG charts, no
    external assets.

    [-html-out PATH] implies [-html] and writes the page to [PATH] instead of
    stdout, so a caller can produce the [.md] and the [.html] in one run without
    shell redirection. A path that cannot be written is a hard error (exit 1),
    not a silent drop.

    [-data-dir PATH] points at the CSV price store so the HTML charts have bars
    to draw; each shown symbol is read on demand via
    {!Csv_storage.create}/{!Csv_storage.get}. Without it (or for a symbol with
    no resident CSV) the charts degrade to a "no chart data" marker and the rest
    of the page renders normally. The flag has no effect on Markdown output,
    which has no charts.

    The optional [-long-limit] / [-short-limit] flags cap the candidate tables
    (default {!Report_renderer.default_long_display_limit} /
    {!Report_renderer.default_short_display_limit}) — e.g. [-long-limit 5] to
    surface a book-sized list. Exits non-zero on read or schema-version errors,
    or [2] on a usage error. *)

open Core
open Weinstein_snapshot

type _flags = {
  html : bool;
  html_out : string option;
  data_dir : string option;
  long_limit : int option;
  short_limit : int option;
}

let _no_flags =
  {
    html = false;
    html_out = None;
    data_dir = None;
    long_limit = None;
    short_limit = None;
  }

let _read_snapshot path : Weekly_snapshot.t =
  match Snapshot_reader.read_from_file path with
  | Ok t -> t
  | Error err ->
      eprintf "Failed to read snapshot %s: %s\n" path (Status.show err);
      exit 1

(* Bars for one symbol out of the CSV price store. Every failure mode — no
   store for this symbol, unreadable CSV — degrades to the empty list, which
   the renderer turns into a chart-less cell. A missing chart must never take
   the whole report down. *)
let _bars_from_store ~data_dir ~symbol =
  let open Result in
  ( Csv.Csv_storage.create ~data_dir:(Fpath.v data_dir) symbol >>= fun store ->
    Csv.Csv_storage.get store () )
  |> function
  | Ok bars -> bars
  | Error _ -> []

let _bar_source = function
  | None -> Html_report_renderer.no_bars
  | Some data_dir -> fun ~symbol -> _bars_from_store ~data_dir ~symbol

let _render (flags : _flags) snap =
  if flags.html then
    Html_report_renderer.render ?long_limit:flags.long_limit
      ?short_limit:flags.short_limit
      ~bars_for:(_bar_source flags.data_dir)
      snap
  else
    Report_renderer.render ?long_limit:flags.long_limit
      ?short_limit:flags.short_limit snap

(* [-html-out] writes the HTML beside whatever stdout is carrying, so one
   invocation can produce both forms without shell redirection. An unwritable
   path is a hard error: silently dropping the report the caller asked to keep
   would be worse than failing. *)
let _emit (flags : _flags) rendered =
  match flags.html_out with
  | None -> print_string rendered
  | Some path -> (
      try Out_channel.write_all path ~data:rendered
      with Sys_error msg ->
        eprintf "Failed to write %s: %s\n" path msg;
        exit 1)

let _usage () =
  eprintf
    "Usage: render_weekly_report <pick-file> [-html] [-html-out PATH] \
     [-data-dir PATH] [-long-limit N] [-short-limit N]\n";
  exit 2

(* Parse the flags following the positional pick-file. Any unrecognised flag or
   missing value is a usage error. *)
let rec _parse_flags args (acc : _flags) =
  match args with
  | [] -> acc
  | "-html" :: rest -> _parse_flags rest { acc with html = true }
  | "-html-out" :: p :: rest ->
      _parse_flags rest { acc with html = true; html_out = Some p }
  | "-data-dir" :: d :: rest -> _parse_flags rest { acc with data_dir = Some d }
  | "-long-limit" :: n :: rest ->
      _parse_flags rest { acc with long_limit = Some (Int.of_string n) }
  | "-short-limit" :: n :: rest ->
      _parse_flags rest { acc with short_limit = Some (Int.of_string n) }
  | _ -> _usage ()

let () =
  match Sys.get_argv () |> Array.to_list with
  | _ :: pick_path :: flags ->
      let flags = _parse_flags flags _no_flags in
      _emit flags (_render flags (_read_snapshot pick_path))
  | _ -> _usage ()

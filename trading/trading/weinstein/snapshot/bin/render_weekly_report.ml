(** [render_weekly_report] CLI — render a weekly snapshot as Markdown or HTML.

    Usage:
    [render_weekly_report <pick-file> [-html] [-html-out PATH] [-data-dir PATH |
     -bars-snapshot-dir PATH] [-long-limit N] [-short-limit N]]

    Reads a single weekly snapshot from disk, renders it, and prints the result
    to stdout.

    Markdown ({!Report_renderer.render}) is the default, so the pre-existing
    invocation is unchanged. [-html] switches to the self-contained HTML page
    ({!Html_report_renderer.render}) — inline CSS, inline SVG charts, no
    external assets.

    [-html-out PATH] writes the HTML page to [PATH] while stdout carries the
    Markdown report, so one invocation produces both forms without shell
    redirection. A path that cannot be written is a hard error (exit 1), not a
    silent drop.

    Chart bars come from one of two mutually-exclusive sources. [-data-dir PATH]
    points at the CSV price store; each shown symbol is read on demand via
    {!Csv_storage.create}/{!Csv_storage.get}. [-bars-snapshot-dir PATH] points
    at a pre-built snapshot warehouse (the weekly-review fast path) — use it
    when candidates are fresh universe members whose bars were fetched straight
    to the warehouse and have no resident CSV (#2122). Without either (or for a
    symbol missing from the chosen source) the charts degrade to a "no chart
    data" marker and the rest of the page renders normally. Neither flag affects
    Markdown output, which has no charts.

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
  bars_snapshot_dir : string option;
  long_limit : int option;
  short_limit : int option;
}

let _no_flags =
  {
    html = false;
    html_out = None;
    data_dir = None;
    bars_snapshot_dir = None;
    long_limit = None;
    short_limit = None;
  }

(* Calendar depth of bar history the chart source loads: the ~2y weekly-close
   window the chart draws, plus the 30-week MA's own lookback, plus slack for
   market holidays. *)
let _chart_history_calendar_days = 1000

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

(* Bars out of a pre-built snapshot warehouse (the weekly-review fast path).
   Fresh universe members often exist only in the warehouse, not the CSV store
   (#2122), so this source charts exactly the symbols the CSV path misses. The
   reader is built once per run; a symbol absent from the warehouse degrades to
   the empty list like every other chart failure mode. *)
let _bars_from_warehouse ~warehouse_dir ~(as_of : Date.t) =
  let reader =
    Weinstein_snapshot_gen.Snapshot_warehouse_reader.build ~warehouse_dir ~as_of
      ~warmup_days:_chart_history_calendar_days ()
  in
  fun ~symbol ->
    Weinstein_strategy.Bar_reader.daily_bars_for reader ~symbol ~as_of

let _bar_source (flags : _flags) ~(as_of : Date.t) =
  match (flags.data_dir, flags.bars_snapshot_dir) with
  | None, None -> Html_report_renderer.no_bars
  | Some data_dir, None -> fun ~symbol -> _bars_from_store ~data_dir ~symbol
  | None, Some warehouse_dir -> _bars_from_warehouse ~warehouse_dir ~as_of
  | Some _, Some _ ->
      eprintf "-data-dir and -bars-snapshot-dir are mutually exclusive\n";
      exit 2

let _render_html (flags : _flags) snap =
  Html_report_renderer.render ?long_limit:flags.long_limit
    ?short_limit:flags.short_limit
    ~bars_for:(_bar_source flags ~as_of:snap.Weekly_snapshot.date)
    snap

let _render_md (flags : _flags) snap =
  Report_renderer.render ?long_limit:flags.long_limit
    ?short_limit:flags.short_limit snap

(* [-html-out] writes the HTML page to the given path while stdout keeps
   carrying the Markdown report, so one invocation produces both forms without
   shell redirection. An unwritable path is a hard error: silently dropping the
   report the caller asked to keep would be worse than failing. *)
let _write_file path data =
  try Out_channel.write_all path ~data
  with Sys_error msg ->
    eprintf "Failed to write %s: %s\n" path msg;
    exit 1

let _emit (flags : _flags) snap =
  match flags.html_out with
  | None ->
      print_string
        (if flags.html then _render_html flags snap else _render_md flags snap)
  | Some path ->
      _write_file path (_render_html flags snap);
      print_string (_render_md flags snap)

let _usage () =
  eprintf
    "Usage: render_weekly_report <pick-file> [-html] [-html-out PATH] \
     [-data-dir PATH | -bars-snapshot-dir PATH] [-long-limit N] [-short-limit \
     N]\n";
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
  | "-bars-snapshot-dir" :: d :: rest ->
      _parse_flags rest { acc with bars_snapshot_dir = Some d }
  | "-long-limit" :: n :: rest ->
      _parse_flags rest { acc with long_limit = Some (Int.of_string n) }
  | "-short-limit" :: n :: rest ->
      _parse_flags rest { acc with short_limit = Some (Int.of_string n) }
  | _ -> _usage ()

let () =
  match Sys.get_argv () |> Array.to_list with
  | _ :: pick_path :: flags ->
      let flags = _parse_flags flags _no_flags in
      _emit flags (_read_snapshot pick_path)
  | _ -> _usage ()

(** [record_fill] CLI — edit [dev/weekly-picks/portfolio.sexp] without
    hand-editing sexp (weekly-snapshot item 4c.a).

    Three subcommands, one per kind of book change, each of which keeps [cash]
    in step with the position list so the two cannot drift apart:

    {v
    record_fill record --portfolio P --as-of D --symbol S --shares N \
                       --entry-price X --stop-price Y [--entry-date D]
    record_fill close  --portfolio P --as-of D --symbol S --exit-price X
    record_fill adjust --portfolio P --as-of D --symbol S [--stop-price Y] \
                       [--trim-shares N --trim-price X]
    v}

    All the book-keeping lives in {!Portfolio_edit}; this file is flag parsing
    plus the read/write at the edges. [--dry-run] prints the file that would
    have been written — the exact bytes, via {!Live_portfolio.to_file_contents},
    so there is no second formatting path to drift from the real one.

    Exits [1] on a read, edit, or write failure, printing the reason. *)

open Core
open Weinstein_snapshot_gen

let _fail message =
  eprintf "%s\n" message;
  exit 1

let _read path =
  match Live_portfolio.load ~path with
  | Ok t -> t
  | Error err ->
      _fail (sprintf "Failed to read %s: %s" path (Error.to_string_hum err))

(* The single write path for all three subcommands: an edit that failed
   validation never reaches the file, and a dry run renders exactly what a real
   write would have produced. *)
let _commit ~path ~dry_run edited =
  match edited with
  | Error err -> _fail (Error.to_string_hum err)
  | Ok t when dry_run -> print_string (Live_portfolio.to_file_contents t)
  | Ok t -> (
      match Live_portfolio.save t ~path with
      | Ok () -> printf "Wrote %s\n" path
      | Error err ->
          _fail
            (sprintf "Failed to write %s: %s" path (Error.to_string_hum err)))

let _date_arg = Command.Arg_type.create Date.of_string

(* Flags every subcommand shares. *)
let _common =
  let%map_open.Command path =
    flag "--portfolio"
      (required Filename_unix.arg_type)
      ~doc:"PATH Live-portfolio sexp file to edit in place"
  and as_of =
    flag "--as-of" (required _date_arg)
      ~doc:"DATE Date to stamp on the file (YYYY-MM-DD); never the wall clock"
  and dry_run =
    flag "--dry-run" no_arg
      ~doc:" Print the resulting file to stdout instead of writing it"
  in
  (path, as_of, dry_run)

let _symbol_flag = "--symbol"
let _stop_price_flag = "--stop-price"

let _record_command =
  Command.basic
    ~summary:
      "Record a new fill: append a position and debit shares * entry-price \
       from cash. Fails if the symbol is already held."
    (let%map_open.Command path, as_of, dry_run = _common
     and symbol =
       flag _symbol_flag (required string) ~doc:"SYM Ticker (case-insensitive)"
     and shares = flag "--shares" (required int) ~doc:"N Shares filled"
     and entry_price = flag "--entry-price" (required float) ~doc:"X Fill price"
     and entry_date =
       flag "--entry-date" (optional _date_arg)
         ~doc:"DATE Date opened (YYYY-MM-DD; defaults to --as-of)"
     and stop_price =
       flag _stop_price_flag (required float)
         ~doc:"Y Initial stop, which must sit below the entry"
     in
     fun () ->
       let entry_date = Option.value entry_date ~default:as_of in
       let position : Live_portfolio.position =
         { symbol; shares; entry_price; entry_date; stop_price }
       in
       _commit ~path ~dry_run
         (Portfolio_edit.record (_read path) ~as_of ~position))

let _close_command =
  Command.basic
    ~summary:
      "Close a position in full: credit shares-held * exit-price to cash and \
       drop the holding."
    (let%map_open.Command path, as_of, dry_run = _common
     and symbol =
       flag _symbol_flag (required string) ~doc:"SYM Ticker (case-insensitive)"
     and exit_price =
       flag "--exit-price" (required float) ~doc:"X Exit price"
     in
     fun () ->
       _commit ~path ~dry_run
         (Portfolio_edit.close (_read path) ~as_of ~symbol ~exit_price))

(* The two trim flags describe one sale, so neither is meaningful alone. *)
let _parse_trim ~trim_shares ~trim_price =
  match (trim_shares, trim_price) with
  | None, None -> Ok None
  | Some shares, Some price -> Ok (Some { Portfolio_edit.shares; price })
  | _ ->
      Or_error.error_string
        "--trim-shares and --trim-price must be given together"

let _adjust_command =
  Command.basic
    ~summary:
      "Adjust an open position: move its stop (no cash movement) and/or trim \
       part of it (crediting cash). Use `close` for a full exit."
    (let%map_open.Command path, as_of, dry_run = _common
     and symbol =
       flag _symbol_flag (required string) ~doc:"SYM Ticker (case-insensitive)"
     and stop_price =
       flag _stop_price_flag (optional float)
         ~doc:"Y New working stop (may sit above the entry once in profit)"
     and trim_shares =
       flag "--trim-shares" (optional int)
         ~doc:"N Shares to sell; must be fewer than those held"
     and trim_price =
       flag "--trim-price" (optional float) ~doc:"X Fill price of the trim"
     in
     fun () ->
       match _parse_trim ~trim_shares ~trim_price with
       | Error err -> _fail (Error.to_string_hum err)
       | Ok trim ->
           _commit ~path ~dry_run
             (Portfolio_edit.adjust (_read path) ~as_of ~symbol ?stop_price
                ?trim ()))

let command =
  Command.group
    ~summary:
      "Edit the live-portfolio sexp file, keeping cash and the position list \
       in step."
    [
      ("record", _record_command);
      ("close", _close_command);
      ("adjust", _adjust_command);
    ]

let () = Command_unix.run command

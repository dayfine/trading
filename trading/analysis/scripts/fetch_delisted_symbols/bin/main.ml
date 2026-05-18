(** Fetch the EODHD US delisted-symbols roster and write it as a sexp file.

    Companion to [dev/notes/eodhd-delisted-roster-unlock-2026-05-18.md] §P1.
    Hits [/api/exchange-symbol-list/US?delisted=1] (via
    [Eodhd.Http_client.get_delisted_symbols]) and emits the response as a
    self-describing sexp at the configured output path.

    Typical usage:
    {v
      fetch_delisted_symbols.exe \
        --output-path data/delisted_symbols.sexp \
        --secrets-path trading/analysis/data/sources/eodhd/secrets
    v}

    The sexp shape is:
    {v
      ((generated_at YYYY-MM-DD)
       (source_endpoint "/api/exchange-symbol-list/US?delisted=1")
       (symbols (
         ((code CODE) (name "...") (exchange EX) (asset_type AT))
         ...
       )))
    v}

    Output is ~3 MB (vs ~8 MB raw JSON). Downstream P2 work builds the
    delisted-aware composition pool by joining this roster with a per-symbol
    bar-availability check on each snapshot date. *)

open Core
open Async

(** {1 On-disk sexp shape} *)

type entry = {
  code : string;
  name : string;
  exchange : string;
  asset_type : Eodhd.Asset_type.t;
}
[@@deriving sexp]

type t = {
  generated_at : Date.t;
  source_endpoint : string;
  symbols : entry list;
}
[@@deriving sexp]

let _of_metadata (m : Eodhd.Http_client.symbol_metadata) : entry =
  {
    code = m.code;
    name = m.name;
    exchange = m.exchange;
    asset_type = m.asset_type;
  }

(** {1 Token loading} *)

let _read_token ~secrets_path =
  try Ok (In_channel.read_all secrets_path |> String.rstrip)
  with Sys_error msg ->
    Status.error_invalid_argument
      (Printf.sprintf "failed to read secrets %s: %s" secrets_path msg)

(** {1 Output writing} *)

let _save_atomic ~path roster : unit Status.status_or =
  let tmp_path = path ^ ".tmp" in
  try
    Out_channel.write_all tmp_path ~data:(Sexp.to_string_hum (sexp_of_t roster));
    Stdlib.Sys.rename tmp_path path;
    Ok ()
  with Sys_error msg | Failure msg ->
    (try Stdlib.Sys.remove tmp_path with _ -> ());
    Status.error_internal
      (Printf.sprintf "fetch_delisted_symbols: write failed: %s" msg)

(** {1 Run + report} *)

let _per_type_counts entries =
  let tbl = Hashtbl.create (module String) in
  List.iter entries ~f:(fun e ->
      let key = Eodhd.Asset_type.show e.asset_type in
      Hashtbl.update tbl key ~f:(function None -> 1 | Some n -> n + 1));
  Hashtbl.to_alist tbl
  |> List.sort ~compare:(fun (_, a) (_, b) -> Int.compare b a)

let _print_summary roster =
  Core.printf "Wrote %d delisted symbols.\n" (List.length roster.symbols);
  Core.print_string "Per-type counts (top entries):\n";
  let counts = _per_type_counts roster.symbols in
  List.iter counts ~f:(fun (label, n) -> Core.printf "  %-32s %d\n" label n)

let _run ~output_path ~secrets_path =
  let open Deferred.Result.Let_syntax in
  let%bind token = _read_token ~secrets_path |> Deferred.return in
  let%bind listings = Eodhd.Http_client.get_delisted_symbols ~token () in
  Core.printf "EODHD delisted-listing returned %d entries.\n%!"
    (List.length listings);
  let today = Date.today ~zone:Time_float.Zone.utc in
  let roster =
    {
      generated_at = today;
      source_endpoint = "/api/exchange-symbol-list/US?delisted=1";
      symbols = List.map listings ~f:_of_metadata;
    }
  in
  let%bind () = _save_atomic ~path:output_path roster |> Deferred.return in
  _print_summary roster;
  Core.printf "Wrote %s\n%!" output_path;
  Deferred.Result.return ()

let _main ~output_path ~secrets_path () =
  _run ~output_path ~secrets_path >>= function
  | Ok () -> return ()
  | Error e ->
      Core.eprintf "Error: %s\n" (Status.show e);
      exit 1

let _default_secrets_path = "trading/analysis/data/sources/eodhd/secrets"

let command =
  Command.async
    ~summary:
      "Fetch + cache the EODHD US delisted-symbols roster (P1 of the \
       delisted-aware universe agenda — see \
       dev/notes/eodhd-delisted-roster-unlock-2026-05-18.md)"
    (let%map_open.Command output_path =
       flag "output-path" (required string)
         ~doc:"PATH Where to write delisted_symbols.sexp"
     and secrets_path =
       flag "secrets-path"
         (optional_with_default _default_secrets_path string)
         ~doc:"PATH EODHD API token file (default: repo-local secrets)"
     in
     _main ~output_path ~secrets_path)

let () = Command_unix.run command

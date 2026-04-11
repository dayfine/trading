open Async
open Core

(** Library powering the [fetch_symbols.exe] script. Exposes [fetch_one] so the
    per-symbol path can be unit-tested with an injected HTTP fetch, and [run] as
    the CLI entrypoint. *)

val fetch_one :
  ?fetch:Eodhd.Http_client.fetch_fn ->
  token:string ->
  data_dir:Fpath.t ->
  string ->
  (string, string) Result.t Deferred.t
(** Fetch historical bars for a single symbol and cache them under [data_dir].

    On success returns [Ok symbol]. On any failure (HTTP error, empty bar list,
    metadata/CSV write failure) returns [Error symbol] without raising. An empty
    bar list is treated as a soft failure: a warning is printed and the symbol
    is skipped. The optional [?fetch] hook allows tests to inject a mock HTTP
    client. *)

val run :
  symbols_flag:string option ->
  data_dir_str:string ->
  api_key_flag:string option ->
  unit ->
  unit Deferred.t
(** Entrypoint used by the CLI. Resolves the symbol list (from [--symbols] or
    from the universe manifest under [data_dir_str]) and fetches each symbol in
    order, printing a progress line per symbol and a
    [Done: %d fetched, %d errors.] summary at the end. Prints
    [No symbols to fetch.] and returns immediately if the resolved list is
    empty. Exits the process with code 1 if no API token is resolvable. *)

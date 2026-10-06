(** Library behind [fetch_corporate_actions.exe]: fetch EODHD dividends and
    splits per symbol and store them as {!Corporate_actions} files.

    {1 Symbol to EODHD ticker}

    The data store's symbol directory name is the EODHD code the price fetcher
    ([fetch_symbols.exe]) requested, including delisted reuse legs such as
    [APC_old] or [ANET_old1]. The price fetcher requests [/api/eod/<SYM>], which
    EODHD reads as [<SYM>.US] when [SYM] has no dot and as [<code>.<exchange>]
    when it does ([GSPC.INDX], [BRK.B]). {!eodhd_ticker} reproduces that split,
    so the corporate-action requests name the same instrument as the bars. *)

open Async

val eodhd_ticker : string -> string * string
(** [eodhd_ticker symbol] is the [(code, exchange)] pair passed to the EODHD
    corporate-action endpoints: split at the last ['.'] when [symbol] contains
    one ([("GSPC", "INDX")] for ["GSPC.INDX"]), else [(symbol, "US")]. *)

(** Result of one symbol's fetch. *)
type outcome =
  | Fetched of { dividends : int; splits : int }
      (** Both endpoints answered and at least one event was recorded; both
          files were written. Counts are the events written. *)
  | Empty  (** Both endpoints answered with no events; header-only files. *)
  | Failed of string
      (** An endpoint or a file write failed; the message says which. Nothing is
          written unless both fetches succeeded. *)
  | Skipped  (** Both files already existed and [refresh] was off. *)
[@@deriving show, eq]

val fetch_symbol :
  ?fetch:Eodhd.Http_client.fetch_fn ->
  token:string ->
  data_dir:Fpath.t ->
  string ->
  outcome Deferred.t
(** [fetch_symbol ?fetch ~token ~data_dir symbol] fetches [symbol]'s dividends
    and splits (via {!eodhd_ticker}) and, when both succeed, writes both
    {!Corporate_actions} files, replacing any existing ones. Never raises.
    [?fetch] stubs the HTTP layer for tests; omitted, it is the live client.
    Does not check whether the files already exist (see {!run}). *)

type config = {
  data_dir : Fpath.t;  (** Root of the per-symbol data store. *)
  refresh : bool;  (** Re-fetch symbols whose two files already exist. *)
  sleep_ms : int;  (** Polite pause after each symbol's fetch, in ms. *)
  parallel : int;  (** Maximum symbols in flight; [1] is sequential. *)
}
(** How {!run} iterates. *)

type summary = { ok : int; empty : int; error : int; skipped : int }
[@@deriving show, eq]
(** Per-outcome symbol counts from one {!run}. *)

val run :
  ?fetch:Eodhd.Http_client.fetch_fn ->
  ?log:(string -> unit) ->
  token:string ->
  config ->
  string list ->
  summary Deferred.t
(** [run ?fetch ?log ~token config symbols] fetches every symbol in [symbols],
    skipping any whose two files exist unless [config.refresh], and returns the
    outcome counts. One progress line per symbol goes to [?log] (default:
    stdout); failed symbols are logged with their error. *)

val render_summary : summary -> string
(** [render_summary s] is the multi-line coverage report printed at the end of a
    run (symbols ok / empty / error / skipped, and the total). *)

val parse_symbols : string -> string list
(** [parse_symbols contents] reads a symbols file: one symbol per line, blank
    lines and lines starting with ['#'] ignored, surrounding whitespace
    stripped. *)

val symbols_in_data_dir : Fpath.t -> string list
(** [symbols_in_data_dir data_dir] lists every symbol directory
    [<data_dir>/<L1>/<L2>/<SYM>] that holds a [data.csv], sorted. This is the
    default universe when no symbols file is given: every symbol we hold bars
    for, delisted [_old] legs included. *)

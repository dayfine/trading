(** Universe file — selects which symbols a scenario runs against.

    The file is a sexp committed alongside scenario fixtures. Two shapes are
    supported:

    - [Pinned] — an explicit [(symbol, sector)] list. The runner uses exactly
      these symbols and ignores [data/sectors.csv] for the scenario. Used by the
      small universe (~300 symbols).
    - [Full_sector_map] — a sentinel asking the runner to use whatever symbols
      are in [data/sectors.csv]. Used by the broad universe (full scale, nightly
      runs).

    See [dev/plans/backtest-scale-optimization-2026-04-17.md] §Step 1 for the
    rationale and the selection criteria behind the small universe. *)

type pinned_entry = {
  symbol : string;  (** Ticker, e.g. ["AAPL"]. *)
  sector : string;  (** GICS sector, e.g. ["Information Technology"]. *)
}
[@@deriving sexp]

type t =
  | Pinned of pinned_entry list
      (** Use only these symbols. The sector given here overrides whatever is in
          [data/sectors.csv] for the scenario — the file is self-contained. *)
  | Full_sector_map
      (** Fall back to [data/sectors.csv] (pre-migration behaviour). *)
[@@deriving sexp]

val load : string -> t
(** [load path] parses a universe-file sexp. Raises [Failure] on malformed
    input. *)

val symbol_count : t -> int option
(** Number of pinned symbols, or [None] for [Full_sector_map] (count unknown at
    load time). *)

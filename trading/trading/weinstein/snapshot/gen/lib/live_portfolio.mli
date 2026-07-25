(** Live portfolio state for the weekly-picks execution protocol (Phase A).

    A human-editable sexp file recording the trader's real holdings, threaded
    into {!Weekly_snapshot_generator.generate} so the weekly report shows held
    positions and sizes new picks against actual cash + exposure.

    Canonical location: [dev/weekly-picks/portfolio.sexp]. The user records
    fills by editing this file directly (a fill-recording CLI is a Phase-C+
    option, not built here).

    {1 On-disk shape}

    {v
    ((cash 100000.0)
     (as_of 2026-07-24)
     (positions
      (((symbol AAPL) (shares 100) (entry_price 180.0)
        (entry_date 2026-06-13) (stop_price 168.0)))))
    v}

    Serialization is via OCaml [sexp], same as the rest of the weekly-picks
    subsystem. An empty [positions] list serializes as [()] and round-trips. *)

open Core

type position = {
  symbol : string;  (** Ticker of the held position. *)
  shares : int;  (** Share count (positive; long-only for now). *)
  entry_price : float;  (** Fill price the position was opened at. *)
  entry_date : Date.t;  (** Date the position was opened. *)
  stop_price : float;  (** Current stop price the trader has working. *)
}
[@@deriving sexp, eq, show]
(** One live holding. *)

type t = {
  cash : float;  (** Current cash balance available to fund new entries. *)
  as_of : Date.t;
      (** Date the trader last updated this file. Informational; the generator's
          own [--as-of] drives pricing. *)
  positions : position list;  (** Open holdings. May be empty. *)
}
[@@deriving sexp, eq, show]
(** A complete live-portfolio snapshot. *)

val load : path:string -> t Or_error.t
(** [load ~path] parses the sexp portfolio file at [path]. Returns an error
    (rather than raising) on a missing file or malformed sexp so the CLI can
    report it cleanly. *)

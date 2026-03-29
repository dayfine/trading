(** Weinstein trading state persistence.

    Captures the complete state needed to resume a weekly Weinstein scan between
    sessions: portfolio positions, per-position stop states, stage history for
    each ticker, and the trade log.

    The state is serialised to JSON and written atomically (temp-file + rename)
    so a crash mid-write never leaves a corrupt state file.

    {1 Design}

    - Does NOT modify the existing [Portfolio] or [Position] modules.
    - The stop states are stored alongside (not inside) the position map.
    - The [prior_stages] map lets the stage classifier detect transitions across
      sessions without replaying the full bar history.
    - The [trade_log] is append-only; entries are never deleted.

    {1 JSON Format}

    Small (<100 KB in practice). Human-readable for debugging. Schema evolution
    is handled by ignoring unknown keys during load. *)

open Core

(** {1 Trade Log} *)

type trade_log_entry = {
  date : Date.t;
  ticker : string;
  action : [ `Buy | `Sell | `Short | `Cover ];
  shares : int;
  price : float;
  grade : Weinstein_types.grade option;
      (** Screener grade at entry, if available. *)
  reason : string;  (** Human-readable rationale (screener rationale list). *)
}
[@@deriving show, eq]
(** One entry in the trade log. *)

(** {1 State} *)

type t = {
  portfolio : Trading_portfolio.Portfolio.t;
      (** Current cash and position quantities. *)
  stop_states : (string * Weinstein_stops.stop_state) list;
      (** Per-ticker Weinstein stop state. *)
  prior_stages : (string * Weinstein_types.stage) list;
      (** Most recent stage classification per ticker, for transition tracking
          across sessions. *)
  trade_log : trade_log_entry list;
      (** Chronological trade history. Append-only. *)
  last_scan_date : Date.t option;
      (** The date of the most recent scan, or [None] before the first scan. *)
}
[@@deriving show]
(** Complete Weinstein session state. *)

val empty : initial_cash:float -> t
(** [empty ~initial_cash] creates a fresh state with the given starting cash and
    no positions, stops, or trade history. *)

val add_log_entry : t -> trade_log_entry -> t
(** [add_log_entry state entry] returns state with [entry] appended to the trade
    log. *)

val set_stop_state : t -> ticker:string -> Weinstein_stops.stop_state -> t
(** [set_stop_state state ~ticker stop_state] updates (or inserts) the stop
    state for [ticker]. *)

val get_stop_state : t -> ticker:string -> Weinstein_stops.stop_state option
(** [get_stop_state state ~ticker] retrieves the current stop state for
    [ticker], or [None] if not tracked. *)

val remove_stop_state : t -> ticker:string -> t
(** [remove_stop_state state ~ticker] removes the stop state entry for [ticker].
    Use when a position is closed. *)

val set_prior_stage : t -> ticker:string -> Weinstein_types.stage -> t
(** [set_prior_stage state ~ticker stage] records the most recent stage
    classification for [ticker]. *)

val get_prior_stage : t -> ticker:string -> Weinstein_types.stage option
(** [get_prior_stage state ~ticker] retrieves the last recorded stage for
    [ticker], or [None] if not seen before. *)

(** {1 Persistence} *)

val save : t -> path:string -> unit Status.status_or
(** [save state ~path] serialises [state] to JSON and writes it atomically to
    [path] (writes to [path ^ ".tmp"] then renames).

    Returns [Error] if the file cannot be written. *)

val load : path:string -> t Status.status_or
(** [load ~path] deserialises state from the JSON file at [path].

    Returns [Error] if the file cannot be read or the JSON is malformed. *)

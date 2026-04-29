(** Per-run collector of force-liquidation events.

    Mirrors the shape of {!Stop_log} / {!Trade_audit}: the strategy emits
    {!Weinstein_strategy.Audit_recorder.force_liquidation_event}s; the backtest
    runner threads them into a collector here, then drains the collector at
    end-of-run for persistence as [force_liquidations.sexp] and post-processing
    of [trades.csv]'s [exit_trigger] column.

    Closes G4 from [dev/notes/short-side-gaps-2026-04-29.md]. Each event is
    evidence the strategy's primary stop machinery failed to protect the trade —
    non-zero counts on a release run flag a regression in stops or sizing.

    See {!Force_liquidation_log.t} for the collector type, [create] / [record]
    for the API, and [save_sexp] for the on-disk shape. *)

open Portfolio_risk

type t
(** Mutable collector of force-liquidation events. Not thread-safe. One per
    backtest run. *)

val create : unit -> t
(** Empty collector. *)

val record : t -> Force_liquidation.event -> unit
(** Append one event. *)

val events : t -> Force_liquidation.event list
(** All recorded events, sorted by [(date, position_id)] ascending. *)

val count : t -> int
(** Number of recorded events. Equivalent to [List.length (events t)]. *)

(** {1 Sexp persistence} *)

type artefact = { events : Force_liquidation.event list } [@@deriving sexp]
(** On-disk envelope for [force_liquidations.sexp]. Wrapping a record (rather
    than a bare list) keeps the file forward-compatible with future fields (e.g.
    config snapshot, peak history). *)

val save_sexp : path:string -> t -> unit
(** Save [events t] to [path] as [force_liquidations.sexp]. No-op when the
    collector is empty — empty list scenarios produce no file. *)

val load_sexp : string -> Force_liquidation.event list
(** Inverse of {!save_sexp}. Raises if the file does not exist or fails to
    parse. *)

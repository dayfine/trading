(** Pure compute helpers for the Full tier of {!Bar_loader}.

    A Full-tier record is a raw OHLCV tail for one symbol — the shape the
    strategy pipeline needs for breakout detection, daily path simulation, and
    weekly aggregation. This module is the pure build step that turns a list of
    bars into the scalars {!Bar_loader.Full.t} needs (validates non-emptiness,
    captures the final bar's date as [as_of]).

    Keeping the build logic here mirrors {!Summary_compute}: the integration
    layer in {!Bar_loader} handles CSV loading and tier bookkeeping, while this
    module stays free of I/O and is unit-testable against synthetic bar lists.

    All functions in this module are pure. *)

open Core

(** {1 Configuration} *)

type config = {
  tail_days : int;
      (** Upper bound on the daily-bar tail the Full loader fetches per symbol.
          Must be large enough to cover the longest analysis window the strategy
          uses. Default: 1800 (~ 7 years of trading days — enough for a 30-week
          MA plus several years of path history). *)
}
[@@deriving sexp, show, eq]

val default_config : config
(** Sensible default: [{ tail_days = 1800 }]. *)

(** {1 Build step} *)

type full_values = {
  bars : Types.Daily_price.t list;
      (** The input bars, retained verbatim. Ordered ascending by date. *)
  as_of : Date.t;  (** Date of the last bar in [bars]. *)
}
[@@deriving show, eq]
(** Mirrors {!Bar_loader.Full.t} minus the [symbol] key. [Types.Daily_price.t]
    has no sexp converters, so this record omits [sexp]. *)

val compute_values : bars:Types.Daily_price.t list -> full_values option
(** [compute_values ~bars] returns [Some { bars; as_of }] when [bars] is
    non-empty, where [as_of] is the date of the last element. Returns [None]
    when [bars] is empty — the caller should leave the symbol at its current
    tier in that case.

    Mirrors the shape of {!Summary_compute.compute_values} so the Bar_loader
    integration layer can treat the two tiers symmetrically. *)

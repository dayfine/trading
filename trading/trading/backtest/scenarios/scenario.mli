(** Declarative backtest scenario: date range, config overrides, and expected
    metric ranges. Used by {!Scenario_runner} to run and validate a single run.
*)

open Core

type range = { min_f : float; max_f : float } [@@deriving sexp]
(** A closed [min..max] interval. In scenario sexp files this is written as
    [((min <f>) (max <f>))]. *)

type period = { start_date : Date.t; end_date : Date.t } [@@deriving sexp]

type expected = {
  total_return_pct : range;
  total_trades : range;
  win_rate : range;
  sharpe_ratio : range;
  max_drawdown_pct : range;
  avg_holding_days : range;
}
[@@deriving sexp]

type t = {
  name : string;
  description : string;
  period : period;
  config_overrides : Sexp.t list;
      (** Partial config sexps deep-merged into the default Weinstein config, in
          order. Empty list means the default config. *)
  expected : expected;
}
[@@deriving sexp] [@@sexp.allow_extra_fields]
(** Extra fields in the scenario file (e.g. [universe_size]) are tolerated —
    they document the context the scenario was written for but aren't part of
    the runtime contract. *)

val load : string -> t
(** Load and parse a scenario sexp file. Raises [Failure] on malformed input. *)

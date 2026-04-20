(** Selector for the bar-loading strategy used by {!Backtest.Runner}.

    Lives in its own tiny library so that both [backtest] (the runner) and
    [scenario_lib] (the scenario sexp parser) can reference the same type
    without introducing a circular dependency between them.

    See [dev/plans/backtest-tiered-loader-2026-04-19.md] §"Legacy vs Tiered
    flag" for the rationale. The concrete Tiered execution path arrives in
    increment 3f; today this is plumbing only. *)

type t =
  | Legacy
      (** Pre-existing path: [Backtest.Runner] materializes every universe
          symbol's bars up-front via [Simulator.create]'s per-symbol bar
          loaders. Memory grows with universe size; current production
          behaviour. *)
  | Tiered
      (** New path: [Bar_loader] keeps the working set bounded by tiering
          symbols across Metadata / Summary / Full and promoting/demoting
          on demand. Not yet wired through the runner — see 3f. *)
[@@deriving sexp, show, eq]

val to_string : t -> string
(** Lowercase string form ([Legacy] -> ["legacy"], [Tiered] -> ["tiered"]).
    Stable, used by CLI flag parsing. *)

val of_string : string -> t
(** Inverse of {!to_string}. Accepts ["legacy"] / ["tiered"] (case-insensitive).
    Raises [Failure] on any other input. *)

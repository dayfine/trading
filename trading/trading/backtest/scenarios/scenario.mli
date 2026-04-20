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
  unrealized_pnl : range option; [@sexp.option]
      (** Dollar range for end-of-simulation unrealized P&L. [None] skips the
          check — use for scenarios where no positions remain open at the end or
          where the value is otherwise not meaningful to pin. Scenarios with
          open positions should pin a non-zero range to guard against regression
          to the UnrealizedPnl=0 bug (see PR #393). *)
}
[@@deriving sexp]

val default_universe_path : string
(** Default [universe_path] assigned to scenarios that omit the field. Relative
    to [trading/test_data/backtest_scenarios/]. *)

type t = {
  name : string;
  description : string;
  period : period;
  universe_path : string; [@sexp.default default_universe_path]
      (** Path to the universe file this scenario runs against, relative to
          [trading/test_data/backtest_scenarios/].

          Two tiers are supported:
          - [universes/small.sexp] (default) — a pinned ~300-symbol curated
            universe, committed to the repo. Fast, low memory, local-friendly.
          - [universes/broad.sexp] — sentinel that defers to the full sector-map
            loaded from [data/sectors.csv] (current behaviour). Intended for
            nightly/GHA scale runs.

          The runner loads the file, resolves it against the fixtures root, and
          filters the loaded sector-map accordingly. See
          [dev/plans/backtest-scale-optimization-2026-04-17.md] §Step 1. *)
  config_overrides : Sexp.t list;
      (** Partial config sexps deep-merged into the default Weinstein config, in
          order. Empty list means the default config. *)
  loader_strategy : Loader_strategy.t option; [@sexp.option]
      (** Selects the bar-loader execution strategy used for this scenario:
          - [None] (default) — Runner falls back to its own default
            ([Loader_strategy.Legacy] today). Pre-3e scenario files have no
            field and continue to behave exactly as before.
          - [Some Legacy] — explicit opt-in to the legacy path. Useful for
            scenarios that should pin the legacy behaviour even after the global
            default flips.
          - [Some Tiered] — opt-in to the tiered loader. Today this raises
            inside the runner since the implementation lands in increment 3f of
            [dev/plans/backtest-tiered-loader-2026-04-19.md]; once available,
            scenarios will use this to exercise it. *)
  expected : expected;
}
[@@deriving sexp] [@@sexp.allow_extra_fields]
(** Extra fields in the scenario file (e.g. [universe_size]) are tolerated —
    they document the context the scenario was written for but aren't part of
    the runtime contract. *)

val load : string -> t
(** Load and parse a scenario sexp file. Raises [Failure] on malformed input. *)

val in_range : range -> float -> bool
(** [in_range r v] is [true] iff [v] lies in the closed interval [r]. *)

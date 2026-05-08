(** Parse a grid-search spec sexp file into the inputs {!Tuner.Grid_search.run}
    consumes. The CLI binary's only job is to wire this spec to a
    {!Backtest.Runner.run_backtest}-backed evaluator; this module pins the
    on-disk shape so the binary stays a thin wrapper. *)

(** Sexp-friendly mirror of {!Tuner.Grid_search.objective}. The grid-search
    library's [objective] type is not [\@\@deriving sexp] (the [param_spec] type
    alias and the underlying ppx context that built the lib don't carry the
    sexp_of converters at the lib's call site). We re-declare here as a small
    variant ppx-derived from sexp and convert via {!to_grid_objective}. *)
type objective_spec =
  | Sharpe
  | Calmar
  | TotalReturn
  | Concavity_coef
  | Composite of
      (Trading_simulation_types.Metric_types.metric_type * float) list
[@@deriving sexp]

type t = {
  params : (string * float list) list;
      (** Structural shape of {!Tuner.Grid_search.param_spec}. Sexp:
          [(("key.path1" (v1 v2 ...)) ("key.path2" (...)))]. *)
  objective : objective_spec;  (** Scoring objective. *)
  scenarios : string list;
      (** Paths to scenario sexp files, resolved relative to the current working
          directory and loaded via {!Scenario_lib.Scenario.load} when the binary
          runs the evaluator. *)
}
[@@deriving sexp]
(** A grid-search spec on disk. Example sexp:
    {[
    (params
       (("screening.weights.rs" (0.2 0.3 0.4))
          ("screening.weights.volume" (0.2 0.3 0.4))))
      (objective Sharpe)
      (scenarios
         ("trading/test_data/backtest_scenarios/smoke/bull-2019.sexp"
            "trading/test_data/backtest_scenarios/smoke/crash-2008.sexp"))
    ]} *)

val load : string -> t
(** Load and parse a spec sexp file. Raises [Failure] on malformed input. *)

val to_grid_objective : objective_spec -> Tuner.Grid_search.objective
(** Convert the parsed objective into the lib-side [Grid_search.objective]
    variant. *)

val to_grid_param_spec :
  (string * float list) list -> Tuner.Grid_search.param_spec
(** Identity at the value level — re-types the structural list as the lib's
    [param_spec] alias. Exposed so the binary doesn't need to mention the
    coercion idiom inline. *)

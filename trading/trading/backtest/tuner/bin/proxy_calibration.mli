(** CLI entry point for the M1 T1.4 proxy-fidelity calibration step.

    Reads two on-disk [fold_actuals.sexp] files (cheap-proxy and expensive
    walk-forward runs of Cell E), joins by [fold_name], computes the Spearman
    rank correlation of a chosen per-fold metric, and emits a verdict against
    the {!Tuner.Proxy_calibration_lib.acceptance_threshold} (default [0.7]).

    {b Why [fold_actuals.sexp], not [aggregate.sexp].} The aggregate carries
    only cross-fold summary statistics (mean / stdev / min / max per metric);
    Spearman ρ between cheap and expensive requires the per-fold sample lists,
    which live in [fold_actuals.sexp] (the sibling artefact written by
    {!Walk_forward_runner.main}). See
    `dev/notes/t1-4-calibration-procedure-<date>.md` for the operator's
    incantation.

    Spec: `dev/plans/tuning-research-driven-program-v2-2026-05-25.md`
    §M1 T1.4. *)

type metric_arg = Sharpe | TotalReturn | Calmar | CAGR | MaxDrawdown
[@@deriving show, eq]
(** CLI-visible metric selector. The CamelCased constructors are matched
    case-insensitively against the [--metric] argument. *)

val metric_arg_of_string : string -> metric_arg
(** Parse a CLI [--metric] argument. Accepts the four token aliases (case
    insensitive): [sharpe], [totalreturn] / [total_return] / [total-return],
    [calmar], [cagr], [maxdrawdown] / [max_drawdown] / [max-drawdown].

    @raise Failure on unrecognised metric. *)

val metric_arg_to_lib :
  metric_arg ->
  [ `Sharpe | `Total_return_pct | `Calmar | `CAGR | `Max_drawdown_pct ]
(** Adapter: maps {!metric_arg} to the polymorphic-variant input shape that
    {!Tuner.Proxy_calibration_lib.matched_pairs} expects. *)

type cli_args = {
  cheap_path : string;
      (** Path to the cheap-proxy [fold_actuals.sexp] (e.g. the 6-fold run). *)
  expensive_path : string;
      (** Path to the expensive [fold_actuals.sexp] (e.g. the 26-fold run). *)
  metric : metric_arg;  (** Default [Sharpe]. *)
  threshold : float;
      (** Acceptance threshold for ρ. Default
          {!Tuner.Proxy_calibration_lib.acceptance_threshold} (= 0.7). *)
  out_path : string option;
      (** Optional markdown report path; [None] = print to stdout. *)
}
[@@deriving show, eq]

val parse_args : string list -> cli_args
(** Parse a [Sys.get_argv |> Array.to_list |> List.tl] arg list into the
    structured {!cli_args}. Recognised flags:

    - [--cheap <path>] (required)
    - [--expensive <path>] (required)
    - [--metric sharpe|totalreturn|calmar|cagr|maxdrawdown] (default [sharpe])
    - [--threshold <float>] (default {!Tuner.Proxy_calibration_lib.acceptance_threshold})
    - [--out <path>] (optional)

    @raise Failure on missing required flags, unknown flags, or malformed
      values. *)

val load_fold_actuals :
  string -> Walk_forward.Walk_forward_types.fold_actual list
(** Load a [fold_actuals.sexp] file produced by {!Walk_forward_runner}. The
    on-disk shape is a [Sexp.List] of [fold_actual_of_sexp]-shaped records.

    @raise Failure with a contextualised message when the file is missing or
      the sexp doesn't parse. *)

val render_markdown :
  cheap_path:string ->
  expensive_path:string ->
  metric:metric_arg ->
  threshold:float ->
  pairs:Tuner.Proxy_calibration_lib.fold_pair list ->
  rho:float ->
  verdict:Tuner.Proxy_calibration_lib.verdict ->
  string
(** Render the calibration result as a self-contained markdown report.
    Deterministic — same inputs produce byte-identical output. *)

val main : unit -> unit
(** Standard executable entry point. Exits with status [0] on PASS and [1] on
    FAIL so CI gates can branch on the verdict. *)

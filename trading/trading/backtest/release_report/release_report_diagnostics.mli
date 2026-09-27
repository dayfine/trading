(** Supplementary release-report comparison sections: trade quality (behavioural
    / Weinstein-conformance metrics) and the optimal-strategy counterfactual
    delta.

    Pure string formatting only — no I/O. Extracted from {!Release_report}
    (issue tracked as a file-length cleanup; see
    [trading/devtools/checks/linter_exceptions.conf]) to keep both files under
    the function/file-length limits. This module takes small primitive/record
    inputs rather than {!Release_report}'s domain records ([scenario_run] etc.)
    so it has no dependency on [release_report.ml] — avoiding a circular module
    dependency within the [release_report] library, since
    [Release_report.render] is what calls into this module. [Release_report]
    adapts its loaded [scenario_run] pairs into these shapes before calling in.
*)

(** {1 Trade quality} *)

type trade_quality_pair = {
  name : string;  (** Scenario name, rendered as the section's subheading. *)
  current : Trade_audit_report.t option;
      (** Current-side trade-audit report, when [trade_audit.sexp] +
          [trades.csv] were both present and loaded successfully. *)
  prior : Trade_audit_report.t option;  (** Prior-side, same contract. *)
}
(** One paired scenario's trade-audit inputs. *)

val render_trade_quality : trade_quality_pair list -> string list
(** [render_trade_quality pairs] renders the "## Trade quality" section as a
    list of markdown lines (no trailing newline): behavioural metrics (Weinstein
    spirit score, mean/median R-multiple, trades/year with an over-trading flag,
    exit-winners/exit-losers-flagged counts, and decision-quality win rate) for
    every pair where at least one side has [Some _]. Returns [[]] when every
    pair has [None] on both sides — the caller should then omit the section
    entirely. *)

(** {1 Optimal-strategy delta} *)

type optimal_variant = {
  constrained_pct : float;
      (** Counterfactual total return for the [constrained] (macro-gate
          honouring) variant, in percentage-point units (e.g. [30.0] = +30%) —
          already normalized from the on-disk fraction. *)
  relaxed_pct : float;
      (** Same, for the [relaxed_macro] (macro-gate ignoring) variant. *)
}
(** One side's counterfactual optimal-strategy readings, pre-normalized to
    percentage-point units so this module never needs
    {!Release_report.optimal_summary}. *)

type optimal_side = {
  actual_total_return_pct : float;
      (** The run's actual total return, in percentage units (matches
          {!Release_report.actual.total_return_pct}). *)
  optimal : optimal_variant option;
      (** [None] when the scenario has no [optimal_summary.sexp]. *)
  report_link : string option;
      (** Relative path to [optimal_strategy.md], when present — rendered as a
          markdown link. [None] renders as an em-dash. *)
}
(** One side (current or prior) of a paired scenario's optimal-strategy inputs.
*)

type optimal_pair = {
  opt_name : string;
      (** Scenario name, rendered as the section's subheading. *)
  opt_current : optimal_side;
  opt_prior : optimal_side;
}
(** One paired scenario's optimal-strategy inputs. *)

val render_optimal_strategy : optimal_pair list -> string list
(** [render_optimal_strategy pairs] renders the "## Optimal-strategy delta"
    section as a list of markdown lines (no trailing newline): actual vs.
    constrained vs. relaxed-macro counterfactual total return, plus Δ (in
    percentage points) from actual to each variant, for every pair where at
    least one side has [Some _] for {!optimal_side.optimal}. Returns [[]] when
    every pair has [None] on both sides. *)

(** Multivariate feature screen over the all-eligible [trades.csv].

    Jointly regresses the counterfactual trade outcome ([return_pct], and the
    win indicator [return_pct > 0]) on the full decision-time feature vector to
    test whether any multivariate entry-selection signal survives that the
    univariate screens missed.

    This is a READ-ONLY, IN-SAMPLE screen. Its output feeds a screen-rigor
    calibrated verdict (no-build decision vs escalate-to-WF-CV); it must NOT be
    read as causal or deployable alpha. See
    [.claude/rules/mechanism-validation-rigor.md]. *)

type era_fit = {
  label : string;  (** Era label from {!Feature_matrix.era_bounds}. *)
  n_rows : int;  (** Rows falling in the era (pre complete-case). *)
  fit : (Regression.ols_result * Regression.logit_result) option;
      (** [None] when the era has too few complete-case rows to fit. *)
}

type t = {
  n_total : int;  (** Rows parsed from the input CSV(s). *)
  coverage : Feature_matrix.coverage list;  (** Per-feature None coverage. *)
  n_complete : int;  (** Complete-case rows used by the full fit. *)
  column_names : string list;  (** Design-matrix column labels. *)
  ols : Regression.ols_result;  (** Full-sample OLS of [return_pct]. *)
  logit : Regression.logit_result;  (** Full-sample logistic of the win flag. *)
  eras : era_fit list;  (** Per-era refits for sign-stability. *)
}

val screen :
  rows:Csv_rows.row list ->
  features:Feature_matrix.feature list ->
  (t, string) result
(** [screen ~rows ~features] runs the full-sample and per-era fits over the
    selected [features]. [Error] when the full sample has no complete-case rows
    or is rank-deficient. *)

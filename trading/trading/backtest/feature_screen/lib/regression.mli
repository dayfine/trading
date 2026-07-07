(** Dense OLS and logistic regression for the feature screen.

    Hand-rolled (no owl): the design matrix is [n × p] with [n] in the tens of
    thousands and [p < 20], so a [p × p] normal-equations solve via Gaussian
    elimination is trivial and exactly reproducible. All fits are IN-SAMPLE and
    intended only for a read-only screen — not for prediction or deployment. *)

type term = {
  name : string;  (** Column label (e.g. ["intercept"], ["rs_value"]). *)
  coef : float;  (** Fitted coefficient. *)
  se : float;
      (** Standard error (HC1-robust for OLS, model-based for logit). *)
  stat : float;  (** t-stat (OLS) or z-stat (logit) = [coef /. se]. *)
}

type ols_result = {
  terms : term list;  (** One per column, in design-matrix column order. *)
  r2 : float;  (** Coefficient of determination. *)
  n : int;  (** Rows used. *)
  p : int;  (** Columns (including intercept). *)
}

type logit_result = {
  terms : term list;  (** One per column. *)
  auc : float;  (** In-sample area under the ROC curve (rank-based). *)
  converged : bool;  (** Whether Newton/IRLS reached the tolerance. *)
  n : int;
  p : int;
}

val solve : float array array -> float array -> (float array, string) result
(** [solve a b] solves the square linear system [a x = b] by Gaussian
    elimination with partial pivoting. [Error] if [a] is singular. *)

val ols :
  x:float array array ->
  y:float array ->
  names:string list ->
  (ols_result, string) result
(** [ols ~x ~y ~names] fits ordinary least squares of [y] on the design matrix
    [x] (rows = observations, columns = predictors incl. an intercept column).
    Standard errors are heteroscedasticity-robust (White HC1). [names] labels
    the columns and must match [x]'s width. *)

val logistic :
  x:float array array ->
  y:float array ->
  names:string list ->
  (logit_result, string) result
(** [logistic ~x ~y ~names] fits a logistic regression of the 0/1 outcome [y] on
    [x] by Newton/IRLS (a small ridge stabilises near-singular steps). Reports
    model-based z-stats and the in-sample rank AUC. *)

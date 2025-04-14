(** Module for linear regression calculations and statistical analysis. This
    module provides functions for performing linear regression and calculating
    related statistical metrics. *)

type regression_stats = {
  intercept : float;  (** Y-intercept of the regression line *)
  slope : float;  (** Slope of the regression line *)
  r_squared : float;  (** Coefficient of determination *)
  residual_std : float;  (** Standard deviation of residuals *)
}
(** Statistics calculated from a linear regression analysis *)

val calculate_stats : float array -> float array -> regression_stats
(** Performs linear regression on the given data points and calculates various
    statistical metrics.
    @param x_data Array of x-coordinates
    @param y_data Array of y-coordinates
    @return regression_stats containing the calculated metrics *)

val predict : intercept:float -> slope:float -> float -> float
(** Predicts the y-value for a given x using the regression line.
    @param intercept Y-intercept of the regression line
    @param slope Slope of the regression line
    @param x Input x-value
    @return Predicted y-value *)

val predict_values : float array -> float -> float -> Owl.Dense.Ndarray.S.arr
(** Predicts multiple y-values for given x-values using the regression line.
    @param x Array of x-values
    @param intercept Y-intercept of the regression line
    @param slope Slope of the regression line
    @return Array of predicted y-values *)

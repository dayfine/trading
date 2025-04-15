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

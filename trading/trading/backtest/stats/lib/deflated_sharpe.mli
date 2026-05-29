(** Deflated Sharpe Ratio (Bailey and Lopez de Prado).

    When the "best" variant is picked out of N trials, its observed Sharpe is
    inflated by selection: the maximum of N noisy estimates exceeds the true
    common mean even if every variant has zero edge. The Deflated Sharpe Ratio
    (DSR) corrects this by testing the winner's Sharpe against the Sharpe a
    best-of-N search would produce under the null of no skill.

    Two closed forms are composed:

    - {!psr} — the Probabilistic Sharpe Ratio PSR(SR_star): the probability that
      the true Sharpe exceeds a benchmark SR_star, accounting for the higher
      moments (skew, kurtosis) of the return series and the sample length T.
    - {!expected_max_sharpe} — the benchmark SR_star itself: the expected
      maximum Sharpe across N independent trials under the null.

    {!deflated_sharpe} is [psr] evaluated at the SR_star from
    {!expected_max_sharpe}, i.e. the probability the winner's Sharpe is real
    after deflating for best-of-N. DSR and PSR return probabilities in the unit
    interval; {!expected_max_sharpe} returns a Sharpe level.

    Reference: Bailey and Lopez de Prado, "The Deflated Sharpe Ratio: Correcting
    for Selection Bias, Backtest Overfitting and Non-Normality" (2014). Gap C of
    [dev/plans/experiment-platform-2026-05-29.md]; shared with the Bayesian
    optimizer's best-of-N correction. *)

val euler_mascheroni : float
(** The Euler-Mascheroni constant gamma (approximately [0.5772156649]), used by
    {!expected_max_sharpe}. *)

val skewness : float list -> float
(** [skewness xs] is the population skewness gamma3 of [xs] (the third
    standardised moment, divisor [n] not [n - 1]). Raises [Invalid_argument] if
    [xs] has fewer than 2 elements or zero variance (skewness undefined). *)

val kurtosis : float list -> float
(** [kurtosis xs] is the population (non-excess) kurtosis gamma4 of [xs] (the
    fourth standardised moment; equals [3.0] for a normal sample). Raises
    [Invalid_argument] if [xs] has fewer than 2 elements or zero variance. *)

val psr :
  observed_sharpe:float ->
  benchmark_sharpe:float ->
  n_obs:int ->
  skewness:float ->
  kurtosis:float ->
  float
(** [psr ~observed_sharpe ~benchmark_sharpe ~n_obs ~skewness ~kurtosis] is the
    Probabilistic Sharpe Ratio. With [observed_sharpe = s],
    [benchmark_sharpe = b], [n_obs = t], [skewness = g3], [kurtosis = g4], it is

    [Normal_dist.cdf ((s -. b) *. sqrt (t - 1) /. sqrt (1 -. g3 *. s +. (g4 - 1)
     /. 4 *. s *. s))].

    [kurtosis] is the non-excess kurtosis ([3.0] for a normal sample). Raises
    [Invalid_argument] if [n_obs < 2] (the [sqrt (t - 1)] term needs at least 2
    observations) or if the variance term under the square root is non-positive
    (a degenerate higher-moment combination). *)

val expected_max_sharpe : n_trials:int -> sharpe_variance:float -> float
(** [expected_max_sharpe ~n_trials ~sharpe_variance] is the expected maximum
    Sharpe across [n_trials] independent trials under the null of no skill. With
    [n_trials = n] and [sharpe_variance = v] it is

    [sqrt v *. ((1 -. gamma) *. Normal_dist.inv_cdf (1 -. 1 /. n) +. gamma *.
     Normal_dist.inv_cdf (1 -. 1 /. (n *. e)))]

    where [gamma] is {!euler_mascheroni} and [v] is the variance of the Sharpe
    estimates across the [n_trials] trials. This is the SR_star benchmark
    {!deflated_sharpe} deflates against. Raises [Invalid_argument] if
    [n_trials < 2] (best-of-N is only meaningful for at least 2 trials; with one
    trial there is no selection to correct) or if [sharpe_variance < 0]. *)

val deflated_sharpe :
  observed_sharpe:float ->
  fold_returns:float list ->
  n_trials:int ->
  sharpe_variance_across_trials:float ->
  float
(** [deflated_sharpe ~observed_sharpe ~fold_returns ~n_trials
     ~sharpe_variance_across_trials] is the Deflated Sharpe Ratio: the
    probability the winner's Sharpe is real after correcting for best-of-N
    selection.

    - [observed_sharpe] — the winning variant's observed Sharpe.
    - [fold_returns] — the per-observation (per-fold) return series the Sharpe
      was estimated from; its length is the [n_obs] for {!psr}, and its skewness
      / kurtosis feed the non-normality adjustment.
    - [n_trials] — the number of variants the winner was selected from.
    - [sharpe_variance_across_trials] — the variance of the Sharpe estimates
      across the trials, feeding {!expected_max_sharpe}.

    Equivalent to {!psr} with [benchmark_sharpe] taken from
    {!expected_max_sharpe}, [n_obs] the length of [fold_returns], and the
    moments taken from [fold_returns]. Raises [Invalid_argument] under the same
    conditions as {!psr} and {!expected_max_sharpe} (in particular
    [n_trials < 2], fewer than 2 fold returns, or zero fold-return variance). *)

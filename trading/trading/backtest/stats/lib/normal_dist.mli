(** Standard normal distribution CDF and its inverse (quantile function).

    Thin wrappers around [Owl.Maths.erf] / [Owl.Maths.erfinv] expressing the
    Gaussian CDF [Phi] and its inverse [Phi^-1] in the forms the Deflated Sharpe
    closed form needs. Kept here (rather than inline in {!Deflated_sharpe}) so
    the two primitives are independently testable against known reference
    points. *)

val cdf : float -> float
(** [cdf z] is [Phi(z)], the probability that a standard normal variate is at
    most [z]. Computed as [0.5 * (1 + erf (z / sqrt 2))]. Monotone increasing,
    [cdf 0. = 0.5], [cdf neg_infinity = 0.], [cdf infinity = 1.]. *)

val inv_cdf : float -> float
(** [inv_cdf p] is [Phi^-1(p)], the [p]-quantile of the standard normal.
    Computed as [sqrt 2 * erfinv (2p - 1)]. Defined for [p] strictly in
    [(0, 1)]; raises [Invalid_argument] for [p <= 0.] or [p >= 1.] (the quantile
    is [+/-infinity] there and the callers never need those endpoints). *)

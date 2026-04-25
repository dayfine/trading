(** Per-tick EMA kernel over a column of an [N x T] Bigarray panel.

    Computes the standard mathematical EMA: simple average of the first [period]
    input values as the warmup seed at column [period-1], then the recurrence

    {[
    EMA [ t ] = (alpha * input [ t ]) + ((1 - alpha) * EMA [ t - 1 ])
    ]}

    where [alpha = 2 / (period + 1)]. Output cells at columns [0..period-2] are
    written as NaN (insufficient warmup data).

    The kernel reads its prior state from the output panel itself (column
    [t-1]). This is the panel design's central trick: indicator state lives in
    the panel, so per-tick advance is allocation-free.

    Note on rounding: this kernel produces unrounded float64 EMA values. The
    legacy [Indicators.Ema.calculate_ema] (FFI to TA-Lib's [ta_ema] +
    [round_to_two_decimals]) returns 2-dp-rounded values. Stage-0 parity is
    against an unrounded scalar-walk reference using the identical expression
    form (warmup = left-to-right [+.] accumulation; recurrence = bind [new_v]
    and [prev] to locals, then [(alpha *. new_v) +. (one_minus_a *. prev)]).
    Output is bit-identical to that reference at N=100 T=252 P=50 (verified in
    [ema_kernel_test.ml]). The legacy 2-dp rounding is intentionally dropped —
    it adds noise strictly worse for downstream signal quality. *)

val advance :
  input:(float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Array2.t ->
  output:(float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Array2.t ->
  period:int ->
  t:int ->
  unit
(** [advance ~input ~output ~period ~t] writes column [t] of [output] from
    column [t] of [input] (and previous columns of both as needed for warmup or
    recurrence).

    Behaviour by [t]:
    - [t < period - 1]: write NaN to [output] column [t].
    - [t = period - 1]: write the simple average of [input] columns
      [0..period-1] (left-to-right summation) to [output] column [t].
    - [t >= period]: write [alpha * input[r,t] + (1 - alpha) * output[r,t-1]] to
      [output] column [t], for each row [r].

    Inputs are bounds-checked: [period] must be [>= 1]; [t] must be in the
    half-open range [0..n_cols-1]; [input] and [output] must have identical
    shape. NaN inputs propagate through the recurrence (the kernel does not skip
    them). *)

val warmup : period:int -> int
(** [warmup ~period] returns the first column index at which [advance] writes a
    non-NaN value. Equal to [period - 1]. Public for tests and for callers that
    want to skip the warmup region in cross-section reads. *)

val alpha : period:int -> float
(** [alpha ~period] returns the smoothing factor [2.0 /. (period +. 1.0)].
    Public for tests. *)

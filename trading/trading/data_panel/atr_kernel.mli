(** Per-tick Wilder ATR kernel over [N x T] Bigarray panels.

    Computes the standard Wilder (1978) Average True Range. Per-bar True Range
    is the greatest of:

    - [high(t) - low(t)],
    - [abs (high(t) - close(t - 1))],
    - [abs (low(t) - close(t - 1))].

    The first column ([t = 0]) has no prior close so TR is undefined; the kernel
    writes NaN there. The first ATR value is the simple average of TR over the
    first [period] true-range values, written at column [t = period]. The Wilder
    recurrence then gives, for [t > period]:

    {[
    ATR [ t ] = ((ATR [ t - 1 ] * (period - 1)) + TR [ t ]) / period
    ]}

    The kernel reads its prior state from the output panel at column [t - 1],
    mirroring [Ema_kernel]'s recurrence shape. NaN inputs propagate through the
    True Range and Wilder smoothing.

    Note: Stage 0 lesson — bind every panel read (high, low, close, prev close,
    prev ATR) to a named local before arithmetic so a scalar reference written
    with the same expression form is bit-identical. The legacy
    [Indicators.Atr.atr] uses simple-mean ATR, not Wilder; parity is asserted
    against a scalar Wilder reference, not against the legacy. *)

val advance :
  high:(float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Array2.t ->
  low:(float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Array2.t ->
  close:(float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Array2.t ->
  output:(float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Array2.t ->
  period:int ->
  t:int ->
  unit
(** [advance ~high ~low ~close ~output ~period ~t] writes column [t] of [output]
    from columns [t - 1] and [t] of the input panels (and column [t - 1] of
    [output] for the Wilder recurrence).

    Behaviour by [t]:
    - [t = 0]: write NaN to [output] column 0 (no prior close, so TR undefined).
    - [0 < t < period]: write NaN (insufficient TR samples to seed the
      [period]-window average).
    - [t = period]: write the simple average of TR over the [period]-tick window
      [1..period] (left-to-right summation), seeding the recurrence.
    - [t > period]: write [(output[r, t - 1] * (period - 1) + tr) / period] for
      each row [r], where [tr] is computed from columns [t - 1] / [t] of
      [high]/[low]/[close].

    Inputs are bounds-checked: [period] must be [>= 1]; [t] must be in the
    half-open range [0..n_cols-1]; all four panels must have identical shape. *)

val warmup : period:int -> int
(** [warmup ~period] is the first column index at which [advance] writes a
    non-NaN value. Equal to [period] (one fewer than naive expectations because
    column 0 is the no-prior-close hole and TR seeds at column 1, so [period] TR
    samples land at column [period]). *)

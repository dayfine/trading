(** Per-tick Wilder RSI kernel over [N x T] Bigarray panels.

    Computes the standard Wilder (1978) Relative Strength Index. Per-bar gain
    and loss are derived from the close panel:

    - [diff(t) = close(t) - close(t - 1)]
    - [gain(t) = max(diff, 0)], [loss(t) = max(-diff, 0)]

    The first column ([t = 0]) has no prior close so gain/loss are undefined;
    the kernel writes NaN there. The first RSI value is at column [t = period],
    seeded from the simple average of gains/losses over the [period]-tick window
    [1..period]. The Wilder recurrence then gives, for [t > period]:

    {[
    avg_gain [ t ]
    = ((avg_gain [ t - 1 ] * (period - 1)) + gain [ t ]) / period avg_loss [ t ]
    = ((avg_loss [ t - 1 ] * (period - 1)) + loss [ t ]) / period rs
    = avg_gain [ t ] / avg_loss [ t ] rsi
    = 100 - (100 / (1 + rs))
    ]}

    Edge cases:
    - [avg_loss[t] = 0]: RSI is 100 (no losses in window). The kernel uses
      [Float.is_finite] on [rs] after the divide and substitutes 100.0 when not
      finite.

    The kernel needs persistent [avg_gain] / [avg_loss] state across ticks. To
    keep it allocation-free per tick, callers pass two scratch panels of the
    same shape as the output. [Indicator_panels] owns these scratch panels.

    Note: bind every panel read (gain, loss, prior averages) to a named local
    before arithmetic so a scalar reference written with the same expression
    form is bit-identical (Stage 0 lesson). Parity is asserted against a scalar
    Wilder RSI reference, not against any legacy implementation. *)

val advance :
  close:(float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Array2.t ->
  avg_gain:(float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Array2.t ->
  avg_loss:(float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Array2.t ->
  output:(float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Array2.t ->
  period:int ->
  t:int ->
  unit
(** [advance ~close ~avg_gain ~avg_loss ~output ~period ~t] writes column [t] of
    [output] (and column [t] of [avg_gain] / [avg_loss]) from columns [t - 1] /
    [t] of [close] (and [t - 1] of the scratch panels for the recurrence).

    Behaviour by [t]:
    - [t = 0]: write NaN to [output], [avg_gain], and [avg_loss] at column 0.
    - [0 < t < period]: write NaN to all three at column [t].
    - [t = period]: seed [avg_gain[t]] / [avg_loss[t]] as the simple average of
      gain/loss over the window [1..period] (left-to-right summation), and write
      the corresponding RSI to [output[t]].
    - [t > period]: Wilder recurrence on [avg_gain] / [avg_loss], then write
      [rsi = 100 - 100 / (1 + avg_gain / avg_loss)] (with [rs = +inf / NaN]
      mapped to RSI = 100 when [avg_loss = 0]).

    Inputs are bounds-checked: [period] must be [>= 1]; [t] must be in the
    half-open range [0..n_cols-1]; all four panels must have identical shape. *)

val warmup : period:int -> int
(** [warmup ~period] is the first column index at which [advance] writes a
    non-NaN [output] value. Equal to [period] (column 0 has no prior close;
    [period] gain/loss samples land at column [period]). *)

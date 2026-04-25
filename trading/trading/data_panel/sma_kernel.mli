(** Per-tick SMA kernel over a column of an [N x T] Bigarray panel.

    Computes the simple moving average: at column [t >= period - 1] the output
    cell is the arithmetic mean of [input] columns [t - period + 1 .. t]. Cells
    at columns [0 .. period - 2] are written as NaN (insufficient warmup data).

    Unlike [Ema_kernel], the SMA recurrence does not chain — each tick re-sums
    the window. The kernel still walks left-to-right within the window using the
    same [acc := !acc +. read] pattern as the EMA warmup, so a scalar reference
    that mirrors the same expression form yields bit-identical output (per the
    Stage 0 lesson about instruction-scheduling latitude when reads aren't bound
    to named locals). *)

val advance :
  input:(float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Array2.t ->
  output:(float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Array2.t ->
  period:int ->
  t:int ->
  unit
(** [advance ~input ~output ~period ~t] writes column [t] of [output] from the
    last [period] columns of [input].

    Behaviour by [t]:
    - [t < period - 1]: write NaN to [output] column [t].
    - [t >= period - 1]: write the simple average of [input] columns
      [t - period + 1 .. t] (left-to-right summation) to [output] column [t],
      for each row.

    Inputs are bounds-checked: [period] must be [>= 1]; [t] must be in the
    half-open range [0..n_cols-1]; [input] and [output] must have identical
    shape. NaN inputs propagate through the sum (any NaN in the window yields
    NaN). *)

val warmup : period:int -> int
(** [warmup ~period] is the first column index at which [advance] writes a
    non-NaN value. Equal to [period - 1]. *)

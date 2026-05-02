(** Per-day scalar indicator arrays for the Phase B snapshot pipeline.

    Each function takes the symbol's full daily series (passed as
    [Float.Array]-style [float array] views) and returns one [float array] of
    the same length whose cell [i] is the indicator value at day [i], computed
    causally over [closes[0..i]] with the same warmup-then-recurrence equations
    the prior {!Pipeline} used to recompute on every call.

    The recurrences are written in the same expression form (same accumulation
    order, same temporary bindings) the prior recompute-from-zero code used, so
    the produced cells are identical to the bit. The hand-pinned indicator tests
    in [test/test_snapshot_pipeline.ml] verify this contract. *)

val sma : closes:float array -> period:int -> float array
(** [sma ~closes ~period] is a [float array] aligned to [closes] whose cell [i]
    is the simple moving average of [closes[i - period + 1 .. i]] (sum bound to
    a local [v] then accumulated newest-to-oldest). Cells [0..period - 2] are
    [Float.nan]. *)

val ema : closes:float array -> period:int -> float array
(** [ema ~closes ~period] is the standard exponential moving average. Cell
    [period - 1] is the simple mean of the first [period] closes (warmup seed);
    each subsequent cell is the recurrence [alpha * close + (1 - alpha) * prev]
    with [alpha = 2 / (period + 1)]. Cells [0..period - 2] are [Float.nan]. *)

val atr :
  highs:float array ->
  lows:float array ->
  closes:float array ->
  period:int ->
  float array
(** [atr ~highs ~lows ~closes ~period] is Wilder's average true range. Cells
    [0..period - 1] are [Float.nan]; cell [period] is the simple mean of true
    range over the [period]-tick window [1..period]; subsequent cells use the
    Wilder recurrence [(prev * (period - 1) + tr) / period]. *)

val rsi : closes:float array -> period:int -> float array
(** [rsi ~closes ~period] is Wilder's relative strength index. Cells
    [0..period - 1] are [Float.nan]; cell [period] is computed from the simple
    mean of gain/loss over diffs [1..period]; subsequent cells apply the Wilder
    smoothing to both averages. When the smoothed loss is zero (or RS is
    non-finite), the cell is [100.0]. *)

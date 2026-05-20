(** Daily-bar Weinstein stage classifier for industry-portfolio level series.

    For each industry we maintain a synthetic price level (cumulative product of
    [1 + daily_return]); the stage classifier then looks at price vs MA and MA
    slope to bucket each (industry, day) into Stage 1-4.

    Slope thresholds are calibrated for daily cadence: a ±0.005 (= 0.5%) move in
    the MA over a 30-trading-day lookback (≈ 6 weeks ≈ "is the MA flat or
    trending") separates Stage 2/4 from Stage 1/3. *)

type stage = Stage1 | Stage2 | Stage3 | Stage4 [@@deriving show, eq]

val label : stage -> string
(** Short label: ["S1"], ["S2"], ["S3"], ["S4"]. Used for table rendering. *)

val moving_average : prices:float array -> window:int -> float array
(** [moving_average ~prices ~window] returns an array of the same length as
    [prices]. The first [window - 1] entries are [Float.nan]; the remaining
    entries are the simple trailing mean. *)

val classify_at :
  prices:float array ->
  ma:float array ->
  slope_lookback:int ->
  slope_threshold_pct:float ->
  int ->
  stage
(** [classify_at ~prices ~ma ~slope_lookback ~slope_threshold_pct t] returns the
    Stage classification at index [t]:

    - Stage 2 (advancing): price > MA AND MA rising
    - Stage 4 (declining): price < MA AND MA falling
    - Stage 1 (basing): price ≤ MA AND MA flat-or-rising
    - Stage 3 (topping): price > MA AND MA flat-or-falling

    "Rising" means
    [(ma[t] - ma[t - slope_lookback]) / prices.(t) > slope_threshold_pct];
    "falling" is the symmetric negative case.

    Falls back to Stage1 if [t < slope_lookback] or either MA point is NaN. *)

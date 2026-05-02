(** Stationary block bootstrap on log returns (Politis-Romano 1994).

    Generates a synthetic daily-price series by resampling variable-length
    blocks of source-index *positions* (not raw prices). For each sampled
    position [i] we replay the source's one-step log-return
    [log(close_i / close_{i-1})] and the source's intra-bar OHLC ratios +
    volume; the output close-price chain is rebuilt by compounding from a base
    price.

    This avoids the price-level discontinuity at block boundaries: every
    synthetic log-return — including the return at a boundary — is an honest
    one-step return drawn from the source. Within-block correlation structure is
    preserved up to the block-length scale; across boundaries, returns are
    independent. At synthesis lengths much larger than the mean block length,
    the empirical moments (skew, kurtosis, lag-1 autocorrelation) of synth
    log-returns track the source closely.

    Determinism: same source + same parameters + same seed produces an identical
    output.

    No look-ahead leakage: the output never uses a return that doesn't appear in
    the source, so by construction it cannot encode information from outside the
    source's time window. *)

type config = {
  target_length_days : int;  (** Number of bars to emit. Must be > 0. *)
  mean_block_length : int;
      (** Mean of the geometric distribution governing block lengths. Must be >
          0. Typical value: 30 (≈ one trading month). *)
  seed : int;  (** Seed for the PRNG. Same seed → identical output. *)
  start_date : Core.Date.t;
      (** First bar's date. Subsequent bars advance one business day at a time
          (Mon–Fri), skipping weekends. Holidays are ignored — the synthesis is
          statistical, not calendar-aware. *)
  start_price : float;
      (** Close price of the first synthetic bar. Must be > 0. The rest of the
          chain is built by compounding sampled log-returns. *)
}

val generate :
  source:Types.Daily_price.t list ->
  config:config ->
  (Types.Daily_price.t list, Status.t) Result.t
(** [generate ~source ~config] produces a synthetic daily-price series of length
    [config.target_length_days]. Returns [Error] if the source has fewer than
    two bars (no return computable), if any config field is non-positive, or if
    the source is shorter than [mean_block_length] (degenerate bootstrap).

    Bars are emitted as follows:
    - The first bar's [close_price] is [config.start_price]; OHLC ratios and
      volume are taken from [source.(0)].
    - For each subsequent bar at synth-position [k], we sample a source index
      [i] and apply that source's one-step log-return on top of the previous
      synth close. OHLC ratios and volume are taken from [source.(i)].
    - Dates are sequential business days starting at [config.start_date]. *)

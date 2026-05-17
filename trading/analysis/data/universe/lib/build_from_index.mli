(** Build a {!Snapshot.t} from Shiller's monthly S&P composite + Kenneth
    French's daily 5-industry returns for the pre-1998 decomposition path.

    For each annual reconstitution date the builder: 1. Splits the
    synthetic-symbol count across the 5 French industries (equal-weight in v1 —
    see {b Caveats} below). 2. Reuses [Synthetic.Factor_model] to draw
    per-symbol β and idio GARCH params and compose per-symbol log-return series
    against the matching French daily-industry-return series ("market factor"
    per bucket). 3. Rescales every synthetic symbol's compound period return by
    a single multiplicative scalar so the cap-weighted aggregate matches
    Shiller's reported total return for the same window (the anchor constraint
    within [shiller_anchor_epsilon]). 4. Emits one {!Snapshot.t} with
    [method_ = Decomposition_from_index { ... }] and per-entry
    [symbol = SYNTH_<industry>_<4-digit rank>] + [synthetic = true].

    Determinism: every sampler is seeded explicitly off [config.rng_seed].

    {1 Caveats — read before consuming the output}

    - {b Equal-weight industry allocation v1.} Historical industry weights drift
      (HiTec was negligible pre-1980 and dominant by 2000). The v1 build splits
      the universe equally across all 5 French buckets — a deliberate
      simplification. Phase-2 calibration TODO: re-weight from historical FF
      market-cap.
    - {b Pre-1962 NYSE-only universe.} French covers 1926-onward but the firm
      universe was NYSE-only pre-1962. The builder produces [size] synthetics
      regardless; callers running pre-1962 calibrations should consider a
      smaller [size] (e.g. 1500) to better match the era's breadth.
    - {b Synthetic names don't delist.} Per-bar aggregate statistics are
      reliable but per-symbol persistence is fictional. Strategies must consume
      aggregates, not per-symbol P&L, when running in deep-history mode.
    - {b 5-industry coarse.} 49-industry French portfolios are available and
      reserved as the phase-2 upgrade
      ([Snapshot.factor_skeleton = `French_49_industry]).
    - {b No pre-1926 mode.} Shiller goes to 1871 but French starts in 1926;
      pre-1926 needs a single-factor (market-only) mode — out of scope for this
      PR. *)

open Core

type config = {
  size : int;
      (** Top-N cutoff; total synthetic symbols emitted. Must be > 0 and
          divisible by 5 in v1 (one bucket per French industry, equal split). *)
  per_industry_count : int;
      (** Computed convenience: [size / 5]. Exposed so tests can pin it. *)
  rng_seed : int;
      (** Master seed; β / idio / return seeds are derived deterministically. *)
  shiller_anchor_epsilon : float;
      (** Max allowed [|aggregate_period_return - shiller_target|]. Default
          [0.005] (0.5%). *)
}
[@@deriving sexp]

val default_config : size:int -> rng_seed:int -> config
(** [default_config ~size ~rng_seed] sets [per_industry_count = size / 5] and
    [shiller_anchor_epsilon = 0.005]. *)

val build :
  date:Date.t ->
  shiller_obs:Shiller.Shiller_client.monthly_observation list ->
  french_obs:Kenneth_french.Kenneth_french_client.daily_return list ->
  config:config ->
  Snapshot.t Status.status_or
(** [build ~date ~shiller_obs ~french_obs ~config] synthesizes a snapshot
    anchored at [date]. Uses Shiller observations covering
    [date .. date + 1 year] to compute the composite total return, and the
    parallel slice of French daily 5-industry returns as the per-industry factor
    skeletons.

    Returns:
    - [Error Status.Invalid_argument] if [config.size <= 0],
      [config.size mod 5 <> 0], [shiller_obs] or [french_obs] is empty, or
      either window does not span at least 12 months from [date].
    - [Error Status.Failed_precondition] if the post-rescale cap-weighted
      aggregate is still outside [config.shiller_anchor_epsilon] of Shiller's
      target after calibration (should not happen in practice — the scalar
      correction is closed-form and exact up to floating-point precision; only
      degenerate inputs trip this).
    - [Ok snapshot] otherwise.

    The [factor_skeleton] in the produced [method_] is [`French_5_industry] in
    v1. *)

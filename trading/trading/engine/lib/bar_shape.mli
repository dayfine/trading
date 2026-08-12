(** Properties inferred from a single OHLC bar's shape, used to drive intraday
    path generation.

    Split out of [price_path.ml] when that file crossed the declared-large file
    limit. The boundary is a real one rather than a line-count convenience:
    everything here is a pure function of a bar (plus, for the coin flips, a
    [Random.State.t]) and none of it depends on [Price_path.path_config], so the
    module sits strictly below the path generator. *)

open Core
open Types

val clamp : min_val:float -> max_val:float -> float -> float
(** Clamp a value into [[min_val, max_val]]. *)

val infer_volatility_scale : price_bar -> float
(** Brownian noise scale inferred from the bar's shape: the geometric mean of a
    choppiness factor ((high-low)/|close-open|, relative to a typical 2.5) and a
    magnitude factor ((high-low)/open, relative to a typical 2% daily range).
    Each factor is capped at 2.0, so the result is capped at ~2.0. A flat bar
    (high = low) scores 0.0. *)

val decide_high_first : Random.State.t -> price_bar -> bool
(** Whether the high is visited before the low. A coin flip biased by the bar's
    direction (bullish favours high-first) and damped by
    {!infer_volatility_scale}, clamped to [[0.2, 0.8]] so the order is never
    fully determined. A doji (close = open) is an unbiased flip. *)

val seed_for_bar : ?salt:int -> price_bar -> int
(** A deterministic seed derived from the bar's ticker and its four prices.

    [salt] selects which intraday-path {e realisation} the run draws, without
    touching any strategy parameter. [0] (the default) returns the unsalted hash
    verbatim, so the default path is bit-identical to the pre-salt build; a
    non-zero salt gives an independent but equally reproducible set of paths.

    This exists because determinism alone does not make a backtest
    {e representative}. The strategy's return is concentrated in a handful of
    trades, and a saturated cash queue means a cent of fill difference changes
    which of them get funded — so a single run is one draw from a lottery, and
    two configurations cannot be ranked by comparing one draw each. Running one
    config across K salts yields a distribution, which is what a comparison
    actually needs. See `dev/notes/ladder-v4-read-2026-08-12.md` §1b.

    Callers that must be reproducible across processes — every backtest —
    generate paths under [{ config with seed = Some (seed_for_bar bar) }] rather
    than the [seed = None] default, whose [Random.State.make_self_init ()] makes
    each run draw a fresh path. Deriving the seed from the bar rather than
    fixing one constant keeps the noise independent across bars and symbols; a
    single constant would give every bar in a run the same noise shape.

    Two bars agreeing on ticker and all four prices share a seed, and so share a
    path. That is intended: the path is a function of the bar, which is what
    {!Trading_engine.Market_state}'s "same bar -> same path" contract asserts.

    Re-exported as [Price_path.seed_for_bar] for callers that already depend on
    that module. *)

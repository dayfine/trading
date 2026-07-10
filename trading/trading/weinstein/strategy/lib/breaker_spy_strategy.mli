(** Breaker SPY sleeve — a long-only, default-in-market index floor strategy
    that consumes the pure {!Index_circuit_breaker} state machine (P1b step 2 of
    the floor-quality program; design authority
    [dev/plans/fast-circuit-breaker-spy-sleeve-2026-07-08.md], lib in
    [analysis/weinstein/macro/lib/index_circuit_breaker.mli], merged #1904).

    This is the {b consumer} of the breaker lib. It trades exactly one symbol
    (default SPY), holds it buy-and-hold by default, and defers every
    sell/re-buy decision to {!Index_circuit_breaker.step}. It is deliberately
    minimal and {b separate} from both the production {!Weinstein_strategy} and
    the {!Spy_only_weinstein_strategy} stage-timing testbed — it reuses their
    sizing shape but carries {e no} per-position trailing stop and runs {e no}
    stage-entry rule. The only exit is a breaker exit; the only entry is a
    breaker re-entry or the default-in-market deploy.

    {1 Framing — we are not timing reversals}

    Per the user steer (2026-07-09, [memory/feedback_no_reversal_timing]):
    {b the sleeve is not trying to time market reversals}. The slow structural
    exit (breadth-led distribution / slow grind,
    {!Index_circuit_breaker.Slow_grind}) is the doctrine-faithful part —
    Weinstein sanctions stepping aside from a genuine distribution top. The fast
    exit ({!Index_circuit_breaker.Fast_crash} /
    {!Index_circuit_breaker.Absolute_floor}) and its fast re-entry are explicit
    {b tail-RISK insurance}: their whipsaw cost is {e accepted and measured},
    not assumed to be free. The lens screen vs total-return SPY (P1b step 3) is
    where that whipsaw cost is quantified — this module only wires the
    machinery.

    {1 Cadence — weekly}

    {!Index_circuit_breaker.step}'s config priors are weekly-bar semantics (a
    4-week fast window, a 3-week grind confirm, a 52-week floor peak, a 30-week
    re-entry MA), so the breaker is evaluated on {b weekly closes (Friday)} over
    the symbol's own weekly-aggregated bars — the symbol {e is} the index, so
    there is no separate index instrument. Between Fridays the breaker is
    {b not} re-evaluated: the lib exposes no daily semantics, so a daily-cadence
    fast exit (the design doc's "days cadence" ambition) is a {e future dial},
    not invented here. The one thing that {e does} run every day is the
    default-in-market deploy: whenever the portfolio is flat and the breaker
    state is {!Index_circuit_breaker.In_market}, available cash is deployed into
    the symbol — this is how "in-market by default, buy on the first tradable
    bar" is realized without a daily breaker evaluation.

    {1 Macro / A-D input}

    {!Index_circuit_breaker.step} needs a {!Macro.result} for its
    {!Decline_character} character read. This sleeve computes it each Friday via
    {!Macro.analyze} over the symbol's weekly bars with {b empty} A-D and global
    breadth inputs ([ad_bars:[] ~global_index_bars:[]]) and
    {!Macro.default_config}. Empty A-D is the documented single-instrument
    degradation (see {!Decline_character.classify}: a missing / [`Neutral] A-D
    reading means "no breadth lead"): the slow-grind path then rests on the
    weeks-below-falling-MA leg alone, and the fast-V path on the rate-of-decline
    leg — both of which read only index price. {!Macro.default_config}
    contributes {b no new tunable threshold} of this module's own — its 30-week
    stage MA merely supplies the [ma_value] / [ma_direction] the character read
    consumes, consistent with the breaker's own 30-week re-entry MA prior. Every
    {e tunable} threshold routes through {!config.breaker} so the whole sleeve
    is a {!Index_circuit_breaker} nesting axis (experiment-flag-discipline R2).
*)

type config = {
  symbol : string;
      (** Instrument to trade. Default {!default_symbol} ([SPY]). Bare ticker,
          no exchange suffix — matches the on-disk CSV layout under
          [data/S/Y/SPY/]. *)
  breaker : Index_circuit_breaker.config;
      (** The circuit-breaker configuration, threaded verbatim into
          {!Index_circuit_breaker.step}. Default
          {!Index_circuit_breaker.default_config}. Every breaker trigger
          threshold lives here (nothing hardcoded in this module), so the sleeve
          is expressible as a nested [Variant_matrix] axis the day it lands. *)
}

val name : string
(** Human-readable strategy name, [BreakerSpySleeve]. *)

val default_symbol : string
(** [SPY]. *)

val default_config : config
(** [default_config] uses {!default_symbol} and
    {!Index_circuit_breaker.default_config}. The breaker defaults are
    {e priors to search}, not a validated configuration (see the lib's
    [default_config] doc): a WF-CV surface + deep bear-regime promotion grid
    gate them before any is trusted as a default. *)

val make :
  ?config:config ->
  bar_reader:Bar_reader.t ->
  unit ->
  (module Trading_strategy.Strategy_interface.STRATEGY)
(** [make ?config ~bar_reader ()] constructor. Returns a first-class
    {!Trading_strategy.Strategy_interface.STRATEGY} module whose
    [on_market_close] implements the weekly-breaker cadence above.

    The instance carries closure-scoped mutable state across [on_market_close]
    calls — the current {!Index_circuit_breaker.state} (seeded fresh at
    {!Index_circuit_breaker.in_market} per {!make}) and the prior week's
    {!Macro.result} (for {!Macro.analyze}'s [prior] / [prior_stage] threading).
    No wall clock is read; given the same bar stream the sequence of decisions
    is deterministic.

    @param config Strategy parameters. Defaults to {!default_config}.
    @param bar_reader
      The snapshot-backed bar source the runner constructs; used to read the
      symbol's weekly aggregates for the breaker step. The simulator's per-tick
      [get_price] supplies today's bar for sizing and the default-in-market
      deploy. *)

(** Shadow screener adapter — drives [Screener.screen] from Summary-tier
    scalars.

    Lets the [Tiered] [Loader_strategy] path run the Friday screener without
    materializing raw bars for every universe symbol. The adapter synthesizes
    minimal [Stock_analysis.t] stubs from a list of
    [(symbol, Summary_compute.summary_values)] pairs and hands them to
    [Screener.screen].

    {1 Synthesis strategy}

    - {b Stage.result}: [ma_value] comes from [summary_values.ma_30w]; [stage]
      comes from [summary_values.stage]; [ma_direction] is a conservative proxy
      — [Rising] when [stage] is [Stage2 _], [Declining] when [Stage4 _], [Flat]
      otherwise. [ma_slope_pct = 0.0] and [above_ma_count = 0] are placeholders
      (the screener does not read them). [transition] is reconstructed by
      comparing against [prior_stages].
    - {b Rs.result}: synthesized from [summary_values.rs_line]. Trend is
      classified by comparing against [1.0]: values [>= 1.0] →
      [Positive_rising], values [< 1.0] → [Negative_declining]. [current_rs] /
      [current_normalized] share the [rs_line] value; [history] is an empty
      list.
    - {b Volume.result}: Stage2 and Stage4 stubs get a synthetic [Adequate]
      confirmation (ratio [1.5] — the floor of the [Adequate] band). This is the
      minimum signal required for [Stock_analysis.is_breakout_candidate] /
      [is_breakdown_candidate] to accept a transition; without it, the shadow
      screener would return zero candidates for every universe (the Summary tier
      does not retain volume bars). Stage1 / Stage3 get [None]. This synthesis
      deliberately collapses the Strong/Adequate/Weak spectrum to a single value
      — the volume scoring weight becomes a constant bonus rather than a
      discriminator.
    - {b Resistance.result}: always [None].
    - {b breakout_price}: [None]. The screener's candidate builder falls back to
      [ma_value * (1 + breakout_fallback_pct)].

    {1 Known divergence from the Legacy [_screen_universe] path}

    The synthesis loses three signals:

    - {b Volume}: the synthesis always returns [Adequate 1.5] for
      breakout/breakdown stages; the Strong/Adequate/Weak spectrum of the Legacy
      path collapses to a single value. Candidates with a genuine Strong volume
      signal score ~10 points lower in shadow than in Legacy.
    - {b Resistance}: no [Virgin_territory] / [Clean] bonus → a further ~10–15
      point reduction.
    - {b RS crossover}: [Bullish_crossover] / [Bearish_crossover] are never
      emitted because the synthesis lacks an RS history series — the crossover
      bonus is unreachable.

    These are documented, accepted gaps. The 3g parity test (separate PR) will
    tell us whether the resulting candidate list diverges from Legacy enough to
    matter in practice.

    {1 Purity}

    [screen] mutates [prior_stages] in place — the same contract as the Legacy
    screener path. Every other input is treated as read-only. *)

open Core

val synthesize_analysis :
  summary:Summary_compute.summary_values ->
  ticker:string ->
  prior_stage:Weinstein_types.stage option ->
  as_of:Date.t ->
  Stock_analysis.t
(** [synthesize_analysis ~summary ~ticker ~prior_stage ~as_of] builds a minimal
    [Stock_analysis.t] from the Summary-tier scalars. Exposed so tests and debug
    tooling can inspect the synthesis without going through the full cascade.
    See the module doc-comment for the exact synthesis rules. *)

val screen :
  summaries:(string * Summary_compute.summary_values) list ->
  config:Screener.config ->
  macro_trend:Weinstein_types.market_trend ->
  sector_map:(string, Screener.sector_context) Hashtbl.t ->
  prior_stages:Weinstein_types.stage Hashtbl.M(String).t ->
  held_tickers:string list ->
  as_of:Date.t ->
  Screener.result
(** [screen ~summaries ~config ~macro_trend ~sector_map ~prior_stages
     ~held_tickers ~as_of] runs the screener cascade on the synthesized stubs.

    @param summaries
      [(ticker, summary_values)] pairs, one per symbol the caller wants
      screened. Typically sourced from [Bar_loader.get_summary] for every ticker
      at Summary tier or higher. Ordering is preserved through the screener
      (which itself sorts by score).
    @param config Screener parameters. Forwarded verbatim to [Screener.screen].
    @param macro_trend Macro regime used by the cascade gate.
    @param sector_map Ticker → [Screener.sector_context].
    @param prior_stages
      Mutable hashtable of previous [Weinstein_types.stage] per ticker. Read to
      fill [Stock_analysis.t.prior_stage] and [Stage.result.transition]; written
      with each ticker's new stage on the way out. Same contract as
      [Weinstein_strategy._screen_universe].
    @param held_tickers Positions already held — excluded by [Screener.screen].
    @param as_of Analysis date; forwarded to the synthesized stubs.

    Returns the standard [Screener.result] so the caller can feed it straight
    into {!Weinstein_strategy.entries_from_candidates}. *)

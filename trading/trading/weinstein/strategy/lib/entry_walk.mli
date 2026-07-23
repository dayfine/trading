(** The per-Friday entry walk: turn a list of assembled screener candidates into
    [CreateEntering] transitions, charging each against a shared cash /
    short-notional / long-notional / sector-exposure budget.

    Extracted from {!Weinstein_strategy_screening} (keeps that coordinator under
    the file-length cap). Sits directly after {!Entry_assembly} in the pipeline:
    [Entry_assembly.assemble] produces the ordered candidate list, this module
    walks it. The gate machinery itself lives in {!Entry_audit_capture} and the
    budget seeding in {!Screening_notional}; this module orchestrates them and
    the optional reserved-short-sleeve partition. *)

val held_symbols : Trading_strategy.Portfolio_view.t -> string list
(** Ticker symbols of positions the strategy is still holding (or still trying
    to enter/exit). Closed positions are excluded — the strategy has no stake in
    them and must be free to re-enter the symbol.

    Used internally to (a) filter screener candidates and (b) populate
    [held_tickers] passed to [Screener.screen]. Public because the result is a
    natural query on strategy state and the behaviour (exclude [Closed]) is
    worth pinning by direct unit test. *)

val entries_from_candidates :
  ?sector_lookup:(string -> string option) ->
  config:Weinstein_strategy_config.config ->
  candidates:Screener.scored_candidate list ->
  stop_states:Weinstein_stops.stop_state Core.String.Map.t ref ->
  bar_reader:Bar_reader.t ->
  portfolio:Trading_strategy.Portfolio_view.t ->
  get_price:(string -> Types.Daily_price.t option) ->
  current_date:Core.Date.t ->
  ?audit_recorder:Audit_recorder.t ->
  ?macro:Macro.result ->
  unit ->
  Trading_strategy.Position.transition list
(** Generate [CreateEntering] transitions for a list of screener candidates.

    For each candidate:
    - Applies the Weinstein position sizer
      ({!Weinstein.Portfolio_risk.compute_position_size}). Candidates whose
      per-trade risk rounds to zero shares are dropped.
    - Computes the initial stop via
      {!Weinstein_stops.compute_initial_stop_with_floor}, threading [cand.side]:
      longs get a stop below the prior correction low; shorts get a stop above
      the prior rally high. Falls back to [config.initial_stop_buffer] when no
      qualifying counter-move is in the lookback window.
    - Emits a [CreateEntering] with [side = cand.side].

    Side effect: seeds [stop_states] with the computed initial stop for each new
    entry.

    Cash tracking: each entry's [target_quantity * entry_price] is deducted from
    [portfolio.cash]; candidates whose cost exceeds the remaining cash are
    skipped. For short candidates this is conservative (shorts generate proceeds
    rather than consume cash) but safe.

    When [config.short_sleeve_fraction > 0.0] the per-Friday cash budget is
    partitioned into a long walk and a reserved short-only walk (both sharing
    the notional / sector accumulators) so longs cannot starve shorts; at the
    [0.0] default it is a single combined walk, bit-identical to the pre-sleeve
    path.

    Public because it's a useful primitive for callers that want to run
    screening out-of-band (e.g. custom universe loops) and feed candidates into
    the strategy's entry pipeline.

    @param audit_recorder
      Optional decision-trail recorder. When passed, every entered candidate
      yields a {!Audit_recorder.entry_event} populated with the chosen
      candidate, the macro snapshot ([macro]), the alternatives considered, and
      the audit-relevant intermediates ([installed_stop], [stop_floor_kind],
      sizing). Defaults to {!Audit_recorder.noop}.
    @param macro
      Macro snapshot consumed by [audit_recorder]'s entry event. Required only
      when [audit_recorder] is passed; ignored otherwise. Tests that don't
      record audit events can omit it.
    @param sector_lookup
      P1 2026-05-15. Resolves a held symbol to its sector name; used to seed the
      per-sector exposure accumulator that drives
      [Portfolio_risk.config.max_sector_exposure_pct]. When omitted, the
      accumulator is empty — held positions don't contribute to any sector
      bucket. Default-off path
      ([config.portfolio_config.max_sector_exposure_pct = None]) is bit-equal to
      pre-P1 behaviour regardless of whether [sector_lookup] is passed. *)

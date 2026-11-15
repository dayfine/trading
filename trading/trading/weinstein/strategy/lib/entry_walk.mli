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

type walk_report = {
  long_cash_left_pct : float;
      (** The long side's spendable cash less the cost of every long ticket the
          walk placed, as a fraction of portfolio value — the cash the long walk
          left unspent. The budget is [portfolio.cash] (net of resting tickets
          under [reserve_cash_for_resting_tickets]) in the combined walk, or the
          part above the reserved short sleeve when [short_sleeve_fraction > 0];
          short tickets never reduce it. Negative only under long-margin
          leverage. [0.0] when portfolio value is not positive.

          On the default path ([reserve_cash_for_resting_tickets = false]) the
          figure does not subtract the cash committed to long entry tickets
          still resting from earlier Fridays, so it overstates the free cash by
          that amount. *)
  long_resting_reserved_pct : float;
      (** That amount: the unfilled cost of the long entry tickets still resting
          at the walk (placed on earlier Fridays, not yet filled or cancelled
          before this Friday), as a fraction of portfolio value. Measured
          exactly as [reserve_cash_for_resting_tickets] (G3) reserves it
          ({!Screening_notional.long_cash_fractions}), but computed whether or
          not G3 is on. With G3 off the free cash is
          [long_cash_left_pct - long_resting_reserved_pct]; with G3 on the
          reserve is already out of [long_cash_left_pct]. [0.0] when portfolio
          value is not positive.

          Caveats: a ticket this Friday's own cancels retire (F2 rescreen, TTL
          clock, macro suspension) is still counted, as G3 counts it, because
          the walk reads the book before those cancels apply, so on such Fridays
          the identity understates the free cash. The G3-off difference can go
          negative (over-commitment) where the G3-on figure floors at 0; the two
          agree only while the cash covers the reserve. *)
  held : Core.String.Set.t;
      (** The symbols the walk treated as held ([Already_held]). *)
  stop_check : Screener.scored_candidate -> Entry_stop_check.t;
      (** The walk's own initial-stop check, with this tick's config, fallback
          buffer, bar reader and date: the same closure every entry of the walk
          was built from. Pure, so it can judge a candidate the walk never saw
          without placing anything. *)
}
(** What the [candidates.sexp] top-N view needs from one Friday's walk. Built
    only when {!entries_from_candidates} is given [?on_walk_report]. *)

type 'config entries_fn =
  ?sector_lookup:(string -> string option) ->
  ?pending_entry_e:Entry_freeze.t ->
  ?suspended_held:string list ->
  config:'config ->
  candidates:Screener.scored_candidate list ->
  stop_states:Weinstein_stops.stop_state Core.String.Map.t ref ->
  bar_reader:Bar_reader.t ->
  portfolio:Trading_strategy.Portfolio_view.t ->
  get_price:(string -> Types.Daily_price.t option) ->
  current_date:Core.Date.t ->
  ?audit_recorder:Audit_recorder.t ->
  ?macro:Macro.result ->
  ?on_candidates_considered:(Audit_recorder.walk_decision list -> unit) ->
  ?on_walk_report:(walk_report -> unit) ->
  unit ->
  Trading_strategy.Position.transition list
(** The type of {!entries_from_candidates}, named so {!Weinstein_strategy}
    re-exports the function without restating its signature. Parameterised by
    the config type only because {!Weinstein_strategy} re-declares [config] as a
    nominally distinct copy. *)

val entries_from_candidates : Weinstein_strategy_config.config entries_fn
(** Generate [CreateEntering] transitions for a list of screener candidates.

    For each candidate:
    - Applies the Weinstein position sizer
      ({!Weinstein.Portfolio_risk.compute_position_size}). Candidates whose
      per-trade risk rounds to zero shares are dropped.
    - Computes the initial stop via
      {!Weinstein_stops.compute_initial_stop_with_floor}, threading [cand.side]:
      longs get a stop below the prior correction low; shorts get a stop above
      the prior rally high. Falls back to [config.initial_stop_buffer] when no
      qualifying counter-move is in the lookback window — or, when
      [config.initial_stop_buffer_by_macro_state] sets a width for the
      [breadth_state] of the [?macro] result passed here, to {i that} width
      instead ({!Stop_buffer_by_state}). The map ships empty and an absent
      [?macro] resolves to the scalar, so the default path is unchanged. The one
      resolved multiplier is also what
      {!Entry_stop_width_order.prefer_narrow_stops} measures with, so the
      ordering pass and the gate cannot disagree about a candidate's width.
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
      pre-P1 behaviour regardless of whether [sector_lookup] is passed.
    @param on_candidates_considered
      Issues #2490 (gap G1) and #3139. When present, called once after the walk
      with {!Entry_audit_emit.walk_decisions_of} — every top-N candidate the
      walk classified, each [Placed] or with its skip reason — so a caller can
      attach the weekly decision record to that Friday's
      {!Audit_recorder.cascade_event} even when nothing was funded. Absent (the
      default) is a provable no-op: the projection is never computed. The
      screening coordinator always installs it (via {!Cascade_trace}); it is a
      separate parameter rather than a recorder callback because the list
      belongs to the {i week}'s cascade event, which the entry walk does not
      itself assemble.
    @param on_walk_report
      When present, called once after the walk with its {!walk_report}. Absent
      (the default) is a provable no-op: the report is never built. Meant to be
      installed only when candidate capture is on. Observational: the walk's
      order, decisions and transitions are the same with or without it.
    @param pending_entry_e
      Fix #2 no-chase pin table ({!Entry_freeze.t}). Threaded from the
      {!Weinstein_strategy.make} closure so the first-qualifying entry [E]
      persists across Fridays. Only consulted when
      [config.freeze_entry_at_first_breakout = true]; when the flag is off the
      table is never touched, so an omitted argument (default fresh table) is
      bit-identical to the pre-freeze path (R1).
    @param suspended_held
      #3015. Symbols of entry tickets withdrawn by the macro suspension
      ({!Entry_ticket_suspend.run}'s second result), counted as pending longs by
      the one-share-class-per-issuer rule ({!Share_class_gate}). Only read when
      [config.max_one_share_class_per_issuer = true]; default [[]]. With the
      flag on, a long candidate whose issuer group already has an open or
      pending long is recorded as [Skipped Share_class_held] and never sized. *)

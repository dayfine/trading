(** Entry-execution-faithfulness enrichment for {!Trade_audit}.

    The user directive (2026-08-05): the trade audit should record not only the
    trades and their screening quality, but also {b execution quality} — whether
    the orders that produced the fills actually {b followed the designed stops}
    (a resting StopLimit at the breakout) rather than {b just making markets} (a
    Market fill). This module joins each entry decision to its realised fill and
    stamps a {!Trade_audit.execution_faithfulness} record onto the matching
    {!Trade_audit.audit_record}.

    Sources (all pre-existing; no new fill plumbing):
    - {b designed order shape} — from the run's {!Weinstein_strategy.config}:
      Market unless [enable_sim_entry_stoplimit && entry_extension_max_pct > 0],
      mirroring {!Order_generator}'s entry-fill model.
    - {b designed trigger} — the [CreateEntering.entry_price] the strategy
      installed (the effective entry [E]), recovered exactly from the audit's
      dollar fields: [initial_position_value = shares * E] and
      [initial_risk_dollars = shares * |E - installed_stop|] give
      [E = installed_stop / (1 -/+ initial_risk_dollars/initial_position_value)]
      for a long / short.
    - {b fill price} — the matched round-trip's open-leg
      {!Trading_simulation.Metrics.trade_metrics.entry_price}.

    The entry↔fill join reuses {!Trade_context} (its [(symbol, entry_date)]
    exact match with a 7-day decision→fill window fallback), so a resting order
    that fills a bar or two after the Friday decision is still matched. *)

type entry_order_kind =
  | Market  (** No resting order — Market fill ("making markets"). *)
  | Stop_limit_band of float
      (** Resting StopLimit whose do-not-chase band is this fraction (e.g.
          [0.15] for the 15-percentage-point cap). The per-entry trigger is the
          effective entry; the limit is [trigger *. (1 +/- band)]. *)
[@@deriving sexp, eq]

val entry_order_kind_of_config : Weinstein_strategy.config -> entry_order_kind
(** [Stop_limit_band (entry_extension_max_pct /. 100.)] when
    [enable_sim_entry_stoplimit && entry_extension_max_pct > 0.0], else
    [Market]. Same arming condition as {!Backtest.Panel_runner}'s simulator
    entry cap, so the recorded designed-order shape matches what the simulator
    actually emitted. *)

val enrich :
  audit:Trade_audit.audit_record list ->
  round_trips:Trading_simulation.Metrics.trade_metrics list ->
  entry_order_kind:entry_order_kind ->
  Trade_audit.audit_record list
(** Populate [audit_record.execution] for every record whose entry has a matched
    fill among [round_trips]. Records with no matched fill (still open at
    end-of-run, or otherwise unjoined) are returned unchanged with
    [execution = None]. Pure; order-preserving. The join is by position id
    resolved through {!Trade_context} — the first round-trip matched to a given
    position supplies its entry fill.

    Also stamps the fill-side half of the PR-5 ticket-lifecycle record: a
    matched record's [entry.ticket_lifecycle.ticket_age_weeks_at_fill] is set to
    whole weeks between its [placement_date] and the matched round-trip's
    entry-fill date. This join is the only place both instants are in hand, so
    the age rides along rather than duplicating the join in a second pass. Only
    that one column is written: a row with no [ticket_lifecycle] (a
    [trade_audit.sexp] written before PR-5) is left untouched, and an
    already-merged [ticket_age_weeks_at_cancel] is preserved — a cancelled
    ticket produces no round-trip to match, so the two never collide.

    {b The age inherits this join's 7-day window.} A ticket that rests longer
    than a week before filling is not matched at all — it already gets
    [execution = None] today — so its age stays [None] rather than being
    recorded. The stamped ages are therefore 0 or 1 week, not a resting-time
    distribution; see [Trade_audit.ticket_lifecycle]'s field doc. *)

val enrich_for_config :
  audit:Trade_audit.audit_record list ->
  round_trips:Trading_simulation.Metrics.trade_metrics list ->
  config:Weinstein_strategy.config ->
  Trade_audit.audit_record list
(** [enrich] with the [entry_order_kind] derived from [config] via
    {!entry_order_kind_of_config} — the runner's one-call entry point. *)

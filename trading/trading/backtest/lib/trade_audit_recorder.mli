(** Construct a {!Weinstein_strategy.Audit_recorder.t} that drains every
    captured event into a {!Trade_audit.t} collector.

    The strategy library does not depend on Backtest, so the strategy emits raw
    events ({!Audit_recorder.entry_event} / [exit_event]) carrying the analysis
    values it has at decision time. This module is the backtest-side translator:
    it builds {!Trade_audit.entry_decision} / [exit_decision] records from the
    events and accumulates them into the collector. *)

val of_collector :
  ?candidate_log:Candidate_log.collector ->
  trade_audit:Trade_audit.t ->
  force_liquidation_log:Force_liquidation_log.t ->
  unit ->
  Weinstein_strategy.Audit_recorder.t
(** [of_collector ~trade_audit ~force_liquidation_log ()] returns a recorder
    bundle whose:
    - [record_entry] / [record_exit] / [record_cascade_summary] callbacks
      construct the corresponding {!Trade_audit} records from the strategy's
      events and route them into [trade_audit].
    - [record_force_liquidation] callback appends the event to
      [force_liquidation_log] verbatim — the event already carries every
      audit-relevant field.

    [?candidate_log] (issue #2490) is the opt-in per-week candidate sink. When
    [Some c], the returned bundle carries [capture_candidates = true], so the
    strategy populates [Audit_recorder.cascade_event.candidates] and
    [record_cascade_summary] additionally drains one {!Candidate_log.week} per
    screened Friday into [c] — including Fridays that funded nothing. When
    absent (the default), [capture_candidates] is [false], the strategy skips
    the projection, and this module's behaviour is bit-identical to the
    pre-#2490 recorder. The candidate weeks accumulate in their own collector
    rather than on [Trade_audit.t], so [trade_audit.sexp]'s on-disk shape does
    not move. *)

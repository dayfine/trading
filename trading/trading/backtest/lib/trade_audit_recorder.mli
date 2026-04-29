(** Construct a {!Weinstein_strategy.Audit_recorder.t} that drains every
    captured event into a {!Trade_audit.t} collector.

    The strategy library does not depend on Backtest, so the strategy emits raw
    events ({!Audit_recorder.entry_event} / [exit_event]) carrying the analysis
    values it has at decision time. This module is the backtest-side translator:
    it builds {!Trade_audit.entry_decision} / [exit_decision] records from the
    events and accumulates them into the collector. *)

val of_collector :
  trade_audit:Trade_audit.t ->
  force_liquidation_log:Force_liquidation_log.t ->
  Weinstein_strategy.Audit_recorder.t
(** [of_collector ~trade_audit ~force_liquidation_log] returns a recorder bundle
    whose:
    - [record_entry] / [record_exit] / [record_cascade_summary] callbacks
      construct the corresponding {!Trade_audit} records from the strategy's
      events and route them into [trade_audit].
    - [record_force_liquidation] callback appends the event to
      [force_liquidation_log] verbatim — the event already carries every
      audit-relevant field. *)

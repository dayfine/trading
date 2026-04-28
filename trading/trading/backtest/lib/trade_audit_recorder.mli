(** Construct a {!Weinstein_strategy.Audit_recorder.t} that drains every
    captured event into a {!Trade_audit.t} collector.

    The strategy library does not depend on Backtest, so the strategy emits raw
    events ({!Audit_recorder.entry_event} / [exit_event]) carrying the analysis
    values it has at decision time. This module is the backtest-side translator:
    it builds {!Trade_audit.entry_decision} / [exit_decision] records from the
    events and accumulates them into the collector. *)

val of_collector : Trade_audit.t -> Weinstein_strategy.Audit_recorder.t
(** [of_collector collector] returns a recorder bundle whose [record_entry] and
    [record_exit] callbacks construct the corresponding {!Trade_audit} records
    from the strategy's events and route them into [collector] via
    {!Trade_audit.record_entry} / [record_exit]. *)

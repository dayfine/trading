(** Exit-side trade-audit capture.

    Bridges {!Stops_runner}'s [TriggerExit] transitions to
    {!Audit_recorder.exit_event}. Reads the strategy's cached macro snapshot and
    the [prior_stages] hashtable (also threaded into the stops loop) to build
    the state-at-exit fields the audit's [exit_decision] requires.

    Pure observer — no side effects on strategy state, only on the audit
    collector. *)

open Core

val emit_exit_audit :
  audit_recorder:Audit_recorder.t ->
  prior_macro_result:Macro.result option ref ->
  stage_config:Stage.config ->
  lookback_bars:int ->
  bar_reader:Bar_reader.t ->
  prior_stages:Weinstein_types.stage Hashtbl.M(String).t ->
  positions:Trading_strategy.Position.t Map.M(String).t ->
  Trading_strategy.Position.transition ->
  unit
(** [emit_exit_audit ~audit_recorder ~prior_macro_result ~stage_config
     ~lookback_bars ~bar_reader ~prior_stages ~positions transition] inspects
    [transition]: when its kind is [TriggerExit], looks up the matching
    {!Trading_strategy.Position.t} via [transition.position_id] in [positions],
    snapshots the macro / stage / RS state at exit time, and invokes
    [audit_recorder.record_exit].

    Other transition kinds are ignored — the function is intentionally a no-op
    when called on adjust / non-exit transitions, so callers can pipe every
    emitted transition through it without filtering first.

    [prior_macro_result] is the strategy's cached macro snapshot (option ref) —
    last set inside [Weinstein_strategy._run_screen]. When it's still [None]
    (exit fired before the first Friday) the snapshot defaults to [Neutral] /
    [0.0]. *)

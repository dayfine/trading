open Macro_types

(** Per-indicator signal helpers for [Macro.analyze_with_callbacks].

    Separated from [Macro] to keep both files under the 300-line linter limit.
    All functions are pure: same inputs (config + callbacks + index stage)
    produce the same indicator readings.

    The five Weinstein macro indicators are:
    - Index Stage — derived from [Stage.classify_with_callbacks] on the primary
      index (caller pre-computes and passes in [index_stage]).
    - A-D Line — divergence signal from cumulative A-D vs index closes.
    - Momentum Index — sign of the precomputed A-D momentum MA scalar.
    - NH-NL — proxy from index price ratio over the configured lookback.
    - Global Markets — consensus signal across the per-global-index Stage
      callbacks bundled in [callbacks.global_index_stages]. *)

val build_indicators_from_callbacks :
  config:config ->
  index_stage:Stage.result ->
  callbacks:callbacks ->
  indicator_reading list
(** [build_indicators_from_callbacks ~config ~index_stage ~callbacks] returns
    the five Weinstein indicator readings in the same order [Macro.analyze]
    consumed them historically: [Index Stage], [A-D Line], [Momentum Index],
    [NH-NL], [Global Markets]. *)

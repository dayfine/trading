open Core

(** Macro computation and screen-dispatch helpers, factored out of
    [Weinstein_strategy_screening] to keep that file within the 300-line soft
    limit. All three functions are wired directly by [Weinstein_strategy] and
    are not intended for external callers. *)

val run_macro_only :
  config:Weinstein_strategy_config.config ->
  ad_bars:Macro.ad_bar list ->
  prior_macro:Weinstein_types.market_trend ref ->
  prior_macro_result:Macro.result option ref ->
  bar_reader:Bar_reader.t ->
  prior_stages:Weinstein_types.stage Hashtbl.M(String).t ->
  current_date:Date.t ->
  index_view:Snapshot_runtime.Snapshot_bar_views.weekly_view ->
  Macro.result
(** Compute the macro result for [current_date] and update [prior_macro] /
    [prior_macro_result] refs in place. Runs unconditionally on every Friday so
    that halt-reset logic can consult the freshest macro trend even when the
    universe screen is gated off. *)

val run_screen_after_macro :
  fold_start_date:Date.t option ->
  config:Weinstein_strategy_config.config ->
  stop_states:Weinstein_stops.stop_state String.Map.t ref ->
  last_stop_out_dates:Date.t Hashtbl.M(String).t ->
  bar_reader:Bar_reader.t ->
  prior_stages:Weinstein_types.stage Hashtbl.M(String).t ->
  sector_prior_stages:Weinstein_types.stage Hashtbl.M(String).t ->
  ticker_sectors:(string, string) Hashtbl.t ->
  get_price:(string -> Types.Daily_price.t option) ->
  portfolio:Trading_strategy.Portfolio_view.t ->
  current_date:Date.t ->
  index_view:Snapshot_runtime.Snapshot_bar_views.weekly_view ->
  audit_recorder:Audit_recorder.t ->
  macro_result:Macro.result ->
  Trading_strategy.Position.transition list
(** Run the Friday universe screener given an already-computed [macro_result].
    Builds the sector map, delegates to
    {!Weinstein_strategy_screening.screen_universe}, and returns entry
    transitions.

    [~fold_start_date] is required (pass [None] to preserve baselines; pass
    [Some d] to enable Win #4 universe pre-pruning at the per-Friday screener).
    Internal helper: optional plumbing is hidden behind
    {!Weinstein_strategy.make}'s [?fold_start_date] (default [None]). When
    [Some d], the screener pre-prunes [config.universe] before Phase 1 stage
    classification, dropping symbols whose [active_through < d] via the
    snapshot-backed [Bar_reader] callbacks. Point-in-time, NOT survivor bias.
    See [dev/plans/v7-sweep-speedup-2026-05-26.md] §Win #4. *)

val entry_transitions_if_active :
  fold_start_date:Date.t option ->
  halted:bool ->
  is_screening_day:bool ->
  macro_result_opt:Macro.result option ->
  config:Weinstein_strategy_config.config ->
  stop_states:Weinstein_stops.stop_state String.Map.t ref ->
  last_stop_out_dates:Date.t Hashtbl.M(String).t ->
  bar_reader:Bar_reader.t ->
  prior_stages:Weinstein_types.stage Hashtbl.M(String).t ->
  sector_prior_stages:Weinstein_types.stage Hashtbl.M(String).t ->
  ticker_sectors:(string, string) Hashtbl.t ->
  get_price:(string -> Types.Daily_price.t option) ->
  portfolio:Trading_strategy.Portfolio_view.t ->
  current_date:Date.t ->
  index_view:Snapshot_runtime.Snapshot_bar_views.weekly_view ->
  audit_recorder:Audit_recorder.t ->
  Trading_strategy.Position.transition list
(** Run the universe screen only when [halted = false],
    [is_screening_day = true], and [macro_result_opt = Some _]. Returns [[]]
    when any guard is false. Keeps [_on_market_close] at a shallow nesting
    level.

    [~fold_start_date] is forwarded to {!run_screen_after_macro}. See its doc.
*)

module Internal_for_test : sig
  val pi_membership_at : bar_reader:Bar_reader.t -> string -> Date.t -> bool
  (** [pi_membership_at ~bar_reader symbol as_of] is the point-in-time
      membership predicate the strategy hands to
      {!Screener.screen_with_cooldown} when [config.enable_pi_filter = true].

      Returns [true] for: a symbol with no resident bars (no delisting marker
      available; the cascade's downstream phases will themselves drop the symbol
      when its weekly view is empty); a symbol whose most recent bar has
      [active_through = None] (still trading or unknown delisting status); a
      symbol whose most recent bar has [active_through = Some d] with
      [as_of <= d].

      Returns [false] only when the most recent bar carries
      [active_through = Some d] with [as_of > d] — the symbol is known to have
      been delisted before the cascade's evaluation date.

      Exposed for behavioural unit-testing of the [Bar_reader] →
      [Daily_price.active_through] wiring. *)

  val membership_at_callback_of :
    config:Weinstein_strategy_config.config ->
    bar_reader:Bar_reader.t ->
    (string -> Date.t -> bool) option
  (** [membership_at_callback_of ~config ~bar_reader] returns [None] when
      [config.enable_pi_filter = false] (default), preserving existing
      baselines, and [Some] of {!pi_membership_at} closed over [bar_reader] when
      [config.enable_pi_filter = true]. Exposed for unit-testing the flag-driven
      branch. *)
end

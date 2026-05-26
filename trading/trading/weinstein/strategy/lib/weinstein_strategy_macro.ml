open Core
open Weinstein_strategy_config

(** Compute the macro result for [current_date] and update the strategy's macro
    refs. Cheap relative to [run_screen_after_macro] — touches only the index,
    globals, AD bars, and the macro analyser. Runs unconditionally on every
    Friday (including when the halt is active) so [_maybe_reset_halt] can
    consult the freshest macro trend even when the universe screen is gated off.
*)
let run_macro_only ~config ~ad_bars ~prior_macro ~prior_macro_result ~bar_reader
    ~prior_stages ~current_date ~index_view =
  let index_prior_stage = Hashtbl.find prior_stages config.indices.primary in
  (* Phase F.3.d-2 caller migration: the global-index view assembly reads
     through {!Snapshot_runtime.Snapshot_callbacks} directly via the
     [*_of_snapshot_views] API rather than re-routing through the
     bar_reader's panel-shaped views. The cb is exposed by the
     snapshot-backed [Bar_reader.t] (production runner uses
     {!Bar_reader.of_snapshot_views} post-#864). *)
  let cb = Bar_reader.snapshot_callbacks bar_reader in
  let global_index_views =
    Macro_inputs.build_global_index_views_of_snapshot_views
      ~lookback_bars:config.lookback_bars
      ~global_index_symbols:config.indices.global ~cb ~as_of:current_date
  in
  let ma_cache = Bar_reader.ma_cache bar_reader in
  let ad_bars =
    Macro_inputs.ad_bars_at_or_before ~ad_bars ~as_of:current_date
  in
  let macro_callbacks =
    Panel_callbacks.macro_callbacks_of_weekly_views ?ma_cache
      ~index_symbol:config.indices.primary ~config:config.macro_config
      ~index:index_view ~globals:global_index_views ~ad_bars ()
  in
  let macro_result =
    Macro.analyze_with_callbacks ~config:config.macro_config
      ~callbacks:macro_callbacks ~prior_stage:index_prior_stage ~prior:None
  in
  prior_macro := macro_result.trend;
  prior_macro_result := Some macro_result;
  macro_result

(** Point-in-time membership predicate derived from [Bar_reader].

    [pi_membership_at ~bar_reader symbol as_of] returns:
    - [true] when the symbol has no resident bars on or before [as_of] — no
      delisting information available, default to membership so the cascade's
      downstream phases (which will themselves drop the symbol when its weekly
      view is empty) make the rejection decision uniformly.
    - [true] when the most recent bar's [active_through] is [None] — the symbol
      is still trading or the loader did not surface a delisting marker.
    - [Core.Date.(as_of <= d)] when the most recent bar's [active_through] is
      [Some d] — the symbol was active through [d] and is treated as a member on
      or before that date.

    Reading the last bar only (rather than scanning the full history) is
    sufficient: the snapshot pipeline writes [active_through] uniformly on every
    per-symbol row, so any non-empty history will surface the marker on its last
    row. *)
let _pi_membership_at ~bar_reader (symbol : string) (as_of : Core.Date.t) =
  let bars = Bar_reader.daily_bars_for bar_reader ~symbol ~as_of in
  match List.last bars with
  | None -> true
  | Some bar -> (
      match bar.Types.Daily_price.active_through with
      | None -> true
      | Some d -> Core.Date.( <= ) as_of d)

(** Build the optional [?membership_at] callback for {!screen_universe} based on
    [config.enable_pi_filter]. When the flag is [false] (default), returns
    [None] — the screener's PI gate is a no-op and baselines are preserved. When
    [true], returns [Some] of {!_pi_membership_at} closed over [bar_reader]. *)
let _membership_at_callback_of ~config ~bar_reader =
  if config.enable_pi_filter then Some (_pi_membership_at ~bar_reader) else None

(** Build the [(?active_through_for, ?fold_start_date)] pair the screener pre-
    pruning uses. Returns [(None, None)] when [fold_start_date] is [None] —
    pre-pruning disabled. Otherwise, derives [active_through_for] from the
    bar_reader's snapshot callbacks and returns [(Some f, Some d)].

    The cb path reads the per-symbol [active_through] field straight off the
    snapshot manifest, so the lookup is O(1) and avoids per-symbol bar reads
    (which is the whole point of pre-pruning — skip Phase-1's weekly_view_for
    work on inactive symbols entirely). *)
let _prune_args_of ~bar_reader ~fold_start_date =
  match fold_start_date with
  | None -> (None, None)
  | Some d ->
      let cb = Bar_reader.snapshot_callbacks bar_reader in
      let f symbol =
        cb.Snapshot_runtime.Snapshot_callbacks.active_through_for ~symbol
      in
      (Some f, Some d)

(** Run the Friday universe screener path given an already-computed
    [macro_result]. Under all macro regimes (Bullish, Neutral, Bearish) the
    screener is invoked; macro-specific gating — longs blocked under Bearish,
    shorts blocked under Bullish — happens inside the screener. Under Bearish
    this yields short-side entries (per the bear-market shorting chapter). *)
let run_screen_after_macro ~fold_start_date ~config ~stop_states
    ~last_stop_out_dates ~bar_reader ~prior_stages ~sector_prior_stages
    ~ticker_sectors ~get_price ~portfolio ~current_date ~index_view
    ~audit_recorder ~macro_result =
  let ma_cache = Bar_reader.ma_cache bar_reader in
  (* Phase F.3.d-2 caller migration: the sector ETF analysis reads through
     {!Snapshot_runtime.Snapshot_callbacks} directly via the
     [*_of_snapshot_views] API. See [run_macro_only] for context on the
     cb-from-bar_reader plumbing. *)
  let cb = Bar_reader.snapshot_callbacks bar_reader in
  let sector_map =
    Macro_inputs.build_sector_map_of_snapshot_views ?ma_cache
      ~stage_config:config.stage_config ~lookback_bars:config.lookback_bars
      ~sector_etfs:config.sector_etfs ~cb ~as_of:current_date
      ~sector_prior_stages ~index_view ~ticker_sectors ()
  in
  let membership_at = _membership_at_callback_of ~config ~bar_reader in
  let active_through_for, fold_start_date =
    _prune_args_of ~bar_reader ~fold_start_date
  in
  Weinstein_strategy_screening.screen_universe ?active_through_for
    ?fold_start_date ?membership_at ~config ~index_view ~macro_result
    ~sector_map ~stop_states ~last_stop_out_dates ~portfolio ~get_price
    ~bar_reader ~prior_stages ~current_date ~audit_recorder ()

(** Run the universe screen when the strategy is active (not halted, on a
    Friday, with a valid macro result). Returns the list of entry transitions,
    or [[]] when any guard is false. Extracted from [_on_market_close] to keep
    the entry-transition branch at a shallower nesting level. *)
let entry_transitions_if_active ~fold_start_date ~halted ~is_screening_day
    ~macro_result_opt ~config ~stop_states ~last_stop_out_dates ~bar_reader
    ~prior_stages ~sector_prior_stages ~ticker_sectors ~get_price ~portfolio
    ~current_date ~index_view ~audit_recorder =
  match (halted, is_screening_day, macro_result_opt) with
  | false, true, Some macro_result ->
      run_screen_after_macro ~fold_start_date ~config ~stop_states
        ~last_stop_out_dates ~bar_reader ~prior_stages ~sector_prior_stages
        ~ticker_sectors ~get_price ~portfolio ~current_date ~index_view
        ~audit_recorder ~macro_result
  | _ -> []

module Internal_for_test = struct
  let pi_membership_at = _pi_membership_at
  let membership_at_callback_of = _membership_at_callback_of
end

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

(** Run the Friday universe screener path given an already-computed
    [macro_result]. Under all macro regimes (Bullish, Neutral, Bearish) the
    screener is invoked; macro-specific gating — longs blocked under Bearish,
    shorts blocked under Bullish — happens inside the screener. Under Bearish
    this yields short-side entries (per the bear-market shorting chapter). *)
let run_screen_after_macro ~config ~stop_states ~last_stop_out_dates ~bar_reader
    ~prior_stages ~sector_prior_stages ~ticker_sectors ~get_price ~portfolio
    ~current_date ~index_view ~audit_recorder ~macro_result =
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
  Weinstein_strategy_screening.screen_universe ~config ~index_view ~macro_result
    ~sector_map ~stop_states ~last_stop_out_dates ~portfolio ~get_price
    ~bar_reader ~prior_stages ~current_date ~audit_recorder

(** Run the universe screen when the strategy is active (not halted, on a
    Friday, with a valid macro result). Returns the list of entry transitions,
    or [[]] when any guard is false. Extracted from [_on_market_close] to keep
    the entry-transition branch at a shallower nesting level. *)
let entry_transitions_if_active ~halted ~is_screening_day ~macro_result_opt
    ~config ~stop_states ~last_stop_out_dates ~bar_reader ~prior_stages
    ~sector_prior_stages ~ticker_sectors ~get_price ~portfolio ~current_date
    ~index_view ~audit_recorder =
  match (halted, is_screening_day, macro_result_opt) with
  | false, true, Some macro_result ->
      run_screen_after_macro ~config ~stop_states ~last_stop_out_dates
        ~bar_reader ~prior_stages ~sector_prior_stages ~ticker_sectors
        ~get_price ~portfolio ~current_date ~index_view ~audit_recorder
        ~macro_result
  | _ -> []

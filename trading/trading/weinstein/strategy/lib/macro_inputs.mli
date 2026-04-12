(** Assembly of macro-analyzer and screener inputs from a per-symbol bar
    history. Isolates data plumbing from the {!Weinstein_strategy} orchestrator
    so the strategy module focuses on transitions, stops, and screening cadence.

    All functions are side-effectful only on their explicitly-passed state
    (notably [sector_prior_stages]). The underlying bar_history is read-only. *)

open Core

val spdr_sector_etfs : (string * string) list
(** SPDR sector ETFs covering the 11 US GICS sectors. The list is stable since
    2018, when XLC was added following the GICS reclassification of
    Communication Services. Exposed so that callers of
    {!Weinstein_strategy.default_config} can opt into sector analysis without
    duplicating the list. *)

val default_global_indices : (string * string) list
(** Major non-US equity indices used by the macro global-consensus indicator.
    [GSPC.INDX] (the US benchmark) is intentionally omitted — it is already
    passed to {!Macro.analyze} as [~index_bars].

    Note: FTSE 100 is represented by [ISF.LSE] (iShares Core FTSE 100 UCITS ETF)
    because EODHD does not carry [FTSE.INDX] or [UKX.INDX]. The ETF is a
    physical-replication tracker with negligible tracking error at weekly
    cadence. *)

val build_global_index_bars :
  lookback_bars:int ->
  global_index_symbols:(string * string) list ->
  bar_history:Bar_history.t ->
  (string * Types.Daily_price.t list) list
(** [build_global_index_bars] returns the [(label, weekly_bars)] list consumed
    by {!Macro.analyze} for the global-consensus indicator. Each entry is
    produced by converting the accumulated daily bars for that symbol to weekly
    bars (most recent [lookback_bars] weeks). Indices with no accumulated bars
    are silently dropped so that Macro sees only usable inputs. *)

val build_sector_map :
  stage_config:Stage.config ->
  lookback_bars:int ->
  sector_etfs:(string * string) list ->
  bar_history:Bar_history.t ->
  sector_prior_stages:Weinstein_types.stage Hashtbl.M(String).t ->
  index_bars:Types.Daily_price.t list ->
  (string, Screener.sector_context) Hashtbl.t
(** [build_sector_map] returns a map keyed by ETF symbol. Each entry is the
    {!Screener.sector_context} produced by {!Sector.analyze} on that ETF's
    accumulated weekly bars. ETFs with fewer than [stage_config.ma_period] bars
    are skipped. An empty [index_bars] also skips analysis.

    [sector_prior_stages] is read and updated in place so that Stage1->Stage2
    transitions are detected across screening days — the caller owns this
    hashtable as part of the strategy closure state. *)

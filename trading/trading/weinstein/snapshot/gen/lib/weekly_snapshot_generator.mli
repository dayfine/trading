(** Weekly-snapshot generator (M6.6 / Initiative A).

    The missing producer in the M6 weekly-snapshot subsystem. M6.1–M6.5 built
    the {!Weekly_snapshot.t} type, the writer/reader, the forward-trace, the
    cross-version diff, and the report renderer — but every consumer
    ([trace_picks] / [diff_picks] / [render_weekly_report]) {b reads} an
    existing pick file; nothing {b produced} one from data. This module closes
    that gap.

    {1 What it does}

    {!generate} runs the {b existing} Weinstein screener cascade on cached bars
    for one as-of date and assembles a {!Weekly_snapshot.t}:

    - macro context — {!Macro.analyze} on the primary index,
    - sector strength — {!Sector.analyze} per sector ETF, expanded to its
      tickers,
    - ranked long / short candidates — {!Screener.screen} (score / grade /
      suggested entry / suggested stop / sector / rationale / RS / resistance),
    - held positions — passed in by the caller (empty for a fresh generate; the
      live cycle threads real trading state here later).

    {b This module reimplements no strategy logic.} Every analysis step
    ({!Macro.analyze}, {!Sector.analyze}, {!Stock_analysis.analyze},
    {!Screener.screen}) is an existing pure primitive; the generator only wires
    them in the documented cascade order, exactly as the live strategy does.

    {1 Degraded inputs}

    The generator fails {b soft} the same way the strategy does:

    - A symbol with too few weekly bars to analyse is dropped from candidate
      consideration (it cannot satisfy the screener's breakout / breakdown
      rules).
    - A sector ETF with no bars (or too few) is skipped; its tickers default to
      a {!Screener.Neutral} sector rating (the screener's own fallback for
      unknown tickers).
    - An empty / too-short primary index degrades the macro gate to
      {!Weinstein_types.Neutral} (both long and short candidates remain
      eligible), matching {!Weinstein_strategy.make}'s no-index behaviour.

    All bar reads route through a {!Weinstein_strategy.Bar_reader.t} so the
    weekly-aggregation + as-of slicing is bit-identical to the strategy's own.
*)

open Core
open Weinstein_snapshot

type inputs = {
  config : Weinstein_strategy.config;
      (** Full strategy config — drives the screener cascade
          ([config.screening_config]), stage / macro analysers, sector ETF list
          ([config.sector_etfs]), primary index ([config.indices.primary]), and
          [config.lookback_bars]. All thresholds come from here, never
          hardcoded. *)
  system_version : string;
      (** System-version tag written into the snapshot (typically a git SHA).
          Recorded verbatim and used in the on-disk path. *)
  as_of : Date.t;  (** The (Friday-close) date the snapshot represents. *)
  bar_reader : Weinstein_strategy.Bar_reader.t;
      (** Snapshot-backed bar source covering the universe symbols, the sector
          ETFs, and the primary index. Built by the caller via
          {!Weinstein_strategy.Bar_reader.of_in_memory_bars} (CLI path) or any
          other constructor. *)
  ticker_sectors : (string * string) list;
      (** [(ticker, sector_name)] pairs — the universe with each symbol's GICS
          sector. Used to (a) drive screening over [config.universe] and (b)
          expand sector-ETF ratings to individual tickers. The screened universe
          is the list of tickers here (it overrides [config.universe] so the
          caller need not keep the two in sync). *)
  held_positions : Weekly_snapshot.held_position list;
      (** Held positions to record in the snapshot. Empty for a fresh generate;
          the live cycle threads real trading-state positions here. The held
          tickers are also excluded from the screener candidate output. *)
}
(** Everything {!generate} needs to assemble one snapshot. *)

val generate : inputs -> Weekly_snapshot.t
(** [generate inputs] runs the cascade and returns the assembled snapshot.

    Pure with respect to its inputs (the [bar_reader] is read-only). The
    returned snapshot carries {!Weekly_snapshot.current_schema_version} and the
    given [system_version] / [as_of]. Candidate lists are score-descending (the
    screener's order). *)

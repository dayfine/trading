(** Pipeline orchestrator for the optimal-strategy counterfactual binary.

    Reads the artefacts a prior [scenario_runner.exe] run leaves in
    [output_dir], replays the same Friday calendar with perfect-hindsight
    candidate selection, and writes [<output_dir>/optimal_strategy.md] via
    {!Optimal_strategy_report.render}.

    {1 Pipeline phases}

    The orchestrator is divided into three phases, each surfaced as a named
    helper for testability + readability:

    - {b Build world.} Loads the universe from [<output_dir>/universe.txt]
      ([Backtest.Result_writer]'s artefact, scoped to the actual run's universe
      — falls back to [Sector_map.load] over [data/sectors.csv] when the file is
      absent), constructs the trading-day calendar with a 210-day warm-up window
      before [start_date], builds [Bar_panels.t] over the universe + benchmark
      index, and computes the Friday calendar over the run window.
    - {b Scan and score.} Walks every Friday in the run window, runs
      [Stock_analysis.analyze] per universe symbol, feeds the analyses into
      {!Stage_transition_scanner.scan_week} to emit [candidate_entry] records,
      then walks each candidate's forward weekly bars + stage classifications
      via {!Outcome_scorer.score} to produce [scored_candidate] records with
      realised exits.
    - {b Emit report.} Runs {!Optimal_portfolio_filler.fill} twice (Constrained
      and Relaxed_macro variants), summarises each pack via
      {!Optimal_summary.summarize}, and renders the markdown via
      {!Optimal_strategy_report.render}, writing it to
      [<output_dir>/optimal_strategy.md].

    {1 Macro-trend lookup}

    Per-Friday macro trend is read from [<output_dir>/macro_trend.sexp] — the
    artefact emitted by [Backtest.Macro_trend_writer] on every backtest run (PR
    #671). The runner builds a [Date.t -> market_trend] table at startup and
    consults it inside [_scan_all_fridays] when constructing each
    [Stage_transition_scanner.week_input]. With the file present, [Bearish]
    Fridays cause [passes_macro = false] for that week's candidates, so the
    [Constrained] variant filters them out while [Relaxed_macro] admits them —
    the variants now diverge on macro-driven outcomes.

    Legacy / partial runs that predate PR #671 will not have [macro_trend.sexp].
    The runner falls back to [Neutral] for every Friday (which produces
    [passes_macro = true] across the board) and emits a one-line stderr warning.
    The pipeline still completes; the variants will tag candidates identically
    as they did before the read-side wiring.

    {1 I/O surface}

    - Reads [output_dir/{summary,actual,trade_audit,macro_trend}.sexp] +
      [output_dir/trades.csv]. [trade_audit.sexp] / [trades.csv] /
      [macro_trend.sexp] are optional; missing values fall back to empty /
      [Neutral].
    - Reads OHLCV CSVs and [sectors.csv] under [Data_path.default_data_dir ()]
      (overridable via [TRADING_DATA_DIR]).
    - Writes [output_dir/optimal_strategy.md] (the rendered report).
    - Writes [output_dir/optimal_summary.sexp] via
      {!Optimal_summary_artefact.write} — a structured record with both
      [Constrained] and [Relaxed_macro] variants of
      {!Optimal_types.optimal_summary}, for downstream consumers (e.g.
      release_report) that want headline counterfactual metrics without parsing
      markdown. See {!Optimal_summary_artefact} for the on-disk shape.
    - Writes progress messages to stderr. *)

open Core

type forward_table = (string, Outcome_scorer.weekly_outlook list) Hashtbl.t
(** Per-symbol chronologically-ordered [Outcome_scorer.weekly_outlook list]
    across the run's full Friday calendar. Built once per run by the scoring
    phase so per-candidate scoring is a list slice rather than a fresh
    Stage-classification sweep (PR-1: optimal-strategy improvements 2026-05-01).

    Key: symbol. Value: outlooks sorted ascending by [date], with one entry per
    Friday for which the symbol has enough bars to classify a stage. Fridays
    with insufficient history are absent from the list. Exposed at module
    boundary for direct unit testing; the runner itself consumes the table
    inside {!run}. *)

val forward_outlooks_for :
  forward_table:forward_table ->
  symbol:string ->
  entry_friday:Date.t ->
  Outcome_scorer.weekly_outlook list
(** [forward_outlooks_for ~forward_table ~symbol ~entry_friday] returns the
    per-symbol forward outlooks strictly after [entry_friday]. Returns the empty
    list when [symbol] is absent from the table. Exposed for unit testing the
    memoized-slice contract. *)

val load_macro_trend :
  output_dir:string -> (Date.t, Weinstein_types.market_trend) Hashtbl.t
(** [load_macro_trend ~output_dir] reads [<output_dir>/macro_trend.sexp] and
    returns a [Date.t -> market_trend] lookup table indexed by Friday. The
    artefact is emitted by [Backtest.Macro_trend_writer] on every run.

    Returns an empty table when the file is missing (legacy runs that predate PR
    #671 — write-side macro persistence) or when parsing fails, after logging a
    one-line stderr warning. The runner's fallback at lookup-miss is
    [Weinstein_types.Neutral]. Exposed for direct unit testing; the runner
    itself consumes it through {!run}. *)

val run : output_dir:string -> unit
(** [run ~output_dir] executes the full pipeline end-to-end:

    1. Loads actual-run artefacts from [output_dir] via
    {!Optimal_run_artefacts.load}. 2. Builds the bar-panel world from
    [Data_path.default_data_dir ()]. 3. Scans every Friday in the run window for
    breakout candidates and scores each with a forward weekly walk. 4. Fills +
    summarises the Constrained and Relaxed_macro variants, renders the markdown
    report, and writes it to [<output_dir>/optimal_strategy.md].

    Raises [Failure] if [summary.sexp] or [actual.sexp] is missing / malformed,
    or if panel construction fails (corrupt CSVs, missing benchmark, etc.).
    Tolerates a missing [trades.csv] (renders with no actual round-trips) and
    missing [trade_audit.sexp] (no cascade-rejection annotations on missed
    trades). *)

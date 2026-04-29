(** Pipeline orchestrator for the optimal-strategy counterfactual binary.

    Reads the artefacts a prior [scenario_runner.exe] run leaves in
    [output_dir], replays the same Friday calendar with perfect-hindsight
    candidate selection, and writes [<output_dir>/optimal_strategy.md] via
    {!Optimal_strategy_report.render}.

    {1 Pipeline phases}

    The orchestrator is divided into three phases, each surfaced as a named
    helper for testability + readability:

    - {b Build world.} Loads the universe ([sectors.csv]), constructs the
      trading-day calendar with a 210-day warm-up window before [start_date],
      builds [Bar_panels.t] over the universe + benchmark index, and computes
      the Friday calendar over the run window.
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

    {1 Macro-trend simplification}

    The actual run records a per-Friday macro trend implicitly, but it is not
    yet persisted to disk. The counterfactual currently uses a fixed [Neutral]
    macro trend across all weeks: [passes_macro = true] for every candidate (the
    gate's rule is [macro_trend <> Bearish]), so [Constrained] and
    [Relaxed_macro] tag every candidate identically. The headline comparison
    still surfaces the cascade-ranking gap; honest macro-driven divergence
    between the two variants is a follow-up blocked on the macro-trend
    persistence work (PR #671 emits the file from the writer side; the read side
    is a separate ~30 LOC follow-up).

    {1 I/O surface}

    - Reads [output_dir/{summary,actual,trade_audit}.sexp] +
      [output_dir/trades.csv] (the latter two optional).
    - Reads OHLCV CSVs and [sectors.csv] under [Data_path.default_data_dir ()]
      (overridable via [TRADING_DATA_DIR]).
    - Writes [output_dir/optimal_strategy.md] (the rendered report).
    - Writes progress messages to stderr. *)

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

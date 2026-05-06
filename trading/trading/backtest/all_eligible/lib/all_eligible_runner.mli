(** Pipeline orchestrator for the all-eligible trade-grading binary.

    Loads a {!Scenario_lib.Scenario.t} sexp file, builds the bar-panel world
    from [Data_path.default_data_dir ()], scans every Friday in the scenario
    window for Stage-1→2 breakouts, scores each candidate by forward-walking the
    panel via {!Backtest_optimal.Outcome_scorer.score}, projects each scored
    candidate into a fixed-dollar {!All_eligible.trade_record} via
    {!All_eligible.grade}, and writes three artefacts to [out_dir]:

    - [trades.csv] — one row per signal with the per-trade fields.
    - [summary.md] — Markdown table summarising the {!All_eligible.aggregate}.
    - [config.sexp] — the resolved {!All_eligible.config} used (so the run is
      reproducible).

    {1 Pipeline phases}

    - {b Build world.} Resolves the scenario's universe via
      {!Scenario_lib.Universe_file.load} (Pinned ⇒ exactly those symbols;
      Full_sector_map ⇒ {!Sector_map.load} over [data/sectors.csv]), builds an
      in-process snapshot directory via {!Backtest.Csv_snapshot_builder.build}
      over the universe + benchmark with a 210-day warm-up window, and opens a
      {!Snapshot_runtime.Daily_panels.t} over it.
    - {b Scan + score.} Walks each Friday running {!Stock_analysis.analyze} per
      symbol, feeds the analyses to
      {!Backtest_optimal.Stage_transition_scanner.scan_week} to emit
      {!Backtest_optimal.Optimal_types.candidate_entry}s, then forward-walks
      each candidate's weekly outlooks via
      {!Backtest_optimal.Outcome_scorer.score} to produce
      {!Backtest_optimal.Optimal_types.scored_candidate}s.
    - {b Dedup.} Applies {!All_eligible.dedup_first_admission} to collapse the
      multiple consecutive-Friday emissions a single Stage 1→2 transition
      produces (the breakout predicate stays true for the first ~four weeks of a
      Stage 2 advance) into one trade per first admission. Without this step the
      trade count is inflated ~5x relative to the actual number of breakout
      events.
    - {b Grade + emit.} Calls {!All_eligible.grade} with the configured
      [entry_dollars] / [return_buckets] and writes the three artefacts.

    {1 Reuse, not duplication}

    The scan + score primitives are public APIs of [backtest_optimal]; the
    orchestration helpers here are minimal local copies of the optimal-strategy
    runner's private equivalents. A future cleanup could extract the shared
    orchestration into a sibling module under [backtest_optimal].

    {1 I/O surface}

    - Reads the scenario sexp at [scenario_path].
    - Reads the universe-file sexp referenced by the scenario.
    - Reads OHLCV CSVs and [sectors.csv] under [Data_path.default_data_dir ()]
      (overridable via [TRADING_DATA_DIR]).
    - Writes [out_dir/{trades.csv,summary.md,config.sexp}].
    - Writes progress messages to stderr. *)

open Core

type cli_args = {
  scenario_path : string;  (** Path to the scenario sexp file. *)
  out_dir : string option;
      (** Output directory. When [None], defaults to
          [dev/all_eligible/<scenario.name>/<UTC-ISO-timestamp>/]. *)
  entry_dollars : float option;
      (** Override for [All_eligible.config.entry_dollars]. [None] keeps the
          library default. *)
  return_buckets : float list option;
      (** Override for [All_eligible.config.return_buckets]. [None] keeps the
          library default. *)
  config_overrides : Sexp.t list;
      (** Additional sexp config-overrides to deep-merge over the scenario's own
          [config_overrides] field (themselves applied over the live screener
          default config). Currently a passthrough — the diagnostic uses the
          screener's default scoring weights / grade thresholds / candidate
          params, and these overrides are accepted on the CLI for
          forward-compatibility but not yet threaded into the scanner config.
          Documented as inert in the public surface so callers don't expect
          behavioural change. *)
}
(** Parsed CLI arguments. Exposed for unit testing the parser; the binary
    consumes this through {!run_with_args}. *)

val parse_argv : string array -> cli_args
(** [parse_argv argv] parses the argv vector (including [argv.(0)], the program
    name) into a {!cli_args} record.

    Recognised flags:
    - [--scenario <path>] (required)
    - [--out-dir <path>] (optional)
    - [--entry-dollars <float>] (optional)
    - [--return-buckets <csv-floats>] (optional, e.g. [-0.5,0.0,0.5])
    - [--config-overrides <sexp-list>] (optional, parsed as a sexp list)

    Raises [Failure] on missing [--scenario] or malformed flag values. *)

val resolve_out_dir : scenario_name:string -> cli_args -> string
(** [resolve_out_dir ~scenario_name args] returns [args.out_dir] when set, else
    [dev/all_eligible/<scenario_name>/<UTC-ISO-timestamp>/]. The directory is
    not created here — the caller materialises it. *)

val resolve_config : cli_args -> All_eligible.config
(** [resolve_config args] starts from {!All_eligible.default_config} and applies
    [args.entry_dollars] / [args.return_buckets] when present. *)

val format_summary_md :
  scenario_name:string ->
  start_date:Date.t ->
  end_date:Date.t ->
  result:All_eligible.result ->
  string
(** [format_summary_md ~scenario_name ~start_date ~end_date ~result] renders
    [result.aggregate] as a Markdown report. Includes the scenario header, the
    aggregate metrics table, and a bucket-histogram table. Pure function;
    exposed for direct unit testing. *)

val write_trades_csv : path:string -> All_eligible.result -> unit
(** [write_trades_csv ~path result] writes one CSV row per [result.trades]
    entry, with a header row matching the {!All_eligible.trade_record} field
    set. Overwrites any existing file at [path]. *)

val run_with_args : cli_args -> unit
(** [run_with_args args] executes the full pipeline:

    1. Loads the scenario sexp and resolves its universe. 2. Builds the
    bar-panel world. 3. Scans + scores all Fridays in the scenario window. 4.
    Dedups consecutive-Friday re-firings via
    {!All_eligible.dedup_first_admission}. 5. Grades each surviving candidate
    via {!All_eligible.grade}. 6. Writes [trades.csv] / [summary.md] /
    [config.sexp] to the resolved [out_dir].

    Raises [Failure] when the scenario file is malformed, when the universe file
    is unresolved, or when snapshot construction fails. *)

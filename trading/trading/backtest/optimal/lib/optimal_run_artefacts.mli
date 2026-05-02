(** On-disk artefact loaders for {!Optimal_strategy_runner}.

    Reads the four files a prior [scenario_runner.exe] run leaves in
    [<output_dir>/]:

    - [summary.sexp] — [Backtest.Summary.t] header (start/end dates, universe
      size, initial cash, final portfolio value).
    - [actual.sexp] — [Backtest.Scenarios.Scenario_runner.actual] record (win
      rate, Sharpe, MaxDD, etc.).
    - [trades.csv] — round-trip rows in the on-disk format produced by
      [Backtest.Result_writer._write_trade_row].
    - [trade_audit.sexp] — optional. When present, parsed via
      [Backtest.Trade_audit.audit_blob_of_sexp] and harvested into
      [(symbol, reason)] pairs for the renderer's missed-trade annotations.
      Missing audit ⇒ empty list.

    All loaders raise (via [failwithf]) when a {b required} file is missing. The
    trade-audit loader and the trades-csv loader both swallow malformed rows /
    parse failures and emit a one-line stderr warning, so a partially corrupt
    audit does not crash the runner.

    Pure with respect to its inputs: same on-disk artefacts ⇒ same
    {!actual_run_inputs}. *)

open Core

type actual_run_inputs = {
  scenario_name : string;
      (** Last path component of [output_dir], used as the scenario display name
          in the rendered report. *)
  start_date : Date.t;
  end_date : Date.t;
  universe_size : int;
  universe : string list;
      (** Sorted list of symbols the actual run traded over. Loaded from
          [<output_dir>/universe.txt] (one symbol per line, no header) — the
          file [Backtest.Result_writer] emits alongside the other artefacts.
          When the file is absent (legacy artefacts), the loader falls back to
          [Sector_map.load] over [data/sectors.csv] with a stderr warning;
          callers that depend on the exact universe should treat the missing
          file as a correctness regression rather than a soft fallback. *)
  initial_cash : float;
  final_portfolio_value : float;
  trades : Trading_simulation.Metrics.trade_metrics list;
      (** Round-trips parsed from [trades.csv]. Empty when the file is missing
          or every row is malformed. *)
  cascade_rejections : (string * string) list;
      (** [(symbol, reason)] pairs harvested from [trade_audit.sexp]'s per-entry
          [alternatives_considered] list. Empty when the audit is absent or
          unreadable. *)
  win_rate_pct : float;
  sharpe_ratio : float;
  max_drawdown_pct : float;
}
(** Bundled output of {!load}. The renderer consumes this (mapped onto
    [Optimal_strategy_report.actual_run]) plus the counterfactual variant packs
    computed by the scanner / scorer / filler. *)

val load : output_dir:string -> actual_run_inputs
(** [load ~output_dir] reads all four artefacts from [output_dir] and bundles
    them.

    Raises [Failure] if [summary.sexp] or [actual.sexp] is missing. Tolerates a
    missing [trades.csv] (returns empty trades) and a missing [trade_audit.sexp]
    (returns empty rejections). Malformed rows in [trades.csv] and parse
    failures on [trade_audit.sexp] log to stderr and are dropped. *)

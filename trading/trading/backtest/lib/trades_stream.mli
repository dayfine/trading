(** [trades.csv] writer — one-shot and incremental.

    Owns the {b sole} definition of the [trades.csv] header and row rendering.
    {!Result_writer.write} calls {!write_all} for the end-of-run file; a long
    run additionally opens a {!t} and appends closed round-trips every N Friday
    cycles (issue #2502). Both paths share {!header} and the same private row
    renderer, so a streamed row and a finalised row are produced by the same
    code — the completed-run contract cannot drift from the mid-run one by
    construction.

    {2 Why stream at all}

    Every scenario artefact is written in one shot at scenario end; mid-run the
    output directory holds only [progress.sexp]. A crash or OOM — which
    [.claude/rules/container-capacity-scheduling.md] documents as a silent,
    recurring failure on multi-hour runs — therefore loses the whole trade
    record of the arm. Streaming turns that into a partial-but-well-formed
    [trades.csv] holding every round-trip closed before the kill, and lets an
    operator read year 1's trades while year 14 is still running.

    {2 The final file is the authority}

    {!Result_writer.write} re-creates [trades.csv] from scratch (truncating
    whatever the stream left) once the run completes, so a {b completed} run's
    file is byte-identical to what it was before streaming existed. Two known
    ways a mid-run row differs from its finalised counterpart, both accepted:

    - {b No [position_id]}. Round-trips are stamped with a position id from the
      simulator's [order_position_links], which only exists on the terminal
      [run_result]. Streamed rows carry an empty [position_id] cell, and the
      {!Trade_context} columns that fall back to the audit join may resolve
      differently.
    - {b Row order}. Streamed rows are appended in flush batches, sorted within
      a batch by [(exit_date, symbol, entry_date)]. The finalised file uses
      {!Trading_simulation.Metrics.extract_round_trips}' own per-symbol
      grouping. Row {e content} for a given round-trip is identical; only the
      line order differs.

    Presence of [trades.csv] is therefore no longer evidence that a run
    finished. The completion sentinel is unchanged: [actual.sexp] for the
    scenario runner (it writes a [crashed = true] sentinel on an exception),
    [summary.sexp] for the plain backtest binary. *)

open Core
module Sim_types = Trading_simulation_types.Simulator_types

type batch = {
  round_trips : Trading_simulation.Metrics.trade_metrics list;
      (** Completed round-trips to render, already filtered to the run window.
      *)
  stop_infos : Stop_log.stop_info list;
      (** Per-position stop records, joined per row by
          {!Trade_context.stop_info_for_trade}. *)
  audit : Trade_audit.audit_record list;
      (** Per-trade decision trail backing the {!Trade_context} columns. *)
  force_liquidations : Portfolio_risk.Force_liquidation.event list;
      (** Force-liquidation events; a row whose [(symbol, exit_date)] matches
          one has its [exit_trigger] overridden to the force-liquidation label.
      *)
}
(** Everything a [trades.csv] row needs. Mirrors the four [Runner.result] fields
    {!Result_writer} previously passed to its private trade writer. *)

val header : string
(** The [trades.csv] header line (without the trailing newline): 13 base columns
    followed by {!Trade_context.csv_header_fields}. Readers must address columns
    by name — see {!Trades_csv_schema}. *)

val default_every_n_fridays : int
(** Flush cadence used when a caller opens a stream without specifying one.
    Matches [Scenario_progress.default_every_n_fridays] so [trades.csv] and
    [progress.sexp] advance together under the scenario runner. *)

val write_all : output_dir:string -> batch -> unit
(** [write_all ~output_dir batch] creates (truncating) [output_dir/trades.csv],
    writes {!header} plus one row per [batch.round_trips] entry in list order,
    and closes the file. This is the end-of-run authority path called by
    {!Result_writer.write}. *)

type t
(** An open incremental [trades.csv] appender. Holds the output channel, the
    per-symbol count of round-trips already emitted, and the simulator steps
    seen so far. Not thread-safe; one per run. *)

val create :
  output_dir:string ->
  ?every_n_fridays:int ->
  snapshot:(steps_rev:Sim_types.step_result list -> batch) ->
  unit ->
  t
(** [create ~output_dir ~snapshot ()] creates (truncating)
    [output_dir/trades.csv] and immediately writes {!header}, so the file is
    present and well-formed from the first cycle even if nothing has closed yet.

    [snapshot] is called at each flush with every simulator step recorded so
    far, {b newest first}, and must return the run-window-filtered {!batch} as
    of that moment. The caller owns window semantics (warmup filtering, etc.);
    this module owns only "which of those round-trips are new".

    [every_n_fridays] defaults to {!default_every_n_fridays} and must be [>= 1];
    a smaller value is clamped to [1]. *)

val record_step : t -> date:Date.t -> step:Sim_types.step_result -> unit
(** [record_step t ~date ~step] records one completed simulator step. On every
    [every_n_fridays]-th Friday it calls the [snapshot] callback and appends the
    round-trips that have closed since the previous flush, then flushes the
    channel so a [SIGKILL]ed process leaves them on disk.

    Emission is exactly-once per round-trip: round-trips are counted per symbol,
    and {!Trading_simulation.Metrics.extract_round_trips} produces a per-symbol
    chronological sequence that only ever grows at its tail (later trades cannot
    change an earlier pairing), so "everything past the count already written"
    is a sound identity. A whole-list index would {e not} be: the extractor
    folds a symbol-keyed map and prepends each symbol's block, so its output
    runs descending by symbol and a newly-traded symbol can insert {e ahead} of
    rows already written. *)

val close : t -> unit
(** [close t] closes the underlying channel. Does not flush a final batch — the
    caller finalises via {!write_all}, which truncates and rewrites the file.
    Idempotent. *)

val rows_written : t -> int
(** Number of data rows appended so far (excluding the header). Exposed for
    tests that pin flush cadence. *)

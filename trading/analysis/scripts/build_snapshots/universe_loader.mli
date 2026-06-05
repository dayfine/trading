(** Universe-file reader for the snapshot warehouse writer.

    [build_snapshots] needs the list of real-ticker symbols to build per-symbol
    snapshots for. Two on-disk universe shapes are accepted; [symbols_of_sexp]
    auto-detects by shape:

    - {b Pinned} — the [scenario_lib/universe_file] shape
      [(Pinned ((symbol AAPL) (sector "Information Technology")) ...)]. The
      [symbol] of each entry is returned verbatim. [Full_sector_map] is
      recognised but unsupported (it needs the sectors.csv side channel the
      runner threads in, which is irrelevant to the snapshot writer).

    - {b Composition snapshot} — an [analysis/data/universe]
      {!Universe.Snapshot.t} with [method_ = Composition_from_individuals], the
      shape the goldens' universes use. Each non-synthetic entry's real ticker
      is returned; synthetic pseudo-symbols ([SYNTH_*], [synthetic = true]) are
      dropped because the writer has no CSV bars for them. Mirrors the
      extraction in [trading/trading/backtest/scenarios/universe_snapshot.ml].
*)

val symbols_of_sexp : Core.Sexp.t -> string list Status.status_or
(** [symbols_of_sexp sexp] extracts the real-ticker symbol list from a parsed
    universe sexp.

    Returns:
    - [Ok symbols] when [sexp] parses as a [Pinned] universe (symbols verbatim)
      or as a composition {!Universe.Snapshot.t} (non-synthetic tickers only).
    - [Error Unimplemented] when [sexp] parses as [Full_sector_map].
    - [Error Failed_precondition] when a composition snapshot has no
      non-synthetic entries (every member is synthetic), mirroring
      [universe_snapshot]'s all-synthetic guard.
    - [Error Failed_precondition] when [sexp] matches neither shape. *)

val symbols_of_path : path:string -> string list Status.status_or
(** [symbols_of_path ~path] loads the sexp at [path] and applies
    {!symbols_of_sexp}. Returns [Error Internal] on a filesystem / sexp-parse
    failure reading the file. *)

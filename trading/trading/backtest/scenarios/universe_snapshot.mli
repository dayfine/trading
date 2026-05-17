(** Bridge: load an [analysis/data/universe] Snapshot sexp and project it onto a
    [(symbol, sector)] pair list — the shape {!Universe_file} downstream
    converts into [pinned_entry] values and into the
    [sector_map_override : (string, string) Hashtbl.t] that
    {!Backtest.Runner.run_backtest} already consumes.

    The custom-universe pipeline ({!Universe.Snapshot}, added in PRs #1161 /
    #1164 / #1169) produces two flavours of universe goldens:

    - {b Composition} ([Composition_from_individuals], 1998-2026): real ticker
      symbols ranked by historical-cap-weight. These are directly tradeable in a
      backtest — the runner loads real CSV bars for each symbol.

    - {b Decomposition} ([Decomposition_from_index], 1926-1997): synthetic
      pseudo-symbols named [SYNTH_<industry>_<rank>]. These are NOT directly
      tradeable; the runner has no synthetic-bar source. This bridge drops them
      and returns [Failed_precondition] when a snapshot contains only synthetic
      entries.

    The {!Universe_file.load} fallback wraps the returned pairs into [Pinned] so
    existing consumers ([scenario_runner], the sweep tool, etc.) work unchanged
    against composition goldens. *)

val load_path_as_pairs : path:string -> (string * string) list Status.status_or
(** [load_path_as_pairs ~path] reads a snapshot sexp at [path] (the shape
    written by {!Universe.Snapshot.save}) and projects each non-synthetic entry
    to a [(symbol, sector)] pair.

    Returns:
    - [Ok pairs] on success, with synthetic entries silently dropped.
    - [Error Failed_precondition] when every entry is synthetic (the resulting
      sector map would be empty, which the runner cannot meaningfully consume).
    - [Error Internal] / [Error Failed_precondition] propagated from
      {!Universe.Snapshot.load} (missing file, malformed sexp). *)

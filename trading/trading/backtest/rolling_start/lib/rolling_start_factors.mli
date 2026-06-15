(** Pure screener-based factor projections for the rolling-start lens (stage
    5b).

    The factor-decomposition lens (design:
    [dev/notes/factor-decomposition-lens-design-2026-06-14.md] §"Factor
    columns") joins each rolling-start row to candidate {b causes} so we can
    explain {b why} the strategy beats (or loses to) the benchmark from a given
    start, not just report a bare aggregate. Stage (a) — the cheap outcome
    columns ([realized_edge_pct], [forward_index_max_dd_pct]) — shipped in
    #1586. This module is stage (b): the {b screener-based} factors evaluated
    {b as-of each start date}.

    All four factors are computed from the {b precomputed} snapshot-warehouse
    fields ([Snapshot_schema.Stage], [Macro_composite], [RS_line]) rather than
    by re-running the classifiers — the offline pipeline is the single source of
    truth for those scalars (see [snapshot_schema.mli]). That keeps the factors
    a cheap point-read per (symbol, date) and keeps this module {b pure}: it
    takes already-read field values and returns the factor, so it is unit-tested
    against hand-computed inputs without any panels handle or I/O.

    Every factor uses [Float.nan] / [None] as the explicit "not available"
    marker, mirroring the nan discipline of {!Rolling_start_types.per_start};
    the renderer / downstream stats decide how to surface "no data" rather than
    this module inventing a sentinel. *)

val macro_stage_of_value : float -> int option
(** [macro_stage_of_value v] decodes the snapshot [Stage] scalar (encoded as
    [1.0 | 2.0 | 3.0 | 4.0], with [Float.nan] = "not yet classifiable") into the
    integer stage [1 | 2 | 3 | 4]. Returns [None] for [Float.nan] or any value
    that does not round to one of those four stages (defensive against a
    malformed cell). The "SPY/macro stage at start" factor — run on the
    benchmark index's [Stage] cell as-of the start date. *)

val stage2_candidate_count : float list -> int
(** [stage2_candidate_count stage_values] counts how many of the universe's
    [Stage] scalars (one per symbol, read as-of the start date) decode to
    {b Stage 2} — the confirmed-breakout-eligible stage. [Float.nan] cells (a
    symbol not yet classifiable on that date, e.g. pre-IPO) are skipped, not
    counted. The "Stage-2 candidate count at start" factor (design H3 /
    "fresh-supply"). *)

val sector_rs_dispersion : (string * float) list -> float
(** [sector_rs_dispersion sector_rs] is the cross-sector {b spread} of relative
    strength as-of the start date — the IQR (75th − 25th percentile, via
    {!Dispersion_stats.iqr}) of the {b per-sector mean} [RS_line].

    Input is one [(sector, rs_value)] pair per universe symbol (the symbol's
    snapshot [RS_line] cell as-of the start date, tagged with its sector). The
    computation: drop pairs whose [rs_value] is [Float.nan], group the rest by
    sector, take each sector's mean RS, then take the IQR across those sector
    means. A wide dispersion means strongly-divergent sector leadership (the
    "stronger/weaker sectors" question); a tight one means the sectors moved
    together.

    Returns [Float.nan] when, after dropping nan cells, fewer than two distinct
    sectors remain (the spread of <2 sectors is undefined). IQR is chosen over
    stdev for consistency with the rest of the rolling-start report, which keys
    its dispersion on quartiles. *)

type factors = {
  spy_stage_at_start : int option;
      (** The benchmark index's Weinstein stage ([1 | 2 | 3 | 4]) as-of the
          start date, via {!macro_stage_of_value} on the benchmark's [Stage]
          cell. [None] when no benchmark is configured, the benchmark has no
          snapshot row on/before the start, or its [Stage] cell is [nan]. Design
          H3: edge is expected worse when this is [3] (toppy start). *)
  macro_composite_at_start : float;
      (** The benchmark index's [Macro_composite] scalar as-of the start date —
          continuous macro-tape strength at entry. [Float.nan] when no benchmark
          is configured, no row priced the date, or the cell is [nan]. *)
  stage2_candidate_count : int option;
      (** Count of universe symbols in Stage 2 as-of the start date
          ({!stage2_candidate_count}). [None] only when the universe could not
          be scanned at all (no panels handle / empty universe); [Some 0] is a
          real "no Stage-2 setups" reading, distinct from "could not compute".
      *)
  sector_rs_dispersion_at_start : float;
      (** Cross-sector IQR of mean [RS_line] as-of the start date
          ({!sector_rs_dispersion}). [Float.nan] when fewer than two sectors had
          a defined RS, or the universe could not be scanned. *)
}
[@@deriving sexp, equal]
(** The four screener-based factor columns for one rolling start. Appended to
    {!Rolling_start_types.per_start} as a strict superset: a row carries these
    alongside the existing outcome columns, and consumers that don't read them
    are unaffected. *)

val empty : factors
(** [empty] is the all-unavailable factor set ([spy_stage_at_start = None],
    [macro_composite_at_start = nan], [stage2_candidate_count = None],
    [sector_rs_dispersion_at_start = nan]) — the value for a start that ran with
    no snapshot warehouse to read factors from (e.g. CSV mode, or no benchmark).
*)

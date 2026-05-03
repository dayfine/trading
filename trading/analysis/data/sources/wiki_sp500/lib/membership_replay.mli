(** Reverse-time replay of S&P 500 membership.

    Companion plan: [dev/plans/wiki-eodhd-historical-universe-2026-05-03.md]
    §PR-B. Given (a) a snapshot of today's index constituents and (b) the list
    of historical change events from [Changes_parser.parse], reconstruct the
    membership at any historical date by un-doing changes newest-first.

    All functions in this module are pure — no I/O, no global state. The caller
    is responsible for loading the inputs (CSV + HTML snapshots) from disk; the
    future [build_universe.exe] CLI in PR-C is the only I/O caller.

    Sector handling: the [sector] field on [constituent] is the GICS sector *as
    of the input snapshot*. Sector reclassifications during the replay window
    are NOT tracked (out of scope per plan §Out). When a symbol is re-added
    during replay (because it was removed after [as_of]), its sector is set to
    the synthetic value ["Unknown"] because the change event does not record
    GICS classification. *)

type constituent = {
  symbol : string;
      (** Ticker symbol. Format matches the input source ([parse_current_csv]
          returns the verbatim "Symbol" column from the Wikipedia main
          constituents table; callers wanting EODHD canonicalisation should run
          [Ticker_aliases.canonicalize] post-hoc). *)
  security_name : string;
      (** Human-readable security name (the "Security" column from the Wikipedia
          main constituents table, e.g. ["Apple Inc."]). *)
  sector : string;
      (** GICS sector as of the input snapshot (e.g.
          ["Information Technology"]). See module docstring for the sector-drift
          limitation. *)
}
[@@deriving show, eq]

val parse_current_csv : string -> constituent list Status.status_or
(** [parse_current_csv csv_text] parses a Wikipedia "List of S&P 500 companies"
    main-table snapshot.

    Expected schema:
    - Header row with at least the columns [Symbol], [Security], and one of
      [GICS Sector] or [Sector] (case-insensitive). Header matching is by column
      name, so additional columns and column-order differences are tolerated.
    - Each subsequent row is one constituent; rows are quoted-CSV so commas
      inside fields (e.g. ["New York, NY"]) are honoured.

    Returns [Error] on:
    - missing required column header,
    - any data row with fewer columns than required by the header,
    - empty input. *)

val replay_back :
  current:constituent list ->
  changes:Changes_parser.change_event list ->
  as_of:Core.Date.t ->
  constituent list Status.status_or
(** [replay_back ~current ~changes ~as_of] reconstructs S&P 500 membership on
    [as_of] by reverse-iterating [changes] (newest→oldest), undoing each event
    with [effective_date > as_of].

    For each such event:
    - drop [event.added.symbol] from the working set (it joined after [as_of]
      and was not a member on that date);
    - re-add [event.removed.symbol] to the working set (it was still a member on
      [as_of]).

    Events with [effective_date <= as_of] are left untouched: a symbol added on
    [as_of] is considered a member that day. Events with neither [added] nor
    [removed] populated are no-ops.

    When re-adding a symbol, the [security_name] is taken from the change event
    ([event.removed.security_name]) and the [sector] is set to ["Unknown"] (we
    have no point-in-time GICS classification — this is documented as a known
    limitation in the module docstring).

    Robustness: if [event.added.symbol] is not present in the current working
    set when its event fires (which can happen due to ticker renames the changes
    table doesn't track, or due to index pre-2010 rows where the changes data is
    sparse), the drop is silently skipped. This is preferred over a hard error
    because the upstream change data is editorial Wikipedia content, not a
    vendor-grade feed; surfacing every disagreement would render the function
    unusable for the [2010, 2026] window the plan targets. The caller can detect
    such drift by comparing [List.length] before and after.

    Pre-condition: [changes] must be in source order, which
    [Changes_parser.parse] guarantees is newest-first. *)

val to_universe_sexp : constituent list -> Core.Sexp.t
(** [to_universe_sexp cs] renders the constituent list as a
    [(Pinned (((symbol XXX) (sector "...")) ...))] sexp matching the layout of
    [trading/test_data/backtest_scenarios/universes/sp500.sexp]. The output is
    sorted by [symbol] ascending for determinism; the input order is not
    preserved.

    Note: [security_name] is dropped from the output sexp because the consuming
    sexp schema (in [Universe.t]) only has [symbol] + [sector] fields. *)

(** Membership replay over a stream of iShares ETF holdings snapshots.

    Companion plan: [dev/plans/iwv-scraper-2026-05-16.md] §2.3 / §PR-B. Given a
    forward-ordered sequence of parsed snapshots produced by
    {!Ishares_holdings_client.parse}, reconstruct a per-ticker tenure record
    capturing the first and last dates on which the ticker was observed in the
    index.

    All functions in this module are pure — no I/O, no global state. The caller
    is responsible for loading and ordering snapshots; the future
    [build_iwv_universe.exe] CLI ties the pieces together.

    The 3-snapshot removal threshold (§2.3.2) prevents single-day data glitches
    (e.g. iShares occasionally returns a sentinel mid-week between two valid
    daily reports) from creating spurious tenure splits. Callers can tune the
    threshold via [threshold_consecutive_misses] — 1 collapses to "any miss ends
    the tenure", larger values are more conservative. *)

open Core

type tenure_record = {
  ticker : string;
      (** The verbatim ticker observed in the holdings stream. Holdings whose
          [Ishares_holdings_client.holding.ticker] is ["-"] are dropped before
          replay and never appear here. *)
  first_seen : Date.t;  (** Earliest snapshot [as_of] containing [ticker]. *)
  last_seen : Date.t;
      (** Latest snapshot [as_of] on which [ticker] was observed before a run of
          [threshold_consecutive_misses] absent snapshots ended its tenure. For
          tickers still present in the most recent snapshot, this is the [as_of]
          of that snapshot. *)
  sector_at_first : string;
      (** The [Ishares_holdings_client.holding.sector] value recorded when the
          ticker was first observed. May be ["-"] (or ["" ] when era is
          pre-2009, per plan §2.3 — the parser preserves whatever cell value
          iShares returns; replay does not normalize). Subsequent
          reclassifications during the tenure are ignored: the per-tenure sector
          is pinned at first sighting to match the legacy [broad-3000-...sexp]
          shape. *)
  index : string;
      (** The index label this tenure belongs to. Defaults to ["IWV"]; the
          parameter is exposed in {!replay} so future IWB / IWM variants can
          flow through the same replay without code change. *)
}
[@@deriving show, eq]

val replay :
  ?index:string ->
  threshold_consecutive_misses:int ->
  (Date.t * Ishares_holdings_client.snapshot) list ->
  tenure_record list
(** [replay ~threshold_consecutive_misses snapshots] consumes the forward-
    ordered list of [(as_of, snapshot)] pairs and returns one {!tenure_record}
    per [(ticker)] observed across the run.

    The caller must supply [snapshots] in ascending [as_of] order; this is the
    natural shape the on-disk cache produces (filenames sort chronologically).
    Order is not validated.

    Tenure semantics:

    - First sighting of a ticker opens a new tenure with
      [first_seen = last_seen = snap.as_of] and [sector_at_first = h.sector]
      from that snapshot.
    - Subsequent appearances move [last_seen] forward; the [sector_at_first]
      field stays pinned to the original observation.
    - A snapshot in which the ticker is absent increments an internal
      consecutive-miss counter. The counter resets the moment the ticker
      reappears.
    - When the miss counter reaches [threshold_consecutive_misses], the tenure
      is closed and emitted. Re-appearance after closure opens a brand-new
      tenure record. A ticker can therefore appear in the output multiple times
      if it falls out and re-enters the index.
    - For tickers still active in the last snapshot, the tenure is emitted with
      [last_seen] set to the most recent [as_of] on which the ticker was
      observed.

    Filtering (matches plan §2.3.3):

    - Holdings with [ticker = "-"] are dropped (un-tickered escrow positions).

    Other vendor-specific filters (Asset Class = "Futures" / "Cash", non-US
    locations) are deliberately {b not} applied here. They belong to the
    universe-builder CLI in PR-D, which has access to the policy knobs callers
    may want to vary per backtest. This module ships the membership-as-observed
    signal raw.

    Returns the tenure records in the order they were emitted: closed tenures
    (those that hit the miss threshold) are emitted at the snapshot that closed
    them; still-active tenures are emitted after the final snapshot, sorted by
    [first_seen] ascending then [ticker] ascending for determinism.

    The function is total: any input list yields a list — the empty list yields
    the empty list. There is no [Error] case because the only pre-condition
    (ascending order) is the caller's responsibility and out-of-order input
    simply produces a different, but still structurally-valid, tenure breakdown.
*)

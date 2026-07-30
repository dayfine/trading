(** Weekly snapshot — durable, sexp-serializable view of one Friday-close
    screener run.

    A snapshot is a {b frozen} view of what the system saw and decided on a
    single trading week. It captures:

    - the macro regime gate that drove cascade decisions,
    - the set of strong / weak sectors,
    - the ranked long and short candidates (with score, grade, suggested entry,
      suggested stop, sector, rationale),
    - the held positions that survived this Friday's update,
    - data-quality warnings for any ticker dropped from consideration (e.g. a
      sparse trailing bar series, issue #2083 fix 1).

    These artifacts are written under
    [dev/weekly-picks/<system-version>/<date>.sexp] and consumed by the
    forward-trace (M6.2), cross-version diff (M6.3), and weekly report (M6.5)
    tools.

    {1 Design}

    Snapshot record types are {b independent} of in-memory analysis types
    ([Screener.scored_candidate], [Macro.result], [Position.t]). This decouples
    the on-disk schema from upstream type evolution: a future refactor of
    [scored_candidate] cannot silently change the snapshot format.

    Serialization is via OCaml [sexp] — same shape as the rest of the codebase.
    Empty data sections (no candidates, no held positions, no strong sectors)
    serialize as [()] and round-trip cleanly.

    {1 Schema versioning}

    Every snapshot carries a [schema_version] field. The reader rejects any file
    whose schema version it does not recognize, with a clear error message. The
    {b current} schema version is {!current_schema_version}.

    Bump {!current_schema_version} whenever the on-disk shape changes
    incompatibly. Forward-compatible additions (new optional fields) do {b not}
    require a bump if [sexp] derives a default for missing fields. *)

open Core

val current_schema_version : int
(** The schema version this module emits and accepts. Bump when the on-disk
    shape changes incompatibly. *)

type macro_context = {
  regime : string;
      (** Macro regime as a string (e.g. ["Bullish"], ["Bearish"], ["Neutral"]).
          Stored as string rather than [Weinstein_types.market_trend] to keep
          the snapshot schema decoupled from upstream variant evolution. *)
  score : float;
      (** Macro confidence / score in [-1.0, 1.0] or [0.0, 1.0] depending on the
          producing analyzer. Recorded verbatim. *)
}
[@@deriving sexp, eq, show]
(** Macro regime context — the gate that drove this Friday's cascade. *)

type candidate = {
  symbol : string;  (** Ticker symbol (e.g. ["AAPL"]). *)
  score : float;
      (** Numeric score from the screener. Higher is better. Stored as [float]
          (the screener uses [int] internally; we widen here so future scoring
          changes don't force a schema bump). *)
  grade : string;
      (** Grade label as displayed (e.g. ["A+"], ["A"], ["B"]). Stored as string
          — see [macro_context.regime] for the rationale. *)
  entry : float;  (** Suggested buy-stop / sell-stop entry price. *)
  stop : float;
      (** Suggested initial stop price. For longs, below the prior base low; for
          shorts, above the prior rally high. *)
  sector : string;
      (** Sector label (e.g. ["XLK"], ["Information Technology"]). Free-form
          string — caller chooses the labeling convention. *)
  rationale : string;
      (** Human-readable single-line rationale (e.g.
          ["Stage2 breakout above 30wk MA, 2.1x volume confirmation"]).
          Multi-signal rationales should be joined with a separator before being
          stored. *)
  rs_vs_spy : float option;
      (** Relative strength vs SPY at pick time, if computed. [None] if not
          available. *)
  resistance_grade : string option;
      (** Resistance quality grade (e.g. ["A"], ["Virgin_territory"]). [None] if
          not computed. *)
  sized_shares : int; [@sexp.default 0]
      (** Order size for this candidate under the live portfolio, computed with
          {!Portfolio_risk.compute_position_size} (fixed-risk sizing, min of the
          risk-based / per-position / side-exposure / spendable-cash caps). [0]
          when the candidate was not sized (short candidates, or [0]-share
          results — see [sizing_note]). Additive field: old snapshots without it
          parse as [0]. *)
  sized_position_value : float; [@sexp.default 0.0]
      (** Dollar notional of the sized order ([sized_shares * entry]). *)
  sized_position_pct : float; [@sexp.default 0.0]
      (** Sized order as a fraction of portfolio value [0.0, 1.0]. *)
  sized_risk_amount : float; [@sexp.default 0.0]
      (** Dollar risk to the stop if filled and stopped out
          ([sized_shares * |entry - stop|]). *)
  sizing_note : string option; [@sexp.default None]
      (** [None] when the candidate was sized normally. [Some msg] carries a
          human-readable qualifier — either the placeholder label
          (["UNSIZED — set portfolio.sexp"], emitted when the generator had no
          live portfolio and sized against the template default) or the reason a
          [0]-share result occurred (cash / caps exhausted, invalid stop
          direction). *)
  stop_is_structural : bool; [@sexp.default false]
      (** [true] when [stop] was derived from a real support floor — the prior
          correction low (long) or counter-rally high (short) found by
          {!Weinstein_stops.Support_floor.find_recent_level} in the symbol's
          daily bar history (weinstein-book-reference.md §5.1 "Initial Stop
          Placement": "Place below the significant support floor (prior
          correction low) BEFORE the breakout"). [false] when no qualifying
          counter-move exists in the lookback window (or the symbol has no
          resident daily bars), in which case [stop] falls back to the fixed
          [entry * initial_stop_buffer] proxy. The generator computes this via
          {!Weinstein_stops.compute_initial_stop_with_floor} — the same
          primitive the live strategy uses to install the ACTUAL stop at fill
          time (issue #2084 Finding 2: this candidate-level [stop] used to be a
          flat 8% proxy divorced from chart structure, unlike the real entry).
          Additive field: old snapshots without it parse as [false]
          (conservative — treats un-labeled historical stops as non-structural).
      *)
  data_suspect : bool; [@sexp.default false]
      (** [true] when this candidate's most recent daily bar is a single
          outsized move vs the prior bar's close — at or above
          [config.spike_bar_threshold_pct] percentage points, per
          {!Weinstein_snapshot_gen.Spike_bar_gate.check}. An engineering
          data-hygiene flag, {b not} a Weinstein book rule: the candidate is
          {e flagged, not dropped}, its entry / stop / size are unchanged, and
          the report marks the row plus emits a line in {!t.warnings} (issue
          #2083 Finding 3 — the 2026-07-17 SNSE pick whose breakout was a single
          [+58%] zombie-feed print). [false] when the flag is disabled
          ([spike_bar_threshold_pct <= 0.0], the default), when the symbol has
          fewer than two resident bars, or when the last move is under the
          threshold. Additive field: old snapshots without it parse as [false].
      *)
  reconciliation : Entry_reconciliation.t;
      [@sexp.default Entry_reconciliation.Not_reconciled]
      (** How this candidate's CURRENT close stands against [entry] — the
          breakout level from the transition week, which the <=4-week
          early-Stage-2 admission window lets a pick outrun by weeks (issue
          #2103). Computed at generate time by
          {!Weinstein_snapshot_gen.Entry_reconcile}; see {!Entry_reconciliation}
          for the classification and its Weinstein authority.

          Drives {!expected_fill_price}, and through it the [sized_*] fields and
          the rendered order ticket: a {!Entry_reconciliation.Through_entry}
          candidate is sized on its close (the price it would actually fill at),
          and an {!Entry_reconciliation.Extended} one is not sized at all
          because its ticket is suppressed. Additive field defaulting to
          {!Entry_reconciliation.Not_reconciled}: old snapshots — and any run
          with the mechanism disarmed — parse and behave exactly as before the
          fix. *)
}
[@@deriving sexp, eq, show]
(** A single ranked candidate. Same shape for long and short candidates — the
    list it lives in determines side. The [sized_*] / [sizing_note] fields are
    populated for long candidates by the generator when it has a live portfolio;
    they default to the unsized values so pre-sizing snapshots round-trip. *)

val expected_fill_price : candidate -> float
(** The price this candidate would actually fill at — the close for a
    {!Entry_reconciliation.Through_entry} candidate (whose resting stop order is
    already triggered, so it fills at the market), and [entry] for every other
    class.

    {b The single source of truth for sizing and for display.} Issue #2103 was
    exactly the two disagreeing: the ticket showed a $46.08 breakout level while
    the stock traded at $62, so the displayed risk understated the real risk by
    14x. The report renderers quote this as the {e expected} fill; sizing runs
    off {!sizing_basis_price} instead (issue #2158, "size on the cap"). *)

val sizing_basis_price : candidate -> float
(** The price {!Weinstein_snapshot_gen.Trade_sizing} sizes on and the
    {!Snapshot_validator} risk identity is checked against — the
    {b worst admissible fill}, not the expected one (issue #2158, "size on the
    cap").

    For a reconciled candidate carrying a do-not-chase cap
    ({!Entry_reconciliation.Valid_stop} / {!Entry_reconciliation.Through_entry}
    with [cap > 0.0]) this is that cap: the live {!Weinstein_order_gen} order
    can fill anywhere up to the cap, so sizing on the cap makes the displayed
    risk the {e worst} case ([cap - stop]) rather than an optimistic one — the
    honest-conservative choice the user settled on 2026-07-29.

    Falls back to {!expected_fill_price} for every other case: a
    {!Entry_reconciliation.Not_reconciled} candidate (the disarmed default), an
    {!Entry_reconciliation.Extended} one (unsized anyway), and any snapshot
    written before #2158 (whose [cap] defaults to [0.0]) all size exactly as
    they did before this feature — so the default path and historical snapshots
    are unchanged. *)

type held_position = {
  symbol : string;  (** Ticker of the held position. *)
  entered : Date.t;  (** Date the position was opened. *)
  stop : float;  (** Current stop price (post any trailing adjustment). *)
  status : string;
      (** Status label (e.g. ["Holding"], ["Exiting"]). Stored as string — see
          [macro_context.regime] for the rationale. *)
  shares : int; [@sexp.default 0]
      (** Share count held. [0] for a pre-enrichment snapshot (old format). *)
  entry_price : float; [@sexp.default 0.0]
      (** Fill price the position was opened at. *)
  current_price : float; [@sexp.default 0.0]
      (** Close price as of this snapshot's date, from the same bar reader the
          screener uses. [0.0] when not priced (old format / no bars). *)
  unrealized_pct : float; [@sexp.default 0.0]
      (** Unrealized return [(current_price - entry_price) / entry_price * 100],
          long convention. [0.0] when not priced. *)
  recommended_stop : float option; [@sexp.default None]
      (** This week's recomputed Weinstein support-floor stop level (via
          {!Weinstein_stops.compute_initial_stop_with_floor}), shown alongside
          [stop] so the reader sees the delta. [None] when not recomputed (old
          format / insufficient bars). The full trailing state machine is not
          threaded here — that is deferred to Phase C. *)
}
[@@deriving sexp, eq, show]
(** A held position carried into this Friday. Captures what the weekly report
    needs to render an execution-ready row (size, entry, current price,
    unrealized %, current + recommended stop); full position state lives in
    [Position.t]. The fields below [status] are additive and default to the
    un-enriched values so pre-enrichment snapshots round-trip. *)

type t = {
  schema_version : int;
      (** Schema version this snapshot was written with. The reader checks this
          against {!current_schema_version}. *)
  system_version : string;
      (** System version tag — typically a git commit SHA (e.g. ["c93bf39d"]).
          Used by the cross-version diff (M6.3) to label the producing system.
      *)
  date : Date.t;
      (** The Friday-close date this snapshot represents. The on-disk file name
          should match: [<date>.sexp] in [YYYY-MM-DD] form. *)
  macro : macro_context;  (** Macro regime context. *)
  sectors_strong : string list;
      (** Sectors classified as strong by the sector analyzer. May be empty. *)
  sectors_weak : string list;
      (** Sectors classified as weak by the sector analyzer. May be empty. *)
  long_candidates : candidate list;
      (** Ranked long candidates, score-descending. May be empty. *)
  short_candidates : candidate list;
      (** Ranked short candidates, score-descending. May be empty. *)
  held_positions : held_position list;
      (** Positions held into this Friday. May be empty. *)
  warnings : string list; [@sexp.default []]
      (** Human-readable data-quality warnings for this run: one line per ticker
          dropped from candidate consideration (the sparse-tail eligibility
          gate, issue #2083 fix 1 — see [Sparse_tail_gate]) and one per
          candidate flagged but KEPT (the spike-bar data-suspect flag, issue
          #2083 fix 3 — see [Spike_bar_gate]; the line says so explicitly, so a
          reader does not go looking for a missing row). Empty when no gate
          fired. Additive field: old snapshots without it parse as [[]]. *)
}
[@@deriving sexp, eq, show]
(** A complete weekly snapshot. *)

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
}
[@@deriving sexp, eq, show]
(** A single ranked candidate. Same shape for long and short candidates — the
    list it lives in determines side. The [sized_*] / [sizing_note] fields are
    populated for long candidates by the generator when it has a live portfolio;
    they default to the unsized values so pre-sizing snapshots round-trip. *)

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
      (** Human-readable data-quality warnings for tickers dropped from
          candidate consideration this run (e.g. the sparse-tail eligibility
          gate, issue #2083 fix 1 — see [Sparse_tail_gate]). One line per
          dropped ticker; empty when no gate fired. Additive field: old
          snapshots without it parse as [[]]. *)
}
[@@deriving sexp, eq, show]
(** A complete weekly snapshot. *)

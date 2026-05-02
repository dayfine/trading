(** Weekly snapshot — durable, sexp-serializable view of one Friday-close
    screener run.

    A snapshot is a {b frozen} view of what the system saw and decided on a
    single trading week. It captures:

    - the macro regime gate that drove cascade decisions,
    - the set of strong / weak sectors,
    - the ranked long and short candidates (with score, grade, suggested entry,
      suggested stop, sector, rationale),
    - the held positions that survived this Friday's update.

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
}
[@@deriving sexp, eq, show]
(** A single ranked candidate. Same shape for long and short candidates — the
    list it lives in determines side. *)

type held_position = {
  symbol : string;  (** Ticker of the held position. *)
  entered : Date.t;  (** Date the position was opened. *)
  stop : float;  (** Current stop price (post any trailing adjustment). *)
  status : string;
      (** Status label (e.g. ["Holding"], ["Exiting"]). Stored as string — see
          [macro_context.regime] for the rationale. *)
}
[@@deriving sexp, eq, show]
(** A held position carried into this Friday. Captures only what's needed for
    the report; full position state lives in [Position.t]. *)

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
}
[@@deriving sexp, eq, show]
(** A complete weekly snapshot. *)

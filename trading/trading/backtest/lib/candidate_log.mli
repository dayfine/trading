(** Per-week candidate emission — the on-disk shape of [candidates.sexp].

    Answers the one question no existing artefact does:
    {i "which names did the cascade look at on week W, and where did each one
       fall out?"} See [dev/plans/candidate-emission-2026-08-23.md] and issue
    #2490.

    {1 Why this is not [trade_audit.sexp]}

    [Trade_audit.cascade_summary] carries per-phase admission {b counts} but no
    names. [Trade_audit.entry_decision.alternatives_considered] carries names —
    but only ever attached to a {b funded} entry, so a Friday that funds nothing
    emits no candidate list at all (gap G1). This module is the unconditional
    per-week sink: it is populated from the same
    {!Weinstein_strategy.Audit_recorder.cascade_event} the cascade summary comes
    from, so a zero-funded week still carries its list.

    {1 Opt-in, observability only}

    Nothing here is on any default path. Emission is gated by
    [scenario_runner.exe --emit-candidates] (default OFF, mirroring
    [--no-emit-all-eligible]), which routes into
    [Runner.run_backtest ?candidate_log] with a {!collector} built by
    {!create_if}. The gate reaching the strategy lives on the {b recorder}
    ([Audit_recorder.t.capture_candidates]), never on
    [Weinstein_strategy.config] or [Screener.config] — so it can never become a
    [Variant_matrix] axis, never routes through [Overlay_validator], and never
    appears in a golden's [config_overrides]. With the gate off the strategy
    allocates nothing and no file is written.

    {1 The top-N view}

    The screener caps its sorted output ([max_buy_candidates], default 20)
    {i before} the entry walk checks buyability, so a name ranked 21+ is cut as
    [Dropped_at_top_n] without ever being asked whether it had a valid stop.
    With capture on, every row that cleared the cascade carries its [rank] in
    the order the cap cut; [Admitted] rows carry what the walk did
    ({!walk_result}) and [Dropped_at_top_n] rows a {!shadow_verdict} computed
    with the walk's own stop check; each week carries the tickets placed and the
    long walk's unspent cash. Together they answer "was a buyable name past the
    cap crowded out on a Friday when cash was still free?" and give a per-gate
    funnel per Friday. Turning capture on changes no trade: the shadow is pure,
    runs after the walk, and cannot reorder it (pinned end to end by
    [test_trade_audit_capture.ml]: [trades.csv] and [equity_curve.csv] are
    byte-identical with the flag on and off). *)

open Core

(** Where in the screener cascade a candidate stopped.

    [Admitted] means the candidate survived every cascade phase and reached the
    screener's top-N — i.e. the strategy's entry walk actually considered it.
    Every candidate emitted by the G1 (per-week walk population) path is
    [Admitted] by construction; the [Dropped_at_*] constructors are populated by
    the G2 pre-top-N trace, which names the candidates the cascade evaluated and
    rejected.

    [Admitted] and [Dropped_at_top_n] are the two outcomes of the cap itself —
    every gate passed, then kept or cut by rank — so on the G2 path those rows,
    and only those, carry the top-N view: {!candidate.rank} on both,
    {!candidate.walk} on [Admitted], {!candidate.shadow} on [Dropped_at_top_n].
*)
type cascade_outcome =
  | Admitted
  | Dropped_at_macro
  | Dropped_at_breakout
      (** Long side: breakout predicate / price floor / volume band / the
          failed-breakout gate. Short side: the mirrored breakdown phase. Which
          of those dials fired is the row's {!candidate.breakout_gate}. *)
  | Dropped_at_sector
  | Dropped_at_rs
      (** Short side only today — the long side's relative strength folds into
          the grade rather than a standalone phase. See [Screener_admission]. *)
  | Dropped_at_grade
  | Dropped_at_top_n
[@@deriving sexp, eq, show]

(** Which dial inside the breakout / breakdown phase rejected the candidate —
    the decomposition of [Dropped_at_breakout] (issue #2533).

    Mirrors [Screener.breakout_gate] constructor-for-constructor, including its
    {b first-failing-gate} contract: a candidate that fails several gates is
    attributed to the earliest in evaluation order, so counting rows by
    constructor partitions the [Dropped_at_breakout] population rather than
    double-counting it. That module's docstring is the authority on the order
    and on which constructors each side can emit; this type is the on-disk
    mirror, kept separate for the same reason {!cascade_outcome} is — the
    artefact owns its own schema, and the mapping between them is one total
    function that fails to compile if either enum moves.

    Non-[None] only on rows whose [outcome] is [Dropped_at_breakout]. *)
type breakout_gate =
  | Price_floor
  | Stage_setup  (** Stage / entry-freshness setup predicate. *)
  | Breakout_volume  (** Breakout-week volume confirmation; long side only. *)
  | Rs_declining  (** RS trend [Negative_declining]; long side only. *)
  | Failed_breakout  (** Failed-breakout re-validation; long side only. *)
  | Volume_band  (** The screener's volume-ratio exclusion window. *)
[@@deriving sexp, eq, show]

type signals = {
  score : int;
  grade : Weinstein_types.grade;
  stage : Weinstein_types.stage;
  weeks_advancing : int option;
      (** [weeks_advancing] when [stage] is [Stage2], else [None]. *)
  rs_value : float option;
      (** Normalised relative-strength value at decision time, [None] when the
          candidate carried no RS analysis. *)
  volume_ratio : float option;
      (** Breakout-bar volume / 4-week average, [None] when no breakout volume
          event was classified. *)
  sector_name : string;  (** Empty string when unknown. *)
}
[@@deriving sexp, eq]
(** Decision-time signals for one candidate.

    Deliberately field-for-field the decision-time subset of
    {!Trade_audit.alternative_candidate}: the two must stay projectable onto
    each other so a reader can join a candidate row against the funded path's
    near-miss rows without a schema translation. {!signals_of_alternative} is
    that projection, and it is the only way this record is built — which is what
    keeps the two from drifting. *)

(** The buyability {b shadow} of a [Dropped_at_top_n] row: what the entry walk's
    own initial-stop check says about a name the screener's top-N cap cut before
    the walk could ask (see [Weinstein_strategy.Audit_recorder.Top_n.shadow] and
    [Cascade_trace.shadow_verdict]).

    The contract: the same initial-stop computation, the same
    [require_structural_stop] gate and the same [max_stop_distance_pct] width
    gate (under the configured [stop_width_mode]) the walk applies, called — not
    re-implemented — through the walk's own closure. Cash, the notional and
    sector caps, the share-class rule, sizing, the entry-assembly gates (short
    side off, short minimum price, short borrow, liquidity, bar recency,
    delisting, declining MA) and the [freeze_entry_at_first_breakout] re-pin are
    ignored. It is pure: no order, no cash debit, no stop-state registration, no
    position id, no recorder event beyond this row. Every distance is a fraction
    of the entry trigger ([0.08] = 8%), the number the width gate compared —
    never a price. *)
type shadow_verdict =
  | Buyable of float  (** Both gates pass; the stop distance. *)
  | No_structural_stop
      (** The investor-preset gate would reject it (fallback stop). *)
  | Stop_too_wide of float
      (** The width gate would drop it; the stop distance. *)
  | Already_held  (** The walk's held set has it; no stop computed. *)
[@@deriving sexp, eq, show]

(** What the entry walk actually did with an [Admitted] row. *)
type walk_outcome =
  | Funded  (** The walk placed the ticket. *)
  | Skipped of Trade_audit.skip_reason
      (** Passed over, with the reason — the same hop [trade_audit.sexp]'s
          weekly decision record uses. *)
  | Not_reached
      (** The walk never classified it: an entry-assembly gate removed it first
          — the short side switched off, the short-only [short_min_price] floor
          and [Short_borrow_gate], or, on either side, liquidity, bar recency,
          delisting or the declining-MA gate. *)
[@@deriving sexp, eq]

type walk_result = {
  result : walk_outcome;
  stop_distance_pct : float option; [@sexp.option]
      (** The distance the walk's width gate measured, as a fraction of the
          entry trigger, whenever the walk computed an initial stop for the name
          — every outcome except [Skipped Already_held] /
          [Skipped Share_class_held] and [Not_reached]. For
          [Skipped No_structural_stop] it is the rejected fallback stop's
          distance. Recomputed after the walk by the walk's own (pure) stop
          check on the walk's copy of the candidate, so it is the number the
          walk saw. *)
}
[@@deriving sexp, eq]
(** An [Admitted] row's walk outcome. *)

type candidate = {
  symbol : string;
  side : Trading_base.Types.position_side;
  outcome : cascade_outcome;
  breakout_gate : breakout_gate option; [@sexp.option]
      (** Which breakout/breakdown dial dropped this candidate. [Some _] exactly
          when [outcome] is [Dropped_at_breakout]; [None] on every other row,
          including every entry-walk (G1) row.

          {b Additive on disk.} [@sexp.option] omits the field entirely when it
          is [None] and accepts its absence when parsing, so this module still
          reads a [candidates.sexp] written before #2533 (every row parses with
          [breakout_gate = None]) and a file written today is unchanged from the
          pre-#2533 shape except on the breakout-drop rows that now carry the
          extra field. The alternative — a payload on [Dropped_at_breakout] —
          would have moved the outcome's own sexp shape and broken that. *)
  signals : signals;
  rank : int option; [@sexp.option]
      (** The top-N view, set on every row that cleared the cascade ([Admitted]
          and [Dropped_at_top_n]) and [None] on every other row: the 1-based
          position in the screener's final sorted order for the row's side
          (score descending, then the configured tiebreak) — the order the
          [max_buy_candidates] / [max_short_candidates] cap cut on. Every
          [Admitted] row has [rank <= cap]. A [Dropped_at_top_n] row with
          [rank <= cap] marks a Friday whose live macro gate blocked the side
          while the trace's diagnostics gate admitted it. *)
  walk : walk_result option; [@sexp.option]
      (** [Some] exactly on [Admitted] rows that carry a [rank]. *)
  shadow : shadow_verdict option; [@sexp.option]
      (** [Some] exactly on [Dropped_at_top_n] rows that carry a [rank]. *)
}
[@@deriving sexp, eq]
(** One candidate row. [rank], [walk] and [shadow] (the top-N view) are additive
    on disk exactly as [breakout_gate] is: [@sexp.option] omits each when [None]
    and accepts its absence, so a file written before them parses with all three
    [None], and a row off the top-N view prints as before. *)

type week = {
  date : Date.t;
  candidates : candidate list;
  tickets_placed : int option; [@sexp.option]
      (** Entry tickets the walk placed this Friday, both sides — the
          [cascade_summary.entered] count. [None] only on files written before
          the field existed. *)
  long_cash_left_pct : float option; [@sexp.option]
      (** The cash the long entry walk left unspent, as a fraction of portfolio
          value: the long side's spendable budget less the cost of the long
          tickets it placed (shorts never reduce it; negative only under
          long-margin leverage). Read against the [Dropped_at_top_n] shadows it
          says whether a buyable name past the cap was crowded out by the cap or
          by cash. [None] on files written before the field existed. *)
  long_resting_reserved_pct : float option; [@sexp.option]
      (** The unfilled cost of the long entry tickets still resting at the walk
          (placed on earlier Fridays, not yet filled or cancelled before this
          Friday), as a fraction of portfolio value — what
          [reserve_cash_for_resting_tickets] (G3) would hold back, computed
          whether or not G3 is on. With G3 off (the default)
          [long_cash_left_pct] does not net it, so the free cash is
          [long_cash_left_pct - long_resting_reserved_pct]; with G3 on it is
          already out of [long_cash_left_pct].

          Two caveats on that identity. A ticket this same Friday's own cancels
          retire (the F2 rescreen, the TTL clock, the macro suspension) is still
          counted, as G3 counts it, because the walk reads the book before those
          cancels apply; on such Fridays the identity understates the free cash
          by those tickets. And the G3-off difference can go negative (the
          resting tickets over-commit the cash), while the G3-on
          [long_cash_left_pct] floors at 0, so the two agree only while the cash
          covers the reserve. [None] on files written before the field existed.
      *)
}
[@@deriving sexp, eq]
(** One Friday's candidate population. Emitted for {b every} screened Friday
    when capture is on — including Fridays that funded nothing, which is the
    whole point (G1). *)

type t = week list [@@deriving sexp]
(** On-disk payload of [<scenario_dir>/candidates.sexp]. *)

val signals_of_alternative : Trade_audit.alternative_candidate -> signals
(** Project a near-miss row onto {!signals}, field-for-field. Every [signals]
    value on an {b entry-walk} row comes through here, so the candidate log and
    [trade_audit.sexp]'s [alternatives_considered] cannot disagree about a
    candidate's decision-time signals. *)

val signals_of_analysis :
  analysis:Stock_analysis.t ->
  sector_name:string ->
  score:int ->
  grade:Weinstein_types.grade ->
  signals
(** The same projection for a {b cascade} row, whose candidate never reached the
    entry walk and so has no [alternative_candidate] to read from — the score
    and grade come from the screener's own trace instead.

    Reads the identical fields off [analysis] that {!Trade_audit_recorder}'s
    near-miss projection does, so the two row kinds in one artefact describe a
    candidate the same way. A test pins that they agree on a candidate reachable
    through both paths. *)

(** {1 Collector} *)

type collector
(** Mutable per-run accumulator of weeks, in record order. One per backtest run;
    not safe to share across threads. Mirrors {!Trade_audit.t}'s shape rather
    than growing a [Queue] on [Trade_audit.t] itself, so [trade_audit.sexp]'s
    on-disk shape does not move. *)

val create : unit -> collector
val record : collector -> week -> unit

val create_if : bool -> collector option
(** [Some (create ())] when capture is on, [None] otherwise — the shape the
    recorder and the runner both thread, so the opt-in test is written once. *)

val weeks : collector -> t
(** Recorded weeks, oldest first. *)

val filter_from : t -> start_date:Date.t -> t
(** Drop weeks before [start_date]. Warmup-window screens must not pollute the
    artefact, matching the treatment [Trade_audit.cascade_summary]s already get.
*)

val weeks_in_window : collector option -> start_date:Date.t -> t
(** {!weeks} then {!filter_from}, and [[]] for [None] — what a runner wants at
    teardown regardless of whether capture was on. *)

val week_of :
  date:Date.t ->
  alternatives:Trade_audit.alternative_candidate list ->
  drops:Weinstein_strategy.Audit_recorder.cascade_drop list ->
  tickets_placed:int ->
  long_cash_left_pct:float option ->
  long_resting_reserved_pct:float option ->
  week
(** Assemble one screened Friday's row set.

    [alternatives] are the candidates the {i entry walk} passed over (G1),
    already projected by the caller (which owns the near-miss projection);
    [drops] are the candidates the {i cascade} evaluated (G2), each carrying the
    phase that dropped it and, on the rows that cleared the cascade, the top-N
    view ([cascade_drop.top_n]) that becomes [rank] / [walk] / [shadow]. The
    week's [tickets_placed], [long_cash_left_pct] and
    [long_resting_reserved_pct] are copied through.

    Emitted even when both are empty: a Friday that funded nothing is still a
    screened Friday, and eliding it would make "no week" and "no candidates"
    indistinguishable.

    {b A non-empty [drops] supersedes [alternatives].} The cascade population
    already contains the entry walk's top-N as its [Admitted] tail, so emitting
    both would double-count those names under two different outcome
    vocabularies. [alternatives] remains the sole source when no cascade trace
    was captured — which is what keeps a G1-only caller working unchanged. *)

(** {1 Emission} *)

val emit : enabled:bool -> scenario_dir:string -> t -> unit
(** Write [<scenario_dir>/candidates.sexp] when [enabled] is [true].

    No-op when [enabled] is [false]: no file is created, nothing is serialised.

    {b Failure isolation.} A writer failure (unwritable directory, full disk) is
    logged to [stderr] and swallowed — this is a diagnostic artefact and must
    never abort the parent backtest, whose [actual.sexp] / [summary.sexp] are
    already on disk by the time this runs. Same contract as
    [Backtest_all_eligible.Scenario_post_step.emit]. *)

(** {1 Checkpoint} *)

type snapshot [@@deriving sexp]
(** The recorded weeks in record order. *)

val capture : collector -> snapshot
(** Copy of the collector's weeks. *)

val restore : snapshot -> collector
(** A fresh collector holding the snapshot's weeks, in the same order. *)

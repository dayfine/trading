(** F1 — which event starts the Stage-2 admission clock.

    Weinstein §1 ("Stage 2 detail"):
    {i "Begins when stock breaks out above the top of the resistance zone AND
       above the 30-week MA on impressive volume."} Stage 1 explicitly has the
    stock {i "tossed above and below the MA"} for months while it bases. Our
    stage classifier, however, starts [weeks_advancing] at the {b MA cross} — so
    a name that crossed its MA ten weeks ago but is still coiled under the top
    of its trading range has already "aged out" of the early-Stage-2 admission
    window ([early_stage2_max_weeks <= 4]) before the book's Stage-2 week one
    has even happened. That mis-mapping (M1 of
    [dev/plans/entry-ticket-async-v2-2026-08-10.md]) structurally excludes the
    base-then-breakout population.

    This module supplies the alternative clock. It is a leaf: it consumes only
    the already-computed MA direction / MA value, the ticket anchor, and the
    current close — no [Stock_analysis.t], no callbacks, no bar walking — so
    {!Stock_analysis} can call it without a cycle and tests can pin it directly.
*)

(** Which event the Stage-2 admission clock is measured from.

    - [Ma_cross] {b (default, no-op)} — today's behaviour: freshness is
      [Stage.result]'s [weeks_advancing], counted from the MA cross, and
      {!range_top_freshness} returns [None] so {!Stock_analysis} keeps its
      pre-feature admission arm verbatim (R1 of
      [.claude/rules/experiment-flag-discipline.md]).
    - [Range_top_breakout] {b (armed)} — freshness is measured from the breakout
      above the ticket anchor (the top of the {i current} trading range). The
      MA-cross age is not consulted at all; the admit test is
      {!range_top_freshness} below. *)
type basis = Ma_cross | Range_top_breakout [@@deriving show, eq, sexp]

val proximity_pct : float
(** Fraction below the ticket anchor within which the breakout setup counts as
    {b live} — [0.05] (5%), the value pinned by
    [dev/plans/entry-ticket-async-v2-2026-08-10.md] §3 F1.

    Rationale (§4.7 order mechanics): the book's GTC buy-stop is
    {i written down before} the breakout — "spot the setup, place the order, you
    may be surprised two or three weeks later". Admission therefore has to fire
    while the stock is still {i under} the range top, or there is no ticket
    resting when the breakout happens. 5% is the band in which the setup is
    close enough to be actionable. Deliberately a constant rather than a second
    axis: F1's experiment question is the {i basis}, not the band. *)

val range_top_freshness :
  basis:basis ->
  ma_direction:Weinstein_types.ma_direction ->
  ma_value:float ->
  local_range_top:float option ->
  current_close:float option ->
  bool option
(** [range_top_freshness ~basis ~ma_direction ~ma_value ~local_range_top
     ~current_close] evaluates the armed clock.

    [None] whenever [basis = Ma_cross] — "this basis has no opinion; use the
    MA-cross window". [Stock_analysis] treats [None] as "run the pre-feature
    admission arm unchanged", which is what makes the default bit-identical.

    [Some live] when [basis = Range_top_breakout]. [live] is [true] iff {b all}
    of:

    - {b the setup is live}:
      [current_close >= local_range_top * (1 - ]{!proximity_pct}[)] — the stock
      is at, or within the band just under, the top of its current trading
      range, so a resting buy-stop at the anchor is a pending breakout rather
      than a stale one;
    - {b the MA is not declining} ([Rising] or [Flat]) — §4.1 requirement 2;
    - {b the trigger sits above the MA}: [local_range_top > ma_value] — §4.1
      requirements 1 and 3. A breakout below a declining MA "is a trap, not a
      buy" (Ch. 3, Western Union: broke out of its range below a declining MA,
      then fell 45 → 8½). Because the ticket rests at [local_range_top], testing
      {i that} level (not the current close) against the MA is what actually
      pins the eventual fill above the MA.

    [Some false] when either [local_range_top] or [current_close] is [None]: the
    anchor is the ticket level, so with no anchor there is no breakout to be
    fresh from, and the armed basis admits nothing (never falls back to the
    MA-cross window — the two clocks are alternatives, not a disjunction).

    {b The anchor must be the ticket anchor.} Callers pass
    [Stock_analysis.t.local_range_top], the same level the screener anchors
    [suggested_entry] at, so the freshness test and the resting order can never
    drift apart (plan §6, last bullet). With
    [entry_anchor_local_range_weeks = 0] there is no anchor and the armed basis
    is inert.

    {b Not the continuation / pullback buy.} There is deliberately no "already
    broke out N weeks ago" disjunct: that shape is the book's second-chance
    pullback buy, which is out of scope here and was rejected as an axis in
    #1366. F1 changes only which event the clock starts at; the
    [early_stage2_max_weeks <= 4] value is untouched. *)

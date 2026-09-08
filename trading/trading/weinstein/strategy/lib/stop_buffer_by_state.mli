(** Per-macro-state {b fallback} initial-stop width: a map from
    {!Weinstein_types.breadth_state} to the multiplier
    [Weinstein_strategy_config.config.initial_stop_buffer] otherwise supplies on
    its own.

    Plan: [dev/plans/stop-width-by-macro-state-2026-09-06.md]. Built on the
    five-state breadth read from PR #2685 ({!Weinstein_types.breadth_state},
    [Macro.result.breadth_state], [Breadth_direction]).

    {1 Why the width wants to see the macro state}

    [dev/experiments/stop-width-cadence-surface-2026-09-05/] measured a wide
    (12%) fallback stop as a large, robust return lever at 26 years — and
    measured why it cannot be flipped on as a {e constant}: the wide arm's
    crash-week losses landed under Bullish/Neutral labels, because the
    three-state trend gate never turned in 2020. The 27-year breadth study (the
    2026-09-04 yearly trade review) then split entry P&L by the state the entry
    was made in: entries made while breadth is {b Deteriorating} lost money in
    both books (-$604k on the record bundle, -$668k on the wide arm), while
    {b Recovering}-breadth entries were the best cohort in the run (+$627k /
    +$1.81M). A width that can read the state can be wide where the tape is
    repairing and tight where it is falling apart; a scalar cannot.

    {1 Weinstein authority}

    The book fixes the flat-stop {e band} at 4-6% (§5.3, "Use 4-6% initial stop
    if no nearby prior peak") and caps structurally-placed risk at ~15% (§5.1).
    Sizing that band {e by macro state} is not in the book: it is an
    {b adaptation of a documented dial} — the stop width — under
    [.claude/rules/weinstein-faithful-core.md] W2, and it touches no spine item
    (stage classification, Stage-2-only entry, volume-confirmed breakout,
    Stage-3/4 exit, stop-below-the-base, the macro/sector gates and RS selection
    are all unchanged). [docs/design/weinstein-book-reference.md] therefore
    needs no amendment for this module.

    {1 R1 / R2 ([.claude/rules/experiment-flag-discipline.md])}

    {b R1.} {!default} leaves every slot at {!unset}, and {!buffer_for} then
    returns its [~fallback] for every state — so with the default config the
    resolved buffer {e is} [config.initial_stop_buffer], by construction rather
    than by a five-literal invariant. Goldens are bit-identical.

    {b R2.} The map is a real [Weinstein_strategy_config.config] field
    ([initial_stop_buffer_by_macro_state]), so it resolves through
    [Backtest.Overlay_validator.apply_overrides] and is expressible as a
    [Variant_matrix] axis:
    - dot-path — [initial_stop_buffer_by_macro_state.deteriorating=1.0]
    - full sexp —
      [((initial_stop_buffer_by_macro_state ((bullish 0.9167) (recovering
       0.9167))))]

    {1 Why a flat five-float record, and not options}

    [Overlay_validator] deep-merges an overlay against the
    {e base config's own sexp} and raises [Failure] for any overlay key with no
    matching key on the base. A field whose default serialises to [Sexp.List []]
    — [None], or an empty assoc list — presents {b zero} base keys, so a
    record-shaped overlay against it makes every key "unknown" and the override
    {e raises} instead of applying. A flat record always serialises all five
    keys, so both override forms above resolve.

    The same reasoning rules out [float option] per slot: the dot-path form
    yields an [Atom] leaf and [option_of_sexp] rejects an atom, so the ergonomic
    override spelling would fail. Hence a plain [float] plus the {!unset}
    sentinel.

    {1 Interaction with the breadth read (not a bug)}

    With [macro_config.breadth_direction] at its default-off setting,
    [Macro.result.breadth_state] is exactly
    [Weinstein_types.breadth_state_of_market_trend result.trend], so it can only
    ever be [Bullish_breadth], [Neutral_breadth] or [Bearish_breadth].
    {b Setting only the [deteriorating] / [recovering] slots is therefore a
       no-op until the breadth read is armed} — arm
    [macro_config.breadth_direction.enabled] alongside them. *)

val unset : float
(** [0.0] — the sentinel meaning "this state has no width of its own; use the
    scalar [initial_stop_buffer]". A buffer is a multiplier on the entry price,
    so [0.0] would put the fallback stop reference at price zero: it is not
    ambiguous with any meaningful value. {!buffer_for} treats any non-positive
    slot as unset, so a negative typo also falls back rather than inverting the
    stop. [0.0]-means-off is the established idiom in this config
    ([stage3_exit_margin_pct], [short_sleeve_fraction], [short_min_price]). *)

type t = {
  bullish : float;  (** Width for [Weinstein_types.Bullish_breadth]. *)
  neutral : float;  (** Width for [Weinstein_types.Neutral_breadth]. *)
  deteriorating : float;  (** Width for [Weinstein_types.Deteriorating]. *)
  recovering : float;  (** Width for [Weinstein_types.Recovering]. *)
  bearish : float;  (** Width for [Weinstein_types.Bearish_breadth]. *)
}
[@@deriving sexp, equal]
(** One optional multiplier per breadth state, each defaulting to {!unset}.
    Field names are the constructor names minus the [_breadth] suffix, so the
    override key reads naturally.

    The first candidate map to test, from the 2026-09-05 width surface —
    {b a value to be swept, not a default to commit}, since R3 forbids flipping
    a default without a ledger ACCEPT: [bullish] / [recovering] at [0.9167]
    (~12% stop), [neutral] at ~[0.94]-[0.96] (8-10%), [deteriorating] /
    [bearish] at [1.0] (the book's 4-6% band). *)

val default : t
(** Every slot at {!unset}: the R1 no-op. Ships as the config field's
    [[@sexp.default]], so a spec written before this field existed parses
    unchanged and behaves bit-identically. *)

val is_no_op : t -> bool
(** [true] when no slot is set, i.e. {!buffer_for} returns its [~fallback] for
    every state. *)

val buffer_for :
  t -> fallback:float -> state:Weinstein_types.breadth_state -> float
(** [buffer_for t ~fallback ~state] is [t]'s multiplier for [state] when that
    slot is set (strictly positive), and [fallback] — the scalar
    [config.initial_stop_buffer] — otherwise.

    Matches exhaustively on [Weinstein_types.breadth_state], so a sixth state
    added later is a compile error here rather than a silent fallback.

    {b Caller note.} The entry walk resolves this once from the [?macro] already
    in scope and threads the resulting [float] to both consumers (the ticket
    builder and {!Entry_stop_width_order.prefer_narrow_stops}), so the ordering
    pass and the gate cannot resolve different buffers. A caller that omits
    [?macro] has no state and gets [fallback] — today's behaviour. *)

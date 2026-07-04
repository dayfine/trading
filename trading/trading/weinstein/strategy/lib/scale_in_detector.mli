(** Pure detection of the scale-in add trigger (explore/exploit scale-in v1).

    Weinstein's scale-in dial buys half on the breakout and adds the other half
    when the first pullback to the breakout zone {e holds}
    (weinstein-book-reference.md §The Trader's Way; plan
    [dev/plans/capital-management-scale-in-2026-07-02.md] §3.2). The add
    {b follows revealed strength, never predicts}: it fires on a market-revealed
    event over the position's own bars, not on a conviction score.

    All functions are pure — same inputs, same answer. The runner (PR 4 of the
    scale-in build) owns position/portfolio state, cash arbitration, and the
    not-late / not-extended gate wiring; this module owns only the per-symbol
    price-action predicates. *)

(** Which revealed event arms the add. [Pullback] is v1's default (the faithful
    ½ + ½ — an INITIAL-position completion tactic tied to the base breakout).
    [Early_new_high] and [Either] exist as v1 experiment axes.
    [Consolidation_breakout] is the book's actual continuation buy (Ch. 3 §The
    Trader's Way; plan [dev/plans/continuation-add-v2-2026-07-04.md]): price
    consolidates near the rising 30-week MA, then breaks out anew above the
    consolidation's top on volume — the press-the-winner add that catches
    gap-and-go names, which never retest the entry but DO reconsolidate mid-run.
*)
type trigger = Pullback | Early_new_high | Either | Consolidation_breakout
[@@deriving sexp, eq, show]

type consolidation_config = {
  min_weeks : int; [@sexp.default 4]
      (** Completed weekly bars the consolidation window must span (before the
          current, breakout-candidate bar). The book demands a real
          reconsolidation zone, not a wiggle. *)
  band_pct : float; [@sexp.default 0.10]
      (** Window tightness: [(max_close - min_close) / max_close] must not
          exceed this — a consolidation is a range, not a trend. *)
  ma_proximity_pct : float; [@sexp.default 0.10]
      (** "Drops back close to its MA": the window's min close must sit within
          this fraction ABOVE the 30-week MA ([min_close <= ma * (1 + p)]). *)
  volume_ratio_min : float; [@sexp.default 1.25]
      (** "Impressive volume": the breakout bar's volume must be at least this
          multiple of the window's average volume. *)
}
[@@deriving sexp, eq, show]
(** Knobs for {!consolidation_breakout}. The book gives no numeric thresholds —
    every field is a searchable [Variant_matrix] axis; defaults are starting
    points only. *)

val default_consolidation_config : consolidation_config
(** All-fields default (4 weeks / 0.10 band / 0.10 MA proximity / 1.25 volume
    ratio). *)

type config = {
  initial_entry_fraction : float; [@sexp.default 1.0]
      (** Fraction of the full risk unit committed at the initial breakout
          entry. [1.0] (default) = today's full single entry — the no-op. v1
          specs set [0.5] (Weinstein's half-on-breakout); the v2 continuation
          surface keeps [1.0] (no explore-side tax). *)
  max_adds : int; [@sexp.default 1]
      (** Maximum follow-up adds per symbol. Weinstein describes exactly one
          (the pullback half); inert while [enable_scale_in = false]. *)
  add_trigger : trigger; [@sexp.default Pullback]
  add_fraction : float option; [@sexp.default None]
      (** Size of each add as a fraction of a full risk unit. [None] (default) =
          the v1-derived [1.0 -. initial_entry_fraction] — bit-identical
          backcompat, and full-size entries get zero-size adds. [Some f] sizes
          the add explicitly (the v2 surface sets [Some 1.0]: the book buys the
          {e entire} position at a continuation breakout — the per-symbol
          notional cap remains the real ceiling). *)
  pullback_proximity_pct : float; [@sexp.default 0.03]
      (** How close (fraction above entry) a bar's low must come to the breakout
          level to count as the pullback touch. *)
  extension_max_pct : float; [@sexp.default 0.15]
      (** Extension gate: no add when the current close sits more than this
          fraction above the 30-week MA — price has outrun its own trend
          (Weinstein: never buy extended). Consumed by the runner via
          {!extended_above_ma} and applied to ALL triggers uniformly.
          {b Interplay warning} (the "Either dead at 0.15" lesson): a
          [Consolidation_breakout] close sits structurally up to
          [(1 + ma_proximity_pct) * (1 + band_pct) - 1] above the MA (~21% at
          defaults) — surfaces arming that trigger must raise this gate (plan:
          0.25) or the trigger is dead on arrival. *)
  require_not_late : bool; [@sexp.default true]
      (** When [true] the runner blocks adds on [Stage2 { late = true }]
          holdings (MA-slope deceleration). For [Consolidation_breakout] this
          doubles as the book's "MA must be clearly trending higher" health
          gate. *)
  consolidation : consolidation_config;
      [@sexp.default default_consolidation_config]
      (** {!consolidation_breakout} knobs; consulted only when [add_trigger] is
          [Consolidation_breakout]. *)
}
[@@deriving sexp, eq, show]

val default_config : config
(** All-fields default; [initial_entry_fraction = 1.0] keeps the disabled
    behaviour bit-identical. *)

val pullback_hold :
  proximity_pct:float ->
  entry_price:float ->
  bars_since_entry:Types.Daily_price.t list ->
  bool
(** [pullback_hold ~proximity_pct ~entry_price ~bars_since_entry] is [true]
    when, over the (chronological) weekly bars strictly after the entry week:

    - some {e prior} bar's low touched the pullback zone
      ([low <= entry_price * (1 + proximity_pct)]), and
    - the current (last) bar closed at or above [entry_price] (the pullback
      {e held} the breakout level), and
    - the current close is above the previous close (the turn back up).

    Needs at least two bars ([false] otherwise) — a touch and a turn cannot be
    the same observation as the entry itself. *)

val early_new_high :
  entry_price:float -> bars_since_entry:Types.Daily_price.t list -> bool
(** [true] when the current (last) bar's close is a new high above every prior
    post-entry close and above [entry_price] — the continuation reveal for
    gap-and-go names that never retest. Needs at least two bars. The extension
    gate ({!extended_above_ma}) is the runner's job. *)

val consolidation_breakout :
  consolidation:consolidation_config ->
  ma:float ->
  bars_since_entry:Types.Daily_price.t list ->
  bool
(** The book's continuation buy (Ch. 3 §The Trader's Way), detected over the
    (chronological) weekly bars strictly after the entry week. [true] when all
    of, for the window of the last [min_weeks] bars before the current bar:

    - the window is tight: [(max_close - min_close) / max_close <= band_pct];
    - the window sits near the MA: [min_close <= ma * (1 + ma_proximity_pct)]
      (requires [ma > 0]);
    - the current bar breaks out: [close > window max close];
    - on volume: [current volume >= volume_ratio_min * window avg volume].

    Needs at least [min_weeks + 1] bars ([false] otherwise). The MA-health
    ("clearly trending higher") gate is the runner's [require_not_late]. *)

val add_signal :
  trigger:trigger ->
  proximity_pct:float ->
  consolidation:consolidation_config ->
  ma:float ->
  entry_price:float ->
  bars_since_entry:Types.Daily_price.t list ->
  bool
(** Dispatch on [trigger]: [Pullback] → {!pullback_hold}, [Early_new_high] →
    {!early_new_high}, [Either] → their disjunction, [Consolidation_breakout] →
    {!consolidation_breakout}. *)

val extended_above_ma : max_pct:float -> close:float -> ma:float -> bool
(** [true] when [(close - ma) / ma > max_pct] — price has outrun its 30-week MA
    by more than the gate allows. [false] for non-positive [ma] (warmup /
    missing MA never blocks-by-crash; the runner separately requires a real MA
    before adding). *)

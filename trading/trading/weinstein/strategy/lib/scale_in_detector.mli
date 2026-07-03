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
    ½ + ½). [Early_new_high] and [Either] exist as experiment axes because a
    pure-pullback trigger systematically under-sizes gap-and-go winners that
    never retest the breakout — the #1 instrumented check in the plan (§3.4). *)
type trigger = Pullback | Early_new_high | Either [@@deriving sexp, eq, show]

type config = {
  initial_entry_fraction : float; [@sexp.default 1.0]
      (** Fraction of the full risk unit committed at the initial breakout
          entry. [1.0] (default) = today's full single entry — the no-op.
          Enabled specs set [0.5] (Weinstein's half-on-breakout). *)
  max_adds : int; [@sexp.default 1]
      (** Maximum follow-up adds per symbol. Weinstein describes exactly one
          (the pullback half); inert while [enable_scale_in = false]. *)
  add_trigger : trigger; [@sexp.default Pullback]
  pullback_proximity_pct : float; [@sexp.default 0.03]
      (** How close (fraction above entry) a bar's low must come to the breakout
          level to count as the pullback touch. *)
  extension_max_pct : float; [@sexp.default 0.15]
      (** Extension gate: no add when the current close sits more than this
          fraction above the 30-week MA — price has outrun its own trend
          (Weinstein: never buy extended). Consumed by the runner via
          {!extended_above_ma}. *)
  require_not_late : bool; [@sexp.default true]
      (** When [true] the runner blocks adds on [Stage2 { late = true }]
          holdings (MA-slope deceleration — the topping warning). *)
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

val add_signal :
  trigger:trigger ->
  proximity_pct:float ->
  entry_price:float ->
  bars_since_entry:Types.Daily_price.t list ->
  bool
(** Dispatch on [trigger]: [Pullback] → {!pullback_hold}, [Early_new_high] →
    {!early_new_high}, [Either] → their disjunction. *)

val extended_above_ma : max_pct:float -> close:float -> ma:float -> bool
(** [true] when [(close - ma) / ma > max_pct] — price has outrun its 30-week MA
    by more than the gate allows. [false] for non-positive [ma] (warmup /
    missing MA never blocks-by-crash; the runner separately requires a real MA
    before adding). *)

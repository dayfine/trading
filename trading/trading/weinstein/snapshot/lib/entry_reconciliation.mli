(** Entry reconciliation — how far a candidate's CURRENT price has travelled
    past the breakout level its {!Weekly_snapshot.candidate.entry} records
    (issue #2103).

    {1 The problem}

    [candidate.entry] is the screener's [suggested_entry]: the breakout level
    computed on the {e transition} week. The early-Stage-2 admission window
    admits a name for up to four weeks {e after} that level was set, so by the
    time a pick is printed the stock may already trade well above it (long) or
    below it (short).

    Nothing used to reconcile the two. On the 2026-07-24 weekly report MBX
    printed ["BUY STOP 651 sh @ $46.08 … risk $784"] while MBX traded at ~$62: a
    resting buy-stop under the market is already triggered, so the order fills
    at ~$62 as a market order. The real risk against the $44.88 stop was ~$11k —
    {b 14x the displayed figure} — and the notional was 34% larger than the
    sizer intended.

    {1 The classification}

    Let [E] be the entry level and [C] the current close. The {b overshoot} is
    how far price has travelled past [E] {e in the trade's own direction}:

    - long: [(C - E) / E * 100]
    - short: [(E - C) / E * 100]

    so a positive overshoot always means "price is already past the entry",
    whichever side the candidate is on. Against two thresholds:

    - {!Valid_stop} — [overshoot <= through_band_pct]. The resting stop order is
      still the right ticket. The band is a de-minimis tolerance: a stop resting
      a few cents under the market fills essentially at the stop, so
      re-anchoring buys nothing.
    - {!Through_entry} — [through_band_pct < overshoot <= extension_max_pct].
      Price is through the trigger: the order would fill at the market, so the
      ticket is re-anchored to [C] and {b re-sized on [C] vs the stop}. This
      mirrors the backtest's [Entry_walk], which fills at the price observed on
      signal evaluation and sizes at that fill.
    - {!Extended} — [overshoot > extension_max_pct]. Too far past the breakout
      to buy: the ticket is suppressed with a do-not-chase reason and the row is
      kept for watch purposes.

    {b Weinstein authority}: [docs/design/weinstein-book-reference.md] §1 "Stage
    2 detail (Ch. 2)" — "Begins when stock breaks out above the top of the
    resistance zone […] After initial rally, usually at least one pullback close
    to the breakout point — this is a second chance to buy."

    That clause is the whole support for the cap: the book locates the buy
    {e at} the breakout, or on a pullback back {e close to} it. A name trading
    far above its breakout is at neither, so there is no Weinstein buy point to
    write a ticket against. (The section's "Late Stage 2 warning" reads
    similarly but is {b not} cited here: it is conditioned on the stock sagging
    toward its MA with the MA's ascent flattening, which is a different
    predicate from distance past the breakout.)

    This module changes no admission rule and schedules no re-entry: it
    describes the executable ticket attached to an already-admitted candidate.
    No pullback-timing mechanic is implied or implemented. *)

type levels = {
  close : float;
      (** The candidate's current close — the price the reconciliation was
          computed against, and the expected fill for a {!Through_entry}. *)
  overshoot_pct : float;
      (** Side-signed distance past the entry level, in percentage points of the
          entry. Positive = price is already past the entry in the trade's
          direction; negative = the entry has not been reached (the ordinary
          resting-stop case). *)
  cap : float; [@sexp.default 0.0]
      (** The do-not-chase ceiling — the worst fill the order may accept, one
          [extension_max_pct] past the entry in the trade's direction
          ([entry x (1 + pct/100)] long, mirrored short). Carried in the frozen
          snapshot so both the sizer ({!Weekly_snapshot.sizing_basis_price}) and
          the report/chart draw the same ceiling the live order caps at (issue
          #2158, "size on the cap" — the honest-conservative basis: worst
          admissible fill, not expected fill). Additive field defaulting to
          [0.0]: snapshots written before #2158 parse with no cap, and
          {!Weekly_snapshot.sizing_basis_price} falls back to the expected fill
          for them, so their sizing is read exactly as it was written. *)
}
[@@deriving sexp, eq, show]
(** Price context carried by every reconciled class, so a renderer can show the
    close, the overshoot and the do-not-chase cap without re-deriving them. *)

(** Reconciliation class of one candidate. *)
type t =
  | Not_reconciled
      (** No reconciliation was performed: the mechanism is disarmed
          ([extension_max_pct <= 0.0]), the entry level is non-positive, or the
          symbol has no resident bar to read a close from. Treated everywhere
          exactly as {!Valid_stop} was treated before this feature existed —
          this is the R1 no-op value. *)
  | Valid_stop of levels
      (** Price has not (materially) reached the entry: today's resting stop
          order, unchanged. *)
  | Through_entry of levels
      (** Price is past the entry but within the extension cap: the ticket
          re-anchors to a market order at [levels.close] and is re-sized on that
          fill. *)
  | Extended of levels
      (** Price is past the extension cap: the ticket is suppressed
          (do-not-chase) and the row kept for watch purposes. *)
[@@deriving sexp, eq, show]

val overshoot_pct :
  side:[ `Long | `Short ] -> entry:float -> close:float -> float
(** [overshoot_pct ~side ~entry ~close] is the side-signed distance of [close]
    past [entry], in percentage points of [entry] —
    [(close - entry) / entry * 100] for a long and its mirror
    [(entry - close) / entry * 100] for a short, so positive always means
    "already past the entry".

    [0.0] for a non-positive [entry] rather than a division by zero. *)

val cap_price :
  side:[ `Long | `Short ] -> entry:float -> extension_max_pct:float -> float
(** [cap_price ~side ~entry ~extension_max_pct] is the do-not-chase ceiling —
    the worst fill an entry order should accept, one [extension_max_pct] past
    [entry] in the trade's direction: [entry x (1 + pct/100)] for a long, its
    mirror [entry x (1 - pct/100)] for a short.

    Returns [entry] unchanged when [extension_max_pct <= 0.0] (disarmed — no
    cap, so the worst admissible fill collapses onto the entry) or when
    [entry <= 0.0] (undefined). This is the same ceiling the live
    {!Weinstein_order_gen} caps its [StopLimit] at, and the value stored in
    {!levels.cap} by {!classify}. *)

val classify :
  side:[ `Long | `Short ] ->
  entry:float ->
  close:float ->
  through_band_pct:float ->
  extension_max_pct:float ->
  t
(** [classify ~side ~entry ~close ~through_band_pct ~extension_max_pct] is the
    reconciliation class per the table above.

    {b Disarmed by default.} [extension_max_pct <= 0.0] is the arming switch: it
    returns {!Not_reconciled} unconditionally, so the default configuration
    reproduces pre-#2103 behaviour exactly (experiment-flag-discipline R1). A
    non-positive [entry] also returns {!Not_reconciled} (the overshoot is
    undefined).

    Both boundaries are {b inclusive of the lower class}: an overshoot exactly
    equal to [through_band_pct] is {!Valid_stop}, and one exactly equal to
    [extension_max_pct] is {!Through_entry}. [through_band_pct] may be [0.0] (no
    de-minimis tolerance — any overshoot at all re-anchors the ticket). *)

val label : t -> string option
(** Short display label for the class — [None] for {!Not_reconciled} (nothing to
    show), ["valid-stop"] / ["through-entry"] / ["EXTENDED"] otherwise. Used for
    the HTML tag chip and its CSS modifier. *)

val levels_of : t -> levels option
(** [levels_of t] is the price context of a reconciled class, [None] for
    {!Not_reconciled}. *)

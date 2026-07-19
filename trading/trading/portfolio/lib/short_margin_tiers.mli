(** Price-banded tier tables for short-side margin mechanics (margin M3a).

    Encodes the FINRA / broker reality that a short's borrow rate and its
    maintenance requirement are {b price-tiered}: low-priced (hard-to-borrow)
    names carry punitive rates and per-share maintenance floors, while liquid
    higher-priced names sit on the base tier. See
    [dev/notes/long-short-margin-mechanics-2026-06-12.md] §1 for the researched
    numbers (sub-$5 → 100% maintenance, ~$5-17 → the $5/share floor ≈ 83%,
    ≥ ~$16.67 → the 30% base tier).

    A tier table is a plain list of {!tier} bands. Lookup is piecewise-constant:
    a symbol marked at [price] uses the {b tightest} band that still covers it
    (the band with the smallest [price_below] strictly greater than [price]);
    when no band covers the price, the caller's flat fallback applies. The table
    is therefore order-independent and, crucially, {b an empty table is a no-op}
    — [tier_value] returns the flat fallback unchanged, so a disarmed
    {!Margin_config} reproduces the pre-M3a flat behaviour bit-for-bit.

    The thresholds themselves are {b not} baked into this module: it only
    provides the lookup mechanism. Concrete tier values live in
    default-disarmed example configs / tests, per
    [.claude/rules/experiment-flag-discipline.md] R1 (default-off) — the code
    ships an empty table.

    Pure. *)

type tier = {
  price_below : float;
      (** Upper price bound (exclusive) of this band. A short marked strictly
          below [price_below] is eligible for this band's [value]. *)
  value : float;
      (** The tier value — an annual borrow-fee fraction, or a maintenance
          equity ratio, depending on which table this tier belongs to. *)
}
[@@deriving show, eq, sexp]

val tier_value : tiers:tier list -> flat_fallback:float -> price:float -> float
(** [tier_value ~tiers ~flat_fallback ~price] resolves the tier value for a short
    marked at [price].

    Selects the band with the smallest [price_below] that is strictly greater
    than [price] (the tightest covering band) and returns its [value]. When no
    band covers [price] — including the {b empty-table case} — returns
    [flat_fallback].

    Examples with [tiers = [ {price_below=5.0; value=1.0};
    {price_below=17.0; value=0.83} ]] and [flat_fallback = 0.30]:
    - [price = 3.0] → [1.0] (covered by the $5 band, the tightest)
    - [price = 10.0] → [0.83] (only the $17 band covers it)
    - [price = 20.0] → [0.30] (no band covers it → fallback)

    Order-independent: the tightest covering band is chosen regardless of list
    order. Pure. *)

(** The [enable_short_side] entry gate.

    Assembles the per-Friday entry-candidate list from the screener's
    [buy_candidates] and [short_candidates], honouring the
    [Weinstein_strategy_config.enable_short_side] switch.

    {1 Why this module exists}

    The switch was previously an inline [if]/[else] inside
    {!Weinstein_strategy_screening.screen_universe} with no dedicated regression
    test. The [enable_short_side = false] contract — "the strategy emits {b zero}
    short entries from the production screening path" — is load-bearing: every
    long-only baseline (Cell-E grids, broad-universe PIT re-baselines) sets
    [((enable_short_side false))] and relies on it to suppress shorts entirely
    while the short-side gaps in [dev/notes/short-side-gaps-2026-04-29.md] are
    open. Extracting it to a named, unit-tested function pins that contract so a
    future refactor cannot silently let shorts leak back into a "long" run.

    The spine is untouched (short selling in Stage 3/4 is part of Weinstein's
    methodology — see [.claude/rules/weinstein-faithful-core.md]); this only
    makes the existing [enable_short_side] {e off} switch honest and testable. *)

val combine :
  enable_short_side:bool ->
  short_min_price:float ->
  buy_candidates:Screener.scored_candidate list ->
  short_candidates:Screener.scored_candidate list ->
  Screener.scored_candidate list
(** [combine ~enable_short_side ~short_min_price ~buy_candidates
      ~short_candidates] is the entry-candidate list fed to
    {!Weinstein_strategy.entries_from_candidates}.

    - When [enable_short_side = false]: returns [buy_candidates] unchanged — no
      short candidate ever reaches the entry walk, so the production path emits
      zero short entries regardless of the screener's [short_candidates]. This
      is the long-only baseline contract.
    - When [enable_short_side = true] (the default): returns
      [buy_candidates @ Short_min_price_gate.filter ~short_min_price
      short_candidates] — i.e. shorts are admitted, after the
      sub-[short_min_price] economic-margin floor is applied (no-op when
      [short_min_price <= 0.0]).

    Pure. Order-preserving (longs first, then admitted shorts) so existing
    goldens replay bit-identically. *)

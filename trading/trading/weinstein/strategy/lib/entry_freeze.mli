(** No-chase entry-[E] freeze (Fix #2, plan
    [dev/plans/fill-model-faithfulness-2026-08-07.md] Workstream D; findings
    [dev/notes/fill-model-fix-findings-2026-08-07.md] §4 Q3).

    The screener recomputes each candidate's [suggested_entry] (breakout level
    [E]) every Friday, so for a symbol making new highs [E] floats upward week
    over week and the strategy's resting entry ticket chases the extension —
    "buying an extended stock," the exact thing Weinstein's breakout rule warns
    against ([docs/design/weinstein-book-reference.md] §4.1 "buy {i the}
    breakout"; §3 do not chase a stock that has already run). This module pins
    [E] to the first-qualifying breakout while the setup stays live, so the
    ticket rests at the price the stock first needed to break out — not every
    successive higher high.

    The pin table is per-run mutable state ([symbol -> first-seen E]) held in
    the {!Weinstein_strategy.make} closure alongside [stop_states] and released
    per the rules on {!apply}. Default-off: the caller gates on
    [config.freeze_entry_at_first_breakout]; when off, {!apply} returns the
    candidate list untouched and never mutates the table (R1, bit-identical). *)

type t
(** Mutable per-run pin table: symbol -> its first-qualifying [suggested_entry].
    Grows only while a symbol keeps qualifying (or is held); released when it
    drops out of both, so a later re-qualification earns a fresh pin. *)

val create : unit -> t
(** A fresh, empty pin table. *)

val apply :
  enabled:bool ->
  pending:t ->
  held_set:Core.String.Set.t ->
  candidates:Screener.scored_candidate list ->
  Screener.scored_candidate list
(** [apply ~enabled ~pending ~held_set ~candidates] freezes each candidate's
    [suggested_entry] to its first-qualifying value.

    When [enabled = false]: returns [candidates] unchanged and does {b not}
    touch [pending] (default-off, bit-identical — R1).

    When [enabled = true], run once per Friday entry walk over the (already
    held-excluded) [candidates]:
    - {b Release} every pinned symbol that is neither still qualifying this week
      nor currently in [held_set] — the setup expired / the candidate dropped
      out / the position round-tripped to [Closed], so a later re-qualification
      earns a fresh [E].
    - {b Reuse} the pinned [E] for any candidate already in [pending]: its
      [suggested_entry] is overridden to the frozen level.
    - {b Pin} the current [suggested_entry] for any candidate not yet in
      [pending] (first qualification), returning it unchanged.

    [held_set] is the strategy's held symbols ({!Entry_walk.held_symbols}); a
    symbol resting an unfilled entry order stays held, so its pin persists
    (dormant, since held symbols are excluded from [candidates]) until the
    position closes and it drops out. Applies symmetrically to long and short
    candidates — a short breakdown level should not be chased lower either. *)

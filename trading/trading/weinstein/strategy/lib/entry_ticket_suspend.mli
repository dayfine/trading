(** #2976 — {b suspend} (not cancel) resting long entry tickets while the macro
    gate rejects new longs, and re-issue them unchanged when it admits again.

    {b The gap.} The cascade's macro gate applies only to {e fresh} candidates:
    a symbol resting an unfilled ticket is held, so it never reaches the
    cascade, and the simulator keeps a StopLimit entry order until a bar trades
    through it (GTC, [trading/simulation/test/test_gtc_entry_persistence.ml]).
    On the 26y walkthrough 103 of 724 fills (14 %) landed in weeks whose screen
    read [Bearish], from tickets placed in a Bullish/Neutral tape
    ([gh issue 2976] and its investigation comment).

    {b Book authority.} Ch. 8 ("Stage Analysis for the Market Averages"):
    "Suspend buying even if you see a few stocks breaking out on their charts"
    ([docs/design/weinstein-book-reference.md] §2.1, "Resolved 2026-09-16").
    Spine item 6 of [.claude/rules/weinstein-faithful-core.md]: the macro gate
    is unconditional. The book's word is {e suspend}; a condition {e cancel}
    ([enable_entry_ticket_rescreen]) throws away the pullback-then-resume
    winners that the suspension keeps (the 159 fills worth +$1.33M that saw a
    Bearish screen while resting and filled after it cleared).

    {b Mechanics — built alongside the core, no Orders/Portfolio change.}
    - {b Suspend.} On a weekly screen where {!suspends} is [true], every resting
      (wholly unfilled) {b long} [Entering] position gets a [CancelEntry] with
      reason {!cancel_reason}. The simulator's existing
      {!Trading_simulation.Cancel_handler.cancel_resting_entry_orders} retires
      its order, so it cannot fill and — being closed — reserves no cash. The
      ticket itself is stashed in {!t}: symbol, side, quantity, frozen entry
      level [E] (the order's trigger; the do-not-chase limit is re-derived
      from [E] by the simulator's unchanged config), entry reasoning, the
      symbol's stop-state plan, and the {b original} placement date.
    - {b Re-issue.} On the first screen where {!suspends} is [false], each
      stashed ticket is re-emitted as a [CreateEntering] with the identical
      parameters (under a fresh position id — a closed position cannot be
      reopened) and its stop state re-installed, so the order that reaches the
      simulator is the order that was withdrawn.
    - {b Age.} Suspension time {b counts} toward [entry_order_max_rest_weeks]:
      a ticket is as old as its first placement, not its latest re-issue. The
      alternative (pausing the clock) would let a ticket outlive the TTL by
      the length of every bear phase it slept through, which is the
      stale-ticket shape the clock exists to stop. A stashed ticket past the
      clock is dropped (and its {!Entry_freeze} pin released) instead of being
      re-issued; a re-issued ticket reads its original date through
      {!aged_portfolio}.
    - {b Cancels win.} The F2 re-screen / clock cancels
      ({!Entry_ticket_ttl}) are computed first; a ticket they retire is not
      also suspended. Note that an armed [enable_entry_ticket_rescreen] asks
      the same macro question, so under [On_bearish_macro] it cancels the
      ticket before this module can suspend it — the two are rival answers
      to one question and are meant to be run as separate arms.
    - {b Held.} While stashed (and on the re-issue tick) the symbol counts as
      held for the cascade, so it is never written as a second, fresh ticket.
      A stashed ticket whose symbol has become held by another position by
      re-issue time (e.g. a short entered during the suspension) is dropped.

    {b Scope.} Longs only. Shorts have their own gate
    ([Screener.shorts_admitted_by_macro]) and the book's Stage-4 instruction on
    that side is the opposite one; resting shorts are untouched.

    {b Default [Off]} (config field
    [Weinstein_strategy_config.entry_ticket_macro_suspend]) never builds or
    reads the store: {!run} reduces to the F2 cancel callback on the unmodified
    portfolio, bit-identical to the pre-#2976 path. *)

open Core
module Position = Trading_strategy.Position

type t
(** Mutable per-run store, held in the {!Weinstein_strategy.make} closure beside
    the {!Entry_freeze} pin table: the stashed tickets (by symbol) and the
    original placement date of every re-issued position (by position id). *)

val create : unit -> t
(** A fresh, empty store. *)

val cancel_reason : string
(** ["entry_ticket_macro_suspended"] — the [CancelEntry] reason of a
    suspension. A {e withdrawal}, not a ticket death: the same setup comes back
    as a new position id once the gate admits. *)

val suspends :
  config:Weinstein_strategy_config.config -> macro_result:Macro.result -> bool
(** Whether this week's tape suspends resting long tickets, per
    [config.entry_ticket_macro_suspend]: never under [Off]; under
    [On_bearish_macro] exactly when {!Long_entry_macro_gate.admits} is [false];
    under [On_index_stage4] exactly when [macro_result.index_stage] is Stage 4,
    whatever the composite [trend] reads. *)

val aged_portfolio :
  t -> Trading_strategy.Portfolio_view.t -> Trading_strategy.Portfolio_view.t
(** The portfolio as the TTL clock should see it: every re-issued [Entering]
    position carries its {b original} [created_date]. Every other position is
    returned as is, so an empty store maps the portfolio to an equal one. *)

val run :
  ?store:t ->
  ?pending_entry_e:Entry_freeze.t ->
  config:Weinstein_strategy_config.config ->
  macro_result:Macro.result ->
  stop_states:Weinstein_stops.stop_state String.Map.t ref ->
  portfolio:Trading_strategy.Portfolio_view.t ->
  current_date:Date.t ->
  cancel_expired:
    (Trading_strategy.Portfolio_view.t -> Position.transition list) ->
  unit ->
  Position.transition list * string list
(** One weekly screen's resting-ticket lifecycle. [cancel_expired] is the F2
    re-screen / clock cancel ({!Entry_ticket_ttl.run} as the screening module
    wires it); it is always called exactly once.

    Returns [(transitions, suspended_held)]: the F2 cancels, then this week's
    suspensions or re-issues; and the symbols the cascade must treat as held
    this week (stashed or being re-issued).

    With [config.entry_ticket_macro_suspend = Off], or no [store], this is
    exactly [(cancel_expired portfolio, [])]. *)

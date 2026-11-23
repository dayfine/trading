(** Entry ADV-participation cap for the weekly picks (issue #3681).

    The live counterpart of the backtest's
    [Liquidity_config.max_entry_adv_participation] check in the entry walk. A
    long pick is dropped when its sized position dollars
    ([Weekly_snapshot.candidate.sized_position_value]) exceed [p] times the
    pick's trailing dollar-ADV, read exactly as the backtest reads it
    ({!Weinstein_strategy.Entry_liquidity_gate.dollar_adv_for}). It blocks; it
    never resizes.

    The position dollars come from the generator's sizing against the live
    account (the [--portfolio] file's cash plus held long value), not from a
    backtest NAV: that file is how a live run states its account size. A $10k
    position therefore passes on names a backtest-sized position would not.

    Default ([max_entry_adv_participation = None]): the identity, no warnings,
    no bars read. *)

open Core
open Weinstein_snapshot

val partition :
  liquidity_config:Weinstein_strategy.Liquidity_config.t ->
  Weinstein_strategy.Bar_reader.t ->
  as_of:Date.t ->
  Weekly_snapshot.candidate list ->
  Weekly_snapshot.candidate list * string list
(** [partition ~liquidity_config reader ~as_of candidates] is
    [(kept, warnings)]: [kept] in input order, and one warning line per dropped
    candidate naming its planned dollars, the ADV and [p]. A candidate with no
    ADV reading is kept. *)

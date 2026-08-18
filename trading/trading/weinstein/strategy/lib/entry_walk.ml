open Core
open Trading_strategy
open Weinstein_strategy_config

(** Collect ticker symbols of positions the strategy is still holding (or still
    trying to enter/exit). Closed positions are excluded — the strategy has no
    stake in them and must be free to re-enter the symbol.

    Bug fix: previously returned every position in the portfolio regardless of
    state, including Closed. That permanently blacklisted every symbol the
    strategy had ever traded from re-entry via both [held_tickers] passed to the
    screener and the in-strategy candidate filter.

    The match is exhaustive so a future state addition forces a compile error
    here, where the keep/drop decision must be re-examined. *)
let held_symbols (portfolio : Portfolio_view.t) =
  Map.data portfolio.positions
  |> List.filter_map ~f:(fun (p : Position.t) ->
      match p.state with
      | Entering _ | Holding _ | Exiting _ -> Some p.symbol
      | Closed _ -> None)

(** Classify one [candidate] through the entry gates against [state], pairing it
    with its decision. Mutates [state]'s accumulators in-place. *)
let _classify_one ~held_set ~make_entry ~portfolio_value
    ~(state : Screening_notional.entry_walk_state) candidate =
  ( candidate,
    Entry_audit_capture.classify_candidate
      ~leverage_enabled:state.leverage_enabled ~held_set ~make_entry
      ~remaining_cash:state.remaining_cash
      ~short_notional_acc:state.short_notional_acc
      ~short_notional_cap:state.short_notional_cap
      ~long_notional_acc:state.long_notional_acc
      ~long_notional_cap:state.long_notional_cap
      ~sector_exposure_acc:state.sector_exposure_acc
      ~max_sector_exposure_pct:state.max_sector_exposure_pct ~portfolio_value
      candidate )

(** Classify [candidates] (in order) through the entry gates against [state],
    pairing each with its decision. The walk mutates [state]'s accumulators
    in-place. *)
let _classify_candidates ~held_set ~make_entry ~portfolio_value ~state
    candidates =
  List.map candidates
    ~f:(_classify_one ~held_set ~make_entry ~portfolio_value ~state)

(** Classify [indexed_candidates] (in original order) while charging them
    against a side-specific [remaining_cash] budget [side_cash], reusing the
    shared [short_notional_acc] / [sector_exposure_acc] in [state] so the caps
    apply across both sides. Returns the [(index, candidate, decision)] triples
    keyed by the candidate's position in the original list. *)
let _walk_side ~held_set ~make_entry ~portfolio_value
    ~(state : Screening_notional.entry_walk_state) ~side_cash indexed_candidates
    =
  let side_state = { state with remaining_cash = ref side_cash } in
  let decisions =
    _classify_candidates ~held_set ~make_entry ~portfolio_value
      ~state:side_state
      (List.map indexed_candidates ~f:snd)
  in
  List.map2_exn indexed_candidates decisions ~f:(fun (i, c) (_, d) -> (i, c, d))

(** Reserved-short-sleeve walk (active when [short_sleeve_fraction > 0.0]).
    Partitions the per-Friday cash budget so longs cannot starve shorts:
    reserves [short_budget] for a short-only walk and walks longs against
    [long_cash]. Both walks reuse [state]'s shared [short_notional_acc] and
    [sector_exposure_acc] (caps apply across both sides) but carry independent
    [remaining_cash] refs. Decisions are re-ordered back into the original
    [candidates] order so emit/kept ordering matches the combined-walk path. See
    [project_short_funnel_crowded_out]. *)
let _sleeve_decisions ~held_set ~make_entry ~portfolio_value ~state ~long_cash
    ~short_budget candidates =
  let indexed = List.mapi candidates ~f:(fun i c -> (i, c)) in
  let is_short (_, (c : Screener.scored_candidate)) =
    Trading_base.Types.equal_position_side c.side Trading_base.Types.Short
  in
  let short_indexed, long_indexed = List.partition_tf indexed ~f:is_short in
  let walk = _walk_side ~held_set ~make_entry ~portfolio_value ~state in
  let long_walk = walk ~side_cash:long_cash long_indexed in
  let short_walk = walk ~side_cash:short_budget short_indexed in
  List.append long_walk short_walk
  |> List.sort ~compare:(fun (i, _, _) (j, _, _) -> Int.compare i j)
  |> List.map ~f:(fun (_, c, d) -> (c, d))

(** Build the per-candidate entry constructor for a walk. Computes the
    E-anchored trigger (both StopLimit flags armed — user decision 2026-08-05)
    and threads the ticket-level stop-anchor knob
    ([config.stop_anchor_at_entry_base], user go 2026-08-06); both default-off,
    so the closure is bit-identical to the pre-flag path when the flags are off
    (R1). Factored out of {!entries_from_candidates} so that function stays
    under the function-length limit. *)
let _make_entry_fn ~config ~bar_reader ~current_date ~stop_states
    ~portfolio_value (cand : Screener.scored_candidate) =
  let trigger_at_suggested =
    config.sim_entry_trigger_at_suggested && config.enable_sim_entry_stoplimit
  in
  Entry_audit_capture.make_entry_transition ~trigger_at_suggested
    ~stop_anchor_at_entry_base:config.stop_anchor_at_entry_base
    ~stop_width:
      {
        Stop_width_mode.mode = config.stop_width_mode;
        size_down_max_pct = config.stop_width_size_down_max_pct;
      }
    ~min_stop_distance_pct:
      (Entry_stop_distance.min_stop_distance_for ~config ~bar_reader
         ~current_date cand)
    ~portfolio_risk_config:config.portfolio_config
    ~stops_config:config.stops_config
    ~initial_stop_buffer:config.initial_stop_buffer ~stop_states ~bar_reader
    ~portfolio_value ~current_date cand

(** The two pre-walk transforms of the candidate list, both default-off
    identities (R1):

    - Fix #2 [freeze_entry_at_first_breakout] pins each candidate's
      [suggested_entry] to its first qualifying breakout, so a trending symbol's
      ticket does not chase the extension upward week over week.
    - Defect B [Demote_over_max] moves the wide-stop candidates behind the
      narrow-stop ones, so §5.1's "prefer other candidates" costs priority
      rather than existence — they are funded with whatever the narrow-stop
      candidates leave.

    Order matters: the freeze rewrites [suggested_entry], and the demotion's
    stop-width measurement keys off the entry, so the freeze must run first or
    the two would disagree about which entry a candidate is being judged at. *)
let _prepare_candidates ~config ~pending_entry_e ~held_set ~bar_reader
    ~current_date candidates =
  Entry_freeze.apply ~enabled:config.freeze_entry_at_first_breakout
    ~pending:pending_entry_e ~held_set ~candidates
  |> Entry_stop_width_order.prefer_narrow_stops ~config ~bar_reader
       ~current_date

(* G3: what one position still owes on a resting entry ticket, 0 for anything
   that is not one.

   Only the UNFILLED remainder counts — a partial fill already drew its own cash
   out of [portfolio.cash], so charging [target_quantity] would double-count it.
   Longs only: an entering short credits cash on fill, so reserving against one
   would shrink the budget for a claim that pays in.

   Split out of the fold below rather than inlined: the per-position rule is the
   part with the two easy-to-get-wrong cases, and keeping it a named function
   keeps both it and the fold under the nesting limit. *)
let _resting_ticket_cost_of (pos : Position.t) =
  match (pos.state, pos.side) with
  | ( Position.Entering { target_quantity; entry_price; filled_quantity; _ },
      Trading_base.Types.Long ) ->
      (target_quantity -. filled_quantity) *. entry_price
  | _ -> 0.0

(* Total the book has committed to tickets that have not yet drawn their cash. *)
let _resting_long_ticket_cost (portfolio : Portfolio_view.t) =
  Map.fold portfolio.positions ~init:0.0 ~f:(fun ~key:_ ~data:pos acc ->
      acc +. _resting_ticket_cost_of pos)

(* Cash the walk may commit this tick.

   The default is [portfolio.cash] verbatim. Under G3 the resting tickets'
   unfilled cost is held back, because the per-tick [remaining_cash] discipline
   in {!Entry_audit_capture.check_cash_and_deduct} is re-seeded every tick and
   so cannot see that last week's tickets have already claimed this week's cash.
   Floored at 0: over-commitment from before the flag was armed must not produce
   a negative budget. *)
let _spendable_cash ~config (portfolio : Portfolio_view.t) =
  if config.reserve_cash_for_resting_tickets then
    Float.max 0.0 (portfolio.cash -. _resting_long_ticket_cost portfolio)
  else portfolio.cash

(** Generate CreateEntering transitions for screener candidates. Tracks
    remaining cash to avoid generating orders that exceed funds.

    Public (see .mli) so callers running custom screening out-of-band can feed
    candidates through the same entry pipeline the strategy uses.

    The walk produces a tagged decision list (see
    {!Entry_audit_capture.candidate_decision}). After the walk, kept candidates
    are emitted to [audit_recorder.record_entry] with the rivals they outranked
    — this is the PR-2 entry-capture site. The output transition list is
    bit-equivalent to the pre-audit shape: same candidates, same transitions,
    same side-effects on [stop_states] and [remaining_cash].

    {b Order.} The list comes back in the order the walk charged the shared
    budget, which is screener order under every mode except
    {!Stop_width_mode.Demote_over_max}; that mode permutes the input in
    {!_prepare_candidates} so wide-stop candidates are charged last. The
    permutation moves the [long_notional_acc] and [sector_exposure_acc]
    mutations with it, not only [remaining_cash] — every accumulator the walk
    threads is order-dependent, which is the whole point of demoting. *)
let entries_from_candidates ?sector_lookup
    ?(pending_entry_e = Entry_freeze.create ()) ~config ~candidates ~stop_states
    ~bar_reader ~(portfolio : Portfolio_view.t) ~get_price ~current_date
    ?(audit_recorder = Audit_recorder.noop) ?macro () =
  let held_set = String.Set.of_list (held_symbols portfolio) in
  let candidates =
    _prepare_candidates ~config ~pending_entry_e ~held_set ~bar_reader
      ~current_date candidates
  in
  let portfolio_value = Portfolio_view.portfolio_value portfolio ~get_price in
  let make_entry =
    _make_entry_fn ~config ~bar_reader ~current_date ~stop_states
      ~portfolio_value
  in
  let spendable = _spendable_cash ~config portfolio in
  let state =
    Screening_notional.make_entry_walk_state ~cash:spendable ~config ~portfolio
      ~portfolio_value ~sector_lookup
  in
  let decisions =
    if Float.( <= ) config.short_sleeve_fraction 0.0 then
      (* No-op default: single combined walk over [candidates], bit-identical
         to the pre-sleeve path. *)
      _classify_candidates ~held_set ~make_entry ~portfolio_value ~state
        candidates
    else
      (* Reserved short sleeve: partition the cash budget between a long and a
         short walk that share [state]'s notional/sector accumulators. *)
      let short_budget = portfolio_value *. config.short_sleeve_fraction in
      let long_cash = Float.max 0.0 (spendable -. short_budget) in
      _sleeve_decisions ~held_set ~make_entry ~portfolio_value ~state ~long_cash
        ~short_budget candidates
  in
  let kept =
    List.filter_map decisions ~f:(fun (_, d) ->
        match d with
        | Entry_audit_capture.Kept (trans, _) -> Some trans
        | Skipped _ -> None)
  in
  Entry_audit_capture.emit_entries ~audit_recorder ~macro ~current_date
    ~decisions;
  kept

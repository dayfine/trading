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

(** Generate CreateEntering transitions for screener candidates. Tracks
    remaining cash to avoid generating orders that exceed funds.

    Public (see .mli) so callers running custom screening out-of-band can feed
    candidates through the same entry pipeline the strategy uses.

    The walk produces a tagged decision list (see
    {!Entry_audit_capture.candidate_decision}). After the walk, kept candidates
    are emitted to [audit_recorder.record_entry] with the rivals they outranked
    — this is the PR-2 entry-capture site. The output transition list (in
    original screener order) is bit-equivalent to the pre-audit shape: same
    candidates, same transitions, same side-effects on [stop_states] and
    [remaining_cash]. *)
let entries_from_candidates ?sector_lookup ~config ~candidates ~stop_states
    ~bar_reader ~(portfolio : Portfolio_view.t) ~get_price ~current_date
    ?(audit_recorder = Audit_recorder.noop) ?macro () =
  let held_set = String.Set.of_list (held_symbols portfolio) in
  let portfolio_value = Portfolio_view.portfolio_value portfolio ~get_price in
  let make_entry (cand : Screener.scored_candidate) =
    Entry_audit_capture.make_entry_transition
      ~min_stop_distance_pct:
        (Entry_stop_distance.min_stop_distance_for ~config ~bar_reader
           ~current_date cand)
      ~portfolio_risk_config:(Scale_in_runner.entry_sizing_config config)
      ~stops_config:config.stops_config
      ~initial_stop_buffer:config.initial_stop_buffer ~stop_states ~bar_reader
      ~portfolio_value ~current_date cand
  in
  let spendable, state =
    Screening_notional.reserve_reduced_walk_state ~config ~portfolio
      ~portfolio_value ~sector_lookup
  in
  let decisions =
    if Float.( <= ) config.short_sleeve_fraction 0.0 then
      (* No-op default: single combined walk over [candidates], bit-identical
         to the pre-sleeve path. *)
      _classify_candidates ~held_set ~make_entry ~portfolio_value ~state
        candidates
    else
      (* Reserved short sleeve: partition the (reserve-reduced) cash budget
         between a long and a short walk that share [state]'s notional/sector
         accumulators. *)
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

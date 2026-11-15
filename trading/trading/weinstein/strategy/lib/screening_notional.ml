open Core
open Trading_strategy

(* Entry-price notional for a single [Holding] short position; 0.0 for all
   other position types. Folded over the position map without a deep nested
   match by [initial_short_notional]. *)
let _short_holding_notional (pos : Position.t) =
  match (pos.side, pos.state) with
  | Trading_base.Types.Short, Position.Holding { quantity; entry_price; _ } ->
      Float.abs quantity *. entry_price
  | _ -> 0.0

let initial_short_notional (positions : Position.t Map.M(String).t) =
  Map.fold positions ~init:0.0 ~f:(fun ~key:_ ~data:pos acc ->
      acc +. _short_holding_notional pos)

(* Entry-price notional for a single [Holding] long position; 0.0 for all
   other position types. Mirror of [_short_holding_notional] for the long
   exposure cap; folded over the position map by [initial_long_notional]. *)
let _long_holding_notional (pos : Position.t) =
  match (pos.side, pos.state) with
  | Trading_base.Types.Long, Position.Holding { quantity; entry_price; _ } ->
      Float.abs quantity *. entry_price
  | _ -> 0.0

let initial_long_notional (positions : Position.t Map.M(String).t) =
  Map.fold positions ~init:0.0 ~f:(fun ~key:_ ~data:pos acc ->
      acc +. _long_holding_notional pos)

(* Entry-price-denominated absolute notional for a single [Holding] position
   (long or short); 0.0 for all other states. Companion to
   [_short_holding_notional] for the sector-exposure cap, which counts long +
   short exposure to the same sector toward the same bucket. *)
let _holding_abs_notional (pos : Position.t) =
  match pos.state with
  | Position.Holding { quantity; entry_price; _ } ->
      Float.abs quantity *. entry_price
  | _ -> 0.0

let initial_sector_exposures ~(positions : Position.t Map.M(String).t)
    ~sector_lookup =
  let acc = Hashtbl.create (module String) in
  Map.iter positions ~f:(fun pos ->
      let notional = _holding_abs_notional pos in
      if Float.( > ) notional 0.0 then
        let sector = sector_lookup pos.symbol |> Option.value ~default:"" in
        Hashtbl.update acc sector ~f:(function
          | None -> notional
          | Some v -> v +. notional));
  acc

type entry_walk_state = {
  remaining_cash : float ref;
  short_notional_acc : float ref;
  short_notional_cap : float;
  long_notional_acc : float ref;
  long_notional_cap : float;
  sector_exposure_acc : (string, float) Hashtbl.t;
  max_sector_exposure_pct : float option;
  leverage_enabled : bool;
}

let borrowed_balance state = Float.max 0.0 (-. !(state.remaining_cash))

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
let spendable_cash ~(config : Weinstein_strategy_config.config)
    (portfolio : Portfolio_view.t) =
  if config.reserve_cash_for_resting_tickets then
    Float.max 0.0 (portfolio.cash -. _resting_long_ticket_cost portfolio)
  else portfolio.cash

let long_budget ~(config : Weinstein_strategy_config.config) ~spendable
    ~portfolio_value =
  if Float.( <= ) config.short_sleeve_fraction 0.0 then spendable
  else
    Float.max 0.0
      (spendable -. (portfolio_value *. config.short_sleeve_fraction))

let make_entry_walk_state ~cash ~(config : Weinstein_strategy_config.config)
    ~(portfolio : Portfolio_view.t) ~portfolio_value ~sector_lookup =
  let short_notional_acc =
    ref (initial_short_notional portfolio.Portfolio_view.positions)
  in
  let short_notional_cap =
    portfolio_value
    *. config.portfolio_config.Portfolio_risk.max_short_notional_fraction
  in
  let long_notional_acc =
    ref (initial_long_notional portfolio.Portfolio_view.positions)
  in
  (* Buying-power ceiling: [min] of the #1965 exposure term and the M1a
     leverage term. At the defaults ([max_long_exposure_pct_entry = 0.0],
     [initial_long_margin_req = 1.0]) both terms are [Float.infinity], so the
     gate is an exact no-op (every long admits) — byte-identical to the prior
     inline computation. See {!Long_buying_power.long_notional_ceiling}. *)
  let long_notional_cap =
    Long_buying_power.long_notional_ceiling
      ~max_long_exposure_pct_entry:config.max_long_exposure_pct_entry
      ~initial_long_margin_req:config.initial_long_margin_req
      ~equity:portfolio_value
  in
  let sector_exposure_acc =
    match sector_lookup with
    | None -> Hashtbl.create (module String)
    | Some lookup ->
        initial_sector_exposures ~positions:portfolio.Portfolio_view.positions
          ~sector_lookup:lookup
  in
  {
    remaining_cash = ref cash;
    short_notional_acc;
    short_notional_cap;
    long_notional_acc;
    long_notional_cap;
    sector_exposure_acc;
    max_sector_exposure_pct =
      config.portfolio_config.Portfolio_risk.max_sector_exposure_pct;
    (* M1b: leverage engages only for a fractional margin requirement
       ([initial_long_margin_req < 1.0]). At the default cash-account setting
       (1.0) this is [false] and the entry-walk cash gate is byte-identical to
       pre-M1b (R1). When [true], the [long_notional_cap] leverage term is
       finite ([equity / req]), so the buying-power ceiling always binds. *)
    leverage_enabled = Float.( < ) config.initial_long_margin_req 1.0;
  }

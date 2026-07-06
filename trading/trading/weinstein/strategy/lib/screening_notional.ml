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
  sector_exposure_acc : (string, float) Hashtbl.t;
  max_sector_exposure_pct : float option;
}

let make_entry_walk_state ~cash ~(config : Weinstein_strategy_config.config)
    ~(portfolio : Portfolio_view.t) ~portfolio_value ~sector_lookup =
  let short_notional_acc =
    ref (initial_short_notional portfolio.Portfolio_view.positions)
  in
  let short_notional_cap =
    portfolio_value
    *. config.portfolio_config.Portfolio_risk.max_short_notional_fraction
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
    sector_exposure_acc;
    max_sector_exposure_pct =
      config.portfolio_config.Portfolio_risk.max_sector_exposure_pct;
  }

let reserve_reduced_walk_state ~(config : Weinstein_strategy_config.config)
    ~(portfolio : Portfolio_view.t) ~portfolio_value ~sector_lookup =
  let spendable =
    Float.max 0.0
      (portfolio.Portfolio_view.cash
      -. (config.cash_reserve_pct *. portfolio_value))
  in
  ( spendable,
    make_entry_walk_state ~cash:spendable ~config ~portfolio ~portfolio_value
      ~sector_lookup )

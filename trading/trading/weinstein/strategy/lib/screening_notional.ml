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

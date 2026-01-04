(** Buy and Hold strategy - Enter position once and hold indefinitely *)

open Core

type config = {
  symbols : string list;
  position_size : float;
  entry_date : Date.t option;
}
[@@deriving show, eq]

let name = "BuyAndHold"
let _position_counter = ref 0

let _generate_position_id (symbol : string) : string =
  _position_counter := !_position_counter + 1;
  Printf.sprintf "%s-bh-%d" symbol !_position_counter

(* Check if we should enter on this date *)
let _should_enter (config : config) (price : Types.Daily_price.t) : bool =
  match config.entry_date with
  | Some target_date -> Date.equal price.date target_date
  | None -> true

(* Execute entry: create CreateEntering transition *)
let _execute_entry ~(symbol : string) ~(config : config)
    ~(price : Types.Daily_price.t) : Position.transition list =
  let position_id = _generate_position_id symbol in
  let entry_price = price.Types.Daily_price.close_price in
  let date = price.Types.Daily_price.date in

  (* Produce CreateEntering transition - engine will create and fill position *)
  [
    {
      Position.position_id;
      date;
      kind =
        CreateEntering
          {
            symbol;
            target_quantity = config.position_size;
            entry_price;
            reasoning =
              ManualDecision { description = "Buy and hold - initial entry" };
          };
    };
  ]

(* Process one symbol - returns transitions only *)
let _process_symbol ~(get_price : Strategy_interface.get_price_fn)
    ~(config : config) ~(positions : Position.t String.Map.t) (symbol : string)
    : Position.transition list =
  (* Early exit if position already exists (entry already executed) *)
  if Map.mem positions symbol then []
  else
    (* Check if we should enter *)
    match get_price symbol with
    | Some price when _should_enter config price ->
        _execute_entry ~symbol ~config ~price
    | _ -> []

let make (config : config) : (module Strategy_interface.STRATEGY) =
  let module M = struct
    let on_market_close ~get_price ~get_indicator:_ ~positions =
      (* Process all symbols and collect transitions *)
      let all_transitions =
        List.concat_map config.symbols ~f:(fun symbol ->
            _process_symbol ~get_price ~config ~positions symbol)
      in

      let output = { Strategy_interface.transitions = all_transitions } in
      Result.return output

    let name = name
  end in
  (module M : Strategy_interface.STRATEGY)

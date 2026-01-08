(** Market data adapter implementation *)

open Core

type t = {
  price_data : (string, Types.Daily_price.t list) Hashtbl.t;
  current_date : Date.t;
}
(** Adapter storing price data indexed by symbol and current simulation date *)

let create ~prices ~current_date =
  let price_data = Hashtbl.create (module String) in
  (* Load all symbol prices into hash table for fast lookup *)
  List.iter prices ~f:(fun sp ->
      Hashtbl.set price_data ~key:sp.Simulator.symbol ~data:sp.Simulator.prices);
  { price_data; current_date }

let _find_price_for_date (prices : Types.Daily_price.t list) (date : Date.t) :
    Types.Daily_price.t option =
  List.find prices ~f:(fun (p : Types.Daily_price.t) -> Date.equal p.date date)

let get_price t symbol =
  match Hashtbl.find t.price_data symbol with
  | None -> None
  | Some prices ->
      (* Only return price if it's at or before current date (prevent lookahead) *)
      let price_opt = _find_price_for_date prices t.current_date in
      (match price_opt with
      | Some p when Date.(p.date <= t.current_date) -> Some p
      | _ -> None)

let get_indicator _t _symbol _indicator_name _period =
  (* Stub for Change 1 - will implement in Change 2 *)
  None

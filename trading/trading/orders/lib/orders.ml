open Core
open Base

(** Order management and validation *)

(** Order validation result *)
type validation_result =
  | Valid
  | Invalid of string list
[@@deriving show, eq]

(** Order request *)
type order_request = {
  symbol: symbol;
  side: side;
  order_type: order_type;
  quantity: quantity;
  time_in_force: string; (* GTC, IOC, FOK *)
} [@@deriving show, eq]

(** Order response *)
type order_response = {
  order_id: string;
  status: string;
  message: string option;
} [@@deriving show, eq]

(** Validate an order request *)
let validate_order_request request =
  let errors = ref [] in

  (* Check symbol *)
  if String.is_empty request.symbol then
    errors := "Symbol cannot be empty" :: !errors;

  (* Check quantity *)
  if request.quantity <= 0 then
    errors := "Quantity must be positive" :: !errors;

  (* Check order type specific validations *)
  (match request.order_type with
   | Limit price ->
     if price <= 0.0 then
       errors := "Limit price must be positive" :: !errors
   | Stop price ->
     if price <= 0.0 then
       errors := "Stop price must be positive" :: !errors
   | Market -> ());

  (* Check time in force *)
  let valid_tif = ["GTC"; "IOC"; "FOK"] in
  if not (List.mem valid_tif request.time_in_force ~equal:String.equal) then
    errors := "Invalid time in force" :: !errors;

  if List.is_empty !errors then
    Valid
  else
    Invalid !errors

(** Create a market order *)
let create_market_order symbol side quantity =
  {
    symbol;
    side;
    order_type = Market;
    quantity;
    time_in_force = "IOC";
  }

(** Create a limit order *)
let create_limit_order symbol side quantity price =
  {
    symbol;
    side;
    order_type = Limit price;
    quantity;
    time_in_force = "GTC";
  }

(** Create a stop order *)
let create_stop_order symbol side quantity price =
  {
    symbol;
    side;
    order_type = Stop price;
    quantity;
    time_in_force = "GTC";
  }

(** Format order request for display *)
let format_order_request request =
  let order_type_str = match request.order_type with
    | Market -> "Market"
    | Limit price -> sprintf "Limit @ %.2f" price
    | Stop price -> sprintf "Stop @ %.2f" price
  in
  let side_str = match request.side with
    | Buy -> "BUY"
    | Sell -> "SELL"
  in
  sprintf "%s %s %s %d %s"
    side_str
    (Int.to_string request.quantity)
    request.symbol
    order_type_str
    request.time_in_force

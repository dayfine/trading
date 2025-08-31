(** Order management and validation *)

(** Order validation result *)
type validation_result =
  | Valid
  | Invalid of string list

(** Order request *)
type order_request = {
  symbol: Base.symbol;
  side: Base.side;
  order_type: Base.order_type;
  quantity: Base.quantity;
  time_in_force: string; (* GTC, IOC, FOK *)
}

(** Order response *)
type order_response = {
  order_id: string;
  status: string;
  message: string option;
}

(** Validate an order request *)
val validate_order_request : order_request -> validation_result

(** Create a market order *)
val create_market_order : Base.symbol -> Base.side -> Base.quantity -> order_request

(** Create a limit order *)
val create_limit_order : Base.symbol -> Base.side -> Base.quantity -> Base.price -> order_request

(** Create a stop order *)
val create_stop_order : Base.symbol -> Base.side -> Base.quantity -> Base.price -> order_request

(** Format order request for display *)
val format_order_request : order_request -> string

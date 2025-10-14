(** Common trading data types and utilities *)

type symbol = string [@@deriving show, eq]
(** Symbol represents a trading security *)

type price = float [@@deriving show, eq]
(** Price represents the price of an security *)

type quantity = float [@@deriving show, eq]
(** Quantity represents the number of shares/contracts *)

(** Side represents whether an order is to buy or sell *)
type side = Buy | Sell [@@deriving show, eq]

(** Order type represents the type of order *)
type order_type =
  | Market
  | Limit of price
  | Stop of price
  | StopLimit of price * price
[@@deriving show, eq]

type position = { symbol : symbol; quantity : quantity; price : price }
[@@deriving show, eq]
(** Position represents a holding in an security *)

type trade_id = string [@@deriving show, eq]

type trade = {
  id : trade_id;
  order_id : string;
  symbol : symbol;
  side : side;
  quantity : quantity;
  price : price;
  commission : float;
  timestamp : Time_ns_unix.t;
}
[@@deriving show, eq]

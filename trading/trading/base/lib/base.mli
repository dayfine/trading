(** Common trading data types and utilities *)

type symbol = string
(** Symbol represents a trading security *)

type price = float
(** Price represents the price of an security *)

type quantity = float
(** Quantity represents the number of shares/contracts *)

(** Side represents whether an order is to buy or sell *)
type side = Buy | Sell

(** Order type represents the type of order *)
type order_type =
  | Market
  | Limit of price
  | Stop of price
  | StopLimit of price * price

type position = { symbol : symbol; quantity : quantity; price : price }
(** Position represents a holding in an security *)

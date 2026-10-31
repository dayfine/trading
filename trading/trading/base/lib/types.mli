(** Common trading data types and utilities *)

type symbol = string [@@deriving show, eq, sexp]
(** Symbol represents a trading security *)

type price = float [@@deriving show, eq, sexp]
(** Price represents the price of an security *)

type quantity = float [@@deriving show, eq, sexp]
(** Quantity represents the number of shares/contracts *)

(** Position direction — long (buying a rising asset) or short (selling a
    declining asset). *)
type position_side = Long | Short [@@deriving show, eq, sexp]

(** Side represents whether an order is to buy or sell *)
type side = Buy | Sell [@@deriving show, eq, sexp]

(** Order type represents the type of order *)
type order_type =
  | Market
  | Limit of price
  | Stop of price
  | StopLimit of price * price
[@@deriving show, eq, sexp]

type trade_id = string [@@deriving show, eq, sexp]

module Utc_time : sig
  type t = Time_ns_unix.t [@@deriving show, eq, sexp]
  (** A [Time_ns_unix.t] whose sexp is the UTC alternate form, independent of
      the host's local zone (checkpoint-safe). *)
end

type trade = {
  id : trade_id;
  order_id : string;
  symbol : symbol;
  side : side;
  quantity : quantity;
  price : price;
  commission : float;
  timestamp : Utc_time.t;
}
[@@deriving show, eq, sexp]

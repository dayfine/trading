(** Common trading data types and utilities *)

open Core

type symbol = string [@@deriving show, eq, sexp]
(** Symbol represents a trading security *)

type price = float [@@deriving show, eq, sexp]
(** Price represents the price of an security *)

type quantity = float [@@deriving show, eq, sexp]
(** Quantity represents the number of shares/contracts *)

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

type position = { symbol : symbol; quantity : quantity; price : price }
[@@deriving show, eq, sexp]
(** Position represents a holding in an security *)

type trade_id = string [@@deriving show, eq, sexp]

(* Zone-independent timestamp: same type as [Time_ns_unix.t], but sexp goes
   through [Time_ns.Alternate_sexp] (UTC), so it needs no tzdata/local zone. *)
module Utc_time = struct
  type t = Time_ns_unix.t

  let pp = Time_ns_unix.pp
  let show t = Stdlib.Format.asprintf "%a" pp t
  let equal = Time_ns_unix.equal
  let sexp_of_t = Time_ns.Alternate_sexp.sexp_of_t
  let t_of_sexp = Time_ns.Alternate_sexp.t_of_sexp
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

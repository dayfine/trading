(** Asset classification per EODHD's [/api/exchange-symbol-list] [Type] field.
    Used downstream to drop mutual funds, ETFs, and other non-common-stock
    instruments from Weinstein universe-build (see
    [dev/plans/custom-universe-bidirectional-2026-05-17.md] §Q1). *)

type t =
  | Common_stock
  | Preferred_stock
  | ETF
  | Mutual_fund
  | Fund  (** Closed-end fund or other generic fund. *)
  | ADR
  | GDR
  | Bond
  | Index
  | Currency
  | Commodity
  | Other of string
      (** Catch-all for unrecognised values. The raw string is preserved so
          downstream filters can still discriminate without code changes. *)
[@@deriving show, eq]

val of_eodhd_string : string -> t
(** Parses the raw [Type] string from EODHD's response. Recognised values are
    listed in this module's source. Anything else returns [Other raw]. Empty or
    whitespace-only input also returns [Other ""]. *)

val to_string : t -> string
(** Round-trips through [of_eodhd_string] for recognised cases. *)

val is_equity_like : t -> bool
(** [true] for instruments that trade like a common stock: [Common_stock],
    [Preferred_stock], [ADR], [GDR]. [false] for everything else, including
    [Other _]. Useful default filter for Weinstein universe-build. *)

(** Exchange resolution for EODHD multi-market support.

    Symbols on EODHD are addressed as [TICKER.EXCHANGE] (for example, [AAPL.US],
    [BARC.LSE], [7203.TSE]). This module factors that suffix handling out of
    {!Http_client} so that callers can:

    - Parse a user-supplied symbol like ["BARC.LSE"] into a structured
      {!parsed_symbol} value.
    - Look up the ISO 4217 currency for a given exchange (used to tag universe
      entries; the [Daily_price.t] bar type itself is intentionally
      currency-free — see PR description).
    - Look up the calendar identifier for the exchange. Per-market holiday
      enumeration is intentionally deferred — calendar gaps surface naturally in
      fetched bars.
    - Render the canonical EODHD symbol string for a request URL. *)

type exchange =
  | US  (** NYSE / NASDAQ — currency USD *)
  | LSE  (** London Stock Exchange — currency GBP *)
  | TSE  (** Tokyo Stock Exchange — currency JPY *)
  | ASX  (** Australian Securities Exchange — currency AUD *)
  | HKEX  (** Hong Kong Exchanges and Clearing — currency HKD *)
  | TSX  (** Toronto Stock Exchange — currency CAD *)
[@@deriving show, eq]

type parsed_symbol = { ticker : string; exchange : exchange }
[@@deriving show, eq]
(** A symbol parsed into its ticker and exchange. For inputs without an explicit
    suffix (for example, ["AAPL"]), the resolver defaults to {!US}, preserving
    the prior single-market behaviour. *)

val parse : string -> parsed_symbol Status.status_or
(** [parse s] splits [s] at the final ['.'] and resolves the suffix to an
    {!exchange}. Recognised suffixes:

    - [.US] → [US] (also: bare ticker with no suffix)
    - [.LSE], [.L] → [LSE]
    - [.TSE], [.T] → [TSE]
    - [.AU], [.AX] → [ASX]
    - [.HK] → [HKEX]
    - [.TO], [.TSX] → [TSX]

    Suffix matching is case-insensitive. Returns [Error] for an unknown suffix
    or an empty ticker (for example, [""], [".US"]). *)

val to_eodhd_symbol : parsed_symbol -> string
(** Render a {!parsed_symbol} as the canonical EODHD-addressable string (for
    example, [{ ticker = "BARC"; exchange = LSE }] → ["BARC.LSE"]). The
    canonical suffix is the {!to_eodhd_code} value. *)

val to_eodhd_code : exchange -> string
(** The canonical EODHD exchange code as it appears in URLs: [US], [LSE], [TSE],
    [AU], [HK], [TO]. Used for both the per-symbol suffix and the
    [/api/exchange-symbol-list/{code}] endpoint. *)

val currency : exchange -> string
(** ISO 4217 currency code for the exchange's primary listing currency (USD,
    GBP, JPY, AUD, HKD, CAD). Tagging is at the universe / instrument-info
    layer; we deliberately do not add a currency field to {!Types.Daily_price.t}
    in this PR. *)

val calendar : exchange -> string
(** Short calendar identifier for the exchange (for example, ["NYSE"], ["LSE"],
    ["TSE"], ["ASX"], ["HKEX"], ["TSX"]). Returned as a string; full holiday
    enumeration is intentionally out of scope — fetched bars encode trading days
    for the markets we currently care about. *)

val all : exchange list
(** All exchanges this resolver knows about, in declaration order. Useful for
    tests and for building per-market reports. *)

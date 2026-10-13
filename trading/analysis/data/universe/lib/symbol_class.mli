(** Symbol-class detection for the composition policy (issue #3183).

    Some members of the top-N composition lists are not USD-priced common stock
    even though the vendor labels them ["Common Stock"] and every bar sits under
    the per-bar junk cap: foreign-currency series (HSBA in GBp, CELSIA in COP,
    SBER, ...), warrants ([C-WS-A], [AIG-WS]) and unit series ([LHC-UN]). Their
    raw price x volume is not dollars, so they rank above AMZN / AAPL. A warrant
    can also be a vendor duplicate of its parent's series ([AIG-WS] duplicates
    [AIG], giving the V6 twin-position defect).

    {1 What the metadata can and cannot tell us}

    The available inputs are [symbol_types.sexp] (asset type + listing exchange)
    and the inventory (symbol + date range). Neither carries a quote currency.
    The listing [exchange] is {b not} a usable signal: the symbol list was
    fetched from the US endpoint only, so HSBA, SBER and CELSIA all read [NYSE].
    Detection therefore uses two sources:

    - {b Suffix rules} (warrants, units): a dash-separated token [WS] or [UN] in
      any position after the first, so [AIG-WS], [C-WS-A], [BAC-WS-A], [LHC-UN]
      match while a bare ticker [UN] or [WS] does not.
    - {b Non-USD symbol set}: an explicit set of symbols, seeded from
      {!curated_non_usd} (the issue's specimens) and extensible by the caller.
      This is a curated list for the same reason {!Asset_type_blocklist.curated}
      is: the vendor field that would discriminate is absent from the data.

    [_old] synthetic series are deliberately {b not} a class: they are renamed
    predecessor tickers (251 in the pit-v12 lists), mostly legitimate USD names.
    A foreign-currency [_old] series is listed individually (CTRA_old).

    Pure: same input -> same output. *)

(** A class of instrument the composition policy can exclude. *)
type t =
  | Warrant  (** Dash-separated [WS] token: [AIG-WS], [C-WS-A]. *)
  | Unit
      (** Dash-separated [UN] token: [LHC-UN]. Mostly trust or foreign unit
          series in the pit-v12 lists, not only SPAC units. *)
  | Non_usd_listing  (** Member of the non-USD symbol set. *)
[@@deriving sexp, eq, show]

val curated_non_usd : string list
(** Seed non-USD symbols: HSBA, SBER, CELSIA, CTRA_old (issue #3183 specimens).
    Uppercase except the [_old] suffix; matching upper-cases both sides.

    The set is keyed on the symbol alone, so it only holds tickers that read as
    non-USD in {b every} vintage they appear in (checked against the pit-v12
    lists). A ticker reused across eras is excluded: [LDG] is Longs Drug Stores
    (US, 1998-2008) before it is the foreign-currency series (2016-2020), so
    adding it globally would drop a US stock from 11 vintages. Callers who want
    such a ticker for one vintage add it through [extra_non_usd]. *)

val classify : ?extra_non_usd:string list -> string -> t option
(** [classify ?extra_non_usd symbol] returns the class of [symbol] or [None] for
    an ordinary symbol. Case-insensitive. Precedence when several apply:
    [Warrant], then [Unit], then [Non_usd_listing]. [extra_non_usd] extends
    {!curated_non_usd}. *)

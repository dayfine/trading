(** Curated asset-type exclusion blocklist for universe construction.

    {1 Why this exists}

    EODHD's [/api/exchange-symbol-list] [Type] field mislabels a large class of
    non-equity instruments as ["Common Stock"] — bond closed-end funds (CEFs),
    equity CEFs, physical-bullion trusts, and SPAC shells. Because
    {!Eodhd.Asset_type.of_eodhd_string} therefore parses them as
    {!Eodhd.Asset_type.Common_stock}, the {!Build_eligible_universe} equity-like
    filter admits them: FTHY (a bond CEF) has surfaced as a top live pick, and
    PHYS / PSLV (bullion trusts) and dozens of bond / equity CEFs leak into the
    tradeable universe. None of these are Weinstein-stage-tradeable operating
    companies.

    This module is a second, {b symbol-level} exclusion layer that catches those
    mislabelled instruments by an explicit curated list, independent of the
    (wrong) vendor [Type]. A blocklisted symbol is dropped from the universe
    regardless of what EODHD calls it.

    {1 Sources of membership}

    A {!t} is a [symbol -> category] map. Three ways to populate one, all
    equivalent downstream:

    - {!curated} — the checked-in, hand-maintained seed. This is the source of
      record today; extend it in [asset_type_blocklist.ml] as new leaks are
      found.
    - {!load} — parse a sexp file of {!entry} values, for a larger externally
      maintained list without a code change.
    - {!of_entries} — build directly from an {!entry} list. This is the intended
      feed point for a future fundamentals enrichment: mapping EODHD's
      [General::Type] (e.g. ["CLOSED-END FUND"]) to a {!category} yields an
      {!entry} list that becomes a {!t} here, with no change to the exclusion
      logic. {!union} combines such a derived set with {!curated}.

    {1 Default is a no-op}

    {!empty} blocks nothing, so a universe build wired with {!empty} is
    bit-identical to one with no blocklist at all — per
    [.claude/rules/experiment-flag-discipline.md] R1, the filter is inert until
    a caller supplies a non-empty {!t}. Arming the live universe with {!curated}
    is a separate decision, not this module's default. *)

(** The kind of non-equity instrument a blocklisted symbol is. Kept distinct
    from {!Eodhd.Asset_type.t} on purpose: these are exactly the instruments the
    vendor {i mis}classifies, so the category records what the symbol truly is,
    not what EODHD labels it. *)
type category =
  | Bond_cef  (** Closed-end fund holding bonds / fixed income. *)
  | Equity_cef  (** Closed-end fund holding equities. *)
  | Bullion_trust  (** Physical precious-metal trust (gold / silver / PGM). *)
  | Spac
      (** Special-purpose acquisition company shell (pre-merger blank check). *)
[@@deriving sexp, eq, show]

type entry = { symbol : string; category : category }
[@@deriving sexp, eq, show]
(** One blocklist member: the ticker and why it is excluded. Symbol matching is
    case-insensitive (see {!find}); the stored form is uppercased. *)

type t [@@deriving sexp]
(** An immutable blocklist: a set of symbols, each tagged with its {!category}.
    Round-trips through sexp as a sorted {!entry} list, so a {!t} can be a
    [[@@deriving sexp]] config field. *)

val empty : t
(** The no-op blocklist: {!is_blocked} is [false] for every symbol. A build
    filtered with {!empty} is bit-identical to an unfiltered build. *)

val of_entries : entry list -> t
(** [of_entries entries] builds a blocklist from [entries]. Symbols are
    uppercased on insertion; on a duplicate symbol the last entry wins. This is
    the feed point for a fundamentals-derived blocklist (map [General::Type] to
    a {!category}, then call this). *)

val load : path:string -> t Status.status_or
(** [load ~path] parses a sexp file whose top-level form is an {!entry} list —
    e.g.
    [(((symbol FTHY) (category Bond_cef)) ((symbol PHYS) (category
     Bullion_trust)))]. Returns [Error Status.Internal] on read or decode
    failure. *)

val curated : t
(** The checked-in curated seed — the source of record for known mislabelled
    CEFs / bullion trusts. SPAC coverage is intentionally minimal here (SPAC
    tickers are ephemeral and better served by a heuristic / fundamentals feed);
    the {!Spac} category exists so such a feed can populate it via
    {!of_entries}. *)

val find : t -> symbol:string -> category option
(** [find t ~symbol] is the symbol's {!category} if blocklisted, else [None].
    Case-insensitive. *)

val is_blocked : t -> symbol:string -> bool
(** [is_blocked t ~symbol] is [true] iff [symbol] is in the blocklist.
    Case-insensitive; equivalent to [Option.is_some (find t ~symbol)]. *)

val union : t -> t -> t
(** [union a b] is the blocklist containing every symbol in either [a] or [b].
    On a symbol present in both, [b]'s category wins. Use to combine {!curated}
    with a derived (e.g. fundamentals) blocklist. *)

val entries : t -> entry list
(** [entries t] is the blocklist as an {!entry} list, sorted by symbol for
    determinism. *)

val size : t -> int
(** [size t] is the number of blocklisted symbols. *)

(** Ticker → issuer-group lookup for the one-share-class-per-issuer entry rule
    (issue #3015,
    {!Weinstein_strategy_config.config.max_one_share_class_per_issuer}).

    Some issuers list more than one live share class (GOOG / GOOGL, BRK-A /
    BRK-B, FOX / FOXA, ...). The classes track one business, so holding two of
    them at once is doubled exposure to one name — the post-run validator's V6
    twin-position invariant flags it. This module is the data half of the rule:
    which tickers belong to the same issuer. The rule itself lives in
    {!Share_class_gate}.

    {b Source of truth.} A committed data file,
    [trading/test_data/share_classes.sexp] ({!default_file_name} under the data
    directory), holding a list of groups, each a list of tickers:
    {v ((GOOG GOOGL) (BRK-A BRK-B) ...) v}
    There is no hardcoded list in any [.ml]. The same sexp shape is the
    {!t_of_sexp} / {!sexp_of_t} representation, so a strategy config carries the
    map verbatim. Symbols absent from every group are unmapped and are never
    affected by the rule.

    Each group is identified by its {b first} listed ticker; the id is only
    compared for equality, never shown to a decision. *)

type t
(** An immutable symbol → group-id lookup. *)

val empty : t
(** The map with no groups — every symbol is unmapped. *)

val is_empty : t -> bool
(** [true] iff the map holds no group. *)

val of_groups : string list list -> t
(** Build the lookup from a list of groups.

    Fails loudly ([Failure]) on a malformed group list rather than silently
    dropping entries: a group with fewer than two tickers (a one-class "group"
    is meaningless and almost certainly a typo), or a ticker listed in more than
    one group (its issuer would be ambiguous). An empty list is valid and yields
    {!empty}. *)

val groups : t -> string list list
(** The groups, in the order and member order they were given to {!of_groups}.
    [of_groups (groups t)] rebuilds [t]. *)

val group_of : t -> string -> string option
(** [group_of t symbol] is the id of [symbol]'s issuer group, or [None] when
    [symbol] is unmapped. Two symbols are share classes of one issuer iff both
    return the same [Some id]. *)

val t_of_sexp : Core.Sexp.t -> t
(** Parse [((A B) (C D E) ...)] via {!of_groups}; raises on the same malformed
    inputs. *)

val sexp_of_t : t -> Core.Sexp.t
(** Inverse of {!t_of_sexp}: [(groups t)] as a list of lists. *)

val default_file_name : string
(** ["share_classes.sexp"] — the committed map's file name, resolved against the
    data directory ([TRADING_DATA_DIR], which points at [trading/test_data/] in
    the container, CI and tests). *)

val load : string -> t
(** [load path] reads and parses the map file at [path]. Fails loudly ([Failure]
    naming [path]) when the file is missing, is not a single sexp of the
    expected shape, or is malformed per {!of_groups}. Never returns a
    silently-empty map for a bad file. *)

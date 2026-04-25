(** Bijection between symbol strings and integer row indices over a fixed
    universe.

    A [Symbol_index.t] pins a universe of [N] symbols to row indices [0..N-1].
    Used by [Ohlcv_panels] and indicator panels to map symbol names to rows of
    the [N x T] Bigarray panels.

    The universe is fixed at construction; new symbols cannot be added.
    Backtest-mode behaviour: the universe is decided up front from [sectors.csv]
    and a universe cap. Symbols that did not yet trade on a given day occupy NaN
    cells in the panel. Live-mode universe rebalance requires panel rebuild
    (deferred — Stage 5 of the columnar plan). *)

type t

val create : universe:string list -> (t, Status.t) Result.t
(** [create ~universe] constructs a symbol index from a list of symbols. The
    list order determines the row indices: [List.nth universe i] occupies row
    [i]. Returns [Error] if [universe] contains a duplicate symbol or any empty
    string. The empty universe is allowed (yields [n=0]). *)

val to_row : t -> string -> int option
(** [to_row t symbol] returns the row index for [symbol], or [None] if the
    symbol is not in the universe. O(1) average via Hashtbl. *)

val of_row : t -> int -> string
(** [of_row t i] returns the symbol at row [i]. Raises [Invalid_argument] if [i]
    is out of range. O(1). *)

val n : t -> int
(** [n t] returns the size of the universe. *)

val symbols : t -> string list
(** [symbols t] returns the universe as a list, in row-index order. Useful for
    snapshot serialization and for iterating panels. *)

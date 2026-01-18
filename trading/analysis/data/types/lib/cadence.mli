(** Time cadence for indicators and price aggregation *)

(** Time cadence for market data aggregation.

    - {b Daily}: Raw daily bars
    - {b Weekly}: Aggregated weekly bars (Mon-Fri)
    - {b Monthly}: Aggregated monthly bars *)
type t = Daily | Weekly | Monthly [@@deriving show, eq, hash, sexp, compare]

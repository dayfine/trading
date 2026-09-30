(** V6 (INV): twin positions — one issuer held twice at the same time.

    {b Where V6's twin set comes from.} Two sources, unioned; each pair is
    reported at most once:

    + {b Rename twins} (the original V6, no data file): two {e different}
      symbols in [trades.csv] with the exact same [(entry_date, exit_date)] pair
      whose entry price, exit price and quantity agree within a 5% relative
      tolerance. This is the shape a same-company ticker rename produces (NLS /
      BFX: one position booked under both tickers), and it needs no list of
      which symbols are related. One violation per [(entry, exit)] date group.
    + {b Share-class groups} (issue #3035): the committed issuer map
      [trading/test_data/share_classes.sexp]
      ({!Weinstein_strategy.Share_class_map}, the same file the #3015
      one-share-class-per-issuer entry rule reads), resolved exactly as the
      backtest runner resolves it:
      [data_dir / Share_class_map.default_file_name]. Two holdings of
      {e different} symbols in one issuer group, on the same side, whose holding
      intervals overlap (strictly: [a.entry < b.exit && b.entry < a.exit], so a
      same-day exit-and-rotate into the sibling class is not an overlap) are a
      violation — FWONA held with FWONK even though their dates and prices
      differ. Holdings are the [trades.csv] round trips plus the
      [open_positions.csv] rows, which are held past every date. A pair the
      rename-twin pass already flagged (both closed, same dates, twin prices) is
      not counted again, so GOOG/GOOGL booked as identical twins is one
      violation, not two. One violation per overlapping pair.

    When the share-class map could not be loaded (file missing or malformed), V6
    still runs the rename-twin pass and sets the result's [skip_reason] to name
    the unavailable source — the report renders it beside the verdict, so a run
    without the map never reads as a clean V6. *)

open Validator_types

val share_class_source_path : data_dir:string -> string
(** [data_dir / Share_class_map.default_file_name] — where {!load_share_classes}
    reads the map, and where the backtest runner reads it
    ({!Weinstein_strategy.resolve_share_class_map}). *)

val load_share_classes :
  data_dir:string -> (Weinstein_strategy.Share_class_map.t, string) result
(** Load the issuer map from {!share_class_source_path}. [Error reason] (never
    an exception) when the file is missing or malformed; [reason] carries
    {!Weinstein_strategy.Share_class_map.load}'s message, which names the path.
*)

val check_v6 : inputs -> Validator_step.finding
(** V6 over [inputs.trades], [inputs.open_positions] and [inputs.share_classes];
    see the module doc for both sources. *)

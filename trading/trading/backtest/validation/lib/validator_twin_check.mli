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
      one-share-class-per-issuer entry rule reads), located by
      {!resolve_share_class_path} — independently of the bar directory, since
      real runs keep bars and the map in different places (issue #3045). Two
      holdings of {e different} symbols in one issuer group, on the same side,
      whose holding intervals overlap (strictly:
      [a.entry < b.exit && b.entry < a.exit], so a same-day exit-and-rotate into
      the sibling class is not an overlap) are a violation — FWONA held with
      FWONK even though their dates and prices differ. Holdings are the
      [trades.csv] round trips plus the [open_positions.csv] rows, which are
      held past every date. A pair the rename-twin pass already flagged (both
      closed, same dates, twin prices) is not counted again, so GOOG/GOOGL
      booked as identical twins is one violation, not two. One violation per
      overlapping pair.

    When the share-class map could not be loaded (file missing or malformed), V6
    still runs the rename-twin pass and sets the result's [skip_reason] to name
    the unavailable source — the report renders it beside the verdict, so a run
    without the map never reads as a clean V6. When the map did load and
    [inputs.share_class_path] is known, [skip_reason] carries
    ["share-class map: <path>"] instead, so every report names the map it was
    checked against. *)

open Validator_types

val share_class_source_path : data_dir:string -> string
(** [data_dir / Share_class_map.default_file_name] — where the backtest runner
    reads the map under its data directory
    ({!Weinstein_strategy.resolve_share_class_map}). *)

val resolve_share_class_path :
  explicit:string option ->
  trading_data_dir:string option ->
  data_dir:string ->
  string
(** Where V6 reads the issuer map; first match wins:
    + [explicit] — the validator CLI's [-share-classes PATH];
    + {!share_class_source_path} of [trading_data_dir] when it is set and
      non-empty — the [TRADING_DATA_DIR] environment value, which is the data
      directory the backtest runner reads the map from
      ([Data_path.default_data_dir]);
    + {!share_class_source_path} of [data_dir] (the bar store) otherwise.

    Pure: the caller reads the environment. Issue #3045 — chain runs pass the
    bar store as [-data-dir] while the map lives under [trading/test_data], so
    resolving from [data_dir] alone left V6's share-class pass unavailable in
    every real run. *)

val load_share_classes :
  path:string -> (Weinstein_strategy.Share_class_map.t, string) result
(** Load the issuer map from [path] (normally {!resolve_share_class_path}).
    [Error reason] (never an exception) when the file is missing or malformed;
    [reason] carries {!Weinstein_strategy.Share_class_map.load}'s message, which
    names the path. *)

val check_v6 : inputs -> Validator_step.finding
(** V6 over [inputs.trades], [inputs.open_positions] and [inputs.share_classes];
    see the module doc for both sources. *)

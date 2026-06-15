(** Volume-only enrichment for committed composition goldens.

    The committed composition snapshots under
    [trading/test_data/goldens-custom-universe/composition/] were pinned before
    the {!Universe.Snapshot.entry} carried an [avg_dollar_volume] field, so
    their real (non-synthetic) entries serialize it as [None]. A full
    {!Build_composition_universes_runner} rebuild *would* populate the field but
    also re-ranks the universe from the current bar store, drifting composition
    (~2.9% of symbols on top-3000) and thereby re-pinning every backtest that
    reads these goldens.

    This module performs a **composition-preserving** add instead: it loads each
    golden, and for every non-synthetic entry recomputes [avg_dollar_volume] via
    {!Universe.Build_from_individuals.avg_dollar_volume_for_symbol} — the *same*
    trailing-window [avg (close * volume)] the builder used to rank — and writes
    the snapshot back with **only** that field injected. Symbol set, weights,
    sectors, order, synthetic flags, [date], [method_], [size], and
    [aggregate_period_return] are all preserved bit-for-bit, so no backtest
    result changes.

    The reconstitution [date] used to window the trailing volume is parsed from
    the golden's own [date] field (the [YYYY-05-31] reconstitution anchor),
    matching {!Build_composition_universes_runner_lib}'s [_reconstitution_date].
*)

open Core

type entry_result = {
  enriched : int;  (** Non-synthetic entries that got a [Some] volume. *)
  no_volume : int;
      (** Non-synthetic entries whose volume came back [None] (missing bars /
          too-short trailing window). Their [avg_dollar_volume] stays [None]. *)
  synthetic : int;  (** Synthetic entries, left untouched ([None]). *)
}
[@@deriving show, eq]
(** Per-file enrichment tally. *)

type file_result = { path : string; result : entry_result }
[@@deriving show, eq]
(** One golden file's path + its tally. *)

type result = {
  files : file_result list;
  composition_changed : int;
      (** Number of files where the post-enrichment symbol/weight/sector/order/
          synthetic projection differed from the input — MUST be 0 for a
          behavior-neutral enrichment. *)
}
[@@deriving show, eq]
(** Aggregate run result. [composition_changed > 0] indicates a bug: the
    enrichment changed something other than [avg_dollar_volume]. *)

val enrich_entry :
  date:Date.t ->
  config:Universe.Build_from_individuals.config ->
  Universe.Snapshot.entry ->
  Universe.Snapshot.entry
(** [enrich_entry ~date ~config entry] returns [entry] with its
    [avg_dollar_volume] recomputed when [entry] is non-synthetic, and unchanged
    when [entry.synthetic] is [true]. Every other field is copied verbatim. *)

val enrich_snapshot :
  config:Universe.Build_from_individuals.config ->
  Universe.Snapshot.t ->
  Universe.Snapshot.t * entry_result
(** [enrich_snapshot ~config snapshot] maps {!enrich_entry} over
    [snapshot.entries] using [snapshot.date] as the trailing-window anchor,
    returning the rewritten snapshot and the per-entry tally. All non-entry
    fields are preserved. *)

val composition_preserved : Universe.Snapshot.t -> Universe.Snapshot.t -> bool
(** [composition_preserved before after] is [true] iff the two snapshots agree
    on everything except per-entry [avg_dollar_volume]: same [date], [method_],
    [size], [aggregate_period_return], and the same entry list under the
    projection that drops [avg_dollar_volume] (symbol, weight, sector,
    synthetic, in order). The enrichment's behavior-neutrality invariant. *)

val run : goldens_dir:string -> bars_root:string -> result Status.status_or
(** [run ~goldens_dir ~bars_root] enriches every [*.sexp] under [goldens_dir] in
    place, recomputing volumes from per-symbol bars under [bars_root]. Each file
    is loaded, enriched, checked with {!composition_preserved} (a failure
    increments [composition_changed] and the file is *not* written), and on
    success written back via {!Universe.Snapshot.save}. Returns
    [Error Status.Internal] if [goldens_dir] cannot be listed, or the first
    load/save failure encountered. *)

(** Internal library for the [build_synthetic_universes_runner] executable.

    Owns the testable orchestration: parsing the canonical Shiller + French
    cache CSVs (the on-disk format written by the [fetch_shiller_history] and
    [fetch_french_history] binaries — {b not} the upstream-mirror format that
    the [_client.parse] functions consume), and the annual-reconstitution-date ×
    top-N synthesis loop that drives {!Universe.Build_from_index.build}.

    Split out from the executable so the loop's I/O semantics (one file per
    successful snapshot, skip + log on builder errors, summary at end) can be
    unit-tested without writing real CSVs to disk. *)

module SC = Shiller.Shiller_client
module KF = Kenneth_french.Kenneth_french_client

(** {1 Cache parsers}

    These parse the {b canonical cache CSV} format produced by the
    [fetch_shiller_history] / [fetch_french_history] binaries. The cache layout
    is intentionally narrower than the upstream mirrors:

    - Shiller cache header: [period,sp_price,dividend,earnings,cpi,long_rate] (6
      columns; the 4 redundant computed columns from the upstream mirror are
      dropped, and option fields are empty cells for [None]).
    - French cache header: [block,date,<industries...>] where [block] is [VW] or
      [EW]. We only consume the value-weighted block per the Build_from_index v1
      contract. *)

val parse_shiller_cache_csv :
  string -> SC.monthly_observation list Status.status_or
(** [parse_shiller_cache_csv body] parses the 6-column cache CSV body into the
    upstream {!Shiller.Shiller_client.monthly_observation} record. Empty cells
    in the four optional columns map to [None]. Returns [Error _] on header
    drift, empty body, unparseable date / float, or wrong column count. *)

val parse_french_cache_csv : string -> KF.daily_return list Status.status_or
(** [parse_french_cache_csv body] parses the value-weighted block of the cache
    CSV into a list of {!Kenneth_french.Kenneth_french_client.daily_return}.
    Skips [EW] rows. Returns [Error _] on header drift, empty body, or
    unparseable values. *)

(** {1 Runner} *)

type result = {
  written : int;  (** Number of snapshots successfully written. *)
  skipped : int;  (** Number of [(year, top_n)] pairs that produced an error. *)
  skip_reasons : (int * int * string) list;
      (** Reverse-chronological list of [(year, top_n, error_message)] for each
          skipped pair. *)
}
[@@deriving show, eq]
(** Summary returned by {!run}. *)

val run :
  shiller_obs:SC.monthly_observation list ->
  french_obs:KF.daily_return list ->
  out_dir:string ->
  start_year:int ->
  end_year:int ->
  top_ns:int list ->
  rng_seed:int ->
  result
(** [run ~shiller_obs ~french_obs ~out_dir ~start_year ~end_year ~top_ns
     ~rng_seed] iterates [(year, top_n)] for [year] in [[start_year..end_year]]
    and [top_n] in [top_ns]. For each pair: anchors at [(year, May, 31)], calls
    {!Universe.Build_from_index.build} with
    {!Universe.Build_from_index.default_config}, and on [Ok] saves the snapshot
    to [{out_dir}/top-{top_n}-{year}.sexp]. On [Error] the pair is recorded in
    the result's [skip_reasons] and the loop continues — never raises. *)

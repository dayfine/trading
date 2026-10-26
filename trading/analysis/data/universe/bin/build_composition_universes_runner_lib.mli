(** Internal library for the [build_composition_universes_runner] executable.

    Owns the testable orchestration: the anchor-date × top-N composition loop
    that drives {!Universe.Build_from_individuals.build}.

    Split out from the executable so the loop's I/O semantics (one file per
    successful snapshot, skip + log on builder errors, summary at end) can be
    unit-tested without writing 87 sexp files to disk. *)

open Core

(** Which anchor dates the runner builds a list at. *)
type schedule =
  | Yearly of { start_year : int; end_year : int }
      (** The default: May 31 of every year in [[start_year..end_year]], files
          named [top-{N}-{YYYY}.sexp]. Byte-identical to the pre-schedule
          runner. *)
  | Month_ends of { first : Date.t; last : Date.t }
      (** Every calendar month end [d] with [first <= d <= last] (arm SM,
          [dev/experiments/floor-nearest-2026-10-25/README.md] §"Arm SM"), files
          named [top-{N}-{YYYY-MM-DD}.sexp]. A May 31 anchor builds the same
          snapshot as {!Yearly} for that year: only the file name differs. *)
[@@deriving show, eq]

type result = {
  written : int;  (** Number of snapshots successfully written. *)
  skipped : int;  (** Number of [(date, top_n)] pairs that produced an error. *)
  skip_reasons : (Date.t * int * string) list;
      (** Reverse-chronological list of [(anchor_date, top_n, error_message)]
          for each skipped pair. *)
}
[@@deriving show, eq]
(** Summary returned by {!run}. *)

val month_ends : first:Date.t -> last:Date.t -> Date.t list
(** [month_ends ~first ~last] is every calendar month end (Jan 31, Feb 28 or 29,
    ...) [d] with [first <= d <= last], ascending. Empty when the range holds no
    month end (e.g. [2020-05-01 .. 2020-05-30]). *)

val anchor_dates : schedule -> Date.t list
(** [anchor_dates schedule] is the ascending list of dates the runner builds at:
    May 31 of each year for {!Yearly}, {!month_ends} for {!Month_ends}. *)

val snapshot_file_name : schedule:schedule -> top_n:int -> date:Date.t -> string
(** [snapshot_file_name ~schedule ~top_n ~date] is [top-{top_n}-{YYYY}.sexp]
    under {!Yearly} and [top-{top_n}-{YYYY-MM-DD}.sexp] under {!Month_ends}. *)

val run :
  dollar_volume:Universe.Dollar_volume_basis.config ->
  bars_root:string ->
  symbol_types_path:string ->
  sectors_csv_path:string ->
  inventory_path:string ->
  out_dir:string ->
  schedule:schedule ->
  top_ns:int list ->
  result
(** [run ~dollar_volume ~bars_root ~symbol_types_path ~sectors_csv_path
     ~inventory_path ~out_dir ~schedule ~top_ns] iterates [(date, top_n)] for
    [date] in {!anchor_dates} [schedule] and [top_n] in [top_ns]. For each pair:
    calls {!Universe.Build_from_individuals.build} at [date] with
    {!Universe.Build_from_individuals.default_config}, and on [Ok] saves the
    snapshot to [{out_dir}/]{!snapshot_file_name}. On [Error] the pair is
    recorded in the result's [skip_reasons] and the loop continues — never
    raises.

    [dollar_volume] sets the ranker's dollar-volume basis (issue #3136);
    {!Universe.Dollar_volume_basis.legacy_config} scores bit-identically to
    pre-#3136 (same order, products and fold); a rebuild on today's store and
    candidate set will not reproduce the committed lists. *)

val is_committed_dir : string -> bool
(** [is_committed_dir path] is true when [path], after resolving symlinks (when
    it exists) and collapsing [.] / [..] / trailing [/], ends in the components
    [goldens-custom-universe/composition] — the committed PIT lists. *)

val dollar_volume_of_flag :
  true_dollars:bool ->
  out_dir:string ->
  (Universe.Dollar_volume_basis.config, string) Result.t
(** Maps the [--true-dollar-volume] flag to a basis config. Without the flag:
    [Ok legacy_config] for any [out_dir]. With it: [Error _] when
    {!is_committed_dir} [out_dir] (the true basis must never overwrite the
    committed lists), else [Ok true_dollars_config]. *)

val schedule_of_flags :
  start_year:int ->
  end_year:int ->
  month_ends:string option ->
  (schedule, string) Result.t
(** Maps the CLI flags to a {!schedule}. [month_ends = None] (the default):
    [Ok (Yearly {start_year; end_year})]. [Some "FROM,TO"] with two [YYYY-MM-DD]
    dates and [FROM <= TO]: [Ok (Month_ends {first; last})], the year flags
    ignored. Anything else (one date, a bad date, [FROM > TO]): [Error _]. *)

(** Internal library for the [build_composition_universes_runner] executable.

    Owns the testable orchestration: the annual-reconstitution-date × top-N
    composition loop that drives {!Universe.Build_from_individuals.build}.

    Split out from the executable so the loop's I/O semantics (one file per
    successful snapshot, skip + log on builder errors, summary at end) can be
    unit-tested without writing 87 sexp files to disk. *)

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
  bars_root:string ->
  symbol_types_path:string ->
  sectors_csv_path:string ->
  inventory_path:string ->
  out_dir:string ->
  start_year:int ->
  end_year:int ->
  top_ns:int list ->
  result
(** [run ~bars_root ~symbol_types_path ~sectors_csv_path ~inventory_path
     ~out_dir ~start_year ~end_year ~top_ns] iterates [(year, top_n)] for [year]
    in [[start_year..end_year]] and [top_n] in [top_ns]. For each pair: anchors
    at [(year, May, 31)], calls {!Universe.Build_from_individuals.build} with
    {!Universe.Build_from_individuals.default_config}, and on [Ok] saves the
    snapshot to [{out_dir}/top-{top_n}-{year}.sexp]. On [Error] the pair is
    recorded in the result's [skip_reasons] and the loop continues — never
    raises. *)

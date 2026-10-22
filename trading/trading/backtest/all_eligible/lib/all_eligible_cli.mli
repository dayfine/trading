(** Command-line options and resolution for the all-eligible runner. *)

open Core

type cli_args = {
  scenario_path : string;  (** Path to the scenario sexp file. *)
  out_dir : string option;
      (** Output directory. When [None], defaults to
          [dev/all_eligible/<scenario.name>/<UTC-ISO-timestamp>/]. *)
  entry_dollars : float option;
      (** Override for [All_eligible.config.entry_dollars]. [None] keeps the
          library default. *)
  return_buckets : float list option;
      (** Override for [All_eligible.config.return_buckets]. [None] keeps the
          library default. *)
  min_grade : Weinstein_types.grade option;
      (** Override for [All_eligible.config.min_grade]. [None] keeps the library
          default ([C], matching the live cascade). Ignored when
          [grade_sweep = true]. *)
  grade_sweep : bool;
      (** When [true], iterate the grade ladder [F → D → C → B → A → A_plus] and
          emit one [grade-<G>/] subdir per cell plus a top-level [summary.md]
          with the cross-grade table. The single-grade flag [min_grade] is
          ignored in this mode. Default [false]. *)
  config_overrides : Sexp.t list;
      (** Additional sexp config-overrides to deep-merge over the scenario's own
          [config_overrides] field (themselves applied over the live screener
          default config). Currently a passthrough — the diagnostic uses the
          screener's default scoring weights / grade thresholds / candidate
          params, and these overrides are accepted on the CLI for
          forward-compatibility but not yet threaded into the scanner config.
          Documented as inert in the public surface so callers don't expect
          behavioural change. *)
  warehouse_dir : string option;
      (** When [Some dir], the bar-panel world is opened over the pre-built
          snapshot warehouse at [dir] (its [manifest.sexp]) instead of being
          built from CSV bars under [Data_path.default_data_dir ()]. Use for
          broad universes (e.g. top-3000) the CSV [data/] store doesn't hold.
          [None] keeps the build-from-CSV path. Set by [--snapshot-dir]. *)
}
(** Parsed CLI arguments. Exposed for unit testing the parser; the binary
    consumes this through {!All_eligible_runner.run_with_args}. *)

val parse_argv : string array -> cli_args
(** [parse_argv argv] parses the argv vector (including [argv.(0)], the program
    name) into a {!cli_args} record.

    Recognised flags:
    - [--scenario <path>] (required)
    - [--out-dir <path>] (optional)
    - [--entry-dollars <float>] (optional)
    - [--return-buckets <csv-floats>] (optional, e.g. [-0.5,0.0,0.5])
    - [--min-grade <F|D|C|B|A|A+>] (optional; default [C])
    - [--grade-sweep] (optional flag; runs the F→A+ sweep)
    - [--config-overrides <sexp-list>] (optional, parsed as a sexp list)

    Raises [Failure] on missing [--scenario] or malformed flag values (including
    an unrecognised [--min-grade] string). *)

val resolve_out_dir : scenario_name:string -> cli_args -> string
(** [resolve_out_dir ~scenario_name args] returns [args.out_dir] when set, else
    [dev/all_eligible/<scenario_name>/<UTC-ISO-timestamp>/]. The directory is
    not created here — the caller materialises it. *)

val resolve_config : cli_args -> All_eligible.config
(** [resolve_config args] starts from {!All_eligible.default_config} and applies
    [args.entry_dollars] / [args.return_buckets] / [args.min_grade] when
    present. The returned config is the {b base} config used for non-sweep runs
    and as the template for each sweep cell (the per-cell [config.min_grade] is
    overwritten in sweep mode). *)

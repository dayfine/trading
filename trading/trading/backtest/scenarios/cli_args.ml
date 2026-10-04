(* Command-line parsing for [scenario_runner]. Extracted from
   scenario_runner.ml (file_length cleanup). *)

open Core

let repo_root () =
  Data_path.default_data_dir () |> Fpath.parent |> Fpath.to_string

let _goldens_small_dir () =
  repo_root () ^ "trading/test_data/backtest_scenarios/goldens-small"

let _goldens_broad_dir () =
  repo_root () ^ "trading/test_data/backtest_scenarios/goldens-broad"

let _smoke_dir () = repo_root () ^ "trading/test_data/backtest_scenarios/smoke"

type t = {
  dir : string;
  parallel : int;
  fixtures_root : string option;
  snapshot_dir : string option;
      (* When [Some dir], every cell reads OHLCV from the snapshot warehouse at
         [dir] (streaming / snapshot mode) instead of building per-symbol bars
         in-process from CSVs. Resolved once at parse time via
         [Bar_source_resolver.resolve]; the resulting [Bar_data_source.t] is
         reused for every cell in the [--dir] run. [None] (the default) keeps
         the pre-existing CSV behaviour bit-identical. The load-bearing use is
         large-N goldens (e.g. N=3000) that OOM the dev container in CSV mode
         (~14 GB resident). *)
  progress_every : int;
      (* Friday-cycle cadence for [progress.sexp] emission, threaded into each
         scenario's [Backtest.Runner.run_backtest] call. Always populated:
         defaults to [Scenario_progress.default_every_n_fridays] (≈ monthly)
         when [--progress-every] is omitted, so the long-running multi-scenario
         exe gets recoverability by default. *)
  emit_all_eligible : bool;
      (* When [true] (the default), each scenario's child process invokes
         [Backtest_all_eligible.Scenario_post_step.emit] after writing
         actual.sexp, producing
         [<scenario_dir>/all_eligible/grade-C/{trades.csv,summary.md,config.sexp}].
         The [--no-emit-all-eligible] flag flips this off for perf sweeps /
         quick smoke pipelines that don't want to pay the diagnostic's scan +
         score cost. *)
  emit_candidates : bool;
      (* When [true], each scenario runs with
         [Backtest.Runner.run_backtest ?candidate_log] (a collector built by
         [Backtest.Candidate_log.create_if]) and its child
         writes [<scenario_dir>/candidates.sexp] (#2490). Default [false]: this
         one opts IN, because unlike the all-eligible diagnostic it costs
         strategy-side work on every screened Friday. *)
}

let _default_parallel = 4

let _usage () =
  eprintf
    "Usage: scenario_runner [--goldens-small | --goldens-broad | --goldens | \
     --smoke | --dir <path>] [--parallel N] [--fixtures-root <path>] \
     [--snapshot-dir <path>] [--progress-every N] [--no-emit-all-eligible] \
     [--emit-candidates]\n";
  Stdlib.exit 1

let _parse_progress_every n_str =
  match Int.of_string_opt n_str with
  | Some n when n >= 1 -> n
  | _ ->
      eprintf "--progress-every requires a positive integer argument\n";
      Stdlib.exit 1

(* Mutable accumulator for the parse. Using a record (rather than threading 7
   positionals through a recursive [loop]) keeps each flag case a one-line field
   update and stays well under the function-length limit as flags grow. *)
type _parse_acc = {
  mutable dir : string option;
  mutable parallel : int option;
  mutable fixtures_root : string option;
  mutable snapshot_dir : string option;
  mutable progress_every : int option;
  mutable emit_all_eligible : bool;
  mutable emit_candidates : bool;
}

let _finalize_acc (acc : _parse_acc) : t =
  {
    dir = Option.value acc.dir ~default:(_goldens_small_dir ());
    parallel = Option.value acc.parallel ~default:_default_parallel;
    fixtures_root = acc.fixtures_root;
    snapshot_dir = acc.snapshot_dir;
    progress_every =
      Option.value acc.progress_every
        ~default:Scenario_progress.default_every_n_fridays;
    emit_all_eligible = acc.emit_all_eligible;
    emit_candidates = acc.emit_candidates;
  }

let _parse_flag args =
  let acc =
    {
      dir = None;
      parallel = None;
      fixtures_root = None;
      snapshot_dir = None;
      progress_every = None;
      emit_all_eligible = true;
      emit_candidates = false;
    }
  in
  let rec loop args =
    match args with
    | [] -> _finalize_acc acc
    | "--goldens-small" :: rest | "--goldens" :: rest ->
        acc.dir <- Some (_goldens_small_dir ());
        loop rest
    | "--goldens-broad" :: rest ->
        acc.dir <- Some (_goldens_broad_dir ());
        loop rest
    | "--smoke" :: rest ->
        acc.dir <- Some (_smoke_dir ());
        loop rest
    | "--dir" :: path :: rest ->
        acc.dir <- Some path;
        loop rest
    | "--parallel" :: n :: rest ->
        acc.parallel <- Some (Int.of_string n);
        loop rest
    | "--fixtures-root" :: path :: rest ->
        acc.fixtures_root <- Some path;
        loop rest
    | "--snapshot-dir" :: path :: rest ->
        acc.snapshot_dir <- Some path;
        loop rest
    | [ "--snapshot-dir" ] ->
        eprintf "--snapshot-dir requires a directory-path argument\n";
        Stdlib.exit 1
    | "--progress-every" :: n :: rest ->
        acc.progress_every <- Some (_parse_progress_every n);
        loop rest
    | "--no-emit-all-eligible" :: rest ->
        acc.emit_all_eligible <- false;
        loop rest
    | "--emit-candidates" :: rest ->
        acc.emit_candidates <- true;
        loop rest
    | _ -> _usage ()
  in
  loop args

let parse_args () =
  let argv = Sys.get_argv () in
  _parse_flag (List.tl_exn (Array.to_list argv))

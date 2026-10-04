open Core

let claim_output_root ~base =
  match Core_unix.mkdir base with
  | () -> base
  | exception Core_unix.Unix_error (Core_unix.EEXIST, _, _) ->
      let path = sprintf "%s-%d" base (Pid.to_int (Core_unix.getpid ())) in
      Core_unix.mkdir_p path;
      path

let list_scenario_files dir =
  Stdlib.Sys.readdir dir |> Array.to_list
  |> List.filter ~f:(fun f -> String.is_suffix f ~suffix:".sexp")
  |> List.sort ~compare:String.compare
  |> List.map ~f:(fun f -> Filename.concat dir f)

let make_timestamped_root ~repo_root =
  let now = Core_unix.gettimeofday () in
  let tm = Core_unix.localtime now in
  let ts =
    sprintf "%04d-%02d-%02d-%02d%02d%02d" (tm.tm_year + 1900) (tm.tm_mon + 1)
      tm.tm_mday tm.tm_hour tm.tm_min tm.tm_sec
  in
  let base = repo_root ^ "dev/backtest/scenarios-" ^ ts in
  Core_unix.mkdir_p (Filename.dirname base);
  (* The timestamp has one-second granularity, so two runners started in the
     same second (e.g. dune running several scenario_runner-spawning tests in
     parallel) would share one root, and one's cleanup would delete the other's
     artefacts (flaky test_scenario_runner_wall_span). [mkdir] is atomic: the
     loser of the race takes a pid-suffixed sibling. *)
  claim_output_root ~base

let scenario_dir ~output_root (s : Scenario.t) =
  Filename.concat output_root s.name

let actual_path ~output_root (s : Scenario.t) =
  Filename.concat (scenario_dir ~output_root s) "actual.sexp"

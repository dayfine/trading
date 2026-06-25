(** All-eligible scenario post-step — see [scenario_post_step.mli] for the API
    contract. *)

open Core

(** Subdir leaf under [scenario_dir] where the all-eligible runner writes its
    per-cell artefacts. The runner itself is responsible for creating
    [grade-<G>/] cells inside this directory. *)
let _all_eligible_subdir = "all_eligible"

(** Build the [All_eligible_runner.cli_args] passed to
    [All_eligible_runner.run_with_args]. We pin
    [out_dir = Some <scenario_dir>/all_eligible] so the runner skips its default
    [dev/all_eligible/<name>/<UTC>/] timestamp path. All other knobs are left at
    library defaults so the per-scenario emission is reproducible across runs
    (the host scenario_runner doesn't accept all-eligible-specific tuning
    flags). *)
let _make_runner_args ~scenario_path ~all_eligible_dir ~warehouse_dir :
    All_eligible_runner.cli_args =
  {
    scenario_path;
    out_dir = Some all_eligible_dir;
    entry_dollars = None;
    return_buckets = None;
    min_grade = None;
    grade_sweep = false;
    config_overrides = [];
    warehouse_dir;
  }

let emit ~enabled ~scenario_path ~scenario_dir ~warehouse_dir =
  if not enabled then ()
  else
    let all_eligible_dir = Filename.concat scenario_dir _all_eligible_subdir in
    Core_unix.mkdir_p all_eligible_dir;
    let args =
      _make_runner_args ~scenario_path ~all_eligible_dir ~warehouse_dir
    in
    try All_eligible_runner.run_with_args args
    with e ->
      eprintf "all_eligible post-step: scenario:%s failed: %s\n%!" scenario_path
        (Exn.to_string e)

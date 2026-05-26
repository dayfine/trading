open Core
module Metric_types = Trading_simulation_types.Metric_types

type saved_iteration = {
  parameters : (string * float) list;
  metric : float;
  per_scenario_metrics : Metric_types.metric_set list;
}
[@@deriving sexp]

type t = {
  schema_version : int;
  spec : Bayesian_runner_spec.t;
  iterations : saved_iteration list;
}
[@@deriving sexp]

(** Pinned to match
    {!Tuner_bin.Bayesian_runner_runner._checkpoint_schema_version}. If that
    constant ever bumps, this one must follow — the reader is explicitly
    intolerant of a mismatch so a stale tool against a fresh checkpoint fails
    loud. *)
let current_schema_version = 1

let load path =
  if not (Sys_unix.file_exists_exn path) then
    failwithf "Bo_checkpoint_reader.load: file not found: %s" path ();
  let sexp =
    try Sexp.load_sexp path
    with exn ->
      failwithf "Bo_checkpoint_reader.load: failed to parse %s: %s" path
        (Exn.to_string exn) ()
  in
  let ck =
    try t_of_sexp sexp
    with exn ->
      failwithf
        "Bo_checkpoint_reader.load: %s does not match the bo_checkpoint shape: \
         %s"
        path (Exn.to_string exn) ()
  in
  if ck.schema_version <> current_schema_version then
    failwithf
      "Bo_checkpoint_reader.load: checkpoint at %s carries schema_version %d; \
       reader expects %d"
      path ck.schema_version current_schema_version ();
  ck

(** Reduce [iterations] to the (index, iteration) pair with the maximum
    [metric], breaking ties by lower index. Returns [None] for an empty input
    list. *)
let _argmax_with_index (xs : saved_iteration list) :
    (int * saved_iteration) option =
  List.foldi xs ~init:None ~f:(fun i acc it ->
      match acc with
      | None -> Some (i, it)
      | Some (_, best) ->
          if Float.(it.metric > best.metric) then Some (i, it) else acc)

let best_iteration (t : t) : saved_iteration option =
  Option.map (_argmax_with_index t.iterations) ~f:snd

let best_iteration_index (t : t) : int option =
  Option.map (_argmax_with_index t.iterations) ~f:fst

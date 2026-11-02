(** See [step_journal.mli]. *)

open Core
module Sim_types = Trading_simulation_types.Simulator_types

type step_result = Sim_types.step_result

let file_name = "steps.sexpl"
let _line_of_step s = Sexp.to_string (Sim_types.sexp_of_step_result s)

let append ~path steps =
  Out_channel.with_file path ~append:true ~f:(fun oc ->
      Out_channel.output_lines oc (List.map steps ~f:_line_of_step))

let _read_lines ~path =
  if Stdlib.Sys.file_exists path then Ok (In_channel.read_lines path)
  else Status.error_not_found (sprintf "step journal missing: %s" path)

(* The first [n] lines, or an error naming the shortfall. *)
let _first_lines ~path ~n =
  let open Result.Let_syntax in
  let%bind all = _read_lines ~path in
  let taken = List.take all n in
  if List.length taken = n then Ok taken
  else
    Status.error_invalid_argument
      (sprintf "step journal %s has %d lines, expected %d" path
         (List.length taken) n)

let _parse_line i line =
  try Ok (Sim_types.step_result_of_sexp (Sexp.of_string line))
  with e ->
    Status.error_invalid_argument
      (sprintf "step journal line %d does not parse: %s" (i + 1)
         (Exn.to_string e))

let read ~path ~n_steps =
  let open Result.Let_syntax in
  let%bind lines = _first_lines ~path ~n:n_steps in
  List.mapi lines ~f:_parse_line |> Result.all

let truncate ~path ~n_steps =
  let open Result.Let_syntax in
  let%map lines = _first_lines ~path ~n:n_steps in
  let tmp = path ^ ".tmp" in
  Out_channel.write_lines tmp lines;
  Stdlib.Sys.rename tmp path

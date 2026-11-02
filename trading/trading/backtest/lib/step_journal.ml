(** See [step_journal.mli]. *)

open Core

type step_result = Trading_simulation_types.Simulator_types.step_result

let file_name = "steps.sexpl"

let append ~path steps =
  Out_channel.with_file path ~append:true ~f:(fun oc ->
      List.iter steps ~f:(fun s ->
          Out_channel.output_string oc
            (Sexp.to_string
               (Trading_simulation_types.Simulator_types.sexp_of_step_result s));
          Out_channel.output_char oc '\n'))

(* The first [n] lines, or an error naming the shortfall. *)
let _first_lines ~path ~n =
  if not (Stdlib.Sys.file_exists path) then
    Status.error_not_found (sprintf "step journal missing: %s" path)
  else
    let taken =
      In_channel.with_file path ~f:(fun ic ->
          let rec go acc k =
            if k = n then List.rev acc
            else
              match In_channel.input_line ic with
              | Some l -> go (l :: acc) (k + 1)
              | None -> List.rev acc
          in
          go [] 0)
    in
    if List.length taken < n then
      Status.error_invalid_argument
        (sprintf "step journal %s has %d lines, expected %d" path
           (List.length taken) n)
    else Ok taken

let _parse_line i line =
  try
    Ok
      (Trading_simulation_types.Simulator_types.step_result_of_sexp
         (Sexp.of_string line))
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

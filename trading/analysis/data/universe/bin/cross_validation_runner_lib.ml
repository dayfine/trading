open Core
module CV = Universe.Cross_validation
module Synth_runner = Build_synthetic_universes_runner_lib

type result = {
  report : CV.report;
  out_sexp_path : string;
  out_markdown_path : string;
}
[@@deriving show]

let _write_markdown ~path body : unit Status.status_or =
  let tmp_path = path ^ ".tmp" in
  try
    Out_channel.write_all tmp_path ~data:body;
    Stdlib.Sys.rename tmp_path path;
    Ok ()
  with Sys_error msg | Failure msg ->
    (try Stdlib.Sys.remove tmp_path with _ -> ());
    Status.error_internal
      (Printf.sprintf "Cross_validation_runner_lib: markdown write failed: %s"
         msg)

let _mkdir_p_for path =
  let dir = Filename.dirname path in
  if String.is_empty dir || String.equal dir "." then ()
  else
    let cmd = Printf.sprintf "mkdir -p %s" (Filename.quote dir) in
    ignore (Stdlib.Sys.command cmd : int)

let run ~composition_dir ~shiller_cache_body ~size ~start_year ~end_year
    ~out_sexp_path ~out_markdown_path =
  let open Result.Let_syntax in
  let%bind shiller_obs =
    Synth_runner.parse_shiller_cache_csv shiller_cache_body
  in
  let%bind report =
    CV.compute ~composition_dir ~shiller_obs ~size ~start_year ~end_year
  in
  _mkdir_p_for out_sexp_path;
  _mkdir_p_for out_markdown_path;
  let%bind () = CV.save_sexp report ~path:out_sexp_path in
  let%bind () =
    _write_markdown ~path:out_markdown_path (CV.format_markdown report)
  in
  Ok { report; out_sexp_path; out_markdown_path }

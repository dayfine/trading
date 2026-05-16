open! Core
open Async

let curl_path = "curl"
let curl_max_time_seconds = 60
let _http_ok_status = 200

let _curl_args ~body_tempfile uri : string list =
  [
    "-sS";
    "--max-time";
    Int.to_string curl_max_time_seconds;
    "-o";
    body_tempfile;
    "-w";
    "%{http_code}";
    Uri.to_string uri;
  ]

let _read_and_remove path : string =
  let body =
    if Sys_unix.file_exists_exn path then In_channel.read_all path else ""
  in
  (try Sys_unix.remove path with _ -> ());
  body

let _classify_zero_exit ~uri ~body ~stdout : string Or_error.t =
  let code_str = String.strip stdout in
  match Int.of_string_opt code_str with
  | None ->
      Or_error.errorf "curl produced unparseable http_code %S for %s" code_str
        (Uri.to_string uri)
  | Some code when code = _http_ok_status -> Ok body
  | Some code ->
      Or_error.errorf "HTTP %d for %s\n%s" code (Uri.to_string uri) body

let _classify_output ~uri ~body (output : Process.Output.t) : string Or_error.t
    =
  match output.exit_status with
  | Ok () -> _classify_zero_exit ~uri ~body ~stdout:output.stdout
  | Error (`Exit_non_zero code) ->
      Or_error.errorf "curl exit %d for %s\nstderr: %s" code (Uri.to_string uri)
        (String.strip output.stderr)
  | Error (`Signal s) ->
      Or_error.errorf "curl killed by signal %s for %s" (Signal.to_string s)
        (Uri.to_string uri)

let fetch (uri : Uri.t) : string Or_error.t Deferred.t =
  let body_tempfile =
    Filename_unix.temp_file ~in_dir:Filename.temp_dir_name "shiller_body" ".csv"
  in
  let args = _curl_args ~body_tempfile uri in
  Process.create ~prog:curl_path ~args () >>= function
  | Error err ->
      let _ : string = _read_and_remove body_tempfile in
      return
        (Or_error.errorf "process exec failed for %s: %s" (Uri.to_string uri)
           (Error.to_string_hum err))
  | Ok proc ->
      Process.collect_output_and_wait proc >>| fun output ->
      let body = _read_and_remove body_tempfile in
      _classify_output ~uri ~body output

open! Core
open Async

let curl_path = "curl"
let curl_max_time_seconds = 60
let user_agent = "Mozilla/5.0 (compatible; trading-1/kenneth-french-ingest)"
let _http_ok_status = 200

let _curl_args ~dest_path uri : string list =
  [
    "-sS";
    "--max-time";
    Int.to_string curl_max_time_seconds;
    "-A";
    user_agent;
    "-o";
    dest_path;
    "-w";
    "%{http_code}";
    Uri.to_string uri;
  ]

let _remove_if_exists path =
  try if Sys_unix.file_exists_exn path then Sys_unix.remove path with _ -> ()

let _classify_zero_exit ~uri ~stdout : unit Or_error.t =
  let code_str = String.strip stdout in
  match Int.of_string_opt code_str with
  | None ->
      Or_error.errorf "curl produced unparseable http_code %S for %s" code_str
        (Uri.to_string uri)
  | Some code when code = _http_ok_status -> Ok ()
  | Some code -> Or_error.errorf "HTTP %d for %s" code (Uri.to_string uri)

let _classify_output ~uri (output : Process.Output.t) : unit Or_error.t =
  match output.exit_status with
  | Ok () -> _classify_zero_exit ~uri ~stdout:output.stdout
  | Error (`Exit_non_zero code) ->
      Or_error.errorf "curl exit %d for %s\nstderr: %s" code (Uri.to_string uri)
        (String.strip output.stderr)
  | Error (`Signal s) ->
      Or_error.errorf "curl killed by signal %s for %s" (Signal.to_string s)
        (Uri.to_string uri)

let fetch (uri : Uri.t) ~(dest_path : string) : unit Or_error.t Deferred.t =
  let args = _curl_args ~dest_path uri in
  Process.create ~prog:curl_path ~args () >>= function
  | Error err ->
      _remove_if_exists dest_path;
      return
        (Or_error.errorf "process exec failed for %s: %s" (Uri.to_string uri)
           (Error.to_string_hum err))
  | Ok proc ->
      Process.collect_output_and_wait proc >>| fun output ->
      let result = _classify_output ~uri output in
      (match result with Ok () -> () | Error _ -> _remove_if_exists dest_path);
      result

open Core

let serialize (t : Weekly_snapshot.t) : string =
  let sexp = Weekly_snapshot.sexp_of_t t in
  Sexp.to_string_hum sexp ^ "\n"

let path_for ~root ~system_version date =
  let date_str = Date.to_string date in
  Filename.concat (Filename.concat root system_version) (date_str ^ ".sexp")

let _mkdir_p_for_file path =
  let dir = Filename.dirname path in
  try
    Core_unix.mkdir_p dir;
    Ok ()
  with exn ->
    Error
      (Status.internal_error
         (Printf.sprintf "Failed to create directory %s: %s" dir
            (Exn.to_string exn)))

let _write_file path contents =
  try
    Out_channel.write_all path ~data:contents;
    Ok path
  with exn ->
    Error
      (Status.internal_error
         (Printf.sprintf "Failed to write %s: %s" path (Exn.to_string exn)))

let write_to_file ~root ~system_version (t : Weekly_snapshot.t) =
  if not (String.equal t.system_version system_version) then
    Error
      (Status.invalid_argument_error
         (Printf.sprintf
            "Snapshot system_version (%s) does not match write directory (%s)"
            t.system_version system_version))
  else
    let path = path_for ~root ~system_version t.date in
    let contents = serialize t in
    Result.bind (_mkdir_p_for_file path) ~f:(fun () ->
        _write_file path contents)

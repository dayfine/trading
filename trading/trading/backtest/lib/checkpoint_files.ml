(** See [checkpoint_files.mli]. *)

open Core

let remove_dir dir =
  if Sys_unix.file_exists_exn dir then (
    Array.iter (Sys_unix.readdir dir) ~f:(fun f ->
        Core_unix.unlink (Filename.concat dir f));
    Core_unix.rmdir dir)

let write_sexp ~dir name sexp =
  Out_channel.write_all (Filename.concat dir name)
    ~data:(Sexp.to_string_hum sexp ^ "\n")

let _read_sexp ~dir name =
  let path = Filename.concat dir name in
  if not (Sys_unix.file_exists_exn path) then
    Status.error_not_found (sprintf "checkpoint file missing: %s" path)
  else
    try Ok (Sexp.load_sexp path)
    with e ->
      Status.error_invalid_argument
        (sprintf "checkpoint file %s does not parse: %s" path (Exn.to_string e))

let read_as ~dir name of_sexp =
  let open Result.Let_syntax in
  let%bind sexp = _read_sexp ~dir name in
  try Ok (of_sexp sexp)
  with e ->
    Status.error_invalid_argument
      (sprintf "checkpoint file %s/%s is malformed: %s" dir name
         (Exn.to_string e))

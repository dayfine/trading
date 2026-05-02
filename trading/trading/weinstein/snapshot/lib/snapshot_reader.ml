open Core

let _check_schema_version (t : Weekly_snapshot.t) =
  let expected = Weekly_snapshot.current_schema_version in
  if t.schema_version = expected then Ok t
  else
    Error
      (Status.invalid_argument_error
         (Printf.sprintf "Snapshot schema_version mismatch: expected %d, got %d"
            expected t.schema_version))

let parse (s : string) : Weekly_snapshot.t Status.status_or =
  match
    try Ok (Sexp.of_string (String.strip s))
    with exn ->
      Error
        (Status.invalid_argument_error
           (Printf.sprintf "Invalid sexp: %s" (Exn.to_string exn)))
  with
  | Error _ as e -> e
  | Ok sexp -> (
      match
        try Ok (Weekly_snapshot.t_of_sexp sexp)
        with exn ->
          Error
            (Status.invalid_argument_error
               (Printf.sprintf "Snapshot schema mismatch: %s"
                  (Exn.to_string exn)))
      with
      | Error _ as e -> e
      | Ok t -> _check_schema_version t)

let read_from_file path =
  if not (Sys_unix.file_exists_exn path) then
    Error
      (Status.not_found_error
         (Printf.sprintf "Snapshot file not found: %s" path))
  else
    try
      let contents = In_channel.read_all path in
      parse contents
    with exn ->
      Error
        (Status.internal_error
           (Printf.sprintf "Failed to read %s: %s" path (Exn.to_string exn)))

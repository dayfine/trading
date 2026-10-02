open Core

let claim_output_root ~base =
  match Core_unix.mkdir base with
  | () -> base
  | exception Core_unix.Unix_error (Core_unix.EEXIST, _, _) ->
      let path = sprintf "%s-%d" base (Pid.to_int (Core_unix.getpid ())) in
      Core_unix.mkdir_p path;
      path

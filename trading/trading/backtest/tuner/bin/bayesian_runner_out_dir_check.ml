open Core

(** The single permitted parent for sweep output. Bind-mounted to the host in
    [.devcontainer/setup.sh]; sweep output written under any other path inflates
    the container's writable layer (i.e. [Docker.raw]) instead. *)
let _allowed_prefix = "/tmp/sweeps/"

(** Documented override. Sole accepted value is the string ["1"]; any other
    value (including unset) is treated as "not overridden" so accidental
    [BAYESIAN_RUNNER_ALLOW_NON_SWEEP_OUTPUT=0] does not silently disable the
    check. *)
let _override_env = "BAYESIAN_RUNNER_ALLOW_NON_SWEEP_OUTPUT"

let _override_enabled env_lookup =
  match env_lookup _override_env with Some "1" -> true | _ -> false

let validate ~out_dir ?(env_lookup = Sys.getenv) () =
  if String.is_prefix out_dir ~prefix:_allowed_prefix then Result.return ()
  else if _override_enabled env_lookup then Result.return ()
  else
    Status.error_invalid_argument
      (sprintf
         "Refusing --out-dir %S — sweep output must start with %S per \
          .claude/rules/sweep-hygiene.md (otherwise it inflates the \
          container's writable layer + Docker.raw on macOS hosts). Override at \
          your own risk: set %s=1."
         out_dir _allowed_prefix _override_env)

let validate_or_exit ~out_dir =
  match validate ~out_dir () with
  | Ok () -> ()
  | Error status ->
      eprintf "Error: %s\n%!" (Status.show status);
      Stdlib.exit 2

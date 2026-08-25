(** Linter entry point for the golden-vs-live config drift check (#2403).

    Prints one line per finding and exits 1 when any golden's drift from the
    live config is undeclared (or declared but no longer real). See
    {!Golden_live_drift_lib.Golden_live_drift} for the rule. *)

open Core

let _run ~overrides_path ~dirs =
  let live =
    Golden_live_drift_lib.Golden_live_drift.live_config ~overrides_path
  in
  let reports = Golden_live_drift_lib.Golden_live_drift.check_dirs ~live dirs in
  print_endline (Golden_live_drift_lib.Golden_live_drift.render_report reports);
  if Golden_live_drift_lib.Golden_live_drift.failure_count reports > 0 then
    Stdlib.exit 1

let command =
  Command.basic
    ~summary:
      "Fail when a golden scenario's effective Weinstein config deviates from \
       the live config without declaring it in deviates_from_live (#2403)."
    (let%map_open.Command overrides_path =
       flag "--live-overrides" (required string)
         ~doc:"PATH dev/weekly-picks/live-config-overrides.sexp"
     and dirs =
       flag "--dir" (listed string)
         ~doc:"DIR directory of golden scenario specs (repeatable)"
     in
     fun () ->
       if List.is_empty dirs then failwith "at least one --dir is required";
       _run ~overrides_path ~dirs)

let () = Command_unix.run command

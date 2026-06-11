(** CLI: apply the explicit universe-composition policy to one snapshot.

    Loads a {!Universe.Snapshot.t} and its [symbol_types.sexp] enrichment, runs
    {!Universe.Composition_policy.apply} with policy flags taken from CLI flags,
    writes the filtered snapshot and a per-filter drop report, and prints a
    summary. Every flag defaults to current behaviour, so a default invocation
    only collapses dual-class duplicates.

    Usage:
    {v
      dune exec analysis/data/universe/bin/apply_composition_policy.exe -- \
        --snapshot trading/test_data/goldens-custom-universe/composition/top-3000-2020.sexp \
        --symbol-types /workspaces/trading-1/data/symbol_types.sexp \
        --out-snapshot /tmp/top-3000-2020-policy.sexp \
        --out-report /tmp/top-3000-2020-policy.report.txt \
        --exclude-reits --exclude-preferred
    v} *)

open! Core
module CPT = Universe.Composition_policy_types

let _exit_with_error msg =
  Stdlib.Printf.fprintf Stdlib.stderr "apply_composition_policy: %s\n" msg;
  Stdlib.flush Stdlib.stderr;
  Stdlib.exit 1

let _config_of_flags ~exclude_reits ~exclude_preferred ~adr_min_dollar_volume =
  {
    CPT.default_config with
    reit_policy = (if exclude_reits then CPT.Exclude else CPT.Include);
    exclude_preferred;
    adr_min_dollar_volume;
  }

let _run ~snapshot_path ~symbol_types_path ~out_snapshot_path ~out_report_path
    ~config =
  match
    Apply_composition_policy_runner_lib.run ~snapshot_path ~symbol_types_path
      ~config ~out_snapshot_path ~out_report_path
  with
  | Error err -> _exit_with_error (Status.show err)
  | Ok result ->
      Stdlib.Printf.printf "apply_composition_policy: input=%d kept=%d\n"
        result.input_count result.kept_count;
      Stdlib.Printf.printf "%s\n" result.report_text

let command =
  Command.basic
    ~summary:
      "Apply the explicit universe-composition policy (dual-class dedup + REIT \
       / ADR / preferred flags) to one snapshot; write the filtered snapshot + \
       drop report."
    (let%map_open.Command snapshot_path =
       flag "--snapshot" (required string)
         ~doc:"PATH input snapshot .sexp (Composition_from_individuals)"
     and symbol_types_path =
       flag "--symbol-types" (required string)
         ~doc:"PATH symbol_types.sexp from asset_type_enrichment"
     and out_snapshot_path =
       flag "--out-snapshot" (required string)
         ~doc:"PATH filtered snapshot output .sexp"
     and out_report_path =
       flag "--out-report" (required string) ~doc:"PATH drop-report output .txt"
     and exclude_reits =
       flag "--exclude-reits" no_arg
         ~doc:" drop Real Estate sector members (default: keep)"
     and exclude_preferred =
       flag "--exclude-preferred" no_arg
         ~doc:" drop Preferred Stock members (default: keep)"
     and adr_min_dollar_volume =
       flag "--adr-min-dollar-volume" (optional float)
         ~doc:
           "FLOAT drop ADR/GDR members below this avg dollar volume (default: \
            keep all)"
     in
     fun () ->
       let config =
         _config_of_flags ~exclude_reits ~exclude_preferred
           ~adr_min_dollar_volume
       in
       _run ~snapshot_path ~symbol_types_path ~out_snapshot_path
         ~out_report_path ~config)

let () = Command_unix.run command

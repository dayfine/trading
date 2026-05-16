(** [manifest_rehash -data-dir DIR [-source S] [-endpoint-fmt F] [-dry-run]
     [-only-missing | -all]] walks the L1/L2-sharded data directory and
    populates manifest entries for every cached CSV that does not yet have one
    (the default mode). With [-all], rehashes every CSV including ones already
    represented in the manifest. With [-dry-run], counts what would be done but
    writes nothing.

    Closes the manifest-deployment gap left by Phase 2 (#1148): {!Csv_storage}
    now writes manifest entries on every new save, but the ~41,575 symbols
    already in the cache predate that integration and so have no entries. This
    CLI is the bulk-rehash tool to backfill them. *)

open Core

let _default_source = "EODHD"
let _default_endpoint_fmt = "/eod/%s"

type cli_args = {
  data_dir : string;
  source : string;
  endpoint_fmt : string;
  dry_run : bool;
  only_missing : bool;
}

let _usage () =
  prerr_endline
    "usage: manifest_rehash -data-dir DIR [-source S] [-endpoint-fmt F] \
     [-dry-run] [-only-missing | -all]";
  Stdlib.exit 2

let _next_arg argv i flag =
  let n = Array.length argv in
  incr i;
  if !i >= n then (
    prerr_endline ("manifest_rehash: missing value for " ^ flag);
    _usage ());
  argv.(!i)

let _parse_args argv =
  let data_dir = ref None in
  let source = ref _default_source in
  let endpoint_fmt = ref _default_endpoint_fmt in
  let dry_run = ref false in
  let only_missing = ref true in
  let i = ref 1 in
  let n = Array.length argv in
  while !i < n do
    (match argv.(!i) with
    | "-data-dir" -> data_dir := Some (_next_arg argv i "-data-dir")
    | "-source" -> source := _next_arg argv i "-source"
    | "-endpoint-fmt" -> endpoint_fmt := _next_arg argv i "-endpoint-fmt"
    | "-dry-run" -> dry_run := true
    | "-only-missing" -> only_missing := true
    | "-all" -> only_missing := false
    | "-h" | "-help" | "--help" -> _usage ()
    | s ->
        prerr_endline ("manifest_rehash: unknown flag " ^ s);
        _usage ());
    incr i
  done;
  match !data_dir with
  | None ->
      prerr_endline "manifest_rehash: -data-dir is required";
      _usage ()
  | Some d ->
      {
        data_dir = d;
        source = !source;
        endpoint_fmt = !endpoint_fmt;
        dry_run = !dry_run;
        only_missing = !only_missing;
      }

let () =
  let args = _parse_args (Sys.get_argv ()) in
  let _ : Manifest_rehash_lib.counters =
    Manifest_rehash_lib.run ~data_dir_str:args.data_dir ~source:args.source
      ~endpoint_fmt:args.endpoint_fmt ~dry_run:args.dry_run
      ~only_missing:args.only_missing
  in
  ()

(** Regenerate the README's two comment-delimited results blocks, idempotently:

    - the light-reference {b toplines} block (recomputed by running the
      reference strategies), and
    - the {b deep-headline} block (rendered from pinned records in
      [dev/backtest/deep_headline_records.sexp] — the heavy multi-decade runs
      that CI cannot regenerate).

    Usage:
    {[
      dune exec trading/backtest/readme_toplines/bin/readme_toplines.exe -- \
        --readme <path-to-README.md> [--check] [--data-dir <dir>] \
        [--deep-records <path>]
    ]}

    - [--readme PATH] (required): the Markdown file whose marker blocks are
      regenerated.
    - [--check]: do not write; print the rendered blocks and exit non-zero if
      they differ from what is already in the file (a CI-friendly drift check).
    - [--data-dir DIR]: override the CSV data store location (defaults to
      [Data_path.default_data_dir ()]).
    - [--deep-records PATH]: override the pinned deep-headline records sexp
      (defaults to [dev/backtest/deep_headline_records.sexp] relative to the
      README's directory). When the file is absent, the deep block is left
      untouched with a warning rather than failing. *)

open Core

type args = {
  readme : string option;
  check : bool;
  data_dir : string option;
  deep_records : string option;
}

let _empty_args =
  { readme = None; check = false; data_dir = None; deep_records = None }

let rec _parse acc = function
  | [] -> acc
  | "--readme" :: path :: rest -> _parse { acc with readme = Some path } rest
  | "--check" :: rest -> _parse { acc with check = true } rest
  | "--data-dir" :: dir :: rest -> _parse { acc with data_dir = Some dir } rest
  | "--deep-records" :: path :: rest ->
      _parse { acc with deep_records = Some path } rest
  | flag :: _ -> failwithf "unrecognised or incomplete flag: %s" flag ()

let _data_dir args =
  match args.data_dir with
  | Some dir -> Fpath.v dir
  | None -> Data_path.default_data_dir ()

let _default_deep_records ~readme =
  Filename.concat (Filename.dirname readme)
    "dev/backtest/deep_headline_records.sexp"

(* Read the on-disk file, returning "" when it does not yet exist. *)
let _read_document path =
  match Sys_unix.file_exists path with
  | `Yes -> In_channel.read_all path
  | `No | `Unknown -> ""

(* The light-reference block: run the reference strategies and render. *)
let _light_block args =
  let data_dir = _data_dir args in
  let report = Readme_toplines.Toplines_runner.run ~data_dir in
  let body = Readme_toplines.Toplines_runner.render_markdown report in
  Readme_toplines.Readme_block.render body

(* The deep-headline block from pinned records; [None] (skip, with a warning)
   when the records file is absent. *)
let _deep_block ~deep_records_path =
  match Readme_toplines.Deep_headline.load deep_records_path with
  | Some records -> Some (Readme_toplines.Deep_headline.render_block records)
  | None ->
      eprintf
        "toplines: WARNING deep-headline records not found at %s — leaving \
         deep block untouched\n"
        deep_records_path;
      None

(* Upsert both blocks into [document]. The deep block (when present) and the
   light block occupy disjoint marker regions, so order does not matter. *)
let _apply_blocks ~document ~light_block ~deep_block =
  let document =
    match deep_block with
    | None -> document
    | Some block ->
        Readme_toplines.Readme_block.upsert_between
          ~start_marker:Readme_toplines.Deep_headline.start_marker
          ~end_marker:Readme_toplines.Deep_headline.end_marker ~document ~block
  in
  Readme_toplines.Readme_block.upsert ~document ~block:light_block

let _check_mode ~readme ~light_block ~deep_block =
  let document = _read_document readme in
  let updated = _apply_blocks ~document ~light_block ~deep_block in
  if String.equal document updated then (
    print_endline "toplines: README blocks are up to date";
    exit 0)
  else (
    print_endline "toplines: README blocks are STALE — regenerate with:";
    print_endline
      "  dune exec trading/backtest/readme_toplines/bin/readme_toplines.exe -- \
       --readme README.md";
    exit 1)

let _write_mode ~readme ~light_block ~deep_block =
  let document = _read_document readme in
  let updated = _apply_blocks ~document ~light_block ~deep_block in
  Out_channel.write_all readme ~data:updated;
  printf "toplines: wrote %s\n" readme

let () =
  let args =
    _parse _empty_args (List.tl_exn (Array.to_list (Sys.get_argv ())))
  in
  let readme =
    match args.readme with
    | Some path -> path
    | None -> failwith "missing required flag: --readme <path>"
  in
  let deep_records_path =
    Option.value args.deep_records ~default:(_default_deep_records ~readme)
  in
  let light_block = _light_block args in
  let deep_block = _deep_block ~deep_records_path in
  if args.check then _check_mode ~readme ~light_block ~deep_block
  else _write_mode ~readme ~light_block ~deep_block

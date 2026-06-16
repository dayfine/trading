(** Compute the four README top-line numbers and write them into a
    comment-delimited block in the repo-root README, idempotently.

    Usage:
    {[
      dune exec trading/backtest/readme_toplines/bin/readme_toplines.exe -- \
        --readme <path-to-README.md> [--check] [--data-dir <dir>]
    ]}

    - [--readme PATH] (required): the Markdown file whose
      [<!-- toplines:start -->]..[<!-- toplines:end -->] block is regenerated.
    - [--check]: do not write; print the rendered block and exit non-zero if it
      differs from what is already in the file (a CI-friendly drift check).
    - [--data-dir DIR]: override the CSV data store location (defaults to
      [Data_path.default_data_dir ()] = [$TRADING_DATA_DIR] or the container
      path). *)

open Core

type args = { readme : string option; check : bool; data_dir : string option }

let _empty_args = { readme = None; check = false; data_dir = None }

let rec _parse acc = function
  | [] -> acc
  | "--readme" :: path :: rest -> _parse { acc with readme = Some path } rest
  | "--check" :: rest -> _parse { acc with check = true } rest
  | "--data-dir" :: dir :: rest -> _parse { acc with data_dir = Some dir } rest
  | flag :: _ -> failwithf "unrecognised or incomplete flag: %s" flag ()

let _data_dir args =
  match args.data_dir with
  | Some dir -> Fpath.v dir
  | None -> Data_path.default_data_dir ()

(* Read the on-disk file, returning "" when it does not yet exist. *)
let _read_document path =
  match Sys_unix.file_exists path with
  | `Yes -> In_channel.read_all path
  | `No | `Unknown -> ""

let _run_and_render args =
  let data_dir = _data_dir args in
  let report = Readme_toplines.Toplines_runner.run ~data_dir in
  let body = Readme_toplines.Toplines_runner.render_markdown report in
  Readme_toplines.Readme_block.render body

let _check_mode ~readme ~block =
  let document = _read_document readme in
  let updated = Readme_toplines.Readme_block.upsert ~document ~block in
  if String.equal document updated then (
    print_endline "toplines: README block is up to date";
    exit 0)
  else (
    print_endline "toplines: README block is STALE — regenerate with:";
    print_endline
      "  dune exec trading/backtest/readme_toplines/bin/readme_toplines.exe -- \
       --readme README.md";
    exit 1)

let _write_mode ~readme ~block =
  let document = _read_document readme in
  let updated = Readme_toplines.Readme_block.upsert ~document ~block in
  Out_channel.write_all readme ~data:updated;
  printf "toplines: wrote %s\n" readme;
  print_endline block

let () =
  let args =
    _parse _empty_args (List.tl_exn (Array.to_list (Sys.get_argv ())))
  in
  let readme =
    match args.readme with
    | Some path -> path
    | None -> failwith "missing required flag: --readme <path>"
  in
  let block = _run_and_render args in
  if args.check then _check_mode ~readme ~block else _write_mode ~readme ~block

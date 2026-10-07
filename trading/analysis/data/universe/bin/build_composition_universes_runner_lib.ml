open Core

type result = {
  written : int;
  skipped : int;
  skip_reasons : (int * int * string) list;
}
[@@deriving show, eq]

let _reconstitution_date ~year = Date.create_exn ~y:year ~m:Month.May ~d:31

let _snapshot_path ~out_dir ~top_n ~year =
  Filename.concat out_dir (Printf.sprintf "top-%d-%d.sexp" top_n year)

let _save_or_record_skip ~out_dir ~top_n ~year snapshot acc =
  let path = _snapshot_path ~out_dir ~top_n ~year in
  match Universe.Snapshot.save snapshot ~path with
  | Ok () -> { acc with written = acc.written + 1 }
  | Error err ->
      {
        acc with
        skipped = acc.skipped + 1;
        skip_reasons = (year, top_n, Status.show err) :: acc.skip_reasons;
      }

let _config_for ~dollar_volume ~bars_root ~symbol_types_path ~sectors_csv_path
    ~inventory_path ~size =
  {
    (Universe.Build_from_individuals.default_config ~size ~bars_root
       ~symbol_types_path ~sectors_csv_path ~inventory_path)
    with
    dollar_volume;
  }

let _step ~dollar_volume ~bars_root ~symbol_types_path ~sectors_csv_path
    ~inventory_path ~out_dir ~top_n ~year acc =
  let date = _reconstitution_date ~year in
  let config =
    _config_for ~dollar_volume ~bars_root ~symbol_types_path ~sectors_csv_path
      ~inventory_path ~size:top_n
  in
  match Universe.Build_from_individuals.build ~date ~config with
  | Ok snapshot -> _save_or_record_skip ~out_dir ~top_n ~year snapshot acc
  | Error err ->
      {
        acc with
        skipped = acc.skipped + 1;
        skip_reasons = (year, top_n, Status.show err) :: acc.skip_reasons;
      }

let _years_inclusive ~start_year ~end_year =
  List.init (end_year - start_year + 1) ~f:(fun i -> start_year + i)

let _mkdir_p path =
  let cmd = Printf.sprintf "mkdir -p %s" (Filename.quote path) in
  ignore (Stdlib.Sys.command cmd : int)

let run ~dollar_volume ~bars_root ~symbol_types_path ~sectors_csv_path
    ~inventory_path ~out_dir ~start_year ~end_year ~top_ns =
  _mkdir_p out_dir;
  let years = _years_inclusive ~start_year ~end_year in
  let initial = { written = 0; skipped = 0; skip_reasons = [] } in
  List.fold years ~init:initial ~f:(fun acc year ->
      List.fold top_ns ~init:acc ~f:(fun acc top_n ->
          _step ~dollar_volume ~bars_root ~symbol_types_path ~sectors_csv_path
            ~inventory_path ~out_dir ~top_n ~year acc))

let _committed_components = [ "goldens-custom-universe"; "composition" ]

(* Resolve symlinks when the path exists; otherwise fall back to the lexical
   absolute path. Either way "." and ".." components are then collapsed. *)
let _canonical_components out_dir =
  let abs =
    match Filename_unix.realpath out_dir with
    | p -> p
    | exception _ ->
        if Filename.is_absolute out_dir then out_dir
        else Filename.concat (Sys_unix.getcwd ()) out_dir
  in
  String.split abs ~on:'/'
  |> List.fold ~init:[] ~f:(fun acc c ->
      match c with
      | "" | "." -> acc
      | ".." -> ( match acc with _ :: rest -> rest | [] -> [])
      | c -> c :: acc)
  |> List.rev

let is_committed_dir out_dir =
  List.is_suffix
    (_canonical_components out_dir)
    ~suffix:_committed_components ~equal:String.equal

let dollar_volume_of_flag ~true_dollars ~out_dir =
  if not true_dollars then Ok Universe.Dollar_volume_basis.legacy_config
  else if is_committed_dir out_dir then
    Error
      "--true-dollar-volume writes new lists; pass an --out-dir other than the \
       committed composition directory"
  else Ok Universe.Dollar_volume_basis.true_dollars_config

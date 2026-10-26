open Core

type schedule =
  | Yearly of { start_year : int; end_year : int }
  | Month_ends of { first : Date.t; last : Date.t }
[@@deriving show, eq]

type result = {
  written : int;
  skipped : int;
  skip_reasons : (Date.t * int * string) list;
}
[@@deriving show, eq]

let _reconstitution_date ~year = Date.create_exn ~y:year ~m:Month.May ~d:31

let _month_end ~year ~month =
  Date.create_exn ~y:year ~m:month ~d:(Date.days_in_month ~year ~month)

(* Month ends of every month from [first]'s month to [last]'s month, kept only
   when they fall inside [[first, last]]. *)
let month_ends ~first ~last =
  let rec loop ~year ~month acc =
    let d = _month_end ~year ~month in
    if Date.( > ) d last then List.rev acc
    else
      let next_year, next_month =
        match month with
        | Month.Dec -> (year + 1, Month.Jan)
        | m -> (year, Month.shift m 1)
      in
      let acc = if Date.( >= ) d first then d :: acc else acc in
      loop ~year:next_year ~month:next_month acc
  in
  loop ~year:(Date.year first) ~month:(Date.month first) []

let anchor_dates = function
  | Yearly { start_year; end_year } ->
      List.init
        (end_year - start_year + 1)
        ~f:(fun i -> _reconstitution_date ~year:(start_year + i))
  | Month_ends { first; last } -> month_ends ~first ~last

let snapshot_file_name ~schedule ~top_n ~date =
  match schedule with
  | Yearly _ -> Printf.sprintf "top-%d-%d.sexp" top_n (Date.year date)
  | Month_ends _ -> Printf.sprintf "top-%d-%s.sexp" top_n (Date.to_string date)

let _record_skip ~date ~top_n err acc =
  {
    acc with
    skipped = acc.skipped + 1;
    skip_reasons = (date, top_n, Status.show err) :: acc.skip_reasons;
  }

let _save_or_record_skip ~out_dir ~schedule ~top_n ~date snapshot acc =
  let path =
    Filename.concat out_dir (snapshot_file_name ~schedule ~top_n ~date)
  in
  match Universe.Snapshot.save snapshot ~path with
  | Ok () -> { acc with written = acc.written + 1 }
  | Error err -> _record_skip ~date ~top_n err acc

type _inputs = {
  dollar_volume : Universe.Dollar_volume_basis.config;
  bars_root : string;
  symbol_types_path : string;
  sectors_csv_path : string;
  inventory_path : string;
}

let _config_for (i : _inputs) ~size =
  {
    (Universe.Build_from_individuals.default_config ~size ~bars_root:i.bars_root
       ~symbol_types_path:i.symbol_types_path
       ~sectors_csv_path:i.sectors_csv_path ~inventory_path:i.inventory_path)
    with
    dollar_volume = i.dollar_volume;
  }

let _step inputs ~out_dir ~schedule ~top_n ~date acc =
  let config = _config_for inputs ~size:top_n in
  match Universe.Build_from_individuals.build ~date ~config with
  | Ok snapshot ->
      _save_or_record_skip ~out_dir ~schedule ~top_n ~date snapshot acc
  | Error err -> _record_skip ~date ~top_n err acc

let _mkdir_p path =
  let cmd = Printf.sprintf "mkdir -p %s" (Filename.quote path) in
  ignore (Stdlib.Sys.command cmd : int)

let run ~dollar_volume ~bars_root ~symbol_types_path ~sectors_csv_path
    ~inventory_path ~out_dir ~schedule ~top_ns =
  _mkdir_p out_dir;
  let inputs =
    {
      dollar_volume;
      bars_root;
      symbol_types_path;
      sectors_csv_path;
      inventory_path;
    }
  in
  let initial = { written = 0; skipped = 0; skip_reasons = [] } in
  List.fold (anchor_dates schedule) ~init:initial ~f:(fun acc date ->
      List.fold top_ns ~init:acc ~f:(fun acc top_n ->
          _step inputs ~out_dir ~schedule ~top_n ~date acc))

(* Yearly keeps the pre-schedule "year=YYYY" skip label byte for byte. *)
let _skip_label ~schedule date =
  match schedule with
  | Yearly _ -> Printf.sprintf "year=%d" (Date.year date)
  | Month_ends _ -> Printf.sprintf "date=%s" (Date.to_string date)

let summary_lines ~schedule result =
  let header =
    Printf.sprintf "build_composition_universes_runner: written=%d skipped=%d"
      result.written result.skipped
  in
  let skips =
    List.rev_map result.skip_reasons ~f:(fun (date, top_n, reason) ->
        Printf.sprintf "  skip %s top_n=%d: %s"
          (_skip_label ~schedule date)
          top_n reason)
  in
  header :: skips

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

let schedule_of_flags ~start_year ~end_year ~month_ends =
  match month_ends with
  | None -> Ok (Yearly { start_year; end_year })
  | Some raw -> (
      match String.split raw ~on:',' |> List.map ~f:String.strip with
      | [ a; b ] -> (
          match (Date.of_string a, Date.of_string b) with
          | first, last when Date.( <= ) first last ->
              Ok (Month_ends { first; last })
          | _ -> Error (Printf.sprintf "--month-ends %S: FROM is after TO" raw)
          | exception _ ->
              Error (Printf.sprintf "--month-ends %S: bad YYYY-MM-DD date" raw))
      | _ -> Error (Printf.sprintf "--month-ends %S: expected FROM,TO" raw))

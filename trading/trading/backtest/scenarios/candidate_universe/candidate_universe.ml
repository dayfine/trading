open Core
module Universe_file = Scenario_lib.Universe_file

(* The macro index the macro gate reads, plus the sector ETFs the sector
   relative-strength scoring reads. Neither class is ever a candidate, so a
   capture-derived universe never contains them. *)
let required_context_symbols =
  [
    "GSPC";
    "SPY";
    "XLB";
    "XLC";
    "XLE";
    "XLF";
    "XLI";
    "XLK";
    "XLP";
    "XLRE";
    "XLU";
    "XLV";
    "XLY";
  ]

let _split_csv_line line = String.split line ~on:',' |> List.map ~f:String.strip

(* Locate the column by header name rather than by index: the all-eligible
   header has grown before (the resistance-quality column was appended), and a
   positional read would silently start reporting a different field. *)
let _symbol_column_index header_fields =
  match List.findi header_fields ~f:(fun _ f -> String.equal f "symbol") with
  | Some (i, _) -> i
  | None ->
      failwith
        "candidate_universe: all-eligible CSV header has no 'symbol' column — \
         input is not an all-eligible capture"

let symbols_of_all_eligible_csv ~contents =
  let lines =
    String.split_lines contents
    |> List.filter ~f:(fun l -> not (String.is_empty (String.strip l)))
  in
  match lines with
  | [] -> String.Set.empty
  | header :: rows ->
      let idx = _symbol_column_index (_split_csv_line header) in
      List.fold rows ~init:String.Set.empty ~f:(fun acc row ->
          let fields = _split_csv_line row in
          match List.nth fields idx with
          | Some s when not (String.is_empty s) -> Set.add acc s
          | _ -> acc)

(* Context symbols are opt-in: a universe file governs candidate membership, and
   the ETFs are tradeable, so adding them to a fixture derived from an
   equities-only universe changes the run rather than preserving it. *)
let _all_symbols ~include_context ~candidate_symbols =
  if include_context then
    List.fold required_context_symbols ~init:candidate_symbols ~f:Set.add
  else candidate_symbols

let build ?(include_context = false) ~candidate_symbols ~sector_of
    ~default_sector () =
  _all_symbols ~include_context ~candidate_symbols
  |> Set.to_list
  |> List.map ~f:(fun symbol ->
      let sector =
        match sector_of symbol with Some s -> s | None -> default_sector
      in
      { Universe_file.symbol; sector })

let sector_of_universe (u : Universe_file.t) =
  match u with
  | Universe_file.Full_sector_map -> fun _ -> None
  | Universe_file.Pinned entries ->
      let tbl = String.Table.create () in
      List.iter entries ~f:(fun e ->
          Hashtbl.set tbl ~key:e.Universe_file.symbol
            ~data:e.Universe_file.sector);
      fun s -> Hashtbl.find tbl s

let first_available lookups s =
  List.find_map lookups ~f:(fun lookup -> lookup s)

let unresolved_sectors ?(include_context = false) ~candidate_symbols ~sector_of
    () =
  _all_symbols ~include_context ~candidate_symbols
  |> Set.to_list
  |> List.filter ~f:(fun s -> Option.is_none (sector_of s))

let render ~entries ~provenance =
  let header =
    List.map provenance ~f:(fun line ->
        if String.is_empty line then ";;" else ";; " ^ line)
  in
  let sexp =
    Universe_file.sexp_of_t (Universe_file.Pinned entries) |> Sexp.to_string_hum
  in
  String.concat ~sep:"\n" (header @ [ ""; sexp; "" ])

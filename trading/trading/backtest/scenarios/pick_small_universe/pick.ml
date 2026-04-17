(** Selection script for the committed small-universe fixture.

    See [dev/scripts/pick_small_universe/README.md] for the why and the contract
    with [trading/test_data/backtest_scenarios/universes/small.sexp].

    This script is not run from CI or [dune runtest]. It produces the committed
    fixture; the fixture is the source of truth for tests. *)

open Core
module Universe_file = Scenario_lib.Universe_file

(* Window the stratified selection must cover (inclusive). Bars outside this
   window are ignored when checking data coverage. *)
let _default_start_date = Date.of_string "2018-01-01"
let _default_end_date = Date.of_string "2023-12-31"

(* Default per-sector cap for stratified sampling. 28 × 11 GICS sectors ≈ 308
   symbols total, matching the plan's ~300 target. *)
let _default_per_sector = 28

(* Minimum sector count — rejects inputs with <8 GICS sectors represented
   post-filter (typically means [sectors.csv] wasn't loaded correctly). *)
let _min_sectors_required = 8

(* Hand-maintained list of historical Weinstein cases. These are always
   included (when present in the inventory + sector map) regardless of
   stratified sampling, so the backtest retains known breakout coverage.
   See README.md §"Known historical cases". *)
let _known_cases =
  [
    "NVDA";
    "MSFT";
    "AAPL";
    "AMD";
    "AVGO";
    "CRM";
    "ORCL";
    "ADBE";
    "AMZN";
    "TSLA";
    "HD";
    "MCD";
    "NKE";
    "META";
    "GOOGL";
    "NFLX";
    "DIS";
    "T";
    "JPM";
    "V";
    "MA";
    "BAC";
    "WFC";
    "GS";
    "PYPL";
    "UNH";
    "JNJ";
    "LLY";
    "PFE";
    "ABBV";
    "TMO";
    "CAT";
    "BA";
    "DE";
    "UNP";
    "UPS";
    "HON";
    "WMT";
    "PG";
    "KO";
    "PEP";
    "COST";
    "XOM";
    "CVX";
    "COP";
    "OXY";
    "NEE";
    "DUK";
    "SO";
    "AEP";
    "AMT";
    "PLD";
    "EQIX";
    "SPG";
    "LIN";
    "APD";
    "SHW";
    "FCX";
  ]

type _candidate = {
  symbol : string;
  sector : string;
  data_start : Date.t;
  data_end : Date.t;
}

(* Filtering *)

let _covers_window (c : _candidate) ~start_date ~end_date =
  Date.( <= ) c.data_start start_date && Date.( >= ) c.data_end end_date

let _has_sector ~sector_map symbol =
  match Hashtbl.find sector_map symbol with
  | Some s when String.length s > 0 -> Some s
  | _ -> None

let _join_inventory_with_sectors ~inventory ~sector_map =
  List.filter_map inventory ~f:(fun (e : Inventory.entry) ->
      match _has_sector ~sector_map e.symbol with
      | None -> None
      | Some sector ->
          Some
            {
              symbol = e.symbol;
              sector;
              data_start = e.data_start_date;
              data_end = e.data_end_date;
            })

(* Stratified sampling *)

let _sort_symbols_alpha candidates =
  List.sort candidates ~compare:(fun a b -> String.compare a.symbol b.symbol)

let _take_per_sector candidates ~per_sector =
  let by_sector =
    List.fold candidates ~init:String.Map.empty ~f:(fun acc c ->
        Map.add_multi acc ~key:c.sector ~data:c)
  in
  Map.fold by_sector ~init:[] ~f:(fun ~key:_ ~data:cs acc ->
      let top = List.take (_sort_symbols_alpha cs) per_sector in
      top @ acc)

let _union_with_known_cases selected ~all_candidates =
  let by_symbol =
    List.fold all_candidates ~init:String.Map.empty ~f:(fun acc c ->
        Map.set acc ~key:c.symbol ~data:c)
  in
  let known =
    List.filter_map _known_cases ~f:(fun sym -> Map.find by_symbol sym)
  in
  let all = selected @ known in
  List.dedup_and_sort all ~compare:(fun a b -> String.compare a.symbol b.symbol)

let _to_pinned_entries candidates =
  List.map candidates ~f:(fun c ->
      { Universe_file.symbol = c.symbol; sector = c.sector })

(* Output *)

let _output_path =
  (* Fixture lives with the scenario files, not under data/. Path is
     relative to the workspace root; caller [cd]s there. *)
  "trading/test_data/backtest_scenarios/universes/small.sexp"

let _write_universe path entries =
  let sexp = Universe_file.sexp_of_t (Universe_file.Pinned entries) in
  Sexp.save_hum path sexp;
  printf "Wrote %d symbols to %s\n" (List.length entries) path

(* CLI *)

let _env_or default key =
  match Sys.getenv key with
  | Some v when String.length v > 0 -> v
  | _ -> default

let _parse_date_env key default =
  try Date.of_string (_env_or (Date.to_string default) key)
  with _ ->
    eprintf "Warning: invalid date in %s; using default %s\n" key
      (Date.to_string default);
    default

let _parse_int_env key default =
  try Int.of_string (_env_or (Int.to_string default) key)
  with _ ->
    eprintf "Warning: invalid int in %s; using default %d\n" key default;
    default

let main () =
  let data_dir = Data_path.default_data_dir () in
  let start_date =
    _parse_date_env "SMALL_UNIVERSE_START_DATE" _default_start_date
  in
  let end_date = _parse_date_env "SMALL_UNIVERSE_END_DATE" _default_end_date in
  let per_sector =
    _parse_int_env "SMALL_UNIVERSE_PER_SECTOR" _default_per_sector
  in
  printf "Data dir: %s\n" (Fpath.to_string data_dir);
  printf "Coverage window: %s → %s\n"
    (Date.to_string start_date)
    (Date.to_string end_date);
  printf "Per-sector cap: %d\n" per_sector;
  let inventory =
    match Inventory.load ~data_dir with
    | Ok inv -> inv.symbols
    | Error e ->
        eprintf "Failed to load inventory: %s\n" (Status.show e);
        Stdlib.exit 1
  in
  let sector_map = Sector_map.load ~data_dir in
  printf "Inventory: %d symbols, sector map: %d symbols\n"
    (List.length inventory)
    (Hashtbl.length sector_map);
  let candidates = _join_inventory_with_sectors ~inventory ~sector_map in
  let covered =
    List.filter candidates ~f:(_covers_window ~start_date ~end_date)
  in
  printf "After coverage filter: %d candidates\n" (List.length covered);
  let stratified = _take_per_sector covered ~per_sector in
  let final = _union_with_known_cases stratified ~all_candidates:covered in
  let sector_count =
    List.map final ~f:(fun c -> c.sector)
    |> List.dedup_and_sort ~compare:String.compare
    |> List.length
  in
  if sector_count < _min_sectors_required then (
    eprintf "Only %d distinct sectors after filtering; aborting\n" sector_count;
    Stdlib.exit 1);
  let entries = _to_pinned_entries (_sort_symbols_alpha final) in
  _write_universe _output_path entries

let () = main ()

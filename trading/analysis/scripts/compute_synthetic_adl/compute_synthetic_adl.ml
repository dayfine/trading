(** Compute synthetic NYSE advance/decline data from the stock universe.

    Reads daily close prices for all stocks in [data/sectors.csv], computes
    per-day advance and decline counts, writes synthetic breadth CSVs, and
    validates against existing golden breadth data.

    Usage:
    {v
      compute_synthetic_adl.exe                       # use default data dir
      compute_synthetic_adl.exe -data-dir /my/data    # custom dir
    v} *)

open Core
open Synthetic_adl

(* ---------- constants ---------- *)

let _min_stocks = 100

(* ---------- path helpers ---------- *)

(** [_symbol_data_path ~data_dir symbol] returns the path to a symbol's
    [data.csv]: [data_dir / first_char / last_char / symbol / data.csv]. *)
let _symbol_data_path ~data_dir symbol =
  let first = String.make 1 (Char.uppercase (String.get symbol 0)) in
  let last =
    String.make 1
      (Char.uppercase (String.get symbol (String.length symbol - 1)))
  in
  Fpath.(data_dir / first / last / symbol / "data.csv") |> Fpath.to_string

(* ---------- file I/O ---------- *)

(** Load symbols from [sectors.csv]. Returns a list of tickers. *)
let _load_symbols ~data_dir =
  let path = Fpath.(data_dir / "sectors.csv") |> Fpath.to_string in
  let lines = In_channel.read_lines path in
  match lines with [] -> [] | _header :: rows -> parse_symbols rows

(** Load close prices from a stock's [data.csv]. Returns [(date, close)] pairs
    sorted by date ascending. Skips rows with unparseable close prices. *)
let _load_close_prices path =
  let lines = try In_channel.read_lines path with Sys_error _ -> [] in
  match lines with [] -> [] | _header :: rows -> parse_close_prices rows

(** Parse a single golden breadth CSV line into [(date, count)] if valid. *)
let _parse_golden_breadth_line line =
  let line = String.rstrip ~drop:(Char.equal '\r') line in
  match String.lsplit2 line ~on:',' with
  | Some (date_str, count_str) -> (
      let date_str = String.strip date_str in
      let count_str = String.strip count_str in
      match Int.of_string_opt count_str with
      | Some count when count > 0 -> Some (date_str, count)
      | _ -> None)
  | None -> None

(** Load golden breadth CSV. Format: [YYYYMMDD, count] (no header). Returns a
    map of YYYYMMDD -> count, skipping zero-count entries. *)
let _load_golden_breadth path =
  let lines = try In_channel.read_lines path with Sys_error _ -> [] in
  List.filter_map lines ~f:_parse_golden_breadth_line
  |> List.fold ~init:String.Map.empty ~f:(fun acc (date_str, count) ->
      Map.set acc ~key:date_str ~data:count)

(** Write breadth CSV in existing format: [YYYYMMDD, count] (no header). *)
let _write_breadth_csv path pairs =
  Out_channel.with_file path ~f:(fun oc ->
      List.iter pairs ~f:(fun pair ->
          Out_channel.fprintf oc "%s\n" (format_breadth_row pair)))

(* ---------- main: loading ---------- *)

(** Try loading prices for a single symbol. Returns [Some prices] on success,
    [None] if the file is missing or has no valid rows. *)
let _try_load_symbol_prices ~data_dir symbol =
  let path = _symbol_data_path ~data_dir symbol in
  match Sys_unix.file_exists path with
  | `Yes ->
      let prices = _load_close_prices path in
      if List.is_empty prices then None else Some prices
  | `No | `Unknown -> None

(** Load all symbol prices, returning [(prices_list, missing_count)]. *)
let _load_all_prices ~data_dir symbols =
  List.fold symbols ~init:([], 0) ~f:(fun (prices_acc, miss) symbol ->
      match _try_load_symbol_prices ~data_dir symbol with
      | Some prices -> (prices :: prices_acc, miss)
      | None -> (prices_acc, miss + 1))

(** Print date range summary for computed daily data. *)
let _print_daily_summary daily avg_stocks =
  printf "Trading days with >= %d stocks: %d (avg %.0f stocks/day)\n%!"
    _min_stocks (List.length daily) avg_stocks;
  if List.is_empty daily then (
    eprintf "Error: no dates with sufficient data\n%!";
    exit 1);
  let first_date = fst (List.hd_exn daily) in
  let last_date = fst (List.last_exn daily) in
  printf "Date range: %s to %s\n%!" first_date last_date

(* ---------- main: output ---------- *)

(** Write advance and decline CSVs, returning the breadth directory path. *)
let _write_output_csvs ~data_dir daily =
  let breadth_dir = Fpath.(data_dir / "breadth") |> Fpath.to_string in
  Core_unix.mkdir_p breadth_dir;
  let advn_path = breadth_dir ^ "/synthetic_advn.csv" in
  let decln_path = breadth_dir ^ "/synthetic_decln.csv" in
  let advn_pairs = List.map daily ~f:(fun (d, c) -> (d, c.advances)) in
  let decln_pairs = List.map daily ~f:(fun (d, c) -> (d, c.declines)) in
  _write_breadth_csv advn_path advn_pairs;
  _write_breadth_csv decln_path decln_pairs;
  printf "\nWrote %s (%d rows)\n%!" advn_path (List.length advn_pairs);
  printf "Wrote %s (%d rows)\n%!" decln_path (List.length decln_pairs);
  breadth_dir

(* ---------- main: validation ---------- *)

(** Print validation stats for one component (advances or declines). *)
let _print_validation_stats ~label overlap_dates corr mae =
  let n = List.length overlap_dates in
  printf "\n  %s:\n%!" label;
  printf "    Overlapping dates: %d\n%!" n;
  printf "    Date range: %s - %s\n%!"
    (List.hd_exn overlap_dates)
    (List.last_exn overlap_dates);
  printf "    Pearson correlation: %.4f\n%!" corr;
  printf "    Mean absolute error: %.1f\n%!" mae

(** Compare synthetic data against golden data for overlapping dates. Prints
    stats and returns [(correlation, mae, overlap_count)]. *)
let _validate_against_golden ~label synthetic golden =
  let overlap_dates =
    Map.fold synthetic ~init:[] ~f:(fun ~key:date ~data:_ acc ->
        if Map.mem golden date then date :: acc else acc)
    |> List.sort ~compare:String.compare
  in
  if List.is_empty overlap_dates then (
    printf "  No overlapping dates for %s\n%!" label;
    (0.0, 0.0, 0))
  else
    let syn_vals =
      List.map overlap_dates ~f:(fun d ->
          Float.of_int (Map.find_exn synthetic d))
    in
    let gold_vals =
      List.map overlap_dates ~f:(fun d -> Float.of_int (Map.find_exn golden d))
    in
    let corr = pearson_correlation syn_vals gold_vals in
    let mae = mean_absolute_error syn_vals gold_vals in
    _print_validation_stats ~label overlap_dates corr mae;
    (corr, mae, List.length overlap_dates)

(** Build synthetic lookup maps keyed by YYYYMMDD. *)
let _build_synthetic_maps daily =
  let syn_advn =
    List.fold daily ~init:String.Map.empty ~f:(fun acc (d, c) ->
        Map.set acc ~key:(format_date_yyyymmdd d) ~data:c.advances)
  in
  let syn_decln =
    List.fold daily ~init:String.Map.empty ~f:(fun acc (d, c) ->
        Map.set acc ~key:(format_date_yyyymmdd d) ~data:c.declines)
  in
  (syn_advn, syn_decln)

(** Compute net breadth correlation and print results. *)
let _validate_net_breadth syn_advn syn_decln golden_advn golden_decln =
  let overlap_dates =
    Map.keys syn_advn
    |> List.filter ~f:(fun date ->
        Map.mem golden_advn date && Map.mem syn_decln date
        && Map.mem golden_decln date)
    |> List.sort ~compare:String.compare
  in
  if List.is_empty overlap_dates then 0.0
  else
    let syn_net =
      List.map overlap_dates ~f:(fun d ->
          Float.of_int (Map.find_exn syn_advn d - Map.find_exn syn_decln d))
    in
    let gold_net =
      List.map overlap_dates ~f:(fun d ->
          Float.of_int (Map.find_exn golden_advn d - Map.find_exn golden_decln d))
    in
    let corr = pearson_correlation syn_net gold_net in
    let mae = mean_absolute_error syn_net gold_net in
    printf "\n  Net breadth (advances - declines):\n%!";
    printf "    Pearson correlation: %.4f\n%!" corr;
    printf "    Mean absolute error: %.1f\n%!" mae;
    corr

(** Run validation against golden NYSE breadth data. *)
let _run_validation ~breadth_dir daily =
  let golden_advn_path = breadth_dir ^ "/nyse_advn.csv" in
  let golden_decln_path = breadth_dir ^ "/nyse_decln.csv" in
  match Sys_unix.file_exists golden_advn_path with
  | `No | `Unknown ->
      printf "\nSkipping validation: %s not found\n%!" golden_advn_path
  | `Yes ->
      printf "\n--- Validation against golden NYSE breadth data ---\n%!";
      let golden_advn = _load_golden_breadth golden_advn_path in
      let golden_decln = _load_golden_breadth golden_decln_path in
      let syn_advn, syn_decln = _build_synthetic_maps daily in
      let corr_a, _mae_a, n_a =
        _validate_against_golden ~label:"Advances" syn_advn golden_advn
      in
      let corr_d, _mae_d, n_d =
        _validate_against_golden ~label:"Declines" syn_decln golden_decln
      in
      let net_corr =
        _validate_net_breadth syn_advn syn_decln golden_advn golden_decln
      in
      printf "\n--- Summary ---\n%!";
      printf "Advance correlation:    %.4f (n=%d)\n%!" corr_a n_a;
      printf "Decline correlation:    %.4f (n=%d)\n%!" corr_d n_d;
      if Float.( <> ) net_corr 0.0 then
        printf "Net breadth correlation: %.4f\n%!" net_corr;
      printf "\n%!"

(* ---------- main ---------- *)

let main ~data_dir_str () =
  let data_dir = Fpath.v data_dir_str in
  let symbols = _load_symbols ~data_dir in
  printf "Universe: %d symbols from sectors.csv\n%!" (List.length symbols);
  printf "Loading daily close prices...\n%!";
  let all_prices, missing = _load_all_prices ~data_dir symbols in
  let loaded = List.length all_prices in
  printf "Loaded prices for %d symbols (%d missing data files)\n%!" loaded
    missing;
  printf "Computing daily advance/decline counts...\n%!";
  let daily = compute_daily_changes ~min_stocks:_min_stocks all_prices in
  let avg_stocks =
    if List.is_empty daily then 0.0
    else
      Float.of_int
        (List.fold daily ~init:0 ~f:(fun acc (_, c) -> acc + c.total))
      /. Float.of_int (List.length daily)
  in
  _print_daily_summary daily avg_stocks;
  let breadth_dir = _write_output_csvs ~data_dir daily in
  _run_validation ~breadth_dir daily

let command =
  Command.basic ~summary:"Compute synthetic advance/decline data from universe"
    (let%map_open.Command data_dir =
       flag "data-dir"
         (optional_with_default
            (Data_path.default_data_dir () |> Fpath.to_string)
            string)
         ~doc:"PATH Data directory (default: from Data_path)"
     in
     fun () -> main ~data_dir_str:data_dir ())

let () = Command_unix.run command

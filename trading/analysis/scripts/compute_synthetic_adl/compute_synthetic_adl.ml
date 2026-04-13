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

(* ---------- formatting helpers ---------- *)

let _format_date_yyyymmdd date = Date.to_string_iso8601_basic date

let _format_breadth_row (date, count) =
  Printf.sprintf "%s, %d" (_format_date_yyyymmdd date) count

(* ---------- file I/O ---------- *)

(** Load symbols from [sectors.csv] via [Sector_map]. Returns a list of tickers.
*)
let _load_symbols ~data_dir = Sector_map.load ~data_dir |> Hashtbl.keys

(** Load close prices for a symbol using [Csv_storage]. Returns [(date, close)]
    pairs sorted by date ascending. *)
let _load_close_prices ~data_dir symbol =
  match Csv.Csv_storage.create ~data_dir symbol with
  | Error _ -> []
  | Ok storage -> (
      match Csv.Csv_storage.get storage () with
      | Error _ -> []
      | Ok prices ->
          List.map prices ~f:(fun (p : Types.Daily_price.t) ->
              (p.date, p.close_price)))

(** Parse a single golden breadth CSV line into [(date, count)] if valid. Golden
    files use YYYYMMDD format without dashes. *)
let _parse_golden_breadth_line line =
  let line = String.rstrip ~drop:(Char.equal '\r') line in
  match String.lsplit2 line ~on:',' with
  | Some (date_str, count_str) -> (
      let date_str = String.strip date_str in
      let count_str = String.strip count_str in
      match Int.of_string_opt count_str with
      | Some count when count > 0 ->
          let iso_date =
            if String.length date_str = 8 then
              String.concat
                [
                  String.prefix date_str 4;
                  "-";
                  String.sub date_str ~pos:4 ~len:2;
                  "-";
                  String.sub date_str ~pos:6 ~len:2;
                ]
            else date_str
          in
          let date_opt = Option.try_with (fun () -> Date.of_string iso_date) in
          Option.map date_opt ~f:(fun date -> (date, count))
      | _ -> None)
  | None -> None

(** Load golden breadth CSV. Format: [YYYYMMDD, count] (no header). Returns a
    map of date -> count, skipping zero-count entries. *)
let _load_golden_breadth path =
  let lines = try In_channel.read_lines path with Sys_error _ -> [] in
  List.filter_map lines ~f:_parse_golden_breadth_line
  |> List.fold ~init:Date.Map.empty ~f:(fun acc (date, count) ->
      Map.set acc ~key:date ~data:count)

(** Write breadth CSV in existing format: [YYYYMMDD, count] (no header). *)
let _write_breadth_csv path pairs =
  Out_channel.with_file path ~f:(fun oc ->
      List.iter pairs ~f:(fun pair ->
          Out_channel.fprintf oc "%s\n" (_format_breadth_row pair)))

(* ---------- main: loading ---------- *)

(** Try loading prices for a single symbol. Returns [Some prices] on success,
    [None] if the file is missing or has no valid rows. *)
let _try_load_symbol_prices ~data_dir symbol =
  let prices = _load_close_prices ~data_dir symbol in
  if List.is_empty prices then None else Some prices

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
  printf "Date range: %s to %s\n%!"
    (Date.to_string first_date)
    (Date.to_string last_date)

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
let _print_validation_stats ~label (r : validation_result) =
  printf "\n  %s:\n%!" label;
  printf "    Overlapping dates: %d\n%!" r.overlap_count;
  printf "    Pearson correlation: %.4f\n%!" r.correlation;
  printf "    Mean absolute error: %.1f\n%!" r.mae

(** Build synthetic lookup maps keyed by date. *)
let _build_synthetic_maps daily =
  let syn_advn =
    List.fold daily ~init:Date.Map.empty ~f:(fun acc (d, c) ->
        Map.set acc ~key:d ~data:c.advances)
  in
  let syn_decln =
    List.fold daily ~init:Date.Map.empty ~f:(fun acc (d, c) ->
        Map.set acc ~key:d ~data:c.declines)
  in
  (syn_advn, syn_decln)

(** Build net breadth maps (advances - declines) for overlapping dates. *)
let _build_net_maps syn_advn syn_decln golden_advn golden_decln =
  let dates =
    Map.keys syn_advn
    |> List.filter ~f:(fun date ->
        Map.mem golden_advn date && Map.mem syn_decln date
        && Map.mem golden_decln date)
  in
  let syn_net =
    List.fold dates ~init:Date.Map.empty ~f:(fun acc d ->
        Map.set acc ~key:d
          ~data:(Map.find_exn syn_advn d - Map.find_exn syn_decln d))
  in
  let gold_net =
    List.fold dates ~init:Date.Map.empty ~f:(fun acc d ->
        Map.set acc ~key:d
          ~data:(Map.find_exn golden_advn d - Map.find_exn golden_decln d))
  in
  (syn_net, gold_net)

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
      let r_a =
        validate_against_golden ~synthetic:syn_advn ~golden:golden_advn
      in
      _print_validation_stats ~label:"Advances" r_a;
      let r_d =
        validate_against_golden ~synthetic:syn_decln ~golden:golden_decln
      in
      _print_validation_stats ~label:"Declines" r_d;
      let syn_net, gold_net =
        _build_net_maps syn_advn syn_decln golden_advn golden_decln
      in
      let r_net = validate_against_golden ~synthetic:syn_net ~golden:gold_net in
      if r_net.overlap_count > 0 then (
        printf "\n  Net breadth (advances - declines):\n%!";
        printf "    Pearson correlation: %.4f\n%!" r_net.correlation;
        printf "    Mean absolute error: %.1f\n%!" r_net.mae);
      printf "\n--- Summary ---\n%!";
      printf "Advance correlation:    %.4f (n=%d)\n%!" r_a.correlation
        r_a.overlap_count;
      printf "Decline correlation:    %.4f (n=%d)\n%!" r_d.correlation
        r_d.overlap_count;
      if r_net.overlap_count > 0 then
        printf "Net breadth correlation: %.4f\n%!" r_net.correlation;
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

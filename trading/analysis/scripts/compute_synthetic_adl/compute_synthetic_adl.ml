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

(* ---------- path helpers ---------- *)

(** [symbol_data_path ~data_dir symbol] returns the path to a symbol's
    [data.csv]: [data_dir / first_char / last_char / symbol / data.csv]. *)
let _symbol_data_path ~data_dir symbol =
  let first = String.make 1 (Char.uppercase (String.get symbol 0)) in
  let last =
    String.make 1
      (Char.uppercase (String.get symbol (String.length symbol - 1)))
  in
  Fpath.(data_dir / first / last / symbol / "data.csv") |> Fpath.to_string

(* ---------- CSV I/O ---------- *)

(** Parse a single line from [sectors.csv] into a symbol, if valid. *)
let _parse_symbol_line line =
  match String.lsplit2 line ~on:',' with
  | Some (sym, _) ->
      let sym = String.strip sym in
      if String.is_empty sym then None else Some sym
  | None -> None

(** Load symbols from [sectors.csv]. Returns a list of tickers. *)
let _load_symbols ~data_dir =
  let path = Fpath.(data_dir / "sectors.csv") |> Fpath.to_string in
  let lines = In_channel.read_lines path in
  match lines with
  | [] -> []
  | _header :: rows -> List.filter_map rows ~f:_parse_symbol_line

(** Parse a single CSV row into [(date, close)] if the close price is valid. *)
let _parse_price_row line =
  let fields = String.split line ~on:',' in
  match fields with
  | date :: _open :: _high :: _low :: close :: _ -> (
      let date = String.strip date in
      let close_str = String.strip close in
      match Float.of_string_opt close_str with
      | Some c -> Some (date, c)
      | None -> None)
  | _ -> None

(** Load close prices from a stock's [data.csv]. Returns [(date_string, close)]
    pairs sorted by date ascending. Skips rows with unparseable close prices. *)
let _load_close_prices path =
  let lines = try In_channel.read_lines path with Sys_error _ -> [] in
  match lines with
  | [] -> []
  | _header :: rows ->
      List.filter_map rows ~f:_parse_price_row
      |> List.sort ~compare:(fun (d1, _) (d2, _) -> String.compare d1 d2)

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

(** Format a [YYYY-MM-DD] date string to [YYYYMMDD]. *)
let _format_date_yyyymmdd date_str =
  String.filter date_str ~f:(fun c -> not (Char.equal c '-'))

(** Write breadth CSV in existing format: [YYYYMMDD, count] (no header). *)
let _write_breadth_csv path pairs =
  Out_channel.with_file path ~f:(fun oc ->
      List.iter pairs ~f:(fun (date_str, count) ->
          Out_channel.fprintf oc "%s, %d\n"
            (_format_date_yyyymmdd date_str)
            count))

(* ---------- advance/decline computation ---------- *)

type daily_counts = { advances : int; declines : int; total : int }
(** Per-date aggregated breadth counts. *)

(** Record a price change direction for a given date into the accumulator. *)
let _record_direction tbl date direction =
  let adv, dec, tot =
    Hashtbl.find_or_add tbl date ~default:(fun () -> (0, 0, 0))
  in
  match direction with
  | `Advance -> Hashtbl.set tbl ~key:date ~data:(adv + 1, dec, tot + 1)
  | `Decline -> Hashtbl.set tbl ~key:date ~data:(adv, dec + 1, tot + 1)
  | `Unchanged -> Hashtbl.set tbl ~key:date ~data:(adv, dec, tot + 1)

(** Classify a price change and record it. *)
let _accumulate_direction tbl date ~prev_close ~close =
  if Float.( > ) close prev_close then _record_direction tbl date `Advance
  else if Float.( < ) close prev_close then _record_direction tbl date `Decline
  else _record_direction tbl date `Unchanged

(** Accumulate price changes for a single symbol's price series. *)
let _accumulate_symbol_changes tbl prices =
  if List.length prices >= 2 then
    let (_ : float option) =
      List.fold prices ~init:None ~f:(fun prev (date, close) ->
          Option.iter prev ~f:(fun prev_close ->
              _accumulate_direction tbl date ~prev_close ~close);
          Some close)
    in
    ()

(** Compute per-date advance/decline counts from all loaded prices.

    For each symbol with at least 2 price points, compare each day's close to
    the previous day's close. A date is included only when at least [min_stocks]
    symbols report data for it. *)
let _compute_daily_changes ~min_stocks all_prices =
  let tbl = Hashtbl.create (module String) in
  List.iter all_prices ~f:(_accumulate_symbol_changes tbl);
  Hashtbl.fold tbl ~init:[] ~f:(fun ~key:date ~data:(adv, dec, tot) acc ->
      if tot >= min_stocks then
        (date, { advances = adv; declines = dec; total = tot }) :: acc
      else acc)
  |> List.sort ~compare:(fun (d1, _) (d2, _) -> String.compare d1 d2)

(* ---------- statistics ---------- *)

let _mean xs =
  let n = List.length xs in
  if n = 0 then 0.0
  else List.fold xs ~init:0.0 ~f:(fun acc x -> acc +. x) /. Float.of_int n

(** Compute variance components for Pearson correlation. *)
let _pearson_components xs ys ~mx ~my =
  List.fold2_exn xs ys ~init:(0.0, 0.0, 0.0) ~f:(fun (cov, var_x, var_y) x y ->
      let dx = x -. mx in
      let dy = y -. my in
      (cov +. (dx *. dy), var_x +. (dx *. dx), var_y +. (dy *. dy)))

(** Pearson correlation coefficient between two float lists. *)
let _pearson_correlation xs ys =
  if List.is_empty xs then 0.0
  else
    let mx = _mean xs in
    let my = _mean ys in
    let cov, var_x, var_y = _pearson_components xs ys ~mx ~my in
    let denom = Float.sqrt (var_x *. var_y) in
    if Float.( = ) denom 0.0 then 0.0 else cov /. denom

(** Mean absolute error between two float lists. *)
let _mean_absolute_error xs ys =
  let n = List.length xs in
  if n = 0 then 0.0
  else
    List.fold2_exn xs ys ~init:0.0 ~f:(fun acc x y -> acc +. Float.abs (x -. y))
    /. Float.of_int n

(* ---------- validation ---------- *)

(** Print validation stats for one component (advances or declines). *)
let _print_validation_stats ~label overlap_dates syn_vals gold_vals corr mae =
  let n = List.length overlap_dates in
  printf "\n  %s:\n%!" label;
  printf "    Overlapping dates: %d\n%!" n;
  printf "    Date range: %s - %s\n%!"
    (List.hd_exn overlap_dates)
    (List.last_exn overlap_dates);
  printf "    Synthetic mean: %.1f\n%!" (_mean syn_vals);
  printf "    Golden mean:    %.1f\n%!" (_mean gold_vals);
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
    let corr = _pearson_correlation syn_vals gold_vals in
    let mae = _mean_absolute_error syn_vals gold_vals in
    _print_validation_stats ~label overlap_dates syn_vals gold_vals corr mae;
    (corr, mae, List.length overlap_dates)

(* ---------- main: loading ---------- *)

let _min_stocks = 100

(** Load all symbol prices, returning [(prices_list, missing_count)]. *)
let _load_all_prices ~data_dir symbols =
  List.fold symbols ~init:([], 0) ~f:(fun (prices_acc, miss) symbol ->
      let path = _symbol_data_path ~data_dir symbol in
      match Sys_unix.file_exists path with
      | `Yes ->
          let prices = _load_close_prices path in
          if List.is_empty prices then (prices_acc, miss + 1)
          else (prices :: prices_acc, miss)
      | `No | `Unknown -> (prices_acc, miss + 1))

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

(** Write advance and decline CSVs, returning the paths. *)
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

(** Build synthetic lookup maps keyed by YYYYMMDD. *)
let _build_synthetic_maps daily =
  let syn_advn =
    List.fold daily ~init:String.Map.empty ~f:(fun acc (d, c) ->
        Map.set acc ~key:(_format_date_yyyymmdd d) ~data:c.advances)
  in
  let syn_decln =
    List.fold daily ~init:String.Map.empty ~f:(fun acc (d, c) ->
        Map.set acc ~key:(_format_date_yyyymmdd d) ~data:c.declines)
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
    let corr = _pearson_correlation syn_net gold_net in
    let mae = _mean_absolute_error syn_net gold_net in
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
  (* Step 1: Load universe *)
  let symbols = _load_symbols ~data_dir in
  printf "Universe: %d symbols from sectors.csv\n%!" (List.length symbols);
  (* Step 2: Load close prices *)
  printf "Loading daily close prices...\n%!";
  let all_prices, missing = _load_all_prices ~data_dir symbols in
  let loaded = List.length all_prices in
  printf "Loaded prices for %d symbols (%d missing data files)\n%!" loaded
    missing;
  (* Step 3: Compute daily advances/declines *)
  printf "Computing daily advance/decline counts...\n%!";
  let daily = _compute_daily_changes ~min_stocks:_min_stocks all_prices in
  let avg_stocks =
    if List.is_empty daily then 0.0
    else
      Float.of_int
        (List.fold daily ~init:0 ~f:(fun acc (_, c) -> acc + c.total))
      /. Float.of_int (List.length daily)
  in
  _print_daily_summary daily avg_stocks;
  (* Step 4: Write output CSVs *)
  let breadth_dir = _write_output_csvs ~data_dir daily in
  (* Step 5: Validate against golden data *)
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

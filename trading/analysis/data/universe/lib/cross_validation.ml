open Core
module SC = Shiller.Shiller_client

type drift_cell = {
  year : int;
  composition_return : float;
  shiller_return : float;
  drift : float;
}
[@@deriving sexp, show, eq]

type report = {
  cells : drift_cell list;
  mean_drift : float;
  median_drift : float;
  max_abs_drift : float;
  worst_year : int;
}
[@@deriving sexp, show, eq]

(* --------------------------------------------------------------------- *)
(* Shiller window math (mirrors Universe.Build_from_index exactly so the
   composition-vs-Shiller comparison is on a like-for-like basis). *)
(* --------------------------------------------------------------------- *)

let _window_days = 365
let _anchor_date_for_year year = Date.create_exn ~y:year ~m:Month.May ~d:31

let _in_window ~start_date ~end_date d =
  Date.( >= ) d start_date && Date.( <= ) d end_date

let _shiller_window_for_year ~year obs =
  let start_date = _anchor_date_for_year year in
  let end_date = Date.add_days start_date _window_days in
  List.filter obs ~f:(fun (o : SC.monthly_observation) ->
      _in_window ~start_date ~end_date o.period)

(* Shiller's dividend is annualized; per-month accrual is [div / 12]. *)
let _monthly_dividend_amount (o : SC.monthly_observation) =
  match o.dividend with Some d -> d /. 12.0 | None -> 0.0

let _sum_dividends obs =
  List.fold obs ~init:0.0 ~f:(fun acc o -> acc +. _monthly_dividend_amount o)

(* Returns [Some return] when the window has ≥2 observations and a positive
   starting price; otherwise [None] so the caller can silently skip the
   year. *)
let _shiller_return_for_window obs : float option =
  match obs with
  | [] | [ _ ] -> None
  | first :: _ ->
      let last = List.last_exn obs in
      let p_start = first.SC.sp_price in
      let p_end = last.SC.sp_price in
      if Float.(p_start <= 0.0) then None
      else
        let div_total = _sum_dividends obs in
        Some (((p_end +. div_total) /. p_start) -. 1.0)

(* --------------------------------------------------------------------- *)
(* Composition golden loader. *)
(* --------------------------------------------------------------------- *)

let _composition_path ~composition_dir ~size ~year =
  Filename.concat composition_dir (Printf.sprintf "top-%d-%d.sexp" size year)

(* Returns [Some snapshot] on success, [None] when the file does not exist
   (silent skip), and a hard error when the file exists but is malformed. *)
let _load_composition_optional ~composition_dir ~size ~year :
    Snapshot.t option Status.status_or =
  let path = _composition_path ~composition_dir ~size ~year in
  if not (Stdlib.Sys.file_exists path) then Ok None
  else
    match Snapshot.load ~path with
    | Ok snap -> Ok (Some snap)
    | Error _ as e -> e

(* --------------------------------------------------------------------- *)
(* Per-year cell construction. *)
(* --------------------------------------------------------------------- *)

let _cell_for_year ~composition_dir ~shiller_obs ~size ~year :
    drift_cell option Status.status_or =
  let open Result.Let_syntax in
  let%bind snapshot_opt =
    _load_composition_optional ~composition_dir ~size ~year
  in
  match snapshot_opt with
  | None -> Ok None
  | Some snapshot -> (
      let window = _shiller_window_for_year ~year shiller_obs in
      match _shiller_return_for_window window with
      | None -> Ok None
      | Some shiller_return ->
          let composition_return = snapshot.Snapshot.aggregate_period_return in
          let drift = composition_return -. shiller_return in
          Ok (Some { year; composition_return; shiller_return; drift }))

let _years_inclusive ~start_year ~end_year =
  List.init (end_year - start_year + 1) ~f:(fun i -> start_year + i)

let _collect_cells ~composition_dir ~shiller_obs ~size ~start_year ~end_year :
    drift_cell list Status.status_or =
  let years = _years_inclusive ~start_year ~end_year in
  List.fold years
    ~init:(Ok ([] : drift_cell list))
    ~f:(fun acc year ->
      match acc with
      | Error _ as e -> e
      | Ok rev -> (
          match _cell_for_year ~composition_dir ~shiller_obs ~size ~year with
          | Error _ as e -> e
          | Ok None -> Ok rev
          | Ok (Some cell) -> Ok (cell :: rev)))
  |> Result.map ~f:List.rev

(* --------------------------------------------------------------------- *)
(* Statistics. *)
(* --------------------------------------------------------------------- *)

let _mean_drift cells =
  let n = List.length cells in
  if n = 0 then 0.0
  else
    let sum = List.fold cells ~init:0.0 ~f:(fun acc c -> acc +. c.drift) in
    sum /. Float.of_int n

let _median_drift cells =
  let sorted =
    List.map cells ~f:(fun c -> c.drift) |> List.sort ~compare:Float.compare
  in
  let n = List.length sorted in
  if n = 0 then 0.0
  else if n mod 2 = 1 then List.nth_exn sorted (n / 2)
  else
    let lo = List.nth_exn sorted ((n / 2) - 1) in
    let hi = List.nth_exn sorted (n / 2) in
    (lo +. hi) /. 2.0

let _worst_cell cells : float * int =
  (* (max_abs_drift, year). Ties broken by earliest year. *)
  List.fold cells ~init:(0.0, 0) ~f:(fun (best_abs, best_year) c ->
      let abs_d = Float.abs c.drift in
      if Float.(abs_d > best_abs) then (abs_d, c.year) else (best_abs, best_year))

let _build_report cells =
  let max_abs_drift, worst_year = _worst_cell cells in
  {
    cells;
    mean_drift = _mean_drift cells;
    median_drift = _median_drift cells;
    max_abs_drift;
    worst_year;
  }

(* --------------------------------------------------------------------- *)
(* Public API. *)
(* --------------------------------------------------------------------- *)

let _validate_year_range ~start_year ~end_year =
  if start_year > end_year then
    Status.error_invalid_argument
      (Printf.sprintf
         "Cross_validation.compute: start_year (%d) > end_year (%d)" start_year
         end_year)
  else Ok ()

let _validate_nonempty_cells cells =
  if List.is_empty cells then
    Status.error_invalid_argument
      "Cross_validation.compute: zero usable (composition, shiller) cells in \
       window"
  else Ok ()

let compute ~composition_dir ~shiller_obs ~size ~start_year ~end_year =
  let open Result.Let_syntax in
  let%bind () = _validate_year_range ~start_year ~end_year in
  let%bind cells =
    _collect_cells ~composition_dir ~shiller_obs ~size ~start_year ~end_year
  in
  let%bind () = _validate_nonempty_cells cells in
  Ok (_build_report cells)

(* --------------------------------------------------------------------- *)
(* Markdown rendering. *)
(* --------------------------------------------------------------------- *)

let _fmt_pct f = Printf.sprintf "%+.2f%%" (f *. 100.0)
let _fmt_pp f = Printf.sprintf "%+.2f pp" (f *. 100.0)

let _row cell =
  Printf.sprintf "| %d | %s | %s | %s |" cell.year
    (_fmt_pct cell.composition_return)
    (_fmt_pct cell.shiller_return)
    (_fmt_pp cell.drift)

let _summary_block report =
  Printf.sprintf
    "## Summary\n\n\
     - Cells: %d\n\
     - Mean drift: %s\n\
     - Median drift: %s\n\
     - Max |drift|: %s\n\
     - Worst year: %d\n"
    (List.length report.cells)
    (_fmt_pp report.mean_drift)
    (_fmt_pp report.median_drift)
    (_fmt_pp report.max_abs_drift)
    report.worst_year

let _table_block cells =
  let header =
    "| Year | Composition | Shiller | Drift |\n\
     |------|-------------|---------|-------|"
  in
  let rows = List.map cells ~f:_row in
  String.concat ~sep:"\n" (header :: rows)

let format_markdown report =
  if List.is_empty report.cells then
    "# Cross-validation: composition vs Shiller\n\n_No cells in report._\n"
  else
    Printf.sprintf
      "# Cross-validation: composition vs Shiller\n\n\
       %s\n\
       ## Per-year drift\n\n\
       %s\n"
      (_summary_block report)
      (_table_block report.cells)

(* --------------------------------------------------------------------- *)
(* Sexp persistence. *)
(* --------------------------------------------------------------------- *)

let save_sexp report ~path =
  let tmp_path = path ^ ".tmp" in
  try
    Out_channel.write_all tmp_path
      ~data:(Sexp.to_string_hum (sexp_of_report report));
    Stdlib.Sys.rename tmp_path path;
    Ok ()
  with Sys_error msg | Failure msg ->
    (try Stdlib.Sys.remove tmp_path with _ -> ());
    Status.error_internal (Printf.sprintf "Cross_validation.save_sexp: %s" msg)

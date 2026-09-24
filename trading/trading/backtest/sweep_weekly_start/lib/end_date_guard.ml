open Core
open Sweep_types

let default_max_end_date_gap_days = 7

let resolve_coverage ~requested_end_date ~last_bar_date ~tolerance_days =
  let gap_days = Date.diff requested_end_date last_bar_date in
  {
    requested_end_date;
    last_bar_date;
    tolerance_days;
    clamped = gap_days > tolerance_days;
  }

let effective_end_date (c : coverage) =
  if c.clamped then c.last_bar_date else c.requested_end_date

let _read_last_bar_date ~data_dir symbol =
  let prices =
    match Csv.Csv_storage.create ~data_dir symbol with
    | Error err -> Error err
    | Ok storage -> Csv.Csv_storage.get storage ()
  in
  match prices with
  | Error err ->
      failwithf "sweep_weekly_start: cannot read bars for %s: %s" symbol
        (Status.show err) ()
  | Ok prices -> (
      let dates =
        List.map prices ~f:(fun (p : Types.Daily_price.t) -> p.date)
      in
      match List.max_elt dates ~compare:Date.compare with
      | Some d -> d
      | None -> failwithf "sweep_weekly_start: no bars for %s" symbol ())

let load_coverage ~data_dir ~symbol ~requested_end_date ~tolerance_days =
  let last_bar_date = _read_last_bar_date ~data_dir symbol in
  resolve_coverage ~requested_end_date ~last_bar_date ~tolerance_days

(** Stderr counterpart of the report's clamp warning, so the workflow log says
    it too. *)
let warn_if_clamped symbol (c : coverage) =
  if c.clamped then
    eprintf
      "sweep_weekly_start: WARNING end_date %s is past the last %s bar %s by \
       more than %d days; clamping every cell to %s\n\
       %!"
      (Date.to_string c.requested_end_date)
      symbol
      (Date.to_string c.last_bar_date)
      c.tolerance_days
      (Date.to_string c.last_bar_date)

let last_bar_line (r : sweep_result) =
  match r.coverage with
  | None -> ""
  | Some c -> Printf.sprintf "Last bar: %s\n" (Date.to_string c.last_bar_date)

let _clamp_text symbol (c : coverage) =
  let requested = Date.to_string c.requested_end_date in
  let last = Date.to_string c.last_bar_date in
  let gap = Date.diff c.requested_end_date c.last_bar_date in
  Printf.sprintf
    "\n\
     > **WARNING -- END DATE CLAMPED.** Requested end date %s is %d days past \
     the last %s bar (%s), beyond the %d-day tolerance. Every cell is measured \
     to %s, not to %s. Refresh the %s bars to measure to the run date.\n"
    requested gap symbol last c.tolerance_days last requested symbol

(** The loud clamp notice (issue #2915): names both dates, the gap, and the
    tolerance, so nobody reads the CAGRs as "to the run date". Empty when the
    guard did not clamp. *)
let clamp_warning (r : sweep_result) =
  match r.coverage with
  | Some c when c.clamped -> _clamp_text r.symbol c
  | Some _ | None -> ""

let _dropped_line (d : dropped_cell) =
  Printf.sprintf "- %s: %s" (Date.to_string d.start_date) d.reason

let _dropped_section (dropped : dropped_cell list) =
  Printf.sprintf
    "\n\
     ## Dropped cells\n\n\
     %d cell(s) dropped -- no trading day between the start date and the end \
     date:\n\n\
     %s\n"
    (List.length dropped)
    (String.concat ~sep:"\n" (List.map dropped ~f:_dropped_line))

(** The [## Dropped cells] section: count plus one line per dropped start date
    with its reason. Empty when nothing was dropped. *)
let dropped_block (dropped : dropped_cell list) =
  if List.is_empty dropped then "" else _dropped_section dropped

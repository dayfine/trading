open Core
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest
module Weekly_sidetable_builder = Snapshot_pipeline.Weekly_sidetable_builder
module Snapshot_columnar = Data_panel_snapshot.Snapshot_columnar
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Snap = Data_panel_snapshot.Snapshot
module Weekly_sidetable = Data_panel_snapshot.Weekly_sidetable

type outcome =
  | Rebuilt of { deep_bars_used : int; basis_factor : float }
  | Fallback_no_csv
  | Fallback_unstable_basis
[@@deriving sexp, equal]

type symbol_report = { symbol : string; outcome : outcome; date_parity : bool }
[@@deriving sexp, equal]

type summary = {
  total : int;
  rebuilt : int;
  fallback_no_csv : int;
  fallback_unstable_basis : int;
  date_parity_failures : int;
  reports : symbol_report list;
}
[@@deriving sexp, equal]

let default_sketch_deep_days = 3650

(* Relative tolerance under which the sampled snap/CSV adjusted ratios count as
   one constant global-rebase factor [c]. The feed stores [adjusted_close]
   rounded to 4 decimals, so a genuine global rebase still shows per-sample
   ratio noise of ~0.5e-4/price (observed ~1e-6 on PFE at $14-24); a real
   historical revision (a corrected split factor, a fixed bad bar) moves a
   ratio by percents. 1e-3 sits between the two classes. *)
let _basis_stability_rel_tol = 1e-3

(* Relative tolerance under which [c] collapses to exactly [1.0] — bit-safety:
   an unchanged CSV yields ratios of identical doubles, i.e. exactly 1.0, so
   anything this close is float noise, not a rebase. *)
let _basis_unity_rel_tol = 1e-9
let _get row field = Option.value (Snap.get row field) ~default:Float.nan

(* Snap [Volume] cells are float64; [Daily_price.volume] is an int. A NaN cell
   (never expected — the writer copies the bar's volume verbatim) maps to 0
   rather than an undefined [Float.to_int]. *)
let _volume_of v = if Float.is_nan v then 0 else Float.to_int v

(* Reconstitute the verbatim daily bar a snap row was built from. Values pass
   through unfiltered — the original side-table build folded the raw CSV rows
   as-is, so a faithful rebuild must too. *)
let _bar_of_row (row : Snap.t) : Types.Daily_price.t =
  Types.Daily_price.make ~date:row.Snap.date
    ~open_price:(_get row Snapshot_schema.Open)
    ~high_price:(_get row Snapshot_schema.High)
    ~low_price:(_get row Snapshot_schema.Low)
    ~close_price:(_get row Snapshot_schema.Close)
    ~volume:(_volume_of (_get row Snapshot_schema.Volume))
    ~adjusted_close:(_get row Snapshot_schema.Adjusted_close)
    ()

(* Prefer the conventional [<warehouse_dir>/<symbol>.snap] location; fall back
   to the manifest entry's recorded path (absolute, or relative to the
   warehouse dir). Keeps the migrator working on a warehouse that was moved
   after its manifest recorded absolute paths. *)
let _snap_path ~warehouse_dir ~(entry : Snapshot_manifest.file_metadata) =
  let conventional = Filename.concat warehouse_dir (entry.symbol ^ ".snap") in
  if Stdlib.Sys.file_exists conventional then conventional
  else if Filename.is_absolute entry.path then entry.path
  else Filename.concat warehouse_dir entry.path

let _read_snap_bars ~path : Types.Daily_price.t list Status.status_or =
  match Snapshot_columnar.with_reader ~path ~f:Snapshot_columnar.read_all with
  | Error e -> Error e
  | Ok rows -> Ok (List.map rows ~f:_bar_of_row)

let _csv_bars ~data_dir ~symbol : Types.Daily_price.t list option =
  match Csv.Csv_storage.create ~data_dir symbol with
  | Error _ -> None
  | Ok storage -> (
      match Csv.Csv_storage.get storage () with
      | Error _ -> None
      | Ok bars -> Some bars)

(* Snap/CSV [adjusted_close] ratio on one overlap date; [None] when the CSV
   has no bar that date or either side is non-finite / non-positive. *)
let _ratio_at ~csv_by_date (snap_bar : Types.Daily_price.t) : float option =
  match Map.find csv_by_date snap_bar.date with
  | None -> None
  | Some (csv_bar : Types.Daily_price.t) ->
      let s = snap_bar.adjusted_close and c = csv_bar.adjusted_close in
      if Float.is_positive s && Float.is_positive c then Some (s /. c) else None

(* Overlap dates sampled for the basis-ratio stability check: five evenly
   spaced snap bars (first / quartiles / last). *)
let _sample_bars (snap_bars : Types.Daily_price.t array) =
  let n = Array.length snap_bars in
  List.dedup_and_sort ~compare:Int.compare [ 0; n / 4; n / 2; 3 * n / 4; n - 1 ]
  |> List.map ~f:(fun i -> snap_bars.(i))

let _rel_close ~tol a b = Float.( <= ) (Float.abs (a -. b)) (tol *. Float.abs b)

let _median sorted =
  let n = List.length sorted in
  List.nth_exn sorted (n / 2)

let _within_rounding_of ~center r =
  _rel_close ~tol:_basis_stability_rel_tol r center

(* [1.0] exactly when [c] is float-noise away from it (bit-safety for the
   unchanged-CSV case), else [c] verbatim. *)
let _collapse_unity c =
  if _rel_close ~tol:_basis_unity_rel_tol c 1.0 then 1.0 else c

(* Collapse sampled ratios into one stable factor (their median — robust to
   per-sample rounding noise), or refuse when any sample strays beyond the
   rounding class. *)
let _basis_factor = function
  | [] -> `Unstable
  | ratios ->
      let c = _median (List.sort ratios ~compare:Float.compare) in
      if List.for_all ratios ~f:(_within_rounding_of ~center:c) then
        `Stable (_collapse_unity c)
      else `Unstable

(* Re-pin CSV deep bars onto the warehouse's adjusted basis: only
   [adjusted_close] moves; the raw O/H/L/C stay, so the weekly builder's own
   [to_adjusted_basis] rescale lands on the warehouse basis. *)
let _repin ~basis_factor bars =
  if Float.equal basis_factor 1.0 then bars
  else
    List.map bars ~f:(fun (b : Types.Daily_price.t) ->
        { b with adjusted_close = b.adjusted_close *. basis_factor })

(* Deep-history slice strictly before the symbol's first snap bar, mirroring
   [Build_runner._deep_bars]'s window arithmetic. *)
let _deep_window ~sketch_deep_days ~first_date csv_bars =
  let deep_start = Date.add_days first_date (-sketch_deep_days) in
  let deep_end = Date.add_days first_date (-1) in
  Bar_window.filter ~start:deep_start ~end_:deep_end csv_bars

let _csv_by_date csv_bars =
  Map.of_alist_reduce
    (module Date)
    (List.map csv_bars ~f:(fun (b : Types.Daily_price.t) -> (b.date, b)))
    ~f:(fun a _ -> a)

let _pinned_deep_bars ~csv_bars ~sketch_deep_days ~first_date ~snap_bars =
  let csv_by_date = _csv_by_date csv_bars in
  let ratios =
    List.filter_map (_sample_bars snap_bars) ~f:(_ratio_at ~csv_by_date)
  in
  match _basis_factor ratios with
  | `Unstable -> ([], Fallback_unstable_basis)
  | `Stable basis_factor ->
      let deep =
        _deep_window ~sketch_deep_days ~first_date csv_bars
        |> _repin ~basis_factor
      in
      (deep, Rebuilt { deep_bars_used = List.length deep; basis_factor })

(* Deep bars for the symbol + the outcome tag describing how we got them. *)
let _deep_and_outcome ~data_dir ~symbol ~sketch_deep_days
    ~(snap_bars : Types.Daily_price.t array) =
  match _csv_bars ~data_dir ~symbol with
  | None -> ([], Fallback_no_csv)
  | Some csv_bars ->
      let first_date = snap_bars.(0).date in
      _pinned_deep_bars ~csv_bars ~sketch_deep_days ~first_date ~snap_bars

(* [true] iff the rebuilt entries carry exactly the source side-table's
   [week_end_date] skeleton. *)
let _date_parity ~warehouse_dir ~symbol ~(entries : Weekly_sidetable.entry list)
    =
  let path = Filename.concat warehouse_dir (symbol ^ ".weekly") in
  match Weekly_sidetable.read_file ~path with
  | Error _ -> false
  | Ok old_entries ->
      let dates es =
        List.map es ~f:(fun (e : Weekly_sidetable.entry) -> e.week_end_date)
      in
      List.equal Date.equal (dates old_entries) (dates entries)

let _copy_file ~src ~dst =
  Out_channel.write_all dst ~data:(In_channel.read_all src)

(* Hard-link the (identical) [.snap] into the clone; copy when linking fails
   (cross-device clone target). Re-runs overwrite. *)
let _link_or_copy ~src ~dst =
  if Stdlib.Sys.file_exists dst then Stdlib.Sys.remove dst;
  try Core_unix.link ~target:src ~link_name:dst ()
  with Core_unix.Unix_error _ -> _copy_file ~src ~dst

let _rebuild_symbol ~warehouse_dir ~data_dir ~output_dir ~sketch_deep_days
    ~(entry : Snapshot_manifest.file_metadata) ~bars =
  let symbol = entry.symbol in
  let snap_bars = Array.of_list bars in
  let deep_bars, outcome =
    _deep_and_outcome ~data_dir ~symbol ~sketch_deep_days ~snap_bars
  in
  let entries = Weekly_sidetable_builder.of_bars ~deep_bars ~bars in
  let date_parity = _date_parity ~warehouse_dir ~symbol ~entries in
  let weekly_path = Filename.concat output_dir (symbol ^ ".weekly") in
  match Weekly_sidetable.write_file ~path:weekly_path entries with
  | Error e -> Error e
  | Ok () -> Ok { symbol; outcome; date_parity }

(* A symbol with an empty [.snap] cannot anchor a deep window or a basis
   sample; the original build skips such symbols entirely (no manifest entry),
   so hitting one here means the warehouse is malformed. *)
let _process_entry ~warehouse_dir ~data_dir ~output_dir ~sketch_deep_days
    (entry : Snapshot_manifest.file_metadata) =
  let src = _snap_path ~warehouse_dir ~entry in
  match _read_snap_bars ~path:src with
  | Error e -> Error e
  | Ok [] ->
      Error
        (Status.invalid_argument_error
           (Printf.sprintf "%s: empty .snap in source warehouse" entry.symbol))
  | Ok bars ->
      _link_or_copy ~src
        ~dst:(Filename.concat output_dir (entry.symbol ^ ".snap"));
      _rebuild_symbol ~warehouse_dir ~data_dir ~output_dir ~sketch_deep_days
        ~entry ~bars

let _summarize reports =
  let count f = List.count reports ~f in
  {
    total = List.length reports;
    rebuilt =
      count (fun r -> match r.outcome with Rebuilt _ -> true | _ -> false);
    fallback_no_csv = count (fun r -> equal_outcome r.outcome Fallback_no_csv);
    fallback_unstable_basis =
      count (fun r -> equal_outcome r.outcome Fallback_unstable_basis);
    date_parity_failures = count (fun r -> not r.date_parity);
    reports;
  }

(* Clone the manifest with entry paths rewritten to bare filenames (resolved
   against the clone dir by the runtime) and the adjusted-basis side-table
   format hash stamped. *)
let _write_clone_manifest ~output_dir (source : Snapshot_manifest.t) =
  let entries =
    List.map source.entries ~f:(fun e ->
        { e with Snapshot_manifest.path = e.symbol ^ ".snap" })
  in
  let manifest =
    Snapshot_manifest.create ~schema:source.schema ~entries |> fun m ->
    Snapshot_manifest.set_weekly_sidetable_format_hash m
      Weekly_sidetable.format_hash
  in
  Snapshot_manifest.write
    ~path:(Filename.concat output_dir "manifest.sexp")
    manifest

let _write_report ~output_dir summary =
  Out_channel.write_all
    (Filename.concat output_dir "migration_report.sexp")
    ~data:(Sexp.to_string_hum (sexp_of_summary summary))

let _ensure_dir path =
  if not (Stdlib.Sys.file_exists path) then Core_unix.mkdir_p path

let _process_all ~warehouse_dir ~data_dir ~output_dir ~sketch_deep_days
    (source : Snapshot_manifest.t) =
  List.fold_result source.entries ~init:[] ~f:(fun acc entry ->
      match
        _process_entry ~warehouse_dir ~data_dir ~output_dir ~sketch_deep_days
          entry
      with
      | Error e -> Error e
      | Ok report -> Ok (report :: acc))
  |> Result.map ~f:List.rev

(* Summarize + write the clone manifest and report once every symbol landed. *)
let _finalize ~output_dir ~source reports =
  let summary = _summarize reports in
  match _write_clone_manifest ~output_dir source with
  | Error e -> Error e
  | Ok () ->
      _write_report ~output_dir summary;
      Ok summary

let _migrate_source ~warehouse_dir ~csv_data_dir ~output_dir ~sketch_deep_days
    source =
  _ensure_dir output_dir;
  let data_dir = Fpath.v csv_data_dir in
  match
    _process_all ~warehouse_dir ~data_dir ~output_dir ~sketch_deep_days source
  with
  | Error e -> Error e
  | Ok reports -> _finalize ~output_dir ~source reports

let migrate ~warehouse_dir ~csv_data_dir ~output_dir
    ?(sketch_deep_days = default_sketch_deep_days) () =
  let manifest_path = Filename.concat warehouse_dir "manifest.sexp" in
  match Snapshot_manifest.read ~path:manifest_path with
  | Error e -> Error e
  | Ok source ->
      _migrate_source ~warehouse_dir ~csv_data_dir ~output_dir ~sketch_deep_days
        source

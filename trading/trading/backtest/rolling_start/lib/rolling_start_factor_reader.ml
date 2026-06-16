open Core
module Daily_panels = Snapshot_runtime.Daily_panels
module Snapshot = Data_panel_snapshot.Snapshot
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema

(* The calendar-day lookback window for an "as-of [date]" snapshot read. Snapshot
   rows exist on trading days only, so [date] (a start date, possibly a weekend
   or holiday) may have no exact row; we read [date - window .. date] and take
   the latest row on/before [date]. ~10 days comfortably spans any holiday gap.
*)
let _as_of_lookback_days = 10

(* The latest snapshot row for [symbol] on/before [date] (within the lookback
   window), or [None] when the symbol has no row there / the read fails. Used
   for every "factor as-of the start date" read. *)
let _row_as_of ~panels ~symbol ~date =
  let from = Date.add_days date (-_as_of_lookback_days) in
  match Daily_panels.read_history panels ~symbol ~from ~until:date with
  | Error _ | Ok [] -> None
  | Ok rows ->
      List.max_elt rows ~compare:(fun (a : Snapshot.t) b ->
          Date.compare a.date b.date)

(* The [field] cell of [symbol]'s as-of-[date] row, as [Some v] (v may be nan)
   or [None] when there is no row / the field is absent. *)
let _field_as_of ~panels ~symbol ~date ~field =
  Option.bind (_row_as_of ~panels ~symbol ~date) ~f:(fun row ->
      Snapshot.get row field)

(* The [field] cell of [symbol]'s as-of-[date] row, defaulting an absent
   row/field to [nan] — the "skip me" marker the universe-scan factors expect. *)
let _field_or_nan ~panels ~symbol ~date ~field =
  _field_as_of ~panels ~symbol ~date ~field |> Option.value ~default:Float.nan

(* The benchmark index's decoded stage as-of [date], or [None] for no symbol /
   no row / nan cell. *)
let _benchmark_stage ~panels ~benchmark_symbol ~date =
  Option.bind benchmark_symbol ~f:(fun symbol ->
      Option.bind
        (_field_as_of ~panels ~symbol ~date ~field:Snapshot_schema.Stage)
        ~f:Rolling_start_factors.macro_stage_of_value)

(* The benchmark index's stage + macro-composite as-of [date]. Both unavailable
   ([None] / [nan]) when there is no benchmark symbol or no as-of row. *)
let _benchmark_factors ~panels ~benchmark_symbol ~date =
  let stage = _benchmark_stage ~panels ~benchmark_symbol ~date in
  let macro_composite =
    match benchmark_symbol with
    | None -> Float.nan
    | Some symbol ->
        _field_or_nan ~panels ~symbol ~date
          ~field:Snapshot_schema.Macro_composite
  in
  (stage, macro_composite)

(* One universe symbol's [(stage_value, (sector, rs_value))] as-of [date]: the
   raw [Stage] scalar (nan when absent, so {!Rolling_start_factors} skips it) and
   the symbol's sector paired with its [RS_line] scalar. *)
let _cell_as_of ~panels ~date (symbol, sector) =
  let stage_value =
    _field_or_nan ~panels ~symbol ~date ~field:Snapshot_schema.Stage
  in
  let rs_value =
    _field_or_nan ~panels ~symbol ~date ~field:Snapshot_schema.RS_line
  in
  (stage_value, (sector, rs_value))

(* Per universe symbol, its as-of-[date] cell ({!_cell_as_of}). *)
let _universe_cells_as_of ~panels ~universe ~date =
  List.map universe ~f:(_cell_as_of ~panels ~date)

let factors_as_of ~panels ~benchmark_symbol ~universe ~date :
    Rolling_start_factors.factors =
  let spy_stage_at_start, macro_composite_at_start =
    _benchmark_factors ~panels ~benchmark_symbol ~date
  in
  let cells = _universe_cells_as_of ~panels ~universe ~date in
  let stage2_candidate_count =
    match universe with
    | [] -> None
    | _ ->
        Some
          (Rolling_start_factors.stage2_candidate_count (List.map cells ~f:fst))
  in
  let sector_rs_dispersion_at_start =
    Rolling_start_factors.sector_rs_dispersion (List.map cells ~f:snd)
  in
  {
    Rolling_start_factors.spy_stage_at_start;
    macro_composite_at_start;
    stage2_candidate_count;
    sector_rs_dispersion_at_start;
  }

(* Fold every start's {!factors_as_of} into a [start_date -> factors] map over
   one already-open [panels] handle. *)
let _fold_factors ~panels ~benchmark_symbol ~universe starts =
  List.fold starts
    ~init:(Map.empty (module Date))
    ~f:(fun acc date ->
      Map.set acc ~key:date
        ~data:(factors_as_of ~panels ~benchmark_symbol ~universe ~date))

(* Build the shared panels, fold the per-start factors over it, close it, and
   return the map; the empty map on any panels failure. *)
let _resolve_via_panels ~src ~benchmark_symbol ~universe ~starts =
  match Backtest.Bar_data_source.build_shared_panels src with
  | Ok (Some panels) ->
      let result = _fold_factors ~panels ~benchmark_symbol ~universe starts in
      Backtest.Bar_data_source.close_shared_panels panels;
      result
  | Ok None | Error _ -> Map.empty (module Date)

let resolve_per_start ~bar_data_source ~benchmark_symbol ~universe ~starts =
  match bar_data_source with
  | None -> Map.empty (module Date)
  | Some src -> _resolve_via_panels ~src ~benchmark_symbol ~universe ~starts

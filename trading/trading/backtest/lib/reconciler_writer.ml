open Core

(** [LONG] for net-positive quantity, [SHORT] for net-negative. Used in
    [open_positions.csv] — case-sensitive per spec. *)
let _open_position_side_label (qty : float) =
  if Float.( > ) qty 0.0 then "LONG" else "SHORT"

(** Earliest acquisition date across the position's lots — the position's "entry
    date" in the PHASE_1_SPEC sense. The {!Trading_portfolio.Types.position_lot}
    invariant ([lots] sorted ascending by [acquisition_date]) means this is
    [(List.hd_exn lots).acquisition_date], but we [List.min_elt] defensively in
    case future refactors break the sort. *)
let _entry_date_of (pos : Trading_portfolio.Types.portfolio_position) =
  match
    List.min_elt pos.lots ~compare:(fun a b ->
        Date.compare a.acquisition_date b.acquisition_date)
  with
  | Some lot -> lot.acquisition_date
  | None -> failwithf "position %s has no lots" pos.symbol ()

(** Emit one [open_positions.csv] row for [pos] to [oc]. PHASE_1_SPEC §3:
    [symbol,side,entry_date,entry_price,quantity]. [entry_price] is the average
    cost per share (positive for both longs and shorts); [quantity] is the
    absolute share count. *)
let _write_open_position_row oc (pos : Trading_portfolio.Types.portfolio_position)
    =
  let qty = Trading_portfolio.Calculations.position_quantity pos in
  let avg_cost = Trading_portfolio.Calculations.avg_cost_of_position pos in
  let side = _open_position_side_label qty in
  let entry_date = _entry_date_of pos in
  fprintf oc "%s,%s,%s,%.2f,%.0f\n" pos.symbol side
    (Date.to_string entry_date)
    avg_cost (Float.abs qty)

(** One row per [Holding] position at run end. PHASE_1_SPEC §3. *)
let write_open_positions ~output_dir ~steps =
  let open Trading_simulation_types.Simulator_types in
  let path = output_dir ^ "/open_positions.csv" in
  let oc = Out_channel.create path in
  fprintf oc "symbol,side,entry_date,entry_price,quantity\n";
  (match List.last steps with
  | None -> ()
  | Some last_step ->
      List.iter last_step.portfolio.Trading_portfolio.Portfolio.positions
        ~f:(_write_open_position_row oc));
  Out_channel.close oc

(** One row per symbol present in [open_positions.csv]. PHASE_1_SPEC §3.3:
    [symbol,price]. Symbols held at run end without an entry in [final_prices]
    (e.g. delisted on the final calendar day) are silently dropped — the
    reconciler's join is left-anti and surfaces these as "missing final price"
    diagnostics. *)
let write_final_prices ~output_dir ~steps
    ~(final_prices : (string * float) list) =
  let open Trading_simulation_types.Simulator_types in
  let path = output_dir ^ "/final_prices.csv" in
  let oc = Out_channel.create path in
  fprintf oc "symbol,price\n";
  let held_symbols =
    match List.last steps with
    | None -> String.Set.empty
    | Some last_step ->
        last_step.portfolio.Trading_portfolio.Portfolio.positions
        |> List.map ~f:(fun (p : Trading_portfolio.Types.portfolio_position) ->
            p.symbol)
        |> String.Set.of_list
  in
  let price_map =
    Map.of_alist_reduce (module String) final_prices ~f:(fun a _ -> a)
  in
  Set.iter held_symbols ~f:(fun sym ->
      match Map.find price_map sym with
      | Some price -> fprintf oc "%s,%.2f\n" sym price
      | None -> ());
  Out_channel.close oc

(** Format a split factor for [splits.csv]. PHASE_1_SPEC §4 examples show plain
    decimal output: [4.0] for forward 4:1, [0.125] for reverse 1:8. Strategy:
    integer factors render as [N.0] (via [%.1f]); fractional factors use [%.6g],
    which produces canonical [0.125] / [1.5] without trailing zeros. [%g] alone
    prints integer factors as ["4"] without a decimal point, which trips
    reconciler parsers expecting a float. *)
let _format_split_factor (f : float) =
  if Float.( = ) f (Float.round_down f) then sprintf "%.1f" f
  else sprintf "%.6g" f

(** All split events that fired during the run. Pulled from
    [step_result.splits_applied] across every step the simulator produced (the
    simulator only logs splits for symbols actively held that day, so no further
    filtering is needed). PHASE_1_SPEC §4: [symbol,date,factor]. *)
let write_splits ~output_dir ~steps =
  let open Trading_simulation_types.Simulator_types in
  let path = output_dir ^ "/splits.csv" in
  let oc = Out_channel.create path in
  fprintf oc "symbol,date,factor\n";
  List.iter steps ~f:(fun (s : step_result) ->
      List.iter s.splits_applied
        ~f:(fun (e : Trading_portfolio.Split_event.t) ->
          fprintf oc "%s,%s,%s\n" e.symbol (Date.to_string e.date)
            (_format_split_factor e.factor)));
  Out_channel.close oc

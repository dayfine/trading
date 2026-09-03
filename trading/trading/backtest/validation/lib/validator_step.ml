open Core
open Validator_types

let _basis_lo = 0.66
let _basis_hi = 1.5

type step = Skip | Pass | Fail of specimen
type finding = { violations : specimen list; skipped : int }

let empty_finding = { violations = []; skipped = 0 }

let _absorb acc = function
  | Skip -> { acc with skipped = acc.skipped + 1 }
  | Pass -> acc
  | Fail sp -> { acc with violations = sp :: acc.violations }

let fold_steps rows ~f =
  List.fold rows ~init:empty_finding ~f:(fun acc x -> _absorb acc (f x))

let _is_long (r : trade_row) = String.equal r.side "LONG"
let longs inputs = List.filter inputs.trades ~f:_is_long

let spec (row : trade_row) detail =
  { symbol = row.symbol; entry_date = Date.to_string row.entry_date; detail }

let open_spec (op : open_row) detail =
  { symbol = op.symbol; entry_date = Date.to_string op.entry_date; detail }

let audit_step audit ~pred (row : trade_row) =
  match audit row with None -> Skip | Some ctx -> pred row ctx

let _entry_week_idx (b : bars) ~entry_date =
  Array.findi b.weekly_dates ~f:(fun _ d -> Date.( >= ) d entry_date)
  |> Option.map ~f:fst

let price_basis_ok ~bar_price ~fill_price =
  Float.( > ) fill_price 0.0
  &&
  let r = bar_price /. fill_price in
  Float.( >= ) r _basis_lo && Float.( <= ) r _basis_hi

let _basis_ok (b : bars) i ~entry_price =
  price_basis_ok ~bar_price:b.weekly_closes.(i) ~fill_price:entry_price

let bars_context inputs (row : trade_row) =
  match inputs.bars row.symbol with
  | None -> None
  | Some b ->
      Option.bind (_entry_week_idx b ~entry_date:row.entry_date) ~f:(fun i ->
          if _basis_ok b i ~entry_price:row.entry_price then Some (b, i)
          else None)

let wbars_step inputs ~pred (row : trade_row) =
  match bars_context inputs row with
  | None -> Skip
  | Some (b, i) -> pred row b i

let dollar_adv (b : bars) ~as_of ~lookback =
  let upto = Array.filter b.daily ~f:(fun d -> Date.( <= ) d.date as_of) in
  let n = Array.length upto in
  if n = 0 then None
  else
    let pos = Int.max 0 (n - lookback) in
    let window = Array.sub upto ~pos ~len:(n - pos) in
    let sum =
      Array.fold window ~init:0.0 ~f:(fun a d ->
          a +. (d.close *. Float.of_int d.volume))
    in
    Some (sum /. Float.of_int (Array.length window))

(* Daily bars are ascending by date, so both lookups binary-search. *)
let _by_date (bar : daily_bar) date = Date.compare bar.date date

let daily_on (b : bars) date =
  Array.binary_search b.daily ~compare:_by_date `First_equal_to date
  |> Option.map ~f:(fun i -> b.daily.(i))

let daily_with_prev (b : bars) date =
  match Array.binary_search b.daily ~compare:_by_date `First_equal_to date with
  | Some i when i > 0 -> Some (b.daily.(i - 1), b.daily.(i))
  | _ -> None

let nearest_daily_date (b : bars) date =
  Array.binary_search b.daily ~compare:_by_date `Last_less_than_or_equal_to date
  |> Option.map ~f:(fun i -> b.daily.(i).date)

let bars_in_window (b : bars) ~after ~upto =
  Array.count b.daily ~f:(fun d ->
      Date.( > ) d.date after && Date.( <= ) d.date upto)

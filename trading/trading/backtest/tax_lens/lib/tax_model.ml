open Core
module T = Tax_types

type year_row = {
  year : int;
  pretax_end : float;
  aftertax_end : float;
  st_gain : float;
  lt_gain : float;
  raw_tax : float;
  paid_tax : float;
  carryforward_end : float;
}
[@@deriving sexp, equal]

type result = {
  config : Tax_config.t;
  rows : year_row list;
  pretax_final : float;
  aftertax_final : float;
  pretax_cagr : float;
  aftertax_cagr : float;
  total_tax_paid : float;
  total_realized_pnl : float;
  final_unrealized : float;
}
[@@deriving sexp]

let year_tax ~st_rate ~lt_rate ~carryforward ~cf ~st ~lt =
  let st_gain = Float.max 0. st and st_loss = Float.max 0. (-.st) in
  let lt_gain = Float.max 0. lt and lt_loss = Float.max 0. (-.lt) in
  if not carryforward then ((st_gain *. st_rate) +. (lt_gain *. lt_rate), cf)
  else begin
    (* carryforward offsets ST gains first (higher rate), then LT gains *)
    let off_st = Float.min st_gain cf in
    let cf = cf -. off_st in
    let off_lt = Float.min lt_gain cf in
    let cf = cf -. off_lt in
    let taxable_st = st_gain -. off_st and taxable_lt = lt_gain -. off_lt in
    (* this year's net losses are disallowed in-year → grow the pool *)
    let cf = cf +. st_loss +. lt_loss in
    ((taxable_st *. st_rate) +. (taxable_lt *. lt_rate), cf)
  end

(* Net realized ST/LT gain per exit-year, keyed by year. *)
let _gains_by_year (trades : T.realized_trade list) ~lt_days =
  let tbl = Hashtbl.create (module Int) in
  List.iter trades ~f:(fun tr ->
      let st, lt =
        Hashtbl.find tbl tr.exit_year |> Option.value ~default:(0., 0.)
      in
      let st, lt =
        if tr.days_held >= lt_days then (st, lt +. tr.pnl)
        else (st +. tr.pnl, lt)
      in
      Hashtbl.set tbl ~key:tr.exit_year ~data:(st, lt));
  tbl

(* Per-year [(year, pt_start, pt_end, st_gain, lt_gain)], pt_start threaded. *)
let _per_year (config : Tax_config.t) (rd : T.run_data) =
  let by_year = _gains_by_year rd.trades ~lt_days:config.lt_days in
  let _, rev =
    List.fold rd.equity_year_ends ~init:(rd.initial_capital, [])
      ~f:(fun (pt_prev, acc) (year, pt_end) ->
        let st, lt =
          match config.mode with
          | Tax_config.Mtm_flat -> (pt_end -. pt_prev, 0.)
          | Tax_config.Realized_st_lt ->
              Hashtbl.find by_year year |> Option.value ~default:(0., 0.)
        in
        (pt_end, (year, pt_prev, pt_end, st, lt) :: acc))
  in
  List.rev rev

let _step_row ~st_rate ~lt_rate ~carryforward (at, cf, rows)
    (year, pt_start, pt_end, st, lt) =
  let raw_tax, cf' = year_tax ~st_rate ~lt_rate ~carryforward ~cf ~st ~lt in
  let r = (pt_end /. pt_start) -. 1. in
  let scale = at /. pt_start in
  let paid_tax = raw_tax *. scale in
  let at' = (at *. (1. +. r)) -. paid_tax in
  let row =
    {
      year;
      pretax_end = pt_end;
      aftertax_end = at';
      st_gain = st;
      lt_gain = lt;
      raw_tax;
      paid_tax;
      carryforward_end = cf';
    }
  in
  (at', cf', row :: rows)

let _cagr ~final ~initial ~years =
  if Float.(years <= 0.) || Float.(initial <= 0.) || Float.(final <= 0.) then
    Float.nan
  else ((final /. initial) ** (1. /. years)) -. 1.

let simulate (config : Tax_config.t) (rd : T.run_data) =
  let st_rate, lt_rate = Tax_config.effective_rates config in
  let years = _per_year config rd in
  let at_final, _cf, rev_rows =
    List.fold years
      ~init:(rd.initial_capital, 0., [])
      ~f:(_step_row ~st_rate ~lt_rate ~carryforward:config.carryforward)
  in
  let rows = List.rev rev_rows in
  let pretax_final =
    List.last rows
    |> Option.value_map ~default:rd.initial_capital ~f:(fun r -> r.pretax_end)
  in
  let total_tax_paid = List.sum (module Float) rows ~f:(fun r -> r.paid_tax) in
  let total_realized_pnl =
    List.sum (module Float) rd.trades ~f:(fun t -> t.pnl)
  in
  {
    config;
    rows;
    pretax_final;
    aftertax_final = at_final;
    pretax_cagr =
      _cagr ~final:pretax_final ~initial:rd.initial_capital ~years:rd.span_years;
    aftertax_cagr =
      _cagr ~final:at_final ~initial:rd.initial_capital ~years:rd.span_years;
    total_tax_paid;
    total_realized_pnl;
    final_unrealized = pretax_final -. rd.initial_capital -. total_realized_pnl;
  }

open Core

type t = {
  started_at : float;
  updated_at : float;
  cycles_done : int;
  cycles_total : int;
  last_completed_date : Date.t;
  trades_so_far : int;
  current_equity : float;
}
[@@deriving sexp]

let write_atomic ~path progress =
  let tmp = path ^ ".tmp" in
  try
    let data = Sexp.to_string_hum (sexp_of_t progress) in
    Out_channel.write_all tmp ~data;
    Stdlib.Sys.rename tmp path
  with Sys_error msg | Failure msg -> (
    eprintf "backtest_progress: write failed at %s: %s\n%!" path msg;
    try Stdlib.Sys.remove tmp with _ -> ())

let count_fridays_in_range ~start_date ~end_date =
  let rec loop d acc =
    if Date.( > ) d end_date then acc
    else
      let acc' =
        if Day_of_week.equal (Date.day_of_week d) Day_of_week.Fri then acc + 1
        else acc
      in
      loop (Date.add_days d 1) acc'
  in
  loop start_date 0

type emitter = { every_n_fridays : int; on_progress : t -> unit }

type accumulator = {
  cycles_total : int;
  emitter : emitter option;
  started_at : float;
  mutable cycles_done : int;
  mutable trades_so_far : int;
  mutable last_step : (Date.t * float) option;
}

let create_accumulator ~cycles_total ?emitter () =
  {
    cycles_total;
    emitter;
    started_at = Core_unix.time ();
    cycles_done = 0;
    trades_so_far = 0;
    last_step = None;
  }

let _is_friday date = Day_of_week.equal (Date.day_of_week date) Day_of_week.Fri

let _build acc ~date ~portfolio_value =
  {
    started_at = acc.started_at;
    updated_at = Core_unix.time ();
    cycles_done = acc.cycles_done;
    cycles_total = acc.cycles_total;
    last_completed_date = date;
    trades_so_far = acc.trades_so_far;
    current_equity = portfolio_value;
  }

let _should_emit acc ~date e =
  _is_friday date && acc.cycles_done > 0
  && acc.cycles_done mod e.every_n_fridays = 0

let record_step acc ~date ~trades_added ~portfolio_value =
  acc.trades_so_far <- acc.trades_so_far + trades_added;
  if _is_friday date then acc.cycles_done <- acc.cycles_done + 1;
  acc.last_step <- Some (date, portfolio_value);
  match acc.emitter with
  | None -> ()
  | Some e ->
      if _should_emit acc ~date e then
        e.on_progress (_build acc ~date ~portfolio_value)

let emit_final acc =
  match (acc.emitter, acc.last_step) with
  | Some e, Some (date, portfolio_value) ->
      e.on_progress (_build acc ~date ~portfolio_value)
  | _ -> ()

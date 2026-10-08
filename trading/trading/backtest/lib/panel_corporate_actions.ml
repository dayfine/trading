open Core

(* Files are read lazily per held symbol from [data_dir], from [start_date]
   on. *)
let dividend_crediting ~(config : Weinstein_strategy.config) ~data_dir
    ~start_date =
  Option.some_if config.dividend_crediting
    (Trading_simulation_dividends.Dividend_crediting.of_data_dir ~data_dir
       ~start_date)

(* Files are read lazily, only for a symbol on which a split is detected. *)
let split_guard ~(config : Weinstein_strategy.config) ~data_dir =
  Option.some_if config.split_dividend_guard
    (Split_dividend_guard.of_data_dir ~data_dir ())

let guard_bar_reader guard reader =
  match guard with
  | None -> reader
  | Some g -> Weinstein_strategy.Bar_reader.with_split_guard reader g

let split_guard_summary guard =
  let c = Split_dividend_guard.counts guard in
  sprintf "Panel_runner: split_dividend_guard rejected=%d no_files=%d"
    c.rejected c.no_files

let log_split_guard guard =
  Option.iter guard ~f:(fun g -> eprintf "%s\n%!" (split_guard_summary g))

(* Files are read lazily, only for a held long. *)
let ex_dividend_stops ~(config : Weinstein_strategy.config) ~data_dir =
  Option.some_if config.ex_dividend_stop_adjust
    (Ex_dividend_stop.of_data_dir ~data_dir)

let ex_dividend_stops_summary eds =
  let c = Ex_dividend_stop.counts eds in
  sprintf
    "Panel_runner: ex_dividend_stop_adjust reduced=%d skipped_no_amount=%d \
     no_files=%d"
    c.reduced c.skipped_no_amount c.no_files

type t = {
  split_guard : Split_dividend_guard.t option;
  ex_dividend_stops : Ex_dividend_stop.t option;
}

let create ~config ~data_dir =
  {
    split_guard = split_guard ~config ~data_dir;
    ex_dividend_stops = ex_dividend_stops ~config ~data_dir;
  }

let arm_bar_reader t reader =
  let reader = guard_bar_reader t.split_guard reader in
  match t.ex_dividend_stops with
  | None -> reader
  | Some eds -> Weinstein_strategy.Bar_reader.with_ex_dividend_stops reader eds

let log t =
  log_split_guard t.split_guard;
  Option.iter t.ex_dividend_stops ~f:(fun eds ->
      eprintf "%s\n%!" (ex_dividend_stops_summary eds))

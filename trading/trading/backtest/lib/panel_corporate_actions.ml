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

(** The per-run readers of the vendor corporate-action files ([dividends.csv] /
    [splits.csv] under [TRADING_DATA_DIR], never the snapshot warehouse) that
    {!Panel_runner} hands to the simulator and the strategy. Each is armed by a
    default-off config flag; unarmed, nothing is read. *)

open Core

val dividend_crediting :
  config:Weinstein_strategy.config ->
  data_dir:Fpath.t ->
  start_date:Date.t ->
  Trading_simulation_dividends.Dividend_crediting.t option
(** #3137: [Some] fresh crediting state from [start_date] iff
    [config.dividend_crediting]; [None] otherwise. *)

val split_guard :
  config:Weinstein_strategy.config ->
  data_dir:Fpath.t ->
  Split_dividend_guard.t option
(** #3173: [Some] fresh guard (default {!Split_dividend_guard.config}) iff
    [config.split_dividend_guard]; [None] otherwise. One value per run, shared
    by the simulator and the strategy so a rejected event counts once. *)

val guard_bar_reader :
  Split_dividend_guard.t option ->
  Weinstein_strategy.Bar_reader.t ->
  Weinstein_strategy.Bar_reader.t
(** [guard_bar_reader guard reader] is [reader] with the guard attached
    ({!Weinstein_strategy.Bar_reader.with_split_guard}), or [reader] itself
    (physically) when [guard] is [None]. *)

val split_guard_summary : Split_dividend_guard.t -> string
(** One stderr line with the run's guard counts:
    ["Panel_runner: split_dividend_guard rejected=<n> no_files=<m>"]. *)

val log_split_guard : Split_dividend_guard.t option -> unit
(** Prints {!split_guard_summary} to stderr when armed; nothing otherwise. *)

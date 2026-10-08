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

val ex_dividend_stops :
  config:Weinstein_strategy.config ->
  data_dir:Fpath.t ->
  Ex_dividend_stop.t option
(** #3174: [Some] fresh ex-dividend stop reducer iff
    [config.ex_dividend_stop_adjust]; [None] otherwise. *)

val ex_dividend_stops_summary : Ex_dividend_stop.t -> string
(** One stderr line with the run's reducer counts:
    ["Panel_runner: ex_dividend_stop_adjust reduced=<n> skipped_no_amount=<k>
     no_files=<m>"]. *)

type t = {
  split_guard : Split_dividend_guard.t option;
      (** {!split_guard}: shared by the simulator and the strategy. *)
  ex_dividend_stops : Ex_dividend_stop.t option;
      (** {!ex_dividend_stops}: strategy side only (the stop state). *)
}
(** The strategy-and-simulator corporate-action readers of one run. *)

val create : config:Weinstein_strategy.config -> data_dir:Fpath.t -> t
(** Both readers, each [Some] only when its flag is on. *)

val arm_bar_reader :
  t -> Weinstein_strategy.Bar_reader.t -> Weinstein_strategy.Bar_reader.t
(** [arm_bar_reader t reader] attaches the split guard ({!guard_bar_reader}) and
    the ex-dividend reducer
    ({!Weinstein_strategy.Bar_reader.with_ex_dividend_stops}) present in [t];
    [reader] itself (physically) when both are [None]. *)

val log : t -> unit
(** {!log_split_guard}, then {!ex_dividend_stops_summary} when armed. *)

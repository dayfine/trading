(** One pass over one symbol's stored bars for the dollar-volume basis
    measurement (issue #3136, [dollar_volume_measurement.exe]).

    For each symbol it reads [data.csv] and [splits.csv] once and returns
    everything the report needs: the PIT ranking score on both bases for every
    reconstitution year the symbol is active in, the bars the true-dollar basis
    rejects, how the vendor's splits line up with the stored closes and volumes,
    and how often the strategy's entry liquidity gate would decide differently
    on the true basis. *)

open Core

type params = {
  years : int list;  (** Reconstitution years ([YYYY-05-31] anchors). *)
  trailing_window_days : int;  (** As {!Universe.Build_from_individuals}. *)
  min_window_bars : int;  (** As {!Universe.Build_from_individuals}. *)
  basis : Universe.Dollar_volume_basis.config;
      (** The true-dollar config (cap, split confirmation, volume check). *)
  liquidity_floor : float;
      (** Entry-gate floor in dollars (the strategy default is [1e6]). *)
  liquidity_lookback_bars : int;
      (** Bars in the gate's trailing mean (strategy default [20]). *)
}
(** Measurement knobs; all mirror a builder or strategy default. *)

type year_score = {
  year : int;
  legacy : float option;  (** Stored [close * volume] score. *)
  truth : float option;  (** True-dollar score. *)
}
(** Ranking scores at one reconstitution date. *)

type liquidity_year = {
  cal_year : int;
  weeks : int;  (** Week-end bars checked while a governing-list member. *)
  lost : int;  (** Passes the floor on the stored basis, fails on true. *)
  gained : int;  (** Fails on the stored basis, passes on true. *)
}
(** Entry-gate decisions per calendar year. *)

type t = {
  symbol : string;
  has_splits_file : bool;  (** [false]: scored with [F = 1]. *)
  vendor_splits : Corporate_actions.split list;
  confirmed : Corporate_actions.split list;
      (** The vendor splits the raw close confirms
          ({!Universe.Dollar_volume_basis.close_confirmed_splits}). *)
  applied : Corporate_actions.split list;
      (** [confirmed] less those whose volume is raw: the splits [F] divides by
          ({!Universe.Dollar_volume_basis.applied_splits}). *)
  volume_jump_shares : float list;
      (** {!Universe.Dollar_volume_basis.volume_jump_share} of each confirmed
          split large enough for the volume check to act on: [0.0] means the
          stored volume is flat across the split (restated), [1.0] means it
          jumps by the full factor (raw). *)
  scores : year_score list;
  rejected : (Universe.Composition_bar_reader.bar * float) list;
      (** In-window bars rejected as implausible, deduplicated, by date. *)
  liquidity : liquidity_year list;
}
(** Scan result for one symbol. *)

val governing_list_year : Date.t -> int
(** [governing_list_year d] is the year [y] of the list dated [y-05-31] that
    governs [d]: the list governs from the day after its date through the next
    list's date. *)

val liquidity_flips :
  params ->
  splits:Corporate_actions.split list ->
  is_member:(int -> bool) ->
  Universe.Composition_bar_reader.bar array ->
  liquidity_year list
(** [liquidity_flips params ~splits ~is_member bars] evaluates the entry gate on
    the last bar of each week, using the trailing mean of the last
    [liquidity_lookback_bars] bars (fewer when fewer exist), on both bases. Only
    weeks whose {!governing_list_year} satisfies [is_member] count. Calendar
    years with no counted week are omitted. *)

val retry_read : (unit -> 'a option) -> 'a option
(** [retry_read f] calls [f] until it returns [Some _], at most 3 times with a
    0.2 s pause between attempts. The container's bind mount of the store
    intermittently reports a present file or directory as missing; a read that
    fails three times is treated as absent. *)

val scan :
  params -> bars_root:string -> is_member:(int -> bool) -> string -> t option
(** [scan params ~bars_root ~is_member symbol] reads [symbol]'s bars and splits
    and builds {!t}. [scores] covers the [params.years] at which the symbol is
    active as the builder's inventory filter reads it: its first bar is on or
    before [date - trailing_window_days] and its last bar on or after [date]
    (activity is read from the bars, not an inventory file). [None] when
    [data.csv] is missing or unparseable. *)

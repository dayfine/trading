(** Dollar volume on one basis: true dollars traded at the time (issue #3136).

    The bar store's [volume] column is, for most splits, restated in today's
    share count, while its [close] column is raw (the price printed that day).
    Their product, which {!Build_from_individuals} used to rank the PIT lists,
    is therefore off by the cumulative split factor after the bar: AMZN on
    2018-06-14 (before its 2022 20:1 split) reads 20x its true dollar volume, C
    on 2010-06-14 (before its 2011 1:10 reverse split) reads 1/10.

    {1 The basis}

    True dollar volume on day [t] is [close_t *. volume_t /. F(t)], where [F(t)]
    is the product of the factors ([new_shares /. old_shares], see
    {!Corporate_actions.split}) of every applied split dated strictly after [t].
    The split day itself already trades on the post-split share count, so its
    own factor is not in [F]. That equals raw close times raw volume, and
    split-only-adjusted close times split-adjusted volume.

    {1 Which splits are applied}

    A vendor split is applied only when the raw close confirms it: across some
    bar near the split date (the first bar on or after it, or up to
    [split_search_bars] bars either side, nearest first) the close moves by the
    split factor against the bar before ({!confirms_split}). The applied split
    is re-dated to that bar, which absorbs vendor dates that fall on a holiday
    or a day off the store's ex-date. Two store shapes fail that test and are
    ignored: a split the vendor records but the price never shows (a bogus
    event; neither close nor volume was restated), and a symbol whose [close]
    column is already split-adjusted (some delisted names), where
    [close *. volume] is already the true figure. Dividing those by [F] would
    move a correct number by the split factor.

    A close-confirmed split is then dropped when the stored volume shows it was
    not restated for that split: the factor is large
    ([|log factor| >= volume_raw_min_log_factor], default 3:1 or 1:3) and the
    median volume jumps by at least [volume_raw_min_share] of the factor in log
    terms across it ({!volume_jump_share}). Raw close times raw volume is
    already the true figure, so dividing it by [F] is wrong. The store has such
    symbols (OHGI: a 1:1500 reverse split in 2006 where volume falls from about
    187M to 55k shares). For smaller factors the check is too noisy to act on
    (ordinary volume moves are as large as the factor), so they are assumed
    restated, which most splits are.

    {1 Implausible bars}

    A bar whose true dollar volume is not finite, is negative, or exceeds
    [max_bar_dollar_volume] is rejected: dropped from the window average and
    returned in {!window_score.rejected} so callers can list it. The default cap
    is [2e11] ($200 billion in one day), about twice the largest real US
    single-stock day (NVDA, March 2024, about $100 billion). The issue's
    specimens (COMP_old, VEXPQ, OCHTQ) print $0.3 to $60 trillion a day. *)

open Core

type t =
  | Close_times_volume
      (** [close *. volume] as stored: raw close times split-adjusted volume.
          The pre-#3136 behaviour; no split file is read and no bar rejected. *)
  | True_dollars
      (** [close *. volume /. F(t)] over the applied splits, with implausible
          bars rejected. *)
[@@deriving sexp, eq, show]

type config = {
  basis : t;  (** Which basis to score on. *)
  max_bar_dollar_volume : float;
      (** Reject cap for one bar, in dollars, applied under {!True_dollars}. *)
  split_confirm_log_tolerance : float;
      (** Largest [|log (observed_jump /. factor)|] at which the raw close
          confirms a split. *)
  split_search_bars : int;
      (** Bars either side of a split's first on-or-after bar searched for the
          confirming close jump. *)
  volume_check_bars : int;
      (** Bars each side of a split whose median volumes {!volume_jump_share}
          compares. *)
  volume_raw_min_log_factor : float;
      (** Smallest [|log factor|] at which the volume check can drop a split. *)
  volume_raw_min_share : float;
      (** Jump share at or above which the volume counts as raw. *)
}
[@@deriving sexp, eq, show]

val default_max_bar_dollar_volume : float
(** [2e11]. *)

val default_split_confirm_log_tolerance : float
(** [0.2] (the jump within about 22 % of the factor). *)

val default_split_search_bars : int
(** [2]. *)

val default_volume_check_bars : int
(** [10]. *)

val default_volume_raw_min_log_factor : float
(** [log 3]. *)

val default_volume_raw_min_share : float
(** [0.5]: nearer a full jump than none. *)

val legacy_config : config
(** {!Close_times_volume} with the default knobs: the behaviour every existing
    caller had. *)

val true_dollars_config : config
(** {!True_dollars} with the default knobs. *)

val confirms_split :
  log_tolerance:float -> prev_close:float -> close:float -> float -> bool
(** [confirms_split ~log_tolerance ~prev_close ~close factor] is [true] when the
    raw close jump [prev_close /. close] matches [factor]: it lies within
    [log_tolerance] of [factor] in log terms and is nearer [factor] than [1.0].
    [false] when either close is not positive. *)

val close_confirmed_splits :
  config ->
  Composition_bar_reader.bar list ->
  Corporate_actions.split list ->
  Corporate_actions.split list
(** [close_confirmed_splits config bars splits] keeps the splits the raw close
    confirms (see the module doc), each re-dated to its confirming bar, sorted
    by date. Dropped: a split with no confirming bar in the search, a split
    dated after the last bar, and a split dated before the first bar (no bar
    before it, so it scales nothing in [bars]). [bars] must be sorted by date.
*)

val volume_jump_share :
  config ->
  Composition_bar_reader.bar list ->
  Corporate_actions.split ->
  float option
(** [volume_jump_share config bars split] is
    [log (after /. before) /. log split.factor], where [before] and [after] are
    the median positive volumes of the [volume_check_bars] bars before the
    split's bar and of the bars from it on: about [0.0] when the stored volume
    is restated for the split, about [1.0] when it is raw. [None] when no bar is
    dated on the split, the factor is [1.0], or either side has fewer than half
    its bars with a positive volume. *)

val volume_restated :
  config -> Composition_bar_reader.bar list -> Corporate_actions.split -> bool
(** [volume_restated config bars split] is [false] only when
    [|log split.factor| >= volume_raw_min_log_factor] and {!volume_jump_share}
    is [Some s] with [s >= volume_raw_min_share]. *)

val applied_splits :
  config ->
  Composition_bar_reader.bar list ->
  Corporate_actions.split list ->
  Corporate_actions.split list
(** [applied_splits config bars splits] is {!close_confirmed_splits} filtered by
    {!volume_restated}: the splits [F] divides by. *)

val split_divisor : splits:Corporate_actions.split list -> Date.t -> float
(** [split_divisor ~splits date] is [F(date)]: the product of the factors of
    every split in [splits] dated strictly after [date]; [1.0] when none. *)

val bar_dollar_volume :
  t ->
  splits:Corporate_actions.split list ->
  Composition_bar_reader.bar ->
  float
(** [bar_dollar_volume basis ~splits bar] is [close *. volume] under
    {!Close_times_volume} (ignoring [splits]) and
    [close *. volume /. split_divisor ~splits bar.date] under {!True_dollars}.
    [splits] should already be {!applied_splits}. *)

type window_score = {
  avg : float option;
      (** Mean dollar volume over the kept bars in the window; [None] when fewer
          than [min_window_bars] bars were kept. *)
  rejected : (Composition_bar_reader.bar * float) list;
      (** In-window bars rejected as implausible, with their dollar volume, in
          date order. Always empty under {!Close_times_volume}. *)
}
(** Result of {!score_window}. *)

val score_window :
  config ->
  splits:Corporate_actions.split list ->
  date:Date.t ->
  trailing_window_days:int ->
  min_window_bars:int ->
  Composition_bar_reader.bar list ->
  window_score
(** [score_window config ~splits ~date ~trailing_window_days ~min_window_bars
     bars] windows [bars] to [[date - trailing_window_days, date]], scores each
    with {!bar_dollar_volume}, rejects implausible bars under {!True_dollars}
    (see the module doc), and averages the rest. Under {!Close_times_volume}
    this is exactly the pre-#3136 score. *)

val read_applied_splits :
  config ->
  bars_root:string ->
  string ->
  Composition_bar_reader.bar list ->
  Corporate_actions.split list option
(** [read_applied_splits config ~bars_root symbol bars] reads [symbol]'s
    [splits.csv] and returns [Some (applied_splits ...)] of it. A missing or
    unreadable file returns [None]; callers treat that as no splits ([F = 1])
    and may count it. Under {!Close_times_volume} it returns [Some []] without
    touching the disk. *)

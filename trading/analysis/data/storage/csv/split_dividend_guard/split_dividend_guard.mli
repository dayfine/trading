(** Reject a detected split that is really a cash dividend (issue #3173).

    {b The defect.} {!Types.Split_detector.detect_split} infers a split factor
    from [adj_ratio /. raw_ratio] between two bars. A cash dividend [D] on a
    prior close [P] produces exactly [P /. (P -. D)] there. When that ratio is
    more than 5 % from 1 and happens to land within the snap tolerance of a
    small rational, the detector reports a split. Specimens from the 26y run:
    TDG 2013-07-11 ($22.00 special, [160.80 /. 138.80 = 1.1585] snapped to
    [22/19]), WING 2018-02-08 ($3.17, [1.0705] to [15/14]), BCH 2010-03-17
    ($3.90, [1.0719] to [15/14]). Held positions then gained phantom shares
    worth the dividend, and with dividend crediting armed the same dividend was
    also credited as cash. The #3105 raw-gap check cannot catch this, because a
    cash dividend does move the raw close.

    {b The rule.} A detected split of [factor] on bar [date] with prior raw
    close [prev_close] is a dividend, and is rejected, iff all three hold:
    - the symbol's [dividends.csv] has a row whose [ex_date] is within
      [window_bars] bars of [date];
    - the symbol's [splits.csv] has {e no} row within [window_bars] bars of
      [date] (a vendor split wins: the split is applied even when a dividend
      shares its date);
    - that dividend's implied factor [prev_close /. (prev_close -. amount)] is
      within [factor_tolerance] (absolute) of [factor]. [amount] is
      [unadjusted_amount], or [adjusted_amount] when the vendor did not report
      the unadjusted one. The adjusted amount is restated down for later splits,
      so the fallback can only fail to match, never match a wrong amount.

    {b Bars.} The guard has no trading calendar, so a bar distance is the count
    of weekdays between the two dates ([Date.diff_weekdays]). Exchange holidays
    are not removed, so around a holiday the window is one bar narrower than
    [window_bars] trading bars.

    {b Missing data.} When either file is absent for a symbol (never fetched),
    or cannot be parsed, the detected split is kept, i.e. the behaviour is
    unchanged, and the symbol is counted once in {!counts}. Files are read
    lazily, only for a symbol on which a split is detected, and cached for the
    life of the value. *)

open Core

type config = {
  window_bars : int;
      (** Bars either side of the detected date searched for vendor dividend and
          split rows. Default 2. *)
  factor_tolerance : float;
      (** Largest absolute gap between the detected factor and the dividend's
          implied factor [P /. (P -. D)] for the two to be the same event.
          Default 0.01: the detector's snap moves the factor by at most 1e-3,
          and a real split's factor (at least 1.5 or at most 0.67 in practice)
          is far from any dividend's implied factor unless the dividend is a
          third of the price. *)
}
[@@deriving show, eq]

val default_config : config
(** [{ window_bars = 2; factor_tolerance = 0.01 }]. *)

val implied_factor : prev_close:float -> amount:float -> float option
(** [implied_factor ~prev_close ~amount] is
    [prev_close /. (prev_close -. amount)], the factor a cash dividend of
    [amount] makes the split detector see. [None] unless
    [0 < amount < prev_close]. *)

val is_dividend_not_split :
  ?config:config ->
  date:Date.t ->
  prev_close:float ->
  factor:float ->
  dividends:Corporate_actions.dividend list ->
  splits:Corporate_actions.split list ->
  unit ->
  bool
(** The pure rule from the module doc: [true] means the detected split of
    [factor] on [date] is the dividend and must not be applied. *)

type loader = string -> Corporate_actions.dividend list Status.status_or
(** Reads one symbol's dividends; [NotFound] means "no file". *)

type split_loader = string -> Corporate_actions.split list Status.status_or
(** Reads one symbol's splits; [NotFound] means "no file". *)

type t
(** Per-run state: the loaders, a per-symbol cache and the counts. *)

val create :
  ?config:config ->
  load_dividends:loader ->
  load_splits:split_loader ->
  unit ->
  t
(** Fresh state. Each loader is called at most once per symbol. *)

val of_data_dir : ?config:config -> data_dir:Fpath.t -> unit -> t
(** {!create} reading [dividends.csv] / [splits.csv] from the [TRADING_DATA_DIR]
    store [data_dir] ({!Corporate_actions.read_dividends} /
    {!Corporate_actions.read_splits}), not the snapshot warehouse. *)

val filter :
  t ->
  symbol:string ->
  date:Date.t ->
  prev_close:float ->
  float option ->
  float option
(** [filter t ~symbol ~date ~prev_close detected] passes [None] through without
    reading a file. For [Some factor] it loads the symbol's files and returns
    [None] when {!is_dividend_not_split} holds, [Some factor] otherwise
    (including when the files are missing or unreadable). *)

type counts = {
  rejected : int;
      (** Distinct [(symbol, date)] detected splits rejected as dividends. The
          simulator and the strategy both ask about the same event; it counts
          once. *)
  no_files : int;
      (** Distinct symbols with a detected split but a missing or unreadable
          [dividends.csv] or [splits.csv]; their splits were kept. *)
}
[@@deriving show, eq]

val counts : t -> counts
(** Counts so far. *)

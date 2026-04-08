(** Synthetic data source for deterministic simulation tests.

    Generates programmatic OHLCV bars without any file I/O or network access.
    All bar patterns are deterministic: same config + same query = same bars.

    Use this in unit tests and smoke tests for the Weinstein strategy and
    simulator instead of relying on cached CSV data from disk.

    {1 Bar patterns}

    - {b Trending}: bars trend upward at a configurable rate, with small daily
      noise. Models a Stage 2 advance.
    - {b Basing}: bars oscillate within a narrow range around a base price.
      Models a Stage 1 base-building period.
    - {b Breakout}: starts with a basing period then transitions to trending.
      Models the Stage 1→2 breakout pattern that the screener targets.
    - {b Declining}: bars trend downward. Models a Stage 3/4 decline. *)

open Core

(** Parameters for a single symbol's synthetic price series. *)
type symbol_pattern =
  | Trending of {
      start_price : float;  (** Price at [start_date]. *)
      weekly_gain_pct : float;
          (** Fractional weekly gain, e.g. 0.01 for 1% per week. *)
      volume : int;  (** Constant bar volume (use > 0). *)
    }  (** Steady uptrend — models a Stage 2 advance. *)
  | Basing of {
      base_price : float;  (** Centre of the oscillation range. *)
      noise_pct : float;
          (** Half-range of random oscillation as a fraction of [base_price],
              e.g. 0.02 for ±2%. *)
      volume : int;  (** Constant bar volume. *)
    }  (** Sideways consolidation — models a Stage 1 base. *)
  | Breakout of {
      base_price : float;  (** Price during the basing phase. *)
      base_weeks : int;  (** Number of basing bars before the breakout. *)
      weekly_gain_pct : float;
          (** Fractional weekly gain after the breakout. *)
      breakout_volume_mult : float;
          (** Volume multiplier on the breakout bar (e.g. 2.5 for 2.5× base). *)
      base_volume : int;  (** Volume during basing. *)
    }  (** Basing then breakout — the classic Stage 1→2 pattern. *)
  | Declining of {
      start_price : float;  (** Price at [start_date]. *)
      weekly_loss_pct : float;
          (** Fractional weekly loss, e.g. 0.01 for 1% decline per week. *)
      volume : int;  (** Constant bar volume. *)
    }  (** Steady downtrend — models a Stage 3/4 decline. *)

type config = {
  start_date : Date.t;
      (** First bar date. Bars are generated daily (weekdays only). *)
  symbols : (string * symbol_pattern) list;
      (** Per-symbol pattern specifications. [get_universe] returns exactly
          these symbols (with placeholder metadata). *)
}
[@@deriving show, eq]
(** Configuration for the synthetic data source. *)

val make : config -> (module Data_source.DATA_SOURCE)
(** [make config] returns a [DATA_SOURCE] backed by synthetic bar generation.

    [get_bars ~query ()] generates bars from [config.start_date] up to
    [query.end_date] (or all available if [None]) for the given symbol. Returns
    [Error NotFound] if the symbol is not in [config.symbols].

    [get_universe ()] returns one [Instrument_info.t] per symbol in
    [config.symbols] with placeholder sector/industry metadata.

    No file I/O, no network calls. Safe to use in any test. *)

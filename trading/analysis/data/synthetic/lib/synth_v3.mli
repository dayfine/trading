(** Synth-v3 — multi-symbol synthetic universe generator.

    Composes a [Synth_v2] market series with [Factor_model]'s single-factor
    cross-section to emit a deterministic universe of OHLCV bar series.

    Pipeline:
    {v
      1. run Synth-v2 with [config.market] to produce market bars
      2. extract market log-returns from the bar list
      3. sample n_symbols β values from [config.loading_distribution]
      4. sample n_symbols idio GARCH params from [config.idio_distribution]
      5. for each symbol i: compose log-returns via Factor_model.generate_symbol_returns,
         then build a per-symbol OHLCV bar list reusing the market's date sequence
         and [config.start_price]
    v}

    All symbols share the same date sequence — the universe is calendar-aligned
    by construction.

    Determinism (seed cascade):
    - [config.seed] flows into Synth-v2 (Synth-v2 uses [seed] and [seed + 1]
      internally)
    - [config.seed + 100_000] seeds β sampling
    - [config.seed + 200_000] seeds idio-parameter sampling
    - [config.seed + 1_000_000 + i] seeds symbol-[i]'s idio return stream

    The offsets are spaced widely so even adversarial seed choices keep streams
    independent. *)

type config = {
  n_symbols : int;  (** Number of symbols in the universe, must be > 0. *)
  symbols : string list option;
      (** Optional explicit symbol names. When [None], [Synth_v3] emits
          deterministic names [SYNTH_0001], [SYNTH_0002], …. When [Some lst],
          the length of [lst] must equal [n_symbols]. *)
  market : Synth_v2.config;
      (** Market-series config. The market's [target_length_days] sets the
          length of every per-symbol bar list. *)
  loading_distribution : Factor_model.loading_distribution;
      (** β-factor cross-section distribution. *)
  idio_distribution : Factor_model.idio_distribution;
      (** Per-symbol idiosyncratic GARCH distribution. *)
  start_price : float;
      (** Starting close price for every symbol's bar series. Must be > 0. We do
          not vary per-symbol start price; the focus is on return structure. *)
  seed : int;  (** Master seed for the universe; see seed cascade above. *)
}

type universe = {
  symbols : (string * Types.Daily_price.t list) list;
      (** Per-symbol bar series, in input order. *)
}

val default_symbol_names : n:int -> string list
(** [default_symbol_names ~n] returns [["SYNTH_0001"; ...; "SYNTH_N"]] for
    [n > 0]. Returns the empty list when [n <= 0]. Padded to 4 digits to keep
    the name length stable at universe sizes up to 9_999; symbols beyond that
    use the bare integer (no truncation). *)

val default_config :
  n_symbols:int ->
  start_date:Core.Date.t ->
  start_price:float ->
  target_length_days:int ->
  seed:int ->
  config
(** Convenience constructor: wraps [Synth_v2.default_config] for the market and
    pairs it with [Factor_model.default_loading_distribution] and
    [Factor_model.default_idio_distribution]. Uses [default_symbol_names] for
    symbol naming. *)

val generate : config -> (universe, Status.t) Result.t
(** [generate config] returns a synthetic universe of [config.n_symbols] bar
    series, each of length [config.market.target_length_days].

    Returns [Error Status.Invalid_argument] when:
    - [config.n_symbols <= 0];
    - [config.start_price <= 0];
    - [config.symbols] is [Some lst] and [List.length lst <> config.n_symbols];
    - [config.market] fails [Synth_v2.generate]'s validation;
    - [config.loading_distribution] fails
      [Factor_model.validate_loading_distribution];
    - [config.idio_distribution] fails
      [Factor_model.validate_idio_distribution]. *)

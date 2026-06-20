val min_stop_distance_for :
  config:Weinstein_strategy_config.config ->
  bar_reader:Bar_reader.t ->
  current_date:Core.Date.t ->
  Screener.scored_candidate ->
  float
(** Per-candidate minimum installed-stop distance. The base floor is the
    screener's [installed_stop_min_pct]; when
    [stops_config.vol_scaled_stop_atr_mult > 0.0] it is widened in proportion to
    the candidate's ATR over its recent daily bars (default-off — exact no-op
    when the mult is [0.0], so the base floor passes through unchanged and every
    golden replays bit-identically). [entry_price] mirrors
    [Entry_audit_helpers.effective_entry_price]: the most recent raw close (the
    price sizing/stops key off), falling back to [cand.suggested_entry] when no
    bars are resident. See {!Weinstein_stops.Vol_scaled_stop}. *)

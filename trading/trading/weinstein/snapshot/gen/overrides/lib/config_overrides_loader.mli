(** Load config-overlay sexps from a file and apply them onto a
    [Weinstein_strategy.config] — the live-arming counterpart of a backtest
    scenario's [config_overrides] field.

    The file contains zero or more top-level overlay sexps, each in the same
    shape the scenario / sweep machinery consumes, e.g.:

    {[
    (extension_stop_config ((trigger_ratio 2.0) (trail_pct 0.25)))
      (reject_declining_ma_long_entry true)
    ]}

    Overlays are deep-merged left-to-right via
    [Backtest.Overlay_validator.apply_overrides], so an overlay key that does
    not resolve to a real config field raises [Failure] (never a silent no-op),
    exactly as in scenario runs. *)

val load_and_apply :
  overrides_path:string ->
  Weinstein_strategy.config ->
  Weinstein_strategy.config
(** [load_and_apply ~overrides_path config] parses every top-level sexp in
    [overrides_path] as one overlay and deep-merges them (left-to-right) into
    [config]. Raises [Failure] on an unreadable file, a malformed sexp, or an
    overlay key path that does not resolve to a real field. *)

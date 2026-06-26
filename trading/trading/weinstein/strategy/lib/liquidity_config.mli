(** Configuration for the liquidity-realism overlay.

    The overlay is a default-off risk/realism dial
    ([.claude/rules/experiment-flag-discipline.md]): the no-op default
    ([min_entry_dollar_adv = 0.0], [min_hold_dollar_adv = 0.0]) preserves prior
    behaviour bit-for-bit — the entry gate passes every candidate and the
    held-position degradation exit never fires. Both thresholds are real config
    fields, so each is expressible as a {!Variant_matrix} axis, e.g.
    [((key (liquidity_config min_hold_dollar_adv)) (values (0.0 1000000.0)))].

    Motivation: a delisted micro-cap held into illiquidity (e.g. ELCO trading ~2
    shares/day) produced a fake −48% single-day NAV crash when a spurious
    high-tick tripped the short stop's worst-case cover fill. The fix is to
    detect the liquidity degradation from data available at decision time and
    exit before the name becomes untradeable. See
    [dev/notes/liquidity-realism-overlay-2026-06-26.md]. *)

type t = {
  adv_lookback_days : int;
      (** Trailing window (in daily bars) over which dollar-ADV is averaged. A
          harmless positive default (e.g. 20) — it is only consulted when one of
          the thresholds below is positive. *)
  min_entry_dollar_adv : float;
      (** Entry gate: drop a long/short candidate whose trailing dollar-ADV is
          below this. [0.0] (default) disables the gate — every candidate
          passes. *)
  min_hold_dollar_adv : float;
      (** Held-position exit: emit a liquidity_exit transition for a held
          position whose trailing dollar-ADV falls below this. [0.0] (default)
          disables the exit — it never fires. *)
}
[@@deriving sexp]

val default_config : t
(** The no-op default: [adv_lookback_days = 20], [min_entry_dollar_adv = 0.0],
    [min_hold_dollar_adv = 0.0]. With this config the overlay changes no
    backtest result — bit-identical to pre-overlay behaviour. *)

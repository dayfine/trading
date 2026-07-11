(** Configuration for the liquidity-realism overlay.

    The overlay has two thresholds. The entry gate ([min_entry_dollar_adv]) is
    {b default-on} at [$1M] since the 2026-07-10 realism-defaults flip; the
    held-position degradation exit ([min_hold_dollar_adv]) remains
    {b default-off} ([0.0]). Both are real config fields, so each is expressible
    as a {!Variant_matrix} axis, e.g.
    [((key (liquidity_config min_hold_dollar_adv)) (values (0.0 1000000.0)))].

    Motivation: a delisted micro-cap held into illiquidity (e.g. ELCO trading ~2
    shares/day) produced a fake −48% single-day NAV crash when a spurious
    high-tick tripped the short stop's worst-case cover fill. The fix is to
    detect the liquidity degradation from data available at decision time and
    exit before the name becomes untradeable. See
    [dev/notes/liquidity-realism-overlay-2026-06-26.md].

    {b The 2026-07-10 entry-gate flip (0.0 -> 1e6, user mandate).} A REALISM /
    faithfulness basis change, {b not} an alpha promotion — same class as the
    warmup 210->364 re-pin ([dev/notes/warmup-364-repin-2026-07-08.md]) and the
    total-return-comparator rule. The simulator must not fill entry orders
    reality could not fill: the walk-forward fold metric CREDITS those fake
    fills as alpha (APPB fake +$540k at ~$9.5k/day ADV; the ELCO short-side
    twin; the 81-symbol corrupt/dust class of audit_bars #1900), so the WF
    metric {b cannot} judge this knob (estimand caveat,
    [dev/backtest/liquidity-overlay-wfcv-2026-07-10/FINDINGS.md]). At fold level
    the entry gate REDUCES simulated Sharpe/Calmar; it is promoted on
    faithfulness grounds notwithstanding, per that caveat (ledger
    [2026-07-10-realism-defaults-flip]). A static $1M gate is calibrated for
    ~$1-10M capital; at larger NAV, position-vs-ADV scaling is the real capacity
    model (documented follow-up, not this change). *)

type t = {
  adv_lookback_days : int;
      (** Trailing window (in daily bars) over which dollar-ADV is averaged. A
          harmless positive default (e.g. 20) — it is only consulted when one of
          the thresholds below is positive. *)
  min_entry_dollar_adv : float;
      (** Entry gate: drop a long/short candidate whose trailing dollar-ADV is
          below this. Default [1_000_000.0] (2026-07-10 realism flip): a
          candidate whose trailing dollar-ADV is below $1M is dropped, so the
          simulator never fills an entry reality could not fill. [0.0] disables
          the gate — every candidate passes (the pre-flip behaviour, kept as a
          searchable axis value). *)
  min_hold_dollar_adv : float;
      (** Held-position exit: emit a liquidity_exit transition for a held
          position whose trailing dollar-ADV falls below this. [0.0] (default,
          unchanged by the 2026-07-10 flip) disables the exit — it never fires.
          Its promotion is a separate evidence pipeline (leading WF-CV
          candidate; not this change). *)
}
[@@deriving sexp]

val default_config : t
(** The default: [adv_lookback_days = 20], [min_entry_dollar_adv = 1_000_000.0]
    (entry gate default-on since 2026-07-10), [min_hold_dollar_adv = 0.0] (exit
    default-off). The entry gate drops sub-$1M-ADV candidates; the held-position
    exit never fires. To reproduce pre-flip behaviour bit-for-bit, set
    [min_entry_dollar_adv = 0.0]. *)

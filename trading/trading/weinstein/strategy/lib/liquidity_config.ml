open Core

(* Default trailing window for the dollar-ADV average. Consulted whenever
   either threshold below is positive; with [default_min_entry_dollar_adv]
   positive by default (2026-07-10 realism flip) the entry gate averages over
   this window on every screen. *)
let default_adv_lookback_days = 20

(* Default entry-gate floor: $1M trailing dollar-ADV. Flipped 0.0 -> 1e6 on
   2026-07-10 (user mandate) as a REALISM/faithfulness basis change — the
   simulator must not FILL entry orders reality could not fill. Evidence: APPB
   fake +$540k at ~$9.5k/day ADV, its ELCO short-side twin, the 81-symbol
   corrupt/dust class (audit_bars #1900). A static $1M gate is calibrated for
   ~$1-10M capital; at larger NAV, position-vs-ADV scaling is the real capacity
   model (documented follow-up, not this change). See the [.mli]. *)
let default_min_entry_dollar_adv = 1_000_000.0

(* Default dollar-ADV aggregation: the arithmetic mean, i.e. exactly the
   pre-#2060 behaviour. The spoof-robust alternatives (Median / Trimmed_mean)
   are default-OFF and searchable per experiment-flag-discipline R1/R2 — no
   ledger ACCEPT exists for them yet. *)
let default_adv_aggregation = Liquidity_metric.Mean

(* Default trim fraction, consulted only when [adv_aggregation] is
   [Trimmed_mean]. Single source of truth lives with the metric. *)
let default_adv_trim_pct = Liquidity_metric.default_trim_pct

type t = {
  adv_lookback_days : int;
  min_entry_dollar_adv : float;
  min_hold_dollar_adv : float;
  adv_aggregation : Liquidity_metric.aggregation;
      [@sexp.default default_adv_aggregation]
  adv_trim_pct : float; [@sexp.default default_adv_trim_pct]
}
[@@deriving sexp]

let default_config =
  {
    adv_lookback_days = default_adv_lookback_days;
    min_entry_dollar_adv = default_min_entry_dollar_adv;
    min_hold_dollar_adv = 0.0;
    adv_aggregation = default_adv_aggregation;
    adv_trim_pct = default_adv_trim_pct;
  }

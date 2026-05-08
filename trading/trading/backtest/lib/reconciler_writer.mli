(** Reconciler-producer artefact writers.

    Writes the three CSVs consumed by the external [trading-reconciler] tool to
    verify cash-floor / held-through-split / unrealized-P&L accounting. Schemas
    are pinned by [~/Projects/trading-reconciler/PHASE_1_SPEC.md] §3 + §4 + §3.3
    — the reconciler exits 2 on any header drift. *)

val write_open_positions :
  output_dir:string ->
  steps:Trading_simulation_types.Simulator_types.step_result list ->
  unit
(** Write [open_positions.csv]: one row per position held at run end.
    PHASE_1_SPEC §3: [symbol,side,entry_date,entry_price,quantity]. Always
    written; header-only when no positions are held. *)

val write_final_prices :
  output_dir:string ->
  steps:Trading_simulation_types.Simulator_types.step_result list ->
  final_prices:(string * float) list ->
  unit
(** Write [final_prices.csv]: one row per held symbol with a known closing
    price. PHASE_1_SPEC §3.3: [symbol,price]. Symbols without a final price
    (e.g. delisted on the last day) are silently omitted. Always written;
    header-only when no positions are held. *)

val write_splits :
  output_dir:string ->
  steps:Trading_simulation_types.Simulator_types.step_result list ->
  unit
(** Write [splits.csv]: all split events that fired during the run across every
    simulator step. PHASE_1_SPEC §4: [symbol,date,factor]. Always written;
    header-only when no splits occurred. *)

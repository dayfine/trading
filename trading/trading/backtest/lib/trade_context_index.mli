(** Join indexes backing {!Trade_context}'s per-trade projection.

    {!Trade_context.of_audit_and_stop_log} rebuilt its audit index per trade —
    at Cell E 15 y scale (~3 700 round-trips × ~3 700 audit records) that turned
    [trades.csv] writing into O(N²). This module owns the one-shot index build
    so the per-trade path is pure Map lookups.

    Extracted from [trade_context.ml] when that file reached the 300-line cap
    (`code-health-discipline.md`: extract, do not raise the limit). Index
    {b construction} lives here; the lookup / fallback policy that reads these
    maps stays in {!Trade_context}, which is where the join-order contract is
    documented. *)

open Core

type t = {
  audit_by_position_id :
    (string, Trade_audit.audit_record, String.comparator_witness) Map.t;
      (** [entry.position_id] → audit_record. The exact join — immune to any
          decision→fill date gap. See {!Trade_context}'s join-order section. *)
  audit_by_key :
    (string, Trade_audit.audit_record, String.comparator_witness) Map.t;
      (** Exact [(symbol, entry_date)] key (see {!audit_key}) → audit_record. *)
  audit_by_symbol :
    (string, Trade_audit.audit_record list, String.comparator_witness) Map.t;
      (** symbol → audit_records sorted by [entry.entry_date] descending. Used
          as fallback when the exact-date key misses: the audit records the
          {b decision} date (typically a Friday), while [trade.entry_date]
          reflects the simulator step on which the order's fill was recorded —
          which can be a calendar day or two later because the simulator
          increments [current_date] by 1 calendar day per step and fills GTC
          orders on the next step that has price-path state. The caller picks
          the most recent record whose [entry.entry_date] is ≤
          [trade.entry_date] and within a small window. *)
  stop_by_position_id :
    (string, Stop_log.stop_info, String.comparator_witness) Map.t;
      (** [position_id] → stop_info. The exact stop-log join. *)
  stop_first_by_symbol :
    (string, Stop_log.stop_info, String.comparator_witness) Map.t;
      (** symbol → the {b first} stop_info seen for that symbol in the input
          list. Head-first, preserving the semantics of the [List.find] this
          index replaced: when several positions share a symbol, the earliest
          one in the list wins. Only reached when no position id resolves. *)
}
(** The index bundle. Exposed as a concrete record because {!Trade_context} is
    its only consumer and reads the maps directly. {!Trade_context} aliases it
    internally and keeps [Trade_context.precomputed] abstract, so this record
    shape is not part of the [Backtest] library's public join contract. *)

val audit_key : symbol:string -> entry_date:Date.t -> string
(** The [audit_by_key] key for a [(symbol, entry_date)] pair. Shared with the
    lookup side so the two cannot drift on separator or date format. *)

val build :
  audit:Trade_audit.audit_record list -> stop_infos:Stop_log.stop_info list -> t
(** Build all five indexes in one pass each. O(N) over the audit + stop-log
    lists (plus the per-symbol sort). Pure — same inputs always produce the same
    indexes. *)

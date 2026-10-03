(* Constructor-by-constructor hops from the strategy-layer audit enums
   ([Weinstein_strategy.Audit_recorder]) to [Trade_audit]'s on-disk schema
   copies. Split out of [trade_audit_recorder.ml] (file-length cap). See
   [trade_audit_enum_hops.mli]. *)

module AR = Weinstein_strategy.Audit_recorder

let stop_floor_kind_of_event = function
  | AR.Support_floor -> Trade_audit.Support_floor
  | AR.Buffer_fallback -> Trade_audit.Buffer_fallback

(* F5 telemetry passthrough between the strategy-layer tag and [Trade_audit]'s
   own on-disk schema copy (see [trade_audit.mli] for why the copy exists).
   Exhaustive by construction — a new basis constructor upstream fails this
   match, which is the point of writing it out rather than casting. Pinned
   per-constructor by [test_trade_audit_recorder.ml]: this is the last hop
   before [trade_audit.sexp], so a value dropped here is invisible everywhere
   else. *)
let split_safe_basis_of_event = function
  | AR.Flag_off -> Trade_audit.Flag_off
  | AR.Adjusted -> Trade_audit.Adjusted
  | AR.Raw_fallback -> Trade_audit.Raw_fallback
  | AR.Empty_window -> Trade_audit.Empty_window

(* Every entry-walk skip reason, one-to-one. *)
let skip_reason_of_event = function
  | AR.Insufficient_cash -> Trade_audit.Insufficient_cash
  | AR.Already_held -> Trade_audit.Already_held
  | AR.Sized_to_zero -> Trade_audit.Sized_to_zero
  | AR.Short_notional_cap -> Trade_audit.Short_notional_cap
  | AR.Stop_too_wide -> Trade_audit.Stop_too_wide
  | AR.Sector_exposure_cap -> Trade_audit.Sector_exposure_cap
  | AR.Long_exposure_cap -> Trade_audit.Long_exposure_cap
  | AR.No_structural_stop -> Trade_audit.No_structural_stop
  | AR.Share_class_held -> Trade_audit.Share_class_held

(* #3074: the screener's anchor arm to [Ticket_lifecycle]'s on-disk copy.
   Exhaustive, so a new anchor arm upstream fails this match. *)
let entry_anchor_of_kind :
    Screener.entry_anchor_kind -> Ticket_lifecycle.entry_anchor = function
  | Continuation -> Ticket_lifecycle.Continuation
  | Local_range_top -> Ticket_lifecycle.Local_range_top
  | Breakout -> Ticket_lifecycle.Breakout
  | Ma_fallback -> Ticket_lifecycle.Ma_fallback

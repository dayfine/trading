(** Per-Friday candidate capture. See [cascade_trace.mli]. *)

type t = { enabled : bool; walk : Audit_recorder.alternative_input list ref }

let create (recorder : Audit_recorder.t) =
  { enabled = recorder.capture_candidates; walk = ref [] }

let on_walk_candidates t =
  if t.enabled then Some (fun alts -> t.walk := alts) else None

let record t ~(audit_recorder : Audit_recorder.t) ~date ~diagnostics ~entered =
  audit_recorder.record_cascade_summary
    { date; diagnostics; entered; candidates = !(t.walk) }

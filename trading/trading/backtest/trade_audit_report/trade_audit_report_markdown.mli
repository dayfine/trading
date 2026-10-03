(** Markdown formatting for the trade-audit report; split out of
    [Trade_audit_report] (file-length cleanup). *)

val to_markdown : Trade_audit_report_types.t -> string
(** Render a report as markdown; see [Trade_audit_report.to_markdown]. *)

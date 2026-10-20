(** Pure Markdown sections for the release report; returned lines have no
    trailing newline. *)

val header : title:string -> current:string -> prior:string -> string list
(** Render the title and current/prior batch labels. *)

val trading :
  (Release_report_types.scenario_run * Release_report_types.scenario_run) list ->
  string list
(** Render paired trading metrics, including the empty-pair message. *)

val rss :
  threshold_pct:float ->
  (Release_report_types.scenario_run * Release_report_types.scenario_run) list ->
  string list
(** Render peak RSS and flag increases strictly above [threshold_pct]. *)

val wall :
  threshold_pct:float ->
  (Release_report_types.scenario_run * Release_report_types.scenario_run) list ->
  string list
(** Render wall time and flag increases strictly above [threshold_pct]. *)

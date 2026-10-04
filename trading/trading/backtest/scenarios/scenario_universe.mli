(** Scenario universe resolution for [scenario_runner]. *)

val of_scenario :
  fixtures_root:string ->
  Scenario.t ->
  (string, string) Core.Hashtbl.t option
  * (string -> Core.Date.t -> bool) option
(** Resolve a scenario's universe into the [sector_map_override] to stage and
    the optional dated membership predicate gating screening candidates. An
    empty [universe_schedule] loads [universe_path] with no predicate; a
    non-empty schedule uses the union of every scheduled list and the schedule's
    step function. Raises [Failure] on a schedule load error. *)

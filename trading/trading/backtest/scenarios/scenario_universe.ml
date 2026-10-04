(* Scenario universe resolution for [scenario_runner]. Extracted from
   scenario_runner.ml (file_length cleanup). *)

open Core

let _sector_map_of_universe_file ~fixtures_root path =
  (* Resolve the scenario's [universe_path] relative to the fixtures root,
     load it, and return an optional sector-map for [Backtest.Runner] to use
     as its universe. [None] means "use the full [data/sectors.csv]" (broad
     tier / pre-migration behaviour). *)
  let resolved = Filename.concat fixtures_root path in
  Universe_file.to_sector_map_override (Universe_file.load resolved)

(* Resolve a scenario's universe into the pair [Backtest.Runner] needs:
   the [sector_map_override] to stage and the optional dated membership
   predicate to gate screening candidates with.

   Empty [universe_schedule] (every pre-existing scenario) takes the
   [universe_path] branch unchanged, with no membership predicate — bit-equal
   to the pre-schedule behaviour. A non-empty schedule ignores [universe_path]
   entirely: the sector map becomes the UNION of every scheduled list (so a
   name that has dropped out of the current list still prices while held) and
   the predicate is the schedule's step function. *)
let of_scenario ~fixtures_root (s : Scenario.t) =
  match s.universe_schedule with
  | [] -> (_sector_map_of_universe_file ~fixtures_root s.universe_path, None)
  | schedule -> (
      match Universe_schedule.load ~fixtures_root schedule with
      | Error err -> failwithf "scenario %s: %s" s.name (Status.show err) ()
      | Ok sched ->
          ( Some (Universe_schedule.union_sector_map sched),
            Some (Universe_schedule.is_member sched) ))

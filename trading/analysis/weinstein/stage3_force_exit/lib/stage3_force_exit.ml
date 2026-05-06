open Core

type config = { hysteresis_weeks : int } [@@deriving sexp]

let _default_hysteresis_weeks = 2
let default_config = { hysteresis_weeks = _default_hysteresis_weeks }

type decision = Hold | Force_exit of { weeks_in_stage3 : int }
[@@deriving show, eq]

(** Effective hysteresis floor: a non-positive [config.hysteresis_weeks] would
    otherwise short-circuit the detector. Treat any [<= 0] as [1] — a single
    Stage-3 read fires immediately. The default is positive (2). *)
let _effective_threshold ~config =
  if config.hysteresis_weeks <= 0 then 1 else config.hysteresis_weeks

let observe ~config ~prior_consecutive_stage3 ~current_stage =
  match (current_stage : Weinstein_types.stage) with
  | Stage3 _ ->
      let new_count = prior_consecutive_stage3 + 1 in
      let threshold = _effective_threshold ~config in
      let decision =
        if new_count >= threshold then
          Force_exit { weeks_in_stage3 = new_count }
        else Hold
      in
      (new_count, decision)
  | Stage1 _ | Stage2 _ | Stage4 _ -> (0, Hold)

let observe_position ~config ~state ~symbol ~current_stage =
  let prior_consecutive_stage3 =
    Hashtbl.find state symbol |> Option.value ~default:0
  in
  let new_count, decision =
    observe ~config ~prior_consecutive_stage3 ~current_stage
  in
  Hashtbl.set state ~key:symbol ~data:new_count;
  decision

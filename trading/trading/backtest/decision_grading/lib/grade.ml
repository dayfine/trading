(** Exit-decision grade. See [grade.mli]. *)

open Core

type exit_grade = Premature | Good_exit | Neutral [@@deriving show, eq, sexp]

type grade_config = {
  premature_threshold_pct : float;
  good_exit_threshold_pct : float;
  grade_horizon_weeks : int;
}
[@@deriving show, eq, sexp]

let default_config =
  {
    premature_threshold_pct = 0.10;
    good_exit_threshold_pct = 0.10;
    grade_horizon_weeks = 13;
  }

(** The first post-exit result computed at [horizon_weeks], if any. *)
let _result_at ~horizon_weeks post_exit =
  List.find post_exit ~f:(fun (r : Post_exit.horizon_result) ->
      Int.equal r.horizon_weeks horizon_weeks)

(** Grade a single (already side-adjusted) continuation against the config
    thresholds. *)
let _grade_continuation ~config continuation_pct =
  if Float.( >= ) continuation_pct config.premature_threshold_pct then Premature
  else if Float.( <= ) continuation_pct (-.config.good_exit_threshold_pct) then
    Good_exit
  else Neutral

let grade_exit ~config ~post_exit =
  match _result_at ~horizon_weeks:config.grade_horizon_weeks post_exit with
  | None -> Neutral
  | Some r -> _grade_continuation ~config r.Post_exit.continuation_pct

let entry_capture_ratio ~realized_pnl_pct ~max_favorable_pct =
  if Float.( <= ) max_favorable_pct 0.0 then None
  else Some (realized_pnl_pct /. max_favorable_pct)

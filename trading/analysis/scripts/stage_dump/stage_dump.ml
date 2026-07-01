open Core

(* stage_dump <data_dir> <symbol> <end_date> <from_date>

   Prints the rolling Weinstein stage per week for [symbol], PRIOR-CHAINED (the
   correct classification the backtest drives via trading_state, and the one the
   live weekly-snapshot generator historically got wrong by passing
   prior_stage:None — see dev/notes/live-generator-prior-stage-bug-2026-07-01.md).

   For each week >= [from_date] it prints:
     <date> <prev_stage>-><stage> w<weeks_in_stage> [<== TRANSITION]
   A TRANSITION marks a week whose stage differs from the prior week's. *)

let stage_label = function
  | Weinstein_types.Stage1 _ -> "Stage1"
  | Weinstein_types.Stage2 _ -> "Stage2"
  | Weinstein_types.Stage3 _ -> "Stage3"
  | Weinstein_types.Stage4 _ -> "Stage4"

let stage_weeks = function
  | Weinstein_types.Stage1 { weeks_in_base } -> weeks_in_base
  | Weinstein_types.Stage2 { weeks_advancing; _ } -> weeks_advancing
  | Weinstein_types.Stage3 { weeks_topping } -> weeks_topping
  | Weinstein_types.Stage4 { weeks_declining } -> weeks_declining

let load_weekly ~data_dir ~symbol ~end_date =
  let result =
    let open Result.Let_syntax in
    let%bind storage =
      Csv.Csv_storage.create ~data_dir:(Fpath.v data_dir) symbol
    in
    let%map daily = Csv.Csv_storage.get storage ~end_date () in
    Time_period.Conversion.daily_to_weekly ~include_partial_week:false daily
  in
  match result with Ok w -> w | Error e -> failwith (Status.show e)

let () =
  let argv = Sys.get_argv () in
  let data_dir = argv.(1) and symbol = argv.(2) in
  let end_date = Date.of_string argv.(3)
  and from_date = Date.of_string argv.(4) in
  let arr = Array.of_list (load_weekly ~data_dir ~symbol ~end_date) in
  let n = Array.length arr in
  let cfg = Stage.default_config in
  let prior = ref None in
  for i = 0 to n - 1 do
    let bars = Array.to_list (Array.sub arr ~pos:0 ~len:(i + 1)) in
    let r = Stage.classify ~config:cfg ~bars ~prior_stage:!prior in
    let d = arr.(i).Types.Daily_price.date in
    (if Date.( >= ) d from_date then
       let cur = stage_label r.stage in
       let prev = Option.value_map !prior ~default:"-" ~f:stage_label in
       let fresh =
         if String.(prev <> "-") && String.(prev <> cur) then "  <== TRANSITION"
         else ""
       in
       printf "%s %s->%s w%d%s\n" (Date.to_string d) prev cur
         (stage_weeks r.stage) fresh);
    prior := Some r.stage
  done

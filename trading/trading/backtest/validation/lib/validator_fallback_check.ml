open Core
open Validator_types
open Validator_step

(* ---- V16: a round trip closed by a fallback safety net ----------------- *)

(* A fallback exit is one no strategy rule asked for: the position was closed
   because the machinery ran out of options, not because the strategy decided
   to sell. Each such row is a data-quality flag, so the check reports the
   symbol, both dates and both prices — enough to chase the specimen down in
   the warehouse without re-running anything. *)
let _v16_detail (row : trade_row) =
  sprintf "%s exit %s (entry %s @ %.2f, exit @ %.2f)" row.exit_trigger
    (Date.to_string row.exit_date)
    (Date.to_string row.entry_date)
    row.entry_price row.exit_price

let _v16_step (c : check_config) (row : trade_row) =
  if List.mem c.fallback_exit_labels row.exit_trigger ~equal:String.equal then
    Fail (spec row (_v16_detail row))
  else Pass

let check_v16 inputs = fold_steps inputs.trades ~f:(_v16_step inputs.config)

let fallback_exit_count report =
  List.find report.checks ~f:(fun (r : check_result) -> String.equal r.id "V16")
  |> Option.value_map ~default:0 ~f:(fun (r : check_result) -> r.n_violations)

(* ---- V17: an entry filled against a bar that had gone stale ------------ *)

(* CY (Cypress -> Infineon) was ENTERED twice in the canonical 26y record on
   2020-04-18 and 2020-04-25, after its series had already ended on
   2020-04-15 — the stale-hold safety net then "exited" both at the deal price
   and the whole episode was invisible because the exit label never reached
   trades.csv (#2687). The decision date is not carried in any artifact, so the
   check asks the equivalent question of the bars instead: how old was the most
   recent bar at or before the fill? At the default threshold the first entry
   (gap 3, a long weekend) passes and the second (gap 10) is reported — the
   comparison is strict, so a gap equal to the threshold passes too. *)
let _v17_detail ~fill_date ~bar_date ~gap =
  sprintf "entry filled %s but last bar is %s (%d days stale)"
    (Date.to_string fill_date) (Date.to_string bar_date) gap

let _v17_verdict (c : check_config) (b : bars) (row : trade_row) =
  match nearest_daily_date b row.entry_date with
  | None -> Skip
  | Some bar_date ->
      let gap = Date.diff row.entry_date bar_date in
      if gap > c.stale_entry_days then
        Fail (spec row (_v17_detail ~fill_date:row.entry_date ~bar_date ~gap))
      else Pass

let _v17_step inputs (row : trade_row) =
  match inputs.bars row.symbol with
  | None -> Skip
  | Some b when Array.is_empty b.daily -> Skip
  | Some b -> _v17_verdict inputs.config b row

let check_v17 inputs = fold_steps inputs.trades ~f:(_v17_step inputs)

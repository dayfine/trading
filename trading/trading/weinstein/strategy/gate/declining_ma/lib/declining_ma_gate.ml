open Core

(* A long whose 30-week MA is still declining at entry is a misclassified
   Stage-2 (a counter-trend bounce). Shorts keep a declining MA. *)
let _keep (c : Screener.scored_candidate) =
  match c.Screener.side with
  | Trading_base.Types.Short -> true
  | Trading_base.Types.Long ->
      not
        (Weinstein_types.equal_ma_direction
           c.Screener.analysis.Stock_analysis.stage.Stage.ma_direction
           Weinstein_types.Declining)

let filter ~reject candidates =
  if not reject then candidates else List.filter candidates ~f:_keep

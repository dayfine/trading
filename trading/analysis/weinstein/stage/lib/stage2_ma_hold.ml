open Core
open Weinstein_types

let apply ~enabled ~prior_stage ~standard_stage ~current_close ~current_ma =
  if not enabled then standard_stage
  else
    match (prior_stage, standard_stage, current_close) with
    | Some (Stage2 { weeks_advancing; late }), Stage3 _, Some close
      when Float.( >= ) close current_ma ->
        (* Pullback that holds the MA: faithful Weinstein keeps this Stage 2
           rather than demoting to Stage 3. Continue the prior advancing count;
           preserve the prior [late] warning flag. *)
        Stage2 { weeks_advancing = weeks_advancing + 1; late }
    | _ -> standard_stage

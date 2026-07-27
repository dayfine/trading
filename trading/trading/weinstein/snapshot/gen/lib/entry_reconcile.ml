open Core
open Weinstein_snapshot

(* Last resident daily close at or before [as_of], or [None] when the symbol has
   no bars. Same reader the spike-bar gate and the stop overlay use, so all
   three annotate off one price series. *)
let _current_close bar_reader ~as_of ~symbol =
  Weinstein_strategy.Bar_reader.daily_bars_for bar_reader ~symbol ~as_of
  |> List.last
  |> Option.map ~f:(fun (b : Types.Daily_price.t) -> b.close_price)

let for_candidate bar_reader ~as_of ~side ~through_band_pct ~extension_max_pct
    (c : Weekly_snapshot.candidate) : Weekly_snapshot.candidate =
  if Float.( <= ) extension_max_pct 0.0 then c
  else
    match _current_close bar_reader ~as_of ~symbol:c.symbol with
    | None -> c
    | Some close ->
        {
          c with
          reconciliation =
            Entry_reconciliation.classify ~side ~entry:c.entry ~close
              ~through_band_pct ~extension_max_pct;
        }

let for_candidates bar_reader ~as_of ~side ~through_band_pct ~extension_max_pct
    candidates =
  List.map candidates
    ~f:
      (for_candidate bar_reader ~as_of ~side ~through_band_pct
         ~extension_max_pct)

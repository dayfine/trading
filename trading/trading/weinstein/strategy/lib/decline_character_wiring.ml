open Core

(* Convert the snapshot weekly index view into the [Daily_price.t list] shape
   {!Decline_character.classify} consumes (chronological, oldest first). The
   weekly_view arrays are already oldest-at-index-0, so a straight fold over the
   index range preserves that order. [Decline_character] reads per-bar closes;
   we still populate high/low/open/adjusted_close from the weekly aggregates so
   the bars are well-formed for any future field the classifier might read. *)
let _index_bars_of_weekly_view
    (v : Snapshot_runtime.Snapshot_bar_views.weekly_view) =
  List.init v.n ~f:(fun i ->
      Types.Daily_price.make ~date:v.dates.(i) ~open_price:v.closes.(i)
        ~high_price:v.highs.(i) ~low_price:v.lows.(i) ~close_price:v.closes.(i)
        ~volume:(Float.to_int v.volumes.(i))
        ~adjusted_close:v.closes.(i) ())

let classify ~config ~macro ~index_view =
  let index_bars = _index_bars_of_weekly_view index_view in
  Decline_character.classify ~config ~macro ~index_bars

let update_ref ~prior_decline_character ~macro_result_opt ~index_view =
  match macro_result_opt with
  | None -> ()
  | Some macro ->
      prior_decline_character :=
        classify ~config:Decline_character.default_config ~macro ~index_view

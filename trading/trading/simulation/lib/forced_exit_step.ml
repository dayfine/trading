(** The simulator step's forced-exit phase — see [forced_exit_step.mli]. *)

open Core

(* Delisted exits, or the inputs unchanged when the caller supplies no
   delisting-marker lookup. *)
let _delisted ~adapter ~active_through_for ~commission ~date ~today_bars
    ~portfolio ~positions =
  match active_through_for with
  | None -> (portfolio, positions, [], [])
  | Some active_through_for ->
      Delisted_exit_runner.tick ~adapter ~active_through_for ~commission ~date
        ~today_bars ~portfolio ~positions ()

let run ~adapter ~active_through_for ~stale_config ~commission ~date ~today_bars
    ~last_known_price ~on_transitions ~portfolio ~positions () =
  (* MARKED delistings first, so a marked one never reaches the stale safety
     net and never counts as a data-quality flag. See the .mli. *)
  let portfolio, positions, delisted_trades, delisted_transitions =
    _delisted ~adapter ~active_through_for ~commission ~date ~today_bars
      ~portfolio ~positions
  in
  let portfolio, positions, stale_trades, stale_transitions =
    Stale_exit_runner.tick ~adapter ~config:stale_config ~commission ~date
      ~today_bars ~last_known_price ~portfolio ~positions ()
  in
  let transitions = delisted_transitions @ stale_transitions in
  if not (List.is_empty transitions) then
    Option.iter on_transitions ~f:(fun observe -> observe transitions);
  (portfolio, positions, delisted_trades @ stale_trades)

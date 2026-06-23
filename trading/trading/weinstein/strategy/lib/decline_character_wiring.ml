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

(* The decline-character classifier config built from the strategy-level
   arming-speed flag and arming rate threshold: default config except
   [fast_v_ignores_ma_filter] is set from [fast_v_arm_on_rate_alone] and
   [fast_v_min_rate_pct] from the strategy field, so the strategy controls both
   classify sites consistently. [fast_v_arm_on_rate_alone = false] together with
   [fast_v_min_rate_pct = default_config.fast_v_min_rate_pct] (0.08) reproduces
   [default_config] exactly. *)
let classifier_config ~fast_v_arm_on_rate_alone ~fast_v_min_rate_pct =
  {
    Decline_character.default_config with
    fast_v_ignores_ma_filter = fast_v_arm_on_rate_alone;
    fast_v_min_rate_pct;
  }

let classify ~config ~macro ~index_view =
  let index_bars = _index_bars_of_weekly_view index_view in
  Decline_character.classify ~config ~macro ~index_bars

let update_ref ~fast_v_arm_on_rate_alone ~fast_v_min_rate_pct
    ~prior_decline_character ~macro_result_opt ~index_view =
  match macro_result_opt with
  | None -> ()
  | Some macro ->
      let config =
        classifier_config ~fast_v_arm_on_rate_alone ~fast_v_min_rate_pct
      in
      prior_decline_character := classify ~config ~macro ~index_view

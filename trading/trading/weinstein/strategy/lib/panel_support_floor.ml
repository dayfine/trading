(** Support-floor callback constructors over the daily view — see
    [panel_support_floor.mli]. *)

module Snapshot_bar_views = Snapshot_runtime.Snapshot_bar_views
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks

let of_daily_view (view : Snapshot_bar_views.daily_view) :
    Weinstein_stops.callbacks =
  let n = view.n_days in
  let lookup f ~day_offset =
    if day_offset < 0 || day_offset >= n then None
    else
      let idx = n - 1 - day_offset in
      Some (f idx)
  in
  {
    get_high = lookup (fun i -> view.highs.(i));
    get_low = lookup (fun i -> view.lows.(i));
    get_close = lookup (fun i -> view.raw_closes.(i));
    get_adjusted_close = lookup (fun i -> view.adjusted_closes.(i));
    get_date =
      (fun ~day_offset ->
        if day_offset < 0 || day_offset >= n then None
        else Some view.dates.(n - 1 - day_offset));
    n_days = n;
  }

let of_snapshot_views ~(cb : Snapshot_callbacks.t) ~symbol ~as_of ~lookback
    ~calendar : Weinstein_stops.callbacks =
  of_daily_view
    (Snapshot_bar_views.daily_view_for cb ~symbol ~as_of ~lookback ~calendar)

open Core

(* Aggregate one week of daily bars (reverse chronological order) into a single
   weekly [Macro.ad_bar]. The aggregated bar is dated on the last calendar day
   of the week present in the input. *)
let _aggregate_week (week_rev : Macro.ad_bar list) : Macro.ad_bar =
  let last = List.hd_exn week_rev in
  let advancing =
    List.sum (module Int) week_rev ~f:(fun b -> b.Macro.advancing)
  in
  let declining =
    List.sum (module Int) week_rev ~f:(fun b -> b.Macro.declining)
  in
  { Macro.date = last.date; advancing; declining }

let daily_to_weekly (bars : Macro.ad_bar list) : Macro.ad_bar list =
  Time_period.Week_bucketing.bucket_weekly
    ~get_date:(fun b -> b.Macro.date)
    ~aggregate:_aggregate_week bars

open Core
module Weekly_sidetable = Data_panel_snapshot.Weekly_sidetable

(* One weekly bar -> one side-table entry, raw (unadjusted) basis: [high] is the
   weekly raw high, [mid] the raw [(H + L) / 2] — mirrors [Resistance_sketch]'s
   [_accumulate_hist] mid/high, which gate + bucket off the same raw fields. *)
let _entry_of_weekly (b : Types.Daily_price.t) : Weekly_sidetable.entry =
  {
    week_end_date = b.date;
    mid = (b.high_price +. b.low_price) /. 2.0;
    high = b.high_price;
  }

let of_bars ~deep_bars ~bars : Weekly_sidetable.entry list =
  let combined = Array.of_list (deep_bars @ bars) in
  let n = Array.length combined in
  if n = 0 then []
  else
    let wp = Weekly_prefix.build combined in
    (* Full weekly series = every finalized week + the trailing partial week as
       of the last daily bar. Equal to
       [daily_to_weekly ~include_partial_week:true combined]. *)
    let weekly = Array.to_list wp.finalized @ [ wp.partial_per_day.(n - 1) ] in
    List.map weekly ~f:_entry_of_weekly

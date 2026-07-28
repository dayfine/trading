open Core
module Weekly_sidetable = Data_panel_snapshot.Weekly_sidetable

(* One weekly bar -> one side-table entry, split/dividend-ADJUSTED basis (#2133):
   [high] is the weekly high, [mid] the [(H + L) / 2], both taken after the daily
   bars are rescaled onto the adjusted basis by {!Adjusted_basis.to_adjusted_basis}
   below. A split inside the lookback window therefore no longer hides real supply
   (forward split) or fabricates phantom supply (reverse split). The manifest
   stamps [Weekly_sidetable.format_hash] (the adjusted-basis hash) so the reader
   anchors these entries at the row's [Adjusted_close] column. *)
let _entry_of_weekly (b : Types.Daily_price.t) : Weekly_sidetable.entry =
  {
    week_end_date = b.date;
    mid = (b.high_price +. b.low_price) /. 2.0;
    high = b.high_price;
  }

let of_bars ~deep_bars ~bars : Weekly_sidetable.entry list =
  (* Pin the weekly aggregation to the adjusted basis BEFORE folding weeks, so
     the entry high/mid are on the same continuous scale as [Adjusted_close]. *)
  let combined =
    List.map (deep_bars @ bars) ~f:Adjusted_basis.to_adjusted_basis
    |> Array.of_list
  in
  let n = Array.length combined in
  if n = 0 then []
  else
    let wp = Weekly_prefix.build combined in
    (* Full weekly series = every finalized week + the trailing partial week as
       of the last daily bar. Equal to
       [daily_to_weekly ~include_partial_week:true combined]. *)
    let weekly = Array.to_list wp.finalized @ [ wp.partial_per_day.(n - 1) ] in
    List.map weekly ~f:_entry_of_weekly

(** Derived chart series for the HTML report. See [.mli]. *)

open Core
module TAR = Trade_audit_report
open Html_data

(* Derived: chart series ---------------------------------------------------- *)

let downsample ~every rows =
  match rows with
  | [] | [ _ ] -> rows
  | _ ->
      let n = List.length rows in
      let sampled = List.filteri rows ~f:(fun i _ -> i % every = 0) in
      if (n - 1) % every = 0 then sampled else sampled @ [ List.last_exn rows ]

(* Buy-and-hold benchmark, indexed to [initial_cash] at the first curve date.
   Every value divides a mark by an *earlier mark of the same symbol*, so the
   marks must be split/dividend-adjusted: on the raw column a split inside the
   run reads as a price move the benchmark never made. Hence [Adjusted]. *)
let benchmark ~adjusted_close ~symbol ~initial_cash ~dates =
  match dates with
  | [] -> None
  | first :: _ -> (
      match adjusted_close ~symbol ~as_of:first with
      | Some base when Float.(base > 0.0) ->
          let vals =
            List.map dates ~f:(fun d ->
                Option.map (adjusted_close ~symbol ~as_of:d) ~f:(fun c ->
                    (d, initial_cash *. c /. base)))
          in
          if List.for_all vals ~f:Option.is_some then
            Some (List.filter_map vals ~f:Fn.id)
          else None
      | _ -> None)

type interval = {
  i_sym : string;
  i_lo : Date.t;
  i_hi : Date.t option;
  i_qty : float;
}

let _no_extra : Html_sources.trade_extra =
  { qty = 0.0; stop_kind = ""; entry_stop = None; exit_stop = None }

let extra_of extras ~sym ~entry ~exit_ : Html_sources.trade_extra =
  let key =
    Html_sources.key sym (Date.to_string entry) (Date.to_string exit_)
  in
  Option.value (Map.find extras key) ~default:_no_extra

let intervals (report : TAR.t) extras (opens : open_position list) =
  let rts =
    List.map report.rows ~f:(fun (r : TAR.per_trade_row) ->
        let extra =
          extra_of extras ~sym:r.symbol ~entry:r.entry_date ~exit_:r.exit_date
        in
        {
          i_sym = r.symbol;
          i_lo = r.entry_date;
          i_hi = Some r.exit_date;
          i_qty = extra.qty;
        })
  in
  let ops =
    List.map opens ~f:(fun o ->
        {
          i_sym = o.symbol;
          i_lo = o.entry_date;
          i_hi = None;
          i_qty = o.quantity;
        })
  in
  rts @ ops

let _covers iv d =
  Date.( >= ) d iv.i_lo
  && match iv.i_hi with None -> true | Some hi -> Date.( <= ) d hi

(* Percentage of NAV deployed at each curve point. Each term *multiplies* a
   mark by a share count and divides by NAV, and both of those are raw: [i_qty]
   comes from [trades.csv] / [open_positions.csv] (as-traded share counts) and
   [nav] from [equity_curve.csv], which marks positions at the raw close. An
   adjusted mark would rescale the whole term by the symbol's split/dividend
   factor from the mark date to the snapshot's last date. Hence [Raw]. *)
let utilization ~position_mark ~intervals ~curve =
  List.map curve ~f:(fun (d, nav) ->
      if Float.(nav <= 0.0) then 0.0
      else
        let deployed =
          List.fold intervals ~init:0.0 ~f:(fun acc iv ->
              if _covers iv d then
                match position_mark ~symbol:iv.i_sym ~as_of:d with
                | Some c -> acc +. (iv.i_qty *. c)
                | None -> acc
              else acc)
        in
        deployed /. nav *. 100.0)

(* 30-bar linearly-weighted MA (the Weinstein weekly WMA30) over [closes];
   [Float.nan] at indices with fewer than [_wma_window] prior bars. Kept
   inline: the analysis-side MA kernels are out of reach per the layering
   rules, and the linear-weight fold is small enough to own here. *)
let _wma_window = 30

let _wma30 closes =
  let n = Array.length closes in
  Array.init n ~f:(fun i ->
      if i + 1 < _wma_window then Float.nan
      else
        let num = ref 0.0 and den = ref 0.0 in
        for k = 0 to _wma_window - 1 do
          let w = Float.of_int (_wma_window - k) in
          num := !num +. (w *. closes.(i - k));
          den := !den +. w
        done;
        !num /. !den)

(* Chart window around a round trip, in weekly bars. *)
let _pre_entry_weeks = 52
let _post_exit_weeks = 26

let _first_idx_on_or_after dates d =
  match Array.findi dates ~f:(fun _ x -> Date.( >= ) x d) with
  | Some (i, _) -> i
  | None -> Array.length dates - 1

(* Build the per-trade weekly series: fetch [_pre_entry_weeks] + holding +
   [_post_exit_weeks] bars (plus the WMA warmup) as of [exit + 26w], compute
   the WMA over the full fetch, then slice the warmup off the front so the
   chart's first visible bar still has a valid trend line. *)
let series ~weekly_series ~(extra : Html_sources.trade_extra) ~sym ~entry ~exit_
    : trade_series option =
  let as_of = Date.add_days exit_ (_post_exit_weeks * 7) in
  let span_weeks =
    Date.diff
      (Date.add_days exit_ (_post_exit_weeks * 7))
      (Date.add_days entry (-_pre_entry_weeks * 7))
    / 7
    + 1
  in
  let n = span_weeks + _wma_window in
  let bars = weekly_series ~symbol:sym ~n ~as_of in
  if Array.length bars <= _wma_window then None
  else
    let dates = Array.map bars ~f:fst in
    let closes = Array.map bars ~f:snd in
    let wma = _wma30 closes in
    let visible_from =
      Int.max 0
        (Int.min
           (_first_idx_on_or_after dates entry - _pre_entry_weeks)
           (Array.length dates - 1))
    in
    let slice a =
      Array.to_list
        (Array.sub a ~pos:visible_from ~len:(Array.length a - visible_from))
    in
    let dates_v = slice dates in
    let entry_idx = _first_idx_on_or_after (Array.of_list dates_v) entry in
    let exit_idx = _first_idx_on_or_after (Array.of_list dates_v) exit_ in
    Some
      {
        dates = dates_v;
        closes = slice closes;
        wma30 = slice wma;
        entry_idx;
        exit_idx;
        entry_stop = extra.entry_stop;
        exit_stop = extra.exit_stop;
      }

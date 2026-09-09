open Core
open Validator_types
open Validator_step

(* ---- V18: a stored series that is not a plausible equity price series --- *)

(* MEL in the top-3000-2000 vintage (issue #2732): 2,427 bars spanning
   2008-11-06..2018-06-28 of which 2,353 close above $1,000 — 2017-01 sits
   around $167k-177k — with a handful of $8-12 bars mixed in on near-zero
   volume, and an adjusted_close that tracks close, so no split explains it.
   It looks like a foreign or OTC listing mis-mapped onto the MEL ticker
   (Mellon Financial was acquired in 2007).

   An arm bought 1 share at $175,002 on 2017-01-30 — a full-sized ticket,
   because at that price ONE SHARE is the ticket — and the 12.2 print on
   2017-02-08 (volume 0) gapped it through the stop for -$171,654, -99.99%.

   Both halves of that description are independently detectable, and this check
   asks both questions of every symbol the run touched: is the LEVEL plausible,
   and did any bar move impossibly far on no volume at all. *)

(* One row per SYMBOL, keyed to the earliest date the run put capital into it,
   so the specimen ties the bad series back to a ticket the reader can find in
   trades.csv. A symbol traded ten times is one row, not ten: the defect is in
   the series, and ten copies of it would crowd out other symbols under the
   10-specimen cap. Open positions are included — a mis-scaled series still
   held at run end is the same defect as one already round-tripped. *)
let _v18_earliest acc (symbol, date) =
  Map.update acc symbol ~f:(function
    | None -> date
    | Some d -> if Date.( < ) d date then d else date)

let _v18_subjects inputs =
  let rows =
    List.map inputs.trades ~f:(fun (r : trade_row) -> (r.symbol, r.entry_date))
    @ List.map inputs.open_positions ~f:(fun (o : open_row) ->
        (o.symbol, o.entry_date))
  in
  List.fold rows ~init:(Map.empty (module String)) ~f:_v18_earliest
  |> Map.to_alist

(* Median rather than mean: the defect is that the BULK of the series is
   mis-scaled, and a mean over MEL's mixture of $170k and $12 prints answers a
   different question. Even bar counts take the mean of the two central
   closes. *)
let _v18_median_close (daily : daily_bar array) =
  let sorted =
    Array.map daily ~f:(fun (d : daily_bar) -> d.close)
    |> Array.sorted_copy ~compare:Float.compare
  in
  let n = Array.length sorted in
  let upper = sorted.(n / 2) in
  if n % 2 = 1 then upper else (sorted.((n / 2) - 1) +. upper) /. 2.0

type _move = Move_clean | Move_unknown | Move_found of (float * daily_bar)

let _v18_move_pct ~prev_close ~(bar : daily_bar) =
  if Float.( <= ) prev_close 0.0 then None
  else Some (100.0 *. Float.abs ((bar.close -. prev_close) /. prev_close))

(* Zero volume is the whole discriminator. Real >90% one-bar moves happen — a
   takeover, a biotech readout, a reverse split the adjustment missed — and
   they happen ON VOLUME. A >90% move that nobody traded is the feed, not the
   market. So the volume test comes first and short-circuits: a traded bar is
   clean whatever it did, and its prior close is never even read. *)
let _v18_classify_move (c : check_config) ~prev_close ~(bar : daily_bar) =
  if bar.volume > c.store_zero_volume_max then Move_clean
  else
    match _v18_move_pct ~prev_close ~bar with
    | None -> Move_unknown
    | Some m when Float.( > ) m c.store_zero_volume_move_pct ->
        Move_found (prev_close, bar)
    | Some _ -> Move_clean

let _v18_pairs (daily : daily_bar array) =
  List.init
    (Int.max 0 (Array.length daily - 1))
    ~f:(fun i -> (daily.(i).close, daily.(i + 1)))

(* Every consecutive pair, so a phantom print anywhere in the series is found
   and not just one adjacent to a fill (that narrower question is V15's). The
   first hit supplies the specimen; an un-evaluable pair matters only when
   nothing was found, mirroring V15's leg handling. *)
let _v18_scan_moves (c : check_config) (daily : daily_bar array) =
  let scans =
    List.map (_v18_pairs daily) ~f:(fun (prev_close, bar) ->
        _v18_classify_move c ~prev_close ~bar)
  in
  match List.find scans ~f:(function Move_found _ -> true | _ -> false) with
  | Some found -> found
  | None ->
      if List.exists scans ~f:(function Move_unknown -> true | _ -> false)
      then Move_unknown
      else Move_clean

let _v18_span (daily : daily_bar array) =
  sprintf "%d bars (%s..%s)" (Array.length daily)
    (Date.to_string daily.(0).date)
    (Date.to_string daily.(Array.length daily - 1).date)

let _v18_level_part (c : check_config) ~median daily =
  let head = sprintf "median close %.2f over %s" median (_v18_span daily) in
  if Float.( > ) median c.store_median_close_max then
    sprintf "%s, above the %.2f ceiling" head c.store_median_close_max
  else head

let _v18_move_part = function
  | Move_found (prev_close, bar) ->
      sprintf "; bar %s close %.2f (%+.2f%% vs prior close %.2f) on volume %d"
        (Date.to_string bar.date) bar.close
        (100.0 *. (bar.close -. prev_close) /. prev_close)
        prev_close bar.volume
  | Move_clean | Move_unknown -> ""

let _v18_specimen ~symbol ~entry_date detail =
  { symbol; entry_date = Date.to_string entry_date; detail }

(* A violation always names the median and the series span, and additionally
   the offending bar when the zero-volume rule fired — so "V18: 1 violation"
   is never the whole story a reader gets. *)
let _v18_verdict (c : check_config) ~symbol ~entry_date daily =
  let median = _v18_median_close daily in
  let scan = _v18_scan_moves c daily in
  match (Float.( > ) median c.store_median_close_max, scan) with
  | false, Move_clean -> Pass
  | false, Move_unknown -> Skip
  | _ ->
      let detail = _v18_level_part c ~median daily ^ _v18_move_part scan in
      Fail (_v18_specimen ~symbol ~entry_date detail)

let _v18_step inputs (symbol, entry_date) =
  let c = inputs.config in
  match inputs.bars symbol with
  | None -> Skip
  | Some b when Array.length b.daily < Int.max 1 c.store_min_bars -> Skip
  | Some b -> _v18_verdict c ~symbol ~entry_date b.daily

let check_v18 inputs = fold_steps (_v18_subjects inputs) ~f:(_v18_step inputs)

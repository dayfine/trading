open Core

(* Monday of the ISO week [d] falls in. Shifting to a weekday (rather than
   keying on a (year, week-number) pair) has no year-boundary discontinuity: a
   week straddling New Year keeps one key. *)
let _monday d =
  let iso = Date.day_of_week d |> Day_of_week.iso_8601_weekday_number in
  Date.add_days d (-(iso - 1))

(* One weekly bar from the dailies that fall in it: opening at the week's first
   open, spanning its extremes, closing at its last close. The bar is DATED at
   its last daily bar, so an as-of-Friday series ends on the snapshot's own
   Friday rather than on the following Monday. *)
let _fold_week week : Types.Daily_price.t =
  let first = List.hd_exn week and last = List.last_exn week in
  let extreme ~f ~init =
    List.fold week ~init ~f:(fun acc (b : Types.Daily_price.t) -> f acc b)
  in
  Types.Daily_price.make ~date:last.Types.Daily_price.date
    ~open_price:first.Types.Daily_price.open_price
    ~high_price:
      (extreme ~init:Float.neg_infinity ~f:(fun a b -> Float.max a b.high_price))
    ~low_price:
      (extreme ~init:Float.infinity ~f:(fun a b -> Float.min a b.low_price))
    ~close_price:last.Types.Daily_price.close_price
    ~volume:
      (List.sum (module Int) week ~f:(fun b -> b.Types.Daily_price.volume))
    ~adjusted_close:last.Types.Daily_price.adjusted_close ()

let weekly_bars bars =
  List.group bars ~break:(fun (a : Types.Daily_price.t) b ->
      not (Date.equal (_monday a.date) (_monday b.date)))
  |> List.map ~f:_fold_week

let sma ~period values =
  let arr = Array.of_list values in
  let mean_ending_at i =
    if period <= 0 || i + 1 < period then None
    else
      let window = Array.sub arr ~pos:(i + 1 - period) ~len:period in
      Some (Array.fold window ~init:0.0 ~f:( +. ) /. Float.of_int period)
  in
  List.init (Array.length arr) ~f:mean_ending_at

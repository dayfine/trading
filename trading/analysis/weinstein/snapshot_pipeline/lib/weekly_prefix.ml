open Core

type t = {
  finalized : Types.Daily_price.t array;
  partial_per_day : Types.Daily_price.t array;
  finalized_count_at_day : int array;
}

(* Two dates are in the same ISO week iff they share (year, week_number). *)
let _is_same_week (d1 : Date.t) (d2 : Date.t) : bool =
  Date.week_number d1 = Date.week_number d2 && Date.year d1 = Date.year d2

let _ordering_error_msg =
  "Data must be sorted chronologically by date with no duplicates"

let _validate_ordering (prev : Date.t) (curr : Date.t) : unit =
  if Date.compare prev curr >= 0 then
    raise (Invalid_argument _ordering_error_msg)

(* Aggregate one week of daily bars (reverse chronological) into a single
   weekly bar — copied from [Time_period.Conversion._aggregate_week] so the
   output is bit-identical. *)
let _aggregate_week (week_rev : Types.Daily_price.t list) : Types.Daily_price.t
    =
  let last = List.hd_exn week_rev in
  let first = List.last_exn week_rev in
  let high_price =
    List.map week_rev ~f:(fun d -> d.high_price)
    |> List.max_elt ~compare:Float.compare
    |> Option.value_exn
  in
  let low_price =
    List.map week_rev ~f:(fun d -> d.low_price)
    |> List.min_elt ~compare:Float.compare
    |> Option.value_exn
  in
  {
    date = last.date;
    open_price = first.open_price;
    high_price;
    low_price;
    close_price = last.close_price;
    volume = List.sum (module Int) week_rev ~f:(fun d -> d.volume);
    adjusted_close = last.adjusted_close;
  }

let _empty =
  { finalized = [||]; partial_per_day = [||]; finalized_count_at_day = [||] }

let build (bars_arr : Types.Daily_price.t array) : t =
  let n = Array.length bars_arr in
  if n = 0 then _empty
  else
    let finalized_rev = ref [] in
    let finalized_count = ref 0 in
    let partial_per_day = Array.create ~len:n bars_arr.(0) in
    let finalized_count_at_day = Array.create ~len:n 0 in
    let curr_week_rev = ref [] in
    let prev_date = ref None in
    for i = 0 to n - 1 do
      let bar = bars_arr.(i) in
      Option.iter !prev_date ~f:(fun p -> _validate_ordering p bar.date);
      (match !curr_week_rev with
      | last :: _ when not (_is_same_week last.Types.Daily_price.date bar.date)
        ->
          let finalized = _aggregate_week !curr_week_rev in
          finalized_rev := finalized :: !finalized_rev;
          incr finalized_count;
          curr_week_rev := []
      | _ -> ());
      curr_week_rev := bar :: !curr_week_rev;
      prev_date := Some bar.date;
      partial_per_day.(i) <- _aggregate_week !curr_week_rev;
      finalized_count_at_day.(i) <- !finalized_count
    done;
    let finalized = Array.of_list (List.rev !finalized_rev) in
    { finalized; partial_per_day; finalized_count_at_day }

let window_for_day t ~day_idx ~lookback =
  let f_count = t.finalized_count_at_day.(day_idx) in
  let partial = t.partial_per_day.(day_idx) in
  (* Window is [finalized[start..f_count - 1]] then [partial]. The total
     length is [f_count + 1]; we want the last [lookback] entries. *)
  let total = f_count + 1 in
  let take = Int.min lookback total in
  let from_finalized = Int.max 0 (take - 1) in
  let start = f_count - from_finalized in
  let acc = ref [ partial ] in
  for k = f_count - 1 downto start do
    acc := t.finalized.(k) :: !acc
  done;
  !acc

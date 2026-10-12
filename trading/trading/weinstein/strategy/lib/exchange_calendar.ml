open Core

let _is_weekday d =
  match Date.day_of_week d with
  | Day_of_week.Sat | Day_of_week.Sun -> false
  | _ -> true

(* Easter Sunday by the anonymous Gregorian algorithm (Meeus/Jones/Butcher). *)
let _easter_sunday year =
  let a = year mod 19 in
  let b = year / 100 and c = year mod 100 in
  let d = b / 4 and e = b mod 4 in
  let f = (b + 8) / 25 in
  let g = (b - f + 1) / 3 in
  let h = ((19 * a) + b - d - g + 15) mod 30 in
  let i = c / 4 and k = c mod 4 in
  let l = (32 + (2 * e) + (2 * i) - h - k) mod 7 in
  let m = (a + (11 * h) + (22 * l)) / 451 in
  let month = (h + l - (7 * m) + 114) / 31 in
  let day = ((h + l - (7 * m) + 114) mod 31) + 1 in
  Date.create_exn ~y:year ~m:(Month.of_int_exn month) ~d:day

(* The [n]th (1-based) [dow] of [month], e.g. the 3rd Monday of January. *)
let _nth_weekday ~year ~month ~dow ~n =
  let first = Date.create_exn ~y:year ~m:month ~d:1 in
  let offset =
    (Day_of_week.to_int dow - Day_of_week.to_int (Date.day_of_week first) + 7)
    % 7
  in
  Date.add_days first (offset + (7 * (n - 1)))

let _last_weekday ~year ~month ~dow =
  let next_first = Date.add_months (Date.create_exn ~y:year ~m:month ~d:1) 1 in
  let last = Date.add_days next_first (-1) in
  let back =
    (Day_of_week.to_int (Date.day_of_week last) - Day_of_week.to_int dow + 7)
    % 7
  in
  Date.add_days last (-back)

(* Weekend-shifted observance of a fixed-date holiday. [shift_saturday] is
   false only for New Year's Day (NYSE stays open the preceding Friday). *)
let _observed ~shift_saturday date =
  match Date.day_of_week date with
  | Day_of_week.Sun -> Some (Date.add_days date 1)
  | Day_of_week.Sat ->
      if shift_saturday then Some (Date.add_days date (-1)) else None
  | _ -> Some date

let _fixed ~year ~month ~day ~shift_saturday =
  _observed ~shift_saturday (Date.create_exn ~y:year ~m:month ~d:day)

(* The year's scheduled closures that can land in [year]'s calendar days. A
   Sunday-shifted 1 January of [year + 1] never moves into [year], and a
   Saturday 1 January is not observed, so [year] alone is enough. *)
let _scheduled_holidays year =
  let christmas = 25 in
  let fixed m d ~shift_saturday =
    _fixed ~year ~month:m ~day:d ~shift_saturday
  in
  let juneteenth =
    if year >= 2022 then fixed Month.Jun 19 ~shift_saturday:true else None
  in
  List.filter_opt
    [
      fixed Month.Jan 1 ~shift_saturday:false;
      Some (_nth_weekday ~year ~month:Month.Jan ~dow:Day_of_week.Mon ~n:3);
      Some (_nth_weekday ~year ~month:Month.Feb ~dow:Day_of_week.Mon ~n:3);
      Some (Date.add_days (_easter_sunday year) (-2));
      Some (_last_weekday ~year ~month:Month.May ~dow:Day_of_week.Mon);
      juneteenth;
      fixed Month.Jul 4 ~shift_saturday:true;
      Some (_nth_weekday ~year ~month:Month.Sep ~dow:Day_of_week.Mon ~n:1);
      Some (_nth_weekday ~year ~month:Month.Nov ~dow:Day_of_week.Thu ~n:4);
      fixed Month.Dec christmas ~shift_saturday:true;
    ]

(* Unscheduled full-day closures that sit on a Friday or empty a whole week
   (see the .mli for why mid-week ones are omitted). *)
let _special_closures =
  [
    Date.of_string "2001-09-11";
    Date.of_string "2001-09-12";
    Date.of_string "2001-09-13";
    Date.of_string "2001-09-14";
    Date.of_string "2004-06-11";
  ]

let is_closed d =
  _is_weekday d
  && (List.mem (_scheduled_holidays (Date.year d)) d ~equal:Date.equal
     || List.mem _special_closures d ~equal:Date.equal)

(* The weekdays after [d] up to and including that week's Friday. *)
let _rest_of_week d =
  let days_to_friday =
    Day_of_week.to_int Day_of_week.Fri - Day_of_week.to_int (Date.day_of_week d)
  in
  List.init (Int.max days_to_friday 0) ~f:(fun i -> Date.add_days d (i + 1))

let is_last_trading_day_of_week d =
  _is_weekday d
  && (not (is_closed d))
  && List.for_all (_rest_of_week d) ~f:is_closed

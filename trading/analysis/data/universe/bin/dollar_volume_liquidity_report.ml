open Core
module Scan = Dollar_volume_scan

let _add buf fmt = Printf.ksprintf (Buffer.add_string buf) fmt

let _pct n d =
  if d = 0 then "n/a"
  else sprintf "%.1f%%" (100.0 *. Float.of_int n /. Float.of_int d)

type _totals = {
  sum : Scan.liquidity_year;
  symbols_lost : int;
  symbols_gained : int;
}

let _zero_totals cal_year =
  {
    sum =
      {
        cal_year;
        weeks = 0;
        lost = 0;
        gained = 0;
        stored_one_bar = 0;
        true_one_bar = 0;
        gained_one_bar = 0;
      };
    symbols_lost = 0;
    symbols_gained = 0;
  }

let _add_year p (l : Scan.liquidity_year) =
  let s = p.sum in
  {
    sum =
      {
        s with
        weeks = s.weeks + l.weeks;
        lost = s.lost + l.lost;
        gained = s.gained + l.gained;
        stored_one_bar = s.stored_one_bar + l.stored_one_bar;
        true_one_bar = s.true_one_bar + l.true_one_bar;
        gained_one_bar = s.gained_one_bar + l.gained_one_bar;
      };
    symbols_lost = (p.symbols_lost + if l.lost > 0 then 1 else 0);
    symbols_gained = (p.symbols_gained + if l.gained > 0 then 1 else 0);
  }

let _liquidity_totals scans =
  let table = Hashtbl.create (module Int) in
  List.iter scans ~f:(fun (s : Scan.t) ->
      List.iter s.liquidity ~f:(fun (l : Scan.liquidity_year) ->
          Hashtbl.update table l.cal_year ~f:(fun prev ->
              _add_year (Option.value prev ~default:(_zero_totals l.cal_year)) l)));
  Hashtbl.to_alist table
  |> List.sort ~compare:(fun (a, _) (b, _) -> Int.compare a b)

let render buf ~floor scans =
  _add buf
    "## Entry liquidity gate flips ($%.0f floor, week-end bars of list \
     members)\n\n\
     | year | symbol-weeks | pass->fail | fail->pass | flip share | symbols \
     pass->fail | symbols fail->pass | one-bar passes stored | one-bar passes \
     true | fail->pass on one bar |\n\
     |---|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n"
    floor;
  List.iter (_liquidity_totals scans) ~f:(fun (y, t) ->
      let s = t.sum in
      _add buf "| %d | %d | %d | %d | %s | %d | %d | %d | %d | %d |\n" y s.weeks
        s.lost s.gained
        (_pct (s.lost + s.gained) s.weeks)
        t.symbols_lost t.symbols_gained s.stored_one_bar s.true_one_bar
        s.gained_one_bar);
  _add buf "\n"

let csv scans =
  let buf = Buffer.create 4096 in
  Buffer.add_string buf
    "symbol,year,weeks,pass_to_fail,fail_to_pass,one_bar_stored,one_bar_true,fail_to_pass_one_bar\n";
  List.iter scans ~f:(fun (s : Scan.t) ->
      List.iter s.liquidity ~f:(fun (l : Scan.liquidity_year) ->
          if l.lost + l.gained + l.stored_one_bar + l.true_one_bar > 0 then
            _add buf "%s,%d,%d,%d,%d,%d,%d,%d\n" s.symbol l.cal_year l.weeks
              l.lost l.gained l.stored_one_bar l.true_one_bar l.gained_one_bar));
  Buffer.contents buf

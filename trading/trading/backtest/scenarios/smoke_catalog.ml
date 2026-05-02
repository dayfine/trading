open Core

type window = {
  name : string;
  start_date : Date.t;
  end_date : Date.t;
  description : string;
  universe_path : string;
}
[@@deriving sexp]

let _date ~y ~m ~d = Date.create_exn ~y ~m ~d

(** Default universe for every smoke window. The full sector-map (~10K symbols)
    was the historical default but OOMs the 8 GB dev container at panel-load
    time, defeating the "fast iteration" purpose of smoke. The sp500 sexp (~491
    symbols) loads in well under 2 GB peak per window. *)
let _default_universe_path = "universes/sp500.sexp"

let bull =
  {
    name = "bull";
    start_date = _date ~y:2019 ~m:Month.Jun ~d:1;
    end_date = _date ~y:2019 ~m:Month.Dec ~d:31;
    description = "Persistent uptrend (H2 2019)";
    universe_path = _default_universe_path;
  }

let crash =
  {
    name = "crash";
    start_date = _date ~y:2020 ~m:Month.Jan ~d:2;
    end_date = _date ~y:2020 ~m:Month.Jun ~d:30;
    description = "COVID crash + initial recovery (H1 2020)";
    universe_path = _default_universe_path;
  }

let recovery =
  {
    name = "recovery";
    start_date = _date ~y:2023 ~m:Month.Jan ~d:2;
    end_date = _date ~y:2023 ~m:Month.Dec ~d:31;
    description = "Post-bear rebound (full year 2023)";
    universe_path = _default_universe_path;
  }

let all = [ bull; crash; recovery ]

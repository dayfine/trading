open Core

type window = {
  name : string;
  start_date : Date.t;
  end_date : Date.t;
  description : string;
}
[@@deriving sexp]

let _date ~y ~m ~d = Date.create_exn ~y ~m ~d

let bull =
  {
    name = "bull";
    start_date = _date ~y:2019 ~m:Month.Jun ~d:1;
    end_date = _date ~y:2019 ~m:Month.Dec ~d:31;
    description = "Persistent uptrend (H2 2019)";
  }

let crash =
  {
    name = "crash";
    start_date = _date ~y:2020 ~m:Month.Jan ~d:2;
    end_date = _date ~y:2020 ~m:Month.Jun ~d:30;
    description = "COVID crash + initial recovery (H1 2020)";
  }

let recovery =
  {
    name = "recovery";
    start_date = _date ~y:2023 ~m:Month.Jan ~d:2;
    end_date = _date ~y:2023 ~m:Month.Dec ~d:31;
    description = "Post-bear rebound (full year 2023)";
  }

let all = [ bull; crash; recovery ]

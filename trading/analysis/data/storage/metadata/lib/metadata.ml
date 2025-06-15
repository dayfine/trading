open Core

type verification_status = Unverified | Verified | Failed | Pending
[@@deriving sexp, show, eq]

type t = {
  symbol : string;
  last_verified : Date.t;
  verification_status : verification_status;
  data_start_date : Date.t;
  data_end_date : Date.t;
  has_volume : bool;
  last_n_prices_avg_below_10 : bool;
  last_n_prices_avg_above_500 : bool;
}
[@@deriving sexp, show, eq]

let generate_metadata ~price_data ~symbol ?(n = 20) () =
  let start_date =
    List.hd_exn price_data |> fun p -> p.Types.Daily_price.date
  in
  let end_date =
    List.last_exn price_data |> fun p -> p.Types.Daily_price.date
  in
  let last_n_prices =
    List.take (List.rev price_data) n
    |> List.rev
    |> List.map ~f:(fun p -> p.Types.Daily_price.adjusted_close)
  in
  let avg_price =
    List.sum (module Float) last_n_prices ~f:Fn.id
    /. Float.of_int (List.length last_n_prices)
  in
  let actual_start =
    List.hd_exn price_data |> fun p -> p.Types.Daily_price.date
  in
  let actual_end =
    List.last_exn price_data |> fun p -> p.Types.Daily_price.date
  in
  let has_volume = List.exists price_data ~f:(fun p -> p.volume > 0) in
  let verification_status =
    if
      (not (Date.equal actual_start start_date))
      || not (Date.equal actual_end end_date)
    then Failed
    else Verified
  in
  {
    symbol;
    last_verified = Date.today ~zone:Time_float.Zone.utc;
    verification_status;
    data_start_date = start_date;
    data_end_date = end_date;
    has_volume;
    last_n_prices_avg_below_10 = Float.(avg_price < 10.0);
    last_n_prices_avg_above_500 = Float.(avg_price > 500.0);
  }

(* Create a module that exposes the type and functions *)
module T_sexp = struct
  type nonrec t = t

  let sexp_of_t = sexp_of_t
  let t_of_sexp = t_of_sexp
end

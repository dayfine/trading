open Core

type verification_status = Unverified | Verified | Failed | Pending
[@@deriving sexp, show]

type t = {
  symbol : string;
  last_verified : Date.t;
  verification_status : verification_status;
  data_start_date : Date.t;
  data_end_date : Date.t;
  has_volume : bool;
  last_n_prices_avg_below_10 : bool;
  last_n_prices_avg_above_500 : bool;
  splits : string list;
}
[@@deriving sexp, show]

let of_csv ~csv_path ~symbol ~n =
  let open Bos in
  let csv_path = Fpath.v csv_path in
  match OS.File.read csv_path with
  | Error (`Msg msg) -> failwith msg
  | Ok contents -> (
      let lines = String.split ~on:'\n' contents in
      match Csv.Parser.parse_lines lines with
      | Error status -> failwith status.message
      | Ok (price_data : Types.Daily_price.t list) ->
          let has_volume = List.exists price_data ~f:(fun p -> p.volume > 0) in
          let start_date =
            List.hd_exn price_data |> fun p -> p.Types.Daily_price.date
          in
          let end_date =
            List.last_exn price_data |> fun p -> p.Types.Daily_price.date
          in
          let last_n_prices =
            List.take (List.rev price_data) n
            |> List.rev
            |> List.map ~f:(fun p -> p.close_price)
          in
          let avg_price =
            List.sum (module Float) last_n_prices ~f:Fn.id
            /. Float.of_int (List.length last_n_prices)
          in
          {
            symbol;
            last_verified = Date.today ~zone:Time_float.Zone.utc;
            verification_status = Unverified;
            data_start_date = start_date;
            data_end_date = end_date;
            has_volume;
            last_n_prices_avg_below_10 = Float.(avg_price < 10.0);
            last_n_prices_avg_above_500 = Float.(avg_price > 500.0);
            splits = [];
          })

let save t ~csv_path =
  let open Bos in
  let metadata_path =
    Fpath.v (String.chop_suffix_exn csv_path ~suffix:".csv" ^ ".metadata.sexp")
  in
  let data = Sexp.to_string_hum (sexp_of_t t) in
  match OS.File.write metadata_path data with
  | Ok () -> ()
  | Error (`Msg msg) -> failwith msg

let load ~csv_path =
  let open Bos in
  let metadata_path =
    Fpath.v (String.chop_suffix_exn csv_path ~suffix:".csv" ^ ".metadata.sexp")
  in
  match OS.File.exists metadata_path with
  | Ok true -> (
      match OS.File.read metadata_path with
      | Ok contents -> Some (Sexp.of_string contents |> t_of_sexp)
      | Error (`Msg msg) -> failwith msg)
  | Ok false -> None
  | Error (`Msg msg) -> failwith msg

let verify t ~csv_path =
  let open Bos in
  let csv_path = Fpath.v csv_path in
  match OS.File.read csv_path with
  | Error (`Msg msg) -> failwith msg
  | Ok contents -> (
      let lines = String.split ~on:'\n' contents in
      match Csv.Parser.parse_lines lines with
      | Ok (price_data : Types.Daily_price.t list) ->
          let actual_start =
            List.hd_exn price_data |> fun p -> p.Types.Daily_price.date
          in
          let actual_end =
            List.last_exn price_data |> fun p -> p.Types.Daily_price.date
          in
          let has_volume = List.exists price_data ~f:(fun p -> p.volume > 0) in
          if
            (not (Date.equal actual_start t.data_start_date))
            || not (Date.equal actual_end t.data_end_date)
          then
            { t with verification_status = Failed }
          else if has_volume <> t.has_volume then
            { t with verification_status = Failed }
          else
            { t with
              verification_status = Verified;
              last_verified = Date.today ~zone:Time_float.Zone.utc;
            }
      | Error status -> failwith status.message)


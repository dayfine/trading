open Async
open Core
open Csv

type config = { data_dir : string; simulation_date : Date.t }
[@@deriving show, eq]

(* Clamp end_date to simulation_date to enforce no-lookahead *)
let _clamp_end_date simulation_date end_date =
  match end_date with
  | None -> Some simulation_date
  | Some d ->
      if Date.compare d simulation_date > 0 then Some simulation_date
      else Some d

(* Treat a missing data file as an empty result rather than an error *)
let _load_bars data_dir symbol ~start_date ~end_date ~simulation_date =
  let clamped_end = _clamp_end_date simulation_date end_date in
  match Csv_storage.create ~data_dir:(Fpath.v data_dir) symbol with
  | Error _ -> Ok []
  | Ok storage -> (
      match Csv_storage.get storage ?start_date ?end_date:clamped_end () with
      | Error { Status.code = NotFound; _ } -> Ok []
      | result -> result)

let make config =
  let data_dir = config.data_dir in
  let simulation_date = config.simulation_date in
  let module S = struct
    let get_bars ~(query : Data_source.bar_query) () =
      return
        (_load_bars data_dir query.symbol ~start_date:query.start_date
           ~end_date:query.end_date ~simulation_date)

    let get_universe () = return (Universe.load data_dir)
  end in
  (module S : Data_source.DATA_SOURCE)

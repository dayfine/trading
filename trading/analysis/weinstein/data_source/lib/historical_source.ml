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

(* Load bars from CSV, respecting the simulation_date ceiling *)
let _load_bars data_dir symbol ~start_date ~end_date ~simulation_date =
  let clamped_end = _clamp_end_date simulation_date end_date in
  match Csv_storage.create ~data_dir:(Fpath.v data_dir) symbol with
  | Error _ -> Ok []
  | Ok storage -> Csv_storage.get storage ?start_date ?end_date:clamped_end ()

(* Universe type for sexp serialisation *)
module Universe = struct
  type t = Types.Instrument_info.t list [@@deriving sexp]
end

(* Load universe from sexp file; return empty list if file absent *)
let _load_universe data_dir =
  let path = Fpath.(v data_dir / "universe.sexp") in
  match File_sexp.Sexp.load (module Universe) ~path with
  | Ok instruments -> Ok instruments
  | Error { Status.code = NotFound; _ } -> Ok []
  | Error e -> Error e

let make config =
  let data_dir = config.data_dir in
  let simulation_date = config.simulation_date in
  let module S = struct
    let get_bars ~(query : Data_source.bar_query) () =
      return
        (_load_bars data_dir query.symbol ~start_date:query.start_date
           ~end_date:query.end_date ~simulation_date)

    let get_universe () = return (_load_universe data_dir)
  end in
  (module S : Data_source.DATA_SOURCE)

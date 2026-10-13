open Core
module DVB = Universe.Dollar_volume_basis
module BR = Universe.Composition_bar_reader

(* The applied splits of [symbol]; none when either file is missing. *)
let _applied_splits ~bars_root symbol =
  let read =
    DVB.read_applied_splits DVB.true_dollars_config ~bars_root symbol
  in
  Option.bind (BR.read_bars ~bars_root symbol) ~f:read
  |> Option.value ~default:[]

let of_data_dir ~data_dir =
  let bars_root = Fpath.to_string data_dir in
  let memo = String.Table.create () in
  fun ~symbol date ->
    let splits =
      Hashtbl.find_or_add memo symbol ~default:(fun () ->
          _applied_splits ~bars_root symbol)
    in
    DVB.split_divisor ~splits date

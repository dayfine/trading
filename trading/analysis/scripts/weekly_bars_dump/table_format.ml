open Core

let _row_line ~label (b : Types.Daily_price.t) =
  Printf.sprintf "%-4s %10.2f %10.2f %10.2f %10.2f %12d" label b.open_price
    b.high_price b.low_price b.close_price b.volume

let render ~symbol_label ~bars ~week_labels ~ma_30w =
  let n = List.length bars in
  let n_labels = List.length week_labels in
  if n_labels <> n then
    invalid_arg
      (Printf.sprintf "Table_format.render: %d bars but %d week_labels" n
         n_labels)
  else
    let header =
      [
        Printf.sprintf "# weekly bars: %s (n=%d)" symbol_label n;
        "# series ends AT the decision week (last row); no bars after it are \
         included";
        Printf.sprintf "%-4s %10s %10s %10s %10s %12s" "week" "open" "high"
          "low" "close" "volume";
      ]
    in
    let rows =
      List.map2_exn week_labels bars ~f:(fun label b -> _row_line ~label b)
    in
    let footer =
      match ma_30w with
      | None -> []
      | Some v -> [ Printf.sprintf "# 30w MA at decision week: %.2f" v ]
    in
    String.concat ~sep:"\n" (header @ rows @ footer) ^ "\n"

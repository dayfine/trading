(** Basic metric types with no dependencies. *)

open Core

(** {1 Metric Types} *)

type metric_unit = Dollars | Percent | Days | Count | Ratio
[@@deriving show, eq]

type metric = {
  name : string;
  display_name : string;
  description : string;
  value : float;
  unit : metric_unit;
}
[@@deriving show, eq]

type metric_set = metric list

(** {1 Metric Type Enum} *)

type metric_type = Summary | SharpeRatio | MaxDrawdown [@@deriving show, eq]

(** {1 Utility Functions} *)

let find_metric (metrics : metric_set) ~name =
  List.find metrics ~f:(fun m -> String.equal m.name name)

let format_metric m =
  match m.unit with
  | Dollars -> Printf.sprintf "%s: $%.2f" m.display_name m.value
  | Percent -> Printf.sprintf "%s: %.2f%%" m.display_name m.value
  | Days -> Printf.sprintf "%s: %.1f days" m.display_name m.value
  | Count -> Printf.sprintf "%s: %.0f" m.display_name m.value
  | Ratio -> Printf.sprintf "%s: %.4f" m.display_name m.value

let format_metrics metrics =
  List.map metrics ~f:format_metric |> String.concat ~sep:"\n"

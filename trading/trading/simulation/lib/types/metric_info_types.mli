(** Shared types for {!Metric_info_registry}. See [.ml] for rationale. *)

type metric_unit = Dollars | Percent | Days | Count | Ratio
[@@deriving show, eq]

type metric_info = {
  display_name : string;
  description : string;
  unit : metric_unit;
}

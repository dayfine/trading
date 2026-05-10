(** Shared types for {!Metric_info_registry}. Carved out so that sibling files
    in the same library (e.g. {!Metric_info_registry_extras}) can contribute
    case branches without a circular dependency on the registry module. *)

type metric_unit = Dollars | Percent | Days | Count | Ratio
[@@deriving show, eq]

type metric_info = {
  display_name : string;
  description : string;
  unit : metric_unit;
}

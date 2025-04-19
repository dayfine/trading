type t = Increasing | Decreasing | Flat | Unknown [@@deriving show, eq]

let to_string = function
  | Increasing -> "increasing"
  | Decreasing -> "decreasing"
  | Flat -> "flat"
  | Unknown -> "unknown"

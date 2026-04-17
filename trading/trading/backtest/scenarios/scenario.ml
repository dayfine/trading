open Core

type range = { min_f : float; max_f : float }
(** A closed interval [min..max]. Kept in sexp form [((min <f>) (max <f>))]
    rather than the default derived [((min_f <f>) (max_f <f>))] so scenario
    files stay readable. *)

let _float_of_sexp = function
  | Sexp.Atom s -> Float.of_string s
  | other ->
      failwith (sprintf "expected float atom, got: %s" (Sexp.to_string other))

let _find_field_exn fields key =
  List.find_map fields ~f:(function
    | Sexp.List [ Sexp.Atom k; v ] when String.equal k key -> Some v
    | _ -> None)
  |> function
  | Some v -> v
  | None -> failwith (sprintf "missing required field: %s" key)

let range_of_sexp = function
  | Sexp.List fields ->
      {
        min_f = _find_field_exn fields "min" |> _float_of_sexp;
        max_f = _find_field_exn fields "max" |> _float_of_sexp;
      }
  | other -> failwith (sprintf "invalid range sexp: %s" (Sexp.to_string other))

let sexp_of_range r =
  Sexp.List
    [
      Sexp.List [ Sexp.Atom "min"; Sexp.Atom (sprintf "%g" r.min_f) ];
      Sexp.List [ Sexp.Atom "max"; Sexp.Atom (sprintf "%g" r.max_f) ];
    ]

type period = { start_date : Date.t; end_date : Date.t } [@@deriving sexp]

type expected = {
  total_return_pct : range;
  total_trades : range;
  win_rate : range;
  sharpe_ratio : range;
  max_drawdown_pct : range;
  avg_holding_days : range;
  unrealized_pnl : range option; [@sexp.option]
}
[@@deriving sexp]

type t = {
  name : string;
  description : string;
  period : period;
  config_overrides : Sexp.t list;
  expected : expected;
}
[@@deriving sexp] [@@sexp.allow_extra_fields]

let load path = t_of_sexp (Sexp.load_sexp path)
let in_range (r : range) v = Float.(v >= r.min_f && v <= r.max_f)

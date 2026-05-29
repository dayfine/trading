open Core

type axis =
  | Key of { path : string list; values : Sexp.t list }
  | Flag of { name : string; values : Sexp.t list }

(* Parse a record-shaped axis sexp into a [field -> args] assoc. *)
let _axis_fields (sexp : Sexp.t) : (string * Sexp.t list) list =
  match sexp with
  | Sexp.List entries ->
      List.map entries ~f:(function
        | Sexp.List (Sexp.Atom k :: rest) -> (k, rest)
        | other ->
            failwithf "Variant_matrix.axis_of_sexp: bad field %s"
              (Sexp.to_string other) ())
  | other ->
      failwithf "Variant_matrix.axis_of_sexp: expected record, saw %s"
        (Sexp.to_string other) ()

(* On-disk axis shape is a record, not a variant tag, so a spec reads naturally:
     ((key (stage3_force_exit_config hysteresis_weeks)) (values (1 2 3)))
     ((flag enable_laggard_rotation) (values (true false)))
   Exactly one of [key] / [flag] must be present alongside [values]. *)
let axis_of_sexp (sexp : Sexp.t) : axis =
  let assoc = _axis_fields sexp in
  let find k = List.Assoc.find assoc k ~equal:String.equal in
  let values =
    match find "values" with
    | Some [ Sexp.List vs ] -> vs
    | _ ->
        failwithf "Variant_matrix.axis_of_sexp: missing (values (...)) in %s"
          (Sexp.to_string sexp) ()
  in
  match (find "key", find "flag") with
  | Some [ Sexp.List path ], None ->
      Key { path = List.map path ~f:Sexp.to_string; values }
  | None, Some [ Sexp.Atom name ] -> Flag { name; values }
  | _ ->
      failwithf
        "Variant_matrix.axis_of_sexp: exactly one of (key (...)) / (flag name) \
         required in %s"
        (Sexp.to_string sexp) ()

let sexp_of_axis (axis : axis) : Sexp.t =
  let values_field values =
    Sexp.List [ Sexp.Atom "values"; Sexp.List values ]
  in
  match axis with
  | Key { path; values } ->
      let path = Sexp.List (List.map path ~f:(fun s -> Sexp.Atom s)) in
      Sexp.List [ Sexp.List [ Sexp.Atom "key"; path ]; values_field values ]
  | Flag { name; values } ->
      Sexp.List
        [ Sexp.List [ Sexp.Atom "flag"; Sexp.Atom name ]; values_field values ]

type expansion = Cartesian | Sampled of { n : int; seed : int }
[@@deriving sexp]

type t = { axes : axis list; expansion : expansion } [@@deriving sexp]

(* A flag is sugar for a single-component key-path axis. Normalising up-front
   means the rest of the module never special-cases [Flag]. *)
let _path_and_values = function
  | Key { path; values } -> (path, values)
  | Flag { name; values } -> ([ name ], values)

(* [path_to_override [a; b] v = ((a ((b v))))] and [[a] v = ((a v))].
   Mirrors the partial-config override shape consumed by [Overlay_validator]. *)
let _path_to_override path value : Sexp.t =
  let rec nest = function
    | [] -> value
    | key :: rest -> Sexp.List [ Sexp.List [ Sexp.Atom key; nest rest ] ]
  in
  match path with
  | [] -> failwith "Variant_matrix: axis key-path must be non-empty"
  | _ -> nest path

(* Compact, deterministic [leaf=value] label segment for one axis cell. *)
let _label_segment path value =
  let leaf = List.last_exn path in
  sprintf "%s=%s" leaf (Sexp.to_string value)

(* The canonical default config to validate overrides against. The universe is
   irrelevant to override key-resolution (we only check that each dot-path
   resolves to a real field), so a single placeholder symbol suffices. *)
let _index_symbol = "GSPC.INDX"

let _default_config () =
  Weinstein_strategy.default_config ~universe:[ "AAPL" ]
    ~index_symbol:_index_symbol

(* Validate one axis's override sexp against the default config. Raises [Failure]
   (via [Overlay_validator.apply_overrides]) on any unknown key-path, AT
   EXPANSION TIME — the 2026-05-12 81-cell silent-no-op guard. *)
let _validate_override override =
  ignore
    (Backtest.Overlay_validator.apply_overrides (_default_config ())
       [ override ])

(* One normalised axis: leaf name + the per-value (label-segment, override)
   pairs, validated. *)
type _axis_cells = { segments : (string * Sexp.t) list }

let _normalise_axis axis =
  let path, values = _path_and_values axis in
  let segments =
    List.map values ~f:(fun value ->
        let override = _path_to_override path value in
        _validate_override override;
        (_label_segment path value, override))
  in
  { segments }

(* Full cartesian product of the per-axis cell lists. Output order: first axis
   varies slowest (lexicographic). Each product element is the list of one
   (label-segment, override) pick per axis, in axis order. *)
let _cartesian (axes : _axis_cells list) : (string * Sexp.t) list list =
  List.fold_right axes ~init:[ [] ] ~f:(fun axis acc ->
      List.concat_map axis.segments ~f:(fun cell ->
          List.map acc ~f:(fun rest -> cell :: rest)))

let _cell_to_variant (cell : (string * Sexp.t) list) :
    Walk_forward_runner.variant =
  let label = String.concat ~sep:"__" (List.map cell ~f:fst) in
  let overrides = List.map cell ~f:snd in
  { label; overrides }

(* Deterministic seeded subset of [n] distinct cells. Shuffles a copy of the
   full product with a fresh [Random.State.t] (no global state), then takes the
   first [n]. Falls back to the full product when [n >= size]. *)
let _sample ~n ~seed (product : 'a list) : 'a list =
  if n >= List.length product then product
  else
    let state = Random.State.make [| seed |] in
    List.take (List.permute ~random_state:state product) n

let expand (t : t) : Walk_forward_runner.variant list =
  if List.is_empty t.axes then failwith "Variant_matrix: axes must be non-empty";
  let axes = List.map t.axes ~f:_normalise_axis in
  let product = _cartesian axes in
  let cells =
    match t.expansion with
    | Cartesian -> product
    | Sampled { n; seed } -> _sample ~n ~seed product
  in
  List.map cells ~f:_cell_to_variant

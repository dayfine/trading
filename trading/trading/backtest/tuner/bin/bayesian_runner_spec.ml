open Core
module Metric_types = Trading_simulation_types.Metric_types

type objective_spec =
  | Sharpe
  | Calmar
  | TotalReturn
  | Concavity_coef
  | Composite of (Metric_types.metric_type * float) list
[@@deriving sexp]

type acquisition_spec = Expected_improvement | Upper_confidence_bound of float
[@@deriving sexp]

type bound_spec =
  | Plain of float * float
  | Sentinel of { threshold : float; upper : float }

(** Custom sexp converters so the on-disk shape mirrors plan §2.5:
    [Plain (lo, hi)] writes as [(lo hi)] (legacy shape, two atoms);
    [Sentinel { threshold; upper }] writes as [(sentinel threshold upper)]
    (three atoms, leading tag). *)
let sexp_of_bound_spec = function
  | Plain (lo, hi) -> Sexp.List [ sexp_of_float lo; sexp_of_float hi ]
  | Sentinel { threshold; upper } ->
      Sexp.List
        [ Sexp.Atom "sentinel"; sexp_of_float threshold; sexp_of_float upper ]

let bound_spec_of_sexp sexp =
  match sexp with
  | Sexp.List [ Sexp.Atom "sentinel"; t; u ] ->
      Sentinel { threshold = float_of_sexp t; upper = float_of_sexp u }
  | Sexp.List [ lo; hi ] -> Plain (float_of_sexp lo, float_of_sexp hi)
  | _ ->
      Sexplib0.Sexp_conv.of_sexp_error
        "Bayesian_runner_spec.bound_spec_of_sexp: expected (lo hi) or \
         (sentinel threshold upper)"
        sexp

let sentinel_margin_fraction = 0.25

let plain_range = function
  | Plain (lo, hi) -> (lo, hi)
  | Sentinel { threshold; upper } ->
      let margin = (upper -. threshold) *. sentinel_margin_fraction in
      (threshold -. margin, upper)

let decode_sentinel_sample spec sampled =
  match spec with
  | Plain _ -> Some sampled
  | Sentinel { threshold; _ } ->
      if Float.( < ) sampled threshold then None else Some sampled

type t = {
  bounds : (string * (float * float)) list;
  acquisition : acquisition_spec;
  initial_random : int;
  total_budget : int;
  seed : int option;
  n_acquisition_candidates : int option;
  objective : objective_spec;
  scenarios : string list;
  holdout_folds : int list option; [@sexp.option]
  sentinel_bounds : (string * bound_spec) list option; [@sexp.option]
  length_scales : float list option; [@sexp.option]
  early_stop : (int * float) option; [@sexp.option]
  gate_penalty_value : float option; [@sexp.option]
  int_keys : string list; [@sexp.list]
}
[@@deriving sexp] [@@sexp.allow_extra_fields]

(** Atom marker that opts a single bounds entry into int-typed rounding.

    Pinned as ["int"] so the on-disk shape per binding is
    [("key" (lo hi) (int))] when the knob is int-typed, and the legacy
    [("key" (lo hi))] when it is float-typed. The marker is intentionally a
    short bare atom (not a record field) so each binding's float range and its
    int flag stay co-located visually, matching the user-facing spec design in
    [dev/notes/bayesian-11knob-int-knob-crash-2026-05-22.md] §"Fix path" Option
    A. *)
let _int_marker_atom = "int"

(** Recognise an [(int)] marker sexp produced by the per-binding sugar. Matches
    only the exact one-atom form ["(int)"] — anything else (extra atoms, quoted,
    wrapped) is rejected so typos do not silently parse as float bindings. *)
let _is_int_marker = function
  | Sexp.List [ Sexp.Atom a ] when String.equal a _int_marker_atom -> true
  | _ -> false

(** Split a single [bounds] binding into (legacy-2-tuple-sexp, is_int).

    Accepts:
    - [(key (lo hi))] — legacy float knob; returns [(input, false)].
    - [(key (lo hi) (int))] — int-marked knob; strips the [(int)] tail and
      returns [(stripped, true)].

    Any other shape is left untouched (returns [(input, false)]) so the
    downstream [(string * (float * float)) list] deserializer surfaces a
    [Of_sexp_error] with its full path — preserves the existing error message
    quality for malformed entries. *)
let _split_binding (binding : Sexp.t) : Sexp.t * bool =
  match binding with
  | Sexp.List [ key_sexp; range_sexp; marker ] when _is_int_marker marker ->
      (Sexp.List [ key_sexp; range_sexp ], true)
  | _ -> (binding, false)

(** Walk every entry in the [bounds] list, stripping any [(int)] markers and
    collecting the keys of int-marked bindings.

    Operates on the [Sexp.t] form of the [bounds] field's right-hand side, i.e.
    the list-of-bindings sexp. Returns
    [(legacy_bounds_list_sexp, ordered_int_keys)] — [ordered_int_keys] preserves
    the order of int-marked bindings in [bounds]. *)
let _strip_int_markers_from_bounds_list (bounds_sexp : Sexp.t) :
    Sexp.t * string list =
  match bounds_sexp with
  | Sexp.List bindings ->
      let stripped_rev, int_keys_rev =
        List.fold bindings ~init:([], []) ~f:(fun (acc_b, acc_k) binding ->
            let stripped, is_int = _split_binding binding in
            let acc_k =
              if is_int then
                match binding with
                | Sexp.List (Sexp.Atom key :: _) -> key :: acc_k
                | _ -> acc_k
              else acc_k
            in
            (stripped :: acc_b, acc_k))
      in
      (Sexp.List (List.rev stripped_rev), List.rev int_keys_rev)
  | _ -> (bounds_sexp, [])

(** Pre-process the outer spec sexp before handing it to the derived
    [t_of_sexp]. Strips per-binding [(int)] markers from [bounds] and injects
    (or augments) the [(int_keys ...)] field on the record with the extracted
    keys.

    Compose-safe: bindings can also opt-in by writing [(int_keys ...)]
    explicitly. When both forms appear, the per-binding markers are unioned into
    the explicit list (order: explicit-first then per-binding, preserved). *)
let _preprocess_spec_sexp (sexp : Sexp.t) : Sexp.t =
  match sexp with
  | Sexp.List fields ->
      let bounds_field, extracted_int_keys =
        List.fold fields ~init:(None, []) ~f:(fun (bf, ik) field ->
            match field with
            | Sexp.List [ Sexp.Atom "bounds"; inner ] ->
                let stripped, ks = _strip_int_markers_from_bounds_list inner in
                (Some (Sexp.List [ Sexp.Atom "bounds"; stripped ]), ik @ ks)
            | _ -> (bf, ik))
      in
      if List.is_empty extracted_int_keys then sexp
      else
        let fields_with_bounds =
          List.map fields ~f:(fun field ->
              match (field, bounds_field) with
              | Sexp.List [ Sexp.Atom "bounds"; _ ], Some bf -> bf
              | _ -> field)
        in
        let existing_int_keys, rest =
          List.partition_tf fields_with_bounds ~f:(function
            | Sexp.List [ Sexp.Atom "int_keys"; _ ] -> true
            | _ -> false)
        in
        let merged_keys =
          let explicit =
            List.concat_map existing_int_keys ~f:(function
              | Sexp.List [ Sexp.Atom "int_keys"; Sexp.List atoms ] ->
                  List.filter_map atoms ~f:(function
                    | Sexp.Atom k -> Some k
                    | _ -> None)
              | _ -> [])
          in
          explicit @ extracted_int_keys
        in
        let int_keys_field =
          Sexp.List
            [
              Sexp.Atom "int_keys";
              Sexp.List (List.map merged_keys ~f:(fun k -> Sexp.Atom k));
            ]
        in
        Sexp.List (rest @ [ int_keys_field ])
  | _ -> sexp

(** Shadow the derived [t_of_sexp] so [load] (and any direct caller) accepts the
    per-binding [(int)] sugar. Internally normalises the input sexp before
    delegating to the derived parser, which sees only the legacy 2-tuple binding
    shape plus the explicit [(int_keys ...)] field. *)
let t_of_sexp sexp = t_of_sexp (_preprocess_spec_sexp sexp)

(** Inject [(int)] markers back into each [bounds] binding whose key is in
    [int_keys_set]. Used by [sexp_of_t] so the on-disk form a checkpoint
    serialises matches the on-disk form a user would write — preserves
    round-trip stability under [t_of_sexp ∘ sexp_of_t]. *)
let _inject_int_markers_into_bounds_list (bounds_sexp : Sexp.t)
    ~(int_keys_set : Set.M(String).t) : Sexp.t =
  match bounds_sexp with
  | Sexp.List bindings ->
      let injected =
        List.map bindings ~f:(function
          | Sexp.List [ Sexp.Atom key; range ] when Set.mem int_keys_set key ->
              Sexp.List
                [
                  Sexp.Atom key; range; Sexp.List [ Sexp.Atom _int_marker_atom ];
                ]
          | other -> other)
      in
      Sexp.List injected
  | _ -> bounds_sexp

(** Post-process the derived [sexp_of_t]'s output to (a) re-attach per-binding
    [(int)] markers and (b) drop the now-redundant top-level [(int_keys ...)]
    field. Symmetric with [_preprocess_spec_sexp] so
    [t_of_sexp ∘ sexp_of_t = id] for any [t]. *)
let _postprocess_spec_sexp (sexp : Sexp.t) ~(int_keys : string list) : Sexp.t =
  let int_keys_set = Set.of_list (module String) int_keys in
  match sexp with
  | Sexp.List fields ->
      let fields_without_int_keys =
        List.filter fields ~f:(function
          | Sexp.List [ Sexp.Atom "int_keys"; _ ] -> false
          | _ -> true)
      in
      let fields_with_injected_bounds =
        List.map fields_without_int_keys ~f:(function
          | Sexp.List [ Sexp.Atom "bounds"; inner ] ->
              Sexp.List
                [
                  Sexp.Atom "bounds";
                  _inject_int_markers_into_bounds_list inner ~int_keys_set;
                ]
          | other -> other)
      in
      Sexp.List fields_with_injected_bounds
  | _ -> sexp

let sexp_of_t (t : t) : Sexp.t =
  _postprocess_spec_sexp (sexp_of_t t) ~int_keys:t.int_keys

let load path =
  try t_of_sexp (Sexp.load_sexp path)
  with exn ->
    failwithf "Bayesian_runner_spec.load: failed to parse %s: %s" path
      (Exn.to_string exn) ()

let to_grid_objective = function
  | Sharpe -> Tuner.Grid_search.Sharpe
  | Calmar -> Tuner.Grid_search.Calmar
  | TotalReturn -> Tuner.Grid_search.TotalReturn
  | Concavity_coef -> Tuner.Grid_search.Concavity_coef
  | Composite weights -> Tuner.Grid_search.Composite weights

let to_acquisition = function
  | Expected_improvement -> `Expected_improvement
  | Upper_confidence_bound beta -> `Upper_confidence_bound beta

let to_bo_config t =
  let rng =
    match t.seed with
    | Some n -> Stdlib.Random.State.make [| n |]
    | None -> Stdlib.Random.State.make [| 42 |]
  in
  let length_scales = Option.map t.length_scales ~f:Array.of_list in
  let early_stop_config =
    Option.map t.early_stop ~f:(fun (window, epsilon) ->
        { Tuner.Bayesian_opt.window; epsilon })
  in
  Tuner.Bayesian_opt.create_config ~bounds:t.bounds
    ~acquisition:(to_acquisition t.acquisition)
    ~initial_random:t.initial_random ~total_budget:t.total_budget ~rng
    ?length_scales ?early_stop_config ()

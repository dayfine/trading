open Core
module BA2 = Bigarray.Array2

type panel = (float, Bigarray.float64_elt, Bigarray.c_layout) BA2.t

(* One registry entry. The output panel is what [get] returns. RSI also needs
   two scratch panels (avg_gain, avg_loss) for its Wilder state; other
   kernels leave [scratch] empty. *)
type entry = {
  spec : Indicator_spec.t;
  output : panel;
  scratch : panel list;
      (** Auxiliary panels owned by the registry. Indexed by kernel-specific
          convention (e.g. RSI: [[avg_gain; avg_loss]]). *)
}

type t = {
  symbol_index : Symbol_index.t;
  n_rows : int;
  n_cols : int;
  entries : entry list;
  by_spec : (Indicator_spec.t, entry) Hashtbl.t;
}

let _make_nan_panel ~n_rows ~n_cols : panel =
  let p = BA2.create Bigarray.Float64 Bigarray.C_layout n_rows n_cols in
  BA2.fill p Float.nan;
  p

let _supported_names = [ "EMA"; "SMA"; "ATR"; "RSI" ]

let _validate_spec (s : Indicator_spec.t) =
  (match s.cadence with
  | Types.Cadence.Daily -> ()
  | other ->
      failwithf
        "Indicator_panels: spec %s has cadence=%s; Stage 1 supports only Daily"
        (Indicator_spec.to_string s)
        (Types.Cadence.sexp_of_t other |> Sexp.to_string)
        ());
  if s.period < 1 then
    failwithf "Indicator_panels: spec %s has non-positive period %d"
      (Indicator_spec.to_string s)
      s.period ();
  if not (List.mem _supported_names s.name ~equal:String.equal) then
    failwithf
      "Indicator_panels: spec %s has unsupported name (Stage 1 supports EMA / \
       SMA / ATR / RSI)"
      (Indicator_spec.to_string s)
      ()

let _make_entry ~n_rows ~n_cols (spec : Indicator_spec.t) =
  _validate_spec spec;
  let output = _make_nan_panel ~n_rows ~n_cols in
  let scratch =
    match spec.name with
    | "RSI" ->
        [ _make_nan_panel ~n_rows ~n_cols; _make_nan_panel ~n_rows ~n_cols ]
    | _ -> []
  in
  { spec; output; scratch }

let create ~symbol_index ~n_days ~specs =
  let n_rows = Symbol_index.n symbol_index in
  let n_cols = n_days in
  let by_spec = Hashtbl.create (module Indicator_spec) in
  let entries =
    List.map specs ~f:(fun spec ->
        match Hashtbl.find by_spec spec with
        | Some e -> e (* dedupe — same output panel for the same spec *)
        | None ->
            let e = _make_entry ~n_rows ~n_cols spec in
            Hashtbl.set by_spec ~key:spec ~data:e;
            e)
  in
  (* Preserve registration order, deduped via the hashtable. *)
  let seen = Hash_set.create (module Indicator_spec) in
  let unique_entries =
    List.filter entries ~f:(fun e ->
        if Hash_set.mem seen e.spec then false
        else (
          Hash_set.add seen e.spec;
          true))
  in
  { symbol_index; n_rows; n_cols; entries = unique_entries; by_spec }

let n t = t.n_rows
let n_days t = t.n_cols
let symbol_index t = t.symbol_index
let specs t = List.map t.entries ~f:(fun e -> e.spec)

let get t spec =
  match Hashtbl.find t.by_spec spec with
  | Some e -> e.output
  | None ->
      failwithf "Indicator_panels.get: unknown spec %s"
        (Indicator_spec.to_string spec)
        ()

let _advance_one ~ohlcv ~t (e : entry) =
  let close = Ohlcv_panels.close ohlcv in
  let high = Ohlcv_panels.high ohlcv in
  let low = Ohlcv_panels.low ohlcv in
  let period = e.spec.period in
  match (e.spec.name, e.scratch) with
  | "EMA", _ -> Ema_kernel.advance ~input:close ~output:e.output ~period ~t
  | "SMA", _ -> Sma_kernel.advance ~input:close ~output:e.output ~period ~t
  | "ATR", _ -> Atr_kernel.advance ~high ~low ~close ~output:e.output ~period ~t
  | "RSI", [ avg_gain; avg_loss ] ->
      Rsi_kernel.advance ~close ~avg_gain ~avg_loss ~output:e.output ~period ~t
  | "RSI", _ ->
      failwithf "Indicator_panels: RSI entry missing scratch panels for %s"
        (Indicator_spec.to_string e.spec)
        ()
  | other, _ ->
      failwithf
        "Indicator_panels: unsupported indicator name %S (validated at create)"
        other ()

let advance_all t ~ohlcv ~t:tick =
  if Ohlcv_panels.n ohlcv <> t.n_rows || Ohlcv_panels.n_days ohlcv <> t.n_cols
  then
    invalid_arg
      (Printf.sprintf
         "Indicator_panels.advance_all: shape mismatch (registry=%dx%d \
          ohlcv=%dx%d)"
         t.n_rows t.n_cols (Ohlcv_panels.n ohlcv)
         (Ohlcv_panels.n_days ohlcv));
  if tick < 0 || tick >= t.n_cols then
    invalid_arg
      (Printf.sprintf
         "Indicator_panels.advance_all: tick %d out of range [0, %d)" tick
         t.n_cols);
  List.iter t.entries ~f:(_advance_one ~ohlcv ~t:tick)

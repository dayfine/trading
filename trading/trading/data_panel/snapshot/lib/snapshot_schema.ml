open Core

type field =
  | EMA_50
  | SMA_50
  | ATR_14
  | RSI_14
  | Stage
  | RS_line
  | Macro_composite
  | Open
  | High
  | Low
  | Close
  | Volume
  | Adjusted_close
  | Res_max_high_130w
  | Res_max_high_260w
  | Res_max_high_520w
  | Res_bars_seen
  | Res_hist of int
[@@deriving sexp, compare, equal, show]

let n_hist_buckets = 20
let n_age_bands = 4
let n_hist_cells = n_age_bands * n_hist_buckets

(* Sketch-v5 PR 4: the dense resistance-sketch columns ([Res_max_high_*],
   [Res_bars_seen], [Res_hist]) are retired from the canonical schema. They were
   ~350x redundant with the per-symbol weekly series they derive from, and
   materializing them for every trading day blew the Docker VM's RAM budget on a
   top-3000 warehouse even on the v5 read path (the panel cache materializes whole
   [.snap] files, so the untouched dense columns still cost memory). The sketch is
   now reconstructed on demand from the sparse [SYMBOL.weekly] side-table
   ({!Data_panel_snapshot.Weekly_sidetable}). The [field] constructors above are
   deliberately KEPT so the three-generation runtime reader still decodes older v3
   (37-col) and v4 (97-col) warehouses via their own per-file manifest schemas —
   only the canonical [all_fields] / [default] no longer emit them. *)
let all_fields =
  [
    EMA_50;
    SMA_50;
    ATR_14;
    RSI_14;
    Stage;
    RS_line;
    Macro_composite;
    Open;
    High;
    Low;
    Close;
    Volume;
    Adjusted_close;
  ]

let field_name = function
  | EMA_50 -> "EMA_50"
  | SMA_50 -> "SMA_50"
  | ATR_14 -> "ATR_14"
  | RSI_14 -> "RSI_14"
  | Stage -> "Stage"
  | RS_line -> "RS_line"
  | Macro_composite -> "Macro_composite"
  | Open -> "Open"
  | High -> "High"
  | Low -> "Low"
  | Close -> "Close"
  | Volume -> "Volume"
  | Adjusted_close -> "Adjusted_close"
  | Res_max_high_130w -> "Res_max_high_130w"
  | Res_max_high_260w -> "Res_max_high_260w"
  | Res_max_high_520w -> "Res_max_high_520w"
  | Res_bars_seen -> "Res_bars_seen"
  | Res_hist k -> Printf.sprintf "Res_hist_%02d" k

(* Canonical sexp form drives the hash. We use [Sexp.to_string] (not
   [to_string_hum]) because the compact form omits whitespace entirely, so
   trivial formatter changes can never perturb the hash. *)
let compute_hash fields =
  let sexp = [%sexp_of: field list] fields in
  Sexp.to_string sexp |> Stdlib.Digest.string |> Stdlib.Digest.to_hex

type t = { fields : field list; schema_hash : string } [@@deriving sexp]

let create ~fields = { fields; schema_hash = compute_hash fields }
let default = create ~fields:all_fields
let n_fields t = List.length t.fields

let index_of t f =
  List.findi t.fields ~f:(fun _ g -> equal_field f g)
  |> Option.map ~f:(fun (i, _) -> i)

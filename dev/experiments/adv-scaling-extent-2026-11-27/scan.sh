#!/bin/sh
# Score every list-build candidate on two dollar-volume rules (current and consistent) for every reconstitution
# year. Measurement only: it writes per-(year, symbol) score files to $WORK and never touches the builder or the
# lists.
#
# The OCaml scanner is embedded below. It is written to a throwaway dune dir inside the checkout, built and run in
# the container, and the dir is removed on exit. It drives only existing libraries (universe, csv.corporate_actions).
#
# Usage (host, from anywhere):
#   TREE=<checkout path relative to /workspaces/trading-1> WORK=<dir inside that checkout> sh scan.sh
# $WORK must sit inside the checkout, so the container sees it at /workspaces/trading-1/$TREE/<same relative path>.
# Output: $WORK/scores-v12.tsv and $WORK/scores-v13.tsv, columns
#   year symbol score_current score_consistent score_all_restated score_all_raw mixed file_raw n_confirmed
#   n_applied_current
# plus $WORK/scores-vNN.tsv.files: one line per mixed file, each close-confirmed split as
# date:factor:jump_share:applied_by_current_rule.
# The scores are dollars: keep them out of the repo. rank.sh turns them into ranks and counts.
set -eu
: "${TREE:?set TREE}"
: "${WORK:?set WORK}"
CONTAINER=${CONTAINER:-trading-1-dev}
HOSTCO=$(cd "$(dirname "$0")/../../.." && pwd)
ROOT=/workspaces/trading-1/$TREE/trading
TMPD=analysis/data/universe/adv_extent_tmp
BARS=/workspaces/trading-1/data
TYPES=$BARS/symbol_types.sexp
mkdir -p "$WORK" "$HOSTCO/trading/$TMPD"
WORK=$(cd "$WORK" && pwd)
case $WORK in
"$HOSTCO"/*) CWORK=/workspaces/trading-1/$TREE/${WORK#"$HOSTCO"/} ;;
*) echo "scan.sh: WORK must be inside $HOSTCO" >&2 && exit 1 ;;
esac
trap 'rm -rf "$HOSTCO/trading/$TMPD"' EXIT

cat >"$HOSTCO/trading/$TMPD/dune" <<'EOF'
(executable
 (name adv_extent)
 (libraries core universe csv.corporate_actions fpath status))
EOF

cat >"$HOSTCO/trading/$TMPD/adv_extent.ml" <<'EOF'
open Core
module BR = Universe.Composition_bar_reader
module DVB = Universe.Dollar_volume_basis
module CI = Universe.Composition_inputs
module CA = Corporate_actions

(* The builder's knobs (Build_from_individuals.default_config with
   --true-dollar-volume). *)
let cfg = DVB.true_dollars_config
let trailing_window_days = 60
let min_window_bars = 30

(* Consistent rule: one volume basis per file. Every close-confirmed split
   whose factor is large enough to test (the current rule's threshold) votes
   with its jump share, weighted by |log factor|. A weighted share at or above
   the current rule's cut means the column is raw for every split (F = 1);
   otherwise it is restated for every close-confirmed split. No testable split:
   restated, as now. *)
let file_raw bars confirmed =
  let votes =
    List.filter_map confirmed ~f:(fun (s : CA.split) ->
        let w = Float.abs (Float.log s.factor) in
        if Float.(w < cfg.volume_raw_min_log_factor) then None
        else
          Option.map (DVB.volume_jump_share cfg bars s) ~f:(fun sh -> (w, sh)))
  in
  match votes with
  | [] -> false
  | _ ->
      let num = List.sum (module Float) votes ~f:(fun (w, sh) -> w *. sh) in
      let den = List.sum (module Float) votes ~f:fst in
      Float.(num /. den >= cfg.volume_raw_min_share)

let score ~splits ~date bars =
  (DVB.score_window cfg ~splits ~date ~trailing_window_days ~min_window_bars
     bars)
    .avg

let fmt = function None -> "NA" | Some v -> sprintf "%.6f" v
let list_date y = Date.create_exn ~y ~m:Month.May ~d:31

let active ~date (e : CI.inventory_entry) =
  Date.( <= ) e.data_start_date (Date.add_days date (-trailing_window_days))
  && Date.( >= ) e.data_end_date date

let emit oc ~bars ~rules ~flags y symbol =
  let date = list_date y in
  let scores = List.map rules ~f:(fun splits -> score ~splits ~date bars) in
  if List.exists scores ~f:Option.is_some then
    Out_channel.output_string oc
      (sprintf "%d\t%s\t%s\t%s\n" y symbol
         (String.concat ~sep:"\t" (List.map scores ~f:fmt))
         flags)

(* One line per mixed file: each close-confirmed split as
   date:factor:jump_share:applied_by_current_rule. *)
let describe oc ~bars ~current ~raw symbol confirmed =
  let one (s : CA.split) =
    let share =
      match DVB.volume_jump_share cfg bars s with
      | None -> "NA"
      | Some v -> sprintf "%.2f" v
    in
    let applied =
      List.mem current s ~equal:(fun (a : CA.split) b -> Date.equal a.date b.date)
    in
    sprintf "%s:%.4g:%s:%d" (Date.to_string s.date) s.factor share
      (Bool.to_int applied)
  in
  Out_channel.output_string oc
    (sprintf "%s\t%d\t%s\n" symbol (Bool.to_int raw)
       (String.concat ~sep:" " (List.map confirmed ~f:one)))

let scan_symbol ~bars_root ~years (oc, fc) (e : CI.inventory_entry) =
  let years = List.filter years ~f:(fun y -> active ~date:(list_date y) e) in
  if not (List.is_empty years) then
    match BR.read_bars ~bars_root e.symbol with
    | None -> ()
    | Some bars ->
        let vendor =
          CA.read_splits ~data_dir:(Fpath.v bars_root) e.symbol
          |> Result.ok |> Option.value ~default:[]
        in
        let confirmed = DVB.close_confirmed_splits cfg bars vendor in
        let current = DVB.applied_splits cfg bars vendor in
        let nc = List.length confirmed and na = List.length current in
        let mixed = na > 0 && na < nc in
        let raw = file_raw bars confirmed in
        let consistent = if raw then [] else confirmed in
        if mixed then describe fc ~bars ~current ~raw e.symbol confirmed;
        let flags =
          sprintf "%d\t%d\t%d\t%d" (Bool.to_int mixed) (Bool.to_int raw) nc na
        in
        (* current, consistent, then the two one-basis bounds: every
           close-confirmed split applied, and none. *)
        let rules = [ current; consistent; confirmed; [] ] in
        List.iter years ~f:(fun y -> emit oc ~bars ~rules ~flags y e.symbol)

let () =
  match Sys.get_argv () with
  | [| _; bars_root; types; inventory; y0; y1; out |] ->
      let ok = function Ok v -> v | Error e -> failwith (Status.show e) in
      let inv = ok (CI.load_inventory inventory) in
      let eq = ok (CI.load_equity_like_lookup types) in
      let years = List.range (Int.of_string y0) (Int.of_string y1 + 1) in
      Out_channel.with_file out ~f:(fun oc ->
          Out_channel.with_file (out ^ ".files") ~f:(fun fc ->
              List.iter inv.symbols ~f:(fun (e : CI.inventory_entry) ->
                  match Hashtbl.find eq e.symbol with
                  | Some true -> scan_symbol ~bars_root ~years (oc, fc) e
                  | _ -> ())))
  | _ -> failwith "usage: adv_extent BARS TYPES INVENTORY Y0 Y1 OUT"
EOF

dx() { docker exec -w "$ROOT" "$CONTAINER" opam exec -- "$@"; }
dx dune build "./$TMPD/adv_extent.exe"
EXE=$ROOT/_build/default/$TMPD/adv_extent.exe
TD=$ROOT/test_data/backtest_scenarios
dx "$EXE" "$BARS" "$TYPES" "$TD/pit-v12/inventory.sexp" 1998 2025 "$CWORK/scores-v12.tsv"
dx "$EXE" "$BARS" "$TYPES" "$TD/pit-v13/inventory.sexp" 1998 2026 "$CWORK/scores-v13.tsv"

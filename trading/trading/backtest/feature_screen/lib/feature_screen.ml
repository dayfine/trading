(** See [feature_screen.mli] for the API contract. *)

open Core

type era_fit = {
  label : string;
  n_rows : int;
  fit : (Regression.ols_result * Regression.logit_result) option;
}

type t = {
  n_total : int;
  coverage : Feature_matrix.coverage list;
  n_complete : int;
  column_names : string list;
  ols : Regression.ols_result;
  logit : Regression.logit_result;
  eras : era_fit list;
}

(* Fit both models on one design. *)
let _fit (design : Feature_matrix.design) :
    (Regression.ols_result * Regression.logit_result, string) result =
  let names = design.column_names in
  let%bind.Result ols = Regression.ols ~x:design.x ~y:design.y ~names in
  let%bind.Result logit =
    Regression.logistic ~x:design.x ~y:design.win ~names
  in
  Ok (ols, logit)

(* Build + fit a subset of rows; [None] fit when it can't be fit (too few
   complete-case rows or rank-deficient) rather than failing the whole screen. *)
let _fit_rows ~features rows :
    (Regression.ols_result * Regression.logit_result) option =
  match Feature_matrix.build ~features ~rows with
  | Error _ -> None
  | Ok (design, _) -> (
      match _fit design with Error _ -> None | Ok r -> Some r)

let _era_fits ~features rows : era_fit list =
  List.map (Feature_matrix.eras rows) ~f:(fun (label, members) ->
      { label; n_rows = List.length members; fit = _fit_rows ~features members })

let screen ~rows ~features : (t, string) result =
  let%bind.Result design, coverage = Feature_matrix.build ~features ~rows in
  let%bind.Result ols, logit = _fit design in
  Ok
    {
      n_total = List.length rows;
      coverage;
      n_complete = design.n_complete;
      column_names = design.column_names;
      ols;
      logit;
      eras = _era_fits ~features rows;
    }

open Core

(* params for calling the EODHD API *)
type historical_price_params = {
  symbol : string;
  (* If not specified, omitted from the API call *)
  start_date : Date.t option;
  (* If not specified, defaults to today *)
  end_date : Date.t option;
}

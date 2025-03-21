open Core

type t = {
  symbol : string;
  start_date : Date.t option;
  end_date : Date.t option;
}

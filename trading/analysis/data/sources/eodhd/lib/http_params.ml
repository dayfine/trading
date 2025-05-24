open Core

type historical_price_params = {
  symbol : string;
  start_date : Date.t option;
  end_date : Date.t option;
}

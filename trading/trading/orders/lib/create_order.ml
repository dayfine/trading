open Trading_base.Types
open Status
open Types

type order_params = {
  symbol : symbol;
  side : side;
  order_type : order_type;
  quantity : quantity;
  time_in_force : time_in_force;
}
[@@deriving show, eq]

let _generate_order_id () =
  let timestamp =
    Time_ns_unix.now () |> Time_ns_unix.to_int63_ns_since_epoch
    |> Core.Int63.to_string
  in
  let random_suffix = Random.int 10000 |> Printf.sprintf "%04d" in
  timestamp ^ "_" ^ random_suffix

let create_order ?(now_time = Time_ns_unix.now ()) params =
  let statuses = ref [] in

  (* Validate symbol *)
  if params.symbol = "" then
    statuses := invalid_argument_error "Symbol cannot be empty" :: !statuses;

  (* Validate quantity *)
  if params.quantity <= 0.0 then
    statuses :=
      invalid_argument_error
        (Printf.sprintf "Quantity must be positive: %.2f" params.quantity)
      :: !statuses;

  (* Validate order type prices *)
  (match params.order_type with
  | (Limit price | Stop price) when price <= 0.0 ->
      statuses :=
        invalid_argument_error
          (Printf.sprintf "Price must be positive: %.2f" price)
        :: !statuses
  | StopLimit (stop_price, limit_price) -> (
      (* Validate stop-limit prices are positive *)
      if stop_price <= 0.0 then
        statuses :=
          invalid_argument_error
            (Printf.sprintf "Stop price must be positive: %.2f" stop_price)
          :: !statuses;
      if limit_price <= 0.0 then
        statuses :=
          invalid_argument_error
            (Printf.sprintf "Limit price must be positive: %.2f" limit_price)
          :: !statuses;
      (* Validate stop-limit price relationships based on order side *)
      match params.side with
      | Buy when stop_price > limit_price ->
          statuses :=
            invalid_argument_error
              (Printf.sprintf
                 "For buy stop-limit orders, stop price (%.2f) must be <= \
                  limit price (%.2f)"
                 stop_price limit_price)
            :: !statuses
      | Sell when stop_price < limit_price ->
          statuses :=
            invalid_argument_error
              (Printf.sprintf
                 "For sell stop-limit orders, stop price (%.2f) must be >= \
                  limit price (%.2f)"
                 stop_price limit_price)
            :: !statuses
      | _ -> ())
  | _ -> ());

  (* Return error if validation failed *)
  match !statuses with
  | [] ->
      Result.Ok
        {
          id = _generate_order_id ();
          symbol = params.symbol;
          side = params.side;
          order_type = params.order_type;
          quantity = params.quantity;
          time_in_force = params.time_in_force;
          status = Pending;
          filled_quantity = 0.0;
          avg_fill_price = None;
          created_at = now_time;
          updated_at = now_time;
        }
  | errs -> Result.Error (combine errs)

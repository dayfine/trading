open Core

type through = By_date of Date.t | By_index of int

let _index_of_by_index ~n i : int Status.status_or =
  if i >= 0 && i < n then Ok i
  else
    Status.error_invalid_argument
      (Printf.sprintf "By_index %d out of range [0, %d)" i n)

let _index_of_by_date ~(weekly : Types.Daily_price.t array) d :
    int Status.status_or =
  match
    Array.findi weekly ~f:(fun _ (b : Types.Daily_price.t) ->
        Date.equal b.date d)
  with
  | Some (i, _) -> Ok i
  | None ->
      Status.error_not_found
        (Printf.sprintf "no weekly bar dated %s" (Date.to_string d))

let _resolve_index ~(weekly : Types.Daily_price.t array) ~through :
    int Status.status_or =
  match through with
  | By_index i -> _index_of_by_index ~n:(Array.length weekly) i
  | By_date d -> _index_of_by_date ~weekly d

let select ~weekly ~through ~weeks_back :
    Types.Daily_price.t list Status.status_or =
  let open Result.Let_syntax in
  if weeks_back <= 0 then
    Status.error_invalid_argument
      (Printf.sprintf "weeks_back must be positive, got %d" weeks_back)
  else
    let arr = Array.of_list weekly in
    let%bind decision_index = _resolve_index ~weekly:arr ~through in
    let start = Int.max 0 (decision_index - weeks_back + 1) in
    let len = decision_index - start + 1 in
    return (Array.to_list (Array.sub arr ~pos:start ~len))

let trailing_average_close (bars : Types.Daily_price.t list) ~period :
    float option =
  let n = List.length bars in
  if n < period then None
  else
    let trailing = List.drop bars (n - period) in
    Some
      (List.sum (module Float) trailing ~f:(fun b -> b.close_price)
      /. Float.of_int period)

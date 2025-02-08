open Async

module Params : sig
  type t

  val make : symbol:string -> t
  val to_uri : t -> Uri.t
end

val get_body : token:string -> uri:Uri.t -> string Deferred.t

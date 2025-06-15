val save :
  (module Base.Sexpable.S with type t = 'a) -> 'a -> path:Fpath.t -> unit
(** Save data to a SEXP file
    @param t: Data to save
    @param path: filepath to save the data to *)

val load :
  (module Base.Sexpable.S with type t = 'a) -> path:Fpath.t -> 'a option
(** Load data from a SEXP file if it exists
    @param path: filepath to load the data from *)

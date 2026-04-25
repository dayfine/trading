(** Snapshot serialization for one or more [N x T] Float64 Bigarray panels.

    File layout:
    {v
      bytes 0..7        header_len : int64 little-endian
      bytes 8..(8+H-1)  header_sexp : ASCII sexp (H = header_len)
      bytes 8+H..       body : N panels, each N_rows * N_cols * 8 bytes,
                               row-major C-layout, raw float64
    v}

    The header sexp records:
    - [n_rows], [n_cols] (panel dimensions; all panels share these)
    - [symbols] (universe, in row-index order — used to reconstruct the
      [Symbol_index])
    - [panel_names] (in body order — informational + sanity-check)
    - [dtype] (presently always ["float64"]; reserved for future variant panels)

    Read path uses [Unix.map_file] so loading a snapshot is dominated by mmap
    page mapping: O(milliseconds) for any realistic size. The Bigarrays returned
    by [load] are mmap'd; modifying them would write through to the file, so
    callers should treat them as read-only or copy with [Bigarray.Array2.blit]
    into a fresh allocation if mutation is needed. *)

type panel = (float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Array2.t

val dump :
  path:string ->
  Symbol_index.t ->
  panels:panel array ->
  panel_names:string list ->
  unit
(** [dump ~path idx ~panels ~panel_names] writes the panels and [Symbol_index]
    to a single file at [path]. All panels must have shape
    [(Symbol_index.n idx) x n_cols] with the same [n_cols]. The number of
    [panels] and [panel_names] must match. Overwrites any existing file at
    [path]. Raises [Invalid_argument] on shape mismatch or name-list length
    mismatch. *)

val load : path:string -> Symbol_index.t * panel array * string list
(** [load ~path] reads the header and mmaps the body. Returns the reconstructed
    [Symbol_index], the panels (mmap'd, read-only by convention), and the
    [panel_names] in body order. Raises [Failure] or [Sys_error] if the file is
    malformed or cannot be opened. *)

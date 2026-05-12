open Core
module GS = Tuner.Grid_search

let _shards_dir ~out_dir = Filename.concat out_dir ".cell-shards"

let _shard_path ~out_dir ~idx =
  Filename.concat (_shards_dir ~out_dir) (sprintf "cell-%05d.sexp" idx)

(* Fork-based cell-parallel evaluator. Each child evaluates exactly one cell
   across all scenarios and writes its [row list] to a per-cell sexp shard
   under [.cell-shards/]. The parent reaps children up to [parallel] at a
   time, then concatenates shards in cell-enumeration order. Mirrors the
   fork-pool pattern in [Scenario_runner._run_scenarios_parallel] — children
   are isolated for memory + crash safety, which matters because each cell
   loads its own ~1-2 GB universe-of-bars snapshot. *)

let _fork_cell ~out_dir ~scenarios ~objective ~evaluator ~idx ~cell =
  match Core_unix.fork () with
  | `In_the_child ->
      let exit_code =
        try
          let rows = GS.rows_for_cell cell ~scenarios ~objective ~evaluator in
          Sexp.save_hum
            (_shard_path ~out_dir ~idx)
            ([%sexp_of: GS.row list] rows);
          0
        with e ->
          eprintf "[grid_search] cell %d crashed: %s\n%!" idx (Exn.to_string e);
          1
      in
      Stdlib.exit exit_code
  | `In_the_parent pid -> pid

let _await_one running =
  let idx, pid = Queue.dequeue_exn running in
  let status = Core_unix.waitpid pid in
  (idx, status)

let _read_shard ~out_dir ~idx =
  [%of_sexp: GS.row list] (Sexp.load_sexp (_shard_path ~out_dir ~idx))

let _evaluate_grid_parallel ~spec ~objective ~evaluator ~parallel ~out_dir =
  Core_unix.mkdir_p (_shards_dir ~out_dir);
  let cells =
    GS.cells_of_spec
      (Grid_search_spec.to_grid_param_spec spec.Grid_search_spec.params)
  in
  let indexed = List.mapi cells ~f:(fun i c -> (i, c)) in
  let running = Queue.create () in
  let crashes = ref [] in
  let reap () =
    let idx, status = _await_one running in
    match status with Ok () -> () | Error _ -> crashes := idx :: !crashes
  in
  List.iter indexed ~f:(fun (idx, cell) ->
      if Queue.length running >= parallel then reap ();
      let pid =
        _fork_cell ~out_dir ~scenarios:spec.scenarios ~objective ~evaluator ~idx
          ~cell
      in
      Queue.enqueue running (idx, pid));
  while not (Queue.is_empty running) do
    reap ()
  done;
  (match !crashes with
  | [] -> ()
  | xs ->
      failwithf "[grid_search] %d cell(s) crashed (indices: %s)"
        (List.length xs)
        (String.concat ~sep:"," (List.map xs ~f:Int.to_string))
        ());
  List.concat_map indexed ~f:(fun (idx, _) -> _read_shard ~out_dir ~idx)

let _result_of_rows rows =
  let best_cell, best_score = GS.argmax_by_cell rows in
  { GS.rows; best_cell; best_score }

let run_and_write ~(spec : Grid_search_spec.t) ~out_dir ~evaluator ~parallel =
  Core_unix.mkdir_p out_dir;
  let objective = Grid_search_spec.to_grid_objective spec.objective in
  let params = Grid_search_spec.to_grid_param_spec spec.params in
  let result =
    if parallel <= 1 then
      GS.run params ~scenarios:spec.scenarios ~objective ~evaluator
    else
      let rows =
        _evaluate_grid_parallel ~spec ~objective ~evaluator ~parallel ~out_dir
      in
      _result_of_rows rows
  in
  let sensitivity = GS.compute_sensitivity params result in
  let csv_path = Filename.concat out_dir "grid.csv" in
  let best_path = Filename.concat out_dir "best.sexp" in
  let sens_path = Filename.concat out_dir "sensitivity.md" in
  GS.write_csv ~output_path:csv_path ~objective result;
  GS.write_best_sexp ~output_path:best_path result;
  GS.write_sensitivity_md ~output_path:sens_path ~objective sensitivity;
  result

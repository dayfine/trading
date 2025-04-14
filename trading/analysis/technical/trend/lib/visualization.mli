(** Visualization module for plotting segmentation results *)

(** Creates a plot visualizing the segmentation results.
    @param data Array of data points
    @param segments List of segments to visualize *)
val create_plot : float array -> Segmentation.segment list -> unit

(** Visualization module for plotting segmentation results *)

val create_plot : float array -> Segmentation.segment list -> unit
(** Creates a plot visualizing the segmentation results.
    @param data Array of data points
    @param segments List of segments to visualize *)

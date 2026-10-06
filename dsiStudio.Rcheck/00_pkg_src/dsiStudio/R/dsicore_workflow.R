## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ DSI Core: main workflow ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Run complete DSI screening workflow
#' 
#' Processes data through the full DSI pipeline.
#' 
#' @param df Input data frame
#' @param col_map Column mapping (year/date, species, fleet, catch, effort, cpue)
#' @param group_cols Grouping columns
#' @param min_n Minimum window length
#' @param max_n Maximum window length
#' @param anchor_mode Window anchor mode ("last_usable_year", "last_year", "free")
#' @param method "corrected" or "legacy"
#' @param effort_semantics Effort handling ("per_group_year", "per_fleet_year", "per_row")
#' @param refs Reference parameters (merged over [default_dsi_refs()])
#' @param weights Component weights (default follows `fixes$weights_sum_one`)
#' @param fixes Bug-fix switches; default `dsi_fix_flags(method)`. Used by the
#'   Legacy vs Corrected comparison to switch one correction at a time.
#' @param min_usable Minimum usable observations per window
#' @param selection_opts Selection criteria
#' @param progress_callback Optional function(message, value) for progress updates
#' @return List with standardized data, audit findings, all windows, best windows
#' @export
run_dsi_workflow <- function(df,
                            col_map,
                            group_cols = c("species", "fleet"),
                            min_n = 8,
                            max_n = 20,
                            anchor_mode = "last_usable_year",
                            method = "corrected",
                            effort_semantics = "per_group_year",
                            refs = default_dsi_refs(),
                            weights = NULL,
                            selection_opts = default_selection_opts(),
                            progress_callback = NULL,
                            fixes = NULL,
                            min_usable = 6) {
  fixes <- fixes %||% dsi_fix_flags(method)
  weights <- weights %||% default_dsi_weights(legacy = !isTRUE(fixes$weights_sum_one))
  refs <- utils::modifyList(default_dsi_refs(), refs %||% list())
  selection_opts <- utils::modifyList(default_selection_opts(), selection_opts %||% list())
  if (length(group_cols) == 0) group_cols <- NULL
  
  report_progress <- function(msg, value = NULL) {
    if (!is.null(progress_callback)) {
      progress_callback(msg, value)
    }
  }
  
  report_progress("Standardizing data...", 0.1)
  df_std <- standardize_columns(df, col_map)
  
  report_progress("Harmonizing effort...", 0.2)
  if (isTRUE(fixes$effort_harmonisation)) {
    df_std <- harmonize_effort_corrected(df_std, effort_semantics, group_cols)
  } else {
    df_std <- harmonize_effort_legacy(df_std)
  }
  
  report_progress("Auditing data quality...", 0.25)
  audit_findings <- audit_data(df_std, group_cols)
  
  report_progress("Generating windows...", 0.3)
  windows <- generate_all_windows(df_std, group_cols, min_n, max_n, 
                                 anchor_mode,
                                 if (isTRUE(fixes$anchor_last_usable)) "corrected" else "legacy")
  
  if (nrow(windows) == 0) {
    return(list(
      data_std = df_std,
      audit = audit_findings,
      windows = windows,
      dsi_all = NULL,
      dsi_best = NULL,
      error = "No valid windows generated"
    ))
  }
  
  report_progress("Computing metrics for windows...", 0.35)
  
  df_std$group_key <- make_group_key(df_std, group_cols)
  
  n_windows <- nrow(windows)
  
  dsi_results <- lapply(seq_len(n_windows), function(i) {
    if (i %% max(1, floor(n_windows / 20)) == 0) {
      progress_val <- 0.35 + 0.5 * (i / n_windows)
      report_progress(sprintf("Processing window %d of %d...", i, n_windows), 
                     progress_val)
    }
    
    row <- windows[i, ]
    grp_data <- df_std[df_std$group_key == row$group_key, ]
    
    result <- score_window(grp_data, row$start_year, row$end_year,
                          refs = refs, weights = weights, include_v2 = TRUE,
                          fixes = fixes, min_n = min_n, min_usable = min_usable)
    
    result$group_key <- row$group_key
    result
  })
  
  report_progress("Compiling results...", 0.85)
  
  # [LOCAL FIX 7] invalid windows return fewer fields than valid ones, so
  # do.call(rbind, ...) failed with "numbers of columns of arguments do not
  # match" on the Species x Fleet demo. bind_rows() fills missing fields with NA.
  dsi_all <- dplyr::bind_rows(lapply(dsi_results, function(x) {
    as.data.frame(x, stringsAsFactors = FALSE)
  }))
  
  report_progress("Selecting best windows...", 0.9)
  
  dsi_best <- select_best_window(dsi_all, selection_opts, "group_key",
                                 stability_filter = isTRUE(fixes$stability_filter))
  
  report_progress("Complete", 1.0)
  
  list(
    data_std = df_std,
    audit = audit_findings,
    windows = windows,
    dsi_all = dsi_all,
    dsi_best = dsi_best,
    config = list(
      col_map = col_map,
      group_cols = group_cols,
      min_n = min_n,
      max_n = max_n,
      anchor_mode = anchor_mode,
      method = method,
      effort_semantics = effort_semantics,
      refs = refs,
      weights = weights,
      selection_opts = selection_opts,
      fixes = fixes,
      min_usable = min_usable
    )
  )
}

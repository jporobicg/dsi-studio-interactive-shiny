## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ DSI Core: selection and interpretation ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Default selection options
#' 
#' @return List of selection thresholds and criteria
#' @export
default_selection_opts <- function() {
  list(
    min_n_usable = 6,
    min_frac_usable = 0.6,
    min_ec = 0.4,
    min_ic = 1.2,
    max_f_beta_pos = 0.3,
    min_eligible_windows = 3,
    min_dsi_v2_top1 = 70,
    max_dsi_v2_spread = 20
  )
}

#' Select best window per group
#'
#' @param dsi_all Data frame with all windows and their scores
#' @param opts Selection options
#' @param group_col Name of group column
#' @param stability_filter TRUE = corrected filter; FALSE = the original,
#'   always-true filter
#' @return Data frame with best window per group and READY status
#' @export
select_best_window <- function(dsi_all, opts = default_selection_opts(),
                               group_col = "group_key", stability_filter = TRUE) {
  opts <- utils::modifyList(default_selection_opts(), opts %||% list())
  if (stability_filter) select_best_window_corrected(dsi_all, opts, group_col)
  else select_best_window_legacy(dsi_all, opts, group_col)
}

#' Select best window per group (CORRECTED VERSION)
#' 
#' Fixed stability filter and proper grouping.
#' 
#' @param dsi_all Data frame with all windows and their scores
#' @param opts Selection options
#' @param group_col Name of group column
#' @return Data frame with best window per group and READY status
#' @export
select_best_window_corrected <- function(dsi_all, opts = default_selection_opts(),
                                        group_col = "group_key") {
  
  dsi_all$eligible <- FALSE
  
  eligible_mask <- 
    dsi_all$valid &
    dsi_all$n_usable >= opts$min_n_usable &
    dsi_all$beta < 0 &
    dsi_all$frac_usable >= opts$min_frac_usable &
    dsi_all$ec >= opts$min_ec &
    dsi_all$ic >= opts$min_ic &
    !is.na(dsi_all$dsi_v2) &
    is.finite(dsi_all$dsi_v2)
  
  eligible_mask[is.na(eligible_mask)] <- FALSE
  
  if ("f_beta_pos" %in% names(dsi_all)) {
    stab_mask <- dsi_all$f_beta_pos <= opts$max_f_beta_pos
    stab_mask[is.na(stab_mask)] <- FALSE
    eligible_mask <- eligible_mask & stab_mask
  }
  
  dsi_all$eligible <- eligible_mask
  
  groups <- unique(dsi_all[[group_col]])
  
  results <- lapply(groups, function(grp) {
    grp_data <- dsi_all[dsi_all[[group_col]] == grp, ]
    grp_eligible <- grp_data[grp_data$eligible, ]
    
    n_eligible <- nrow(grp_eligible)
    
    if (n_eligible == 0) {
      best_all <- grp_data[order(-grp_data$dsi_v2, -grp_data$n_usable, 
                                  grp_data$beta, -grp_data$ec, 
                                  na.last = TRUE)[1], ]
      best_all$ready <- FALSE
      best_all$selection_reason <- "no_eligible_windows"
      return(best_all)
    }
    
    grp_eligible <- grp_eligible[order(-grp_eligible$dsi_v2, -grp_eligible$n_usable,
                                       grp_eligible$beta, -grp_eligible$ec), ]
    
    top1_score <- grp_eligible$dsi_v2[1]
    
    ready <- TRUE
    reasons <- character(0)
    
    if (n_eligible < opts$min_eligible_windows) {
      ready <- FALSE
      reasons <- c(reasons, "few_eligible")
    }
    
    if (top1_score < opts$min_dsi_v2_top1) {
      ready <- FALSE
      reasons <- c(reasons, "low_DSI_v2")
    }
    
    if (n_eligible >= 3) {
      top3_score <- grp_eligible$dsi_v2[3]
      spread <- top1_score - top3_score
      
      if (spread > opts$max_dsi_v2_spread) {
        ready <- FALSE
        reasons <- c(reasons, "unstable_spread")
      }
    }
    
    best <- grp_eligible[1, ]
    best$ready <- ready
    best$selection_reason <- if (ready) "ready" else paste(reasons, collapse = "; ")
    
    best
  })
  
  do.call(rbind, results)
}

#' Select best window per group (LEGACY VERSION)
#' 
#' Reproduces broken stability filter: (f_beta_pos <= 0.3) | (s_stab >= 0)
#' which is always TRUE.
#' 
#' @param dsi_all Data frame with all windows
#' @param opts Selection options
#' @param group_col Name of group column
#' @return Data frame with best window per group
#' @keywords internal
select_best_window_legacy <- function(dsi_all, opts = default_selection_opts(),
                                     group_col = "group_key") {
  
  dsi_all$eligible <- FALSE
  
  eligible_mask <- 
    dsi_all$valid &
    dsi_all$n_usable >= opts$min_n_usable &
    dsi_all$beta < 0 &
    dsi_all$frac_usable >= opts$min_frac_usable &
    dsi_all$ec >= opts$min_ec &
    dsi_all$ic >= opts$min_ic &
    !is.na(dsi_all$dsi_v2) &
    is.finite(dsi_all$dsi_v2)
  
  eligible_mask[is.na(eligible_mask)] <- FALSE
  
  if ("f_beta_pos" %in% names(dsi_all) && "s_stab" %in% names(dsi_all)) {
    stab_mask <- (dsi_all$f_beta_pos <= opts$max_f_beta_pos) | (dsi_all$s_stab >= 0)
    stab_mask[is.na(stab_mask)] <- FALSE
    eligible_mask <- eligible_mask & stab_mask
  }
  
  dsi_all$eligible <- eligible_mask
  
  groups <- unique(dsi_all[[group_col]])
  
  results <- lapply(groups, function(grp) {
    grp_data <- dsi_all[dsi_all[[group_col]] == grp, ]
    grp_eligible <- grp_data[grp_data$eligible, ]
    
    n_eligible <- nrow(grp_eligible)
    
    if (n_eligible == 0) {
      best_all <- grp_data[order(-grp_data$dsi_v2, -grp_data$n_usable, 
                                  grp_data$beta, -grp_data$ec, 
                                  na.last = TRUE)[1], ]
      best_all$ready <- FALSE
      best_all$selection_reason <- "no_eligible_windows"
      return(best_all)
    }
    
    grp_eligible <- grp_eligible[order(-grp_eligible$dsi_v2, -grp_eligible$n_usable,
                                       grp_eligible$beta, -grp_eligible$ec), ]
    
    top1_score <- grp_eligible$dsi_v2[1]
    
    ready <- TRUE
    reasons <- character(0)
    
    if (n_eligible < opts$min_eligible_windows) {
      ready <- FALSE
      reasons <- c(reasons, "few_eligible")
    }
    
    if (top1_score < opts$min_dsi_v2_top1) {
      ready <- FALSE
      reasons <- c(reasons, "low_DSI_v2")
    }
    
    if (n_eligible >= 3) {
      top3_score <- grp_eligible$dsi_v2[3]
      spread <- top1_score - top3_score
      
      if (spread > opts$max_dsi_v2_spread) {
        ready <- FALSE
        reasons <- c(reasons, "unstable_spread")
      }
    }
    
    best <- grp_eligible[1, ]
    best$ready <- ready
    best$selection_reason <- if (ready) "ready" else paste(reasons, collapse = "; ")
    
    best
  })
  
  do.call(rbind, results)
}

#' Generate plain-language interpretation for a window
#' 
#' Creates human-readable summary of DSI results.
#' 
#' @param metrics Named list of metrics for one window
#' @param group_name Group identifier
#' @return Character string with interpretation
#' @export
interpret_window <- function(metrics, group_name = NULL) {
  if (!metrics$valid) {
    return(sprintf("Window %d-%d is invalid: %s",
                  metrics$start_year, metrics$end_year,
                  metrics$reasons_invalid))
  }
  
  dsi_v2 <- ifelse(is.na(metrics$dsi_v2), metrics$dsi, metrics$dsi_v2)
  dsi_band <- ifelse(dsi_v2 >= 70, "Good",
                    ifelse(dsi_v2 >= 50, "Moderate", "Poor"))
  
  prefix <- if (!is.null(group_name)) {
    sprintf("%s, %d-%d", group_name, metrics$start_year, metrics$end_year)
  } else {
    sprintf("%d-%d", metrics$start_year, metrics$end_year)
  }
  
  parts <- character(0)
  
  parts <- c(parts, sprintf("%s: DSI_v2 %.0f (%s)", prefix, dsi_v2, dsi_band))
  
  parts <- c(parts, sprintf("%d usable years", metrics$n_usable))
  
  if (metrics$beta < 0 && !is.na(metrics$p_value)) {
    parts <- c(parts, sprintf("CPUE falls as effort rises (\u03b2 = %.3f, p = %.3f)",
                             metrics$beta, metrics$p_value))
  } else if (metrics$beta >= 0) {
    parts <- c(parts, "WARNING: positive slope (\u03b2 >= 0)")
  }
  
  parts <- c(parts, sprintf("Effort contrast: %.1fx mean; CPUE contrast: %.1fx",
                           metrics$ec, metrics$ic))
  
  if (!is.na(metrics$p_out) && metrics$p_out < 1) {
    loss_pct <- (1 - metrics$p_out) * 100
    parts <- c(parts, sprintf("Outlier penalty: %.0f%% loss (P_out = %.2f)",
                             loss_pct, metrics$p_out))
  }
  
  if (!is.na(metrics$frac_usable) && metrics$frac_usable < 1) {
    parts <- c(parts, sprintf("Coverage: %.0f%% of years usable",
                             metrics$frac_usable * 100))
  }
  
  paste(parts, collapse = ". ")
}

#' Get DSI band label and color
#' 
#' @param score DSI or DSI_v2 score
#' @param cutpoints Named vector of cutpoints
#' @return List with label and color
#' @export
get_dsi_band <- function(score, cutpoints = c(poor = 0, moderate = 50, good = 70)) {
  if (is.na(score) || !is.finite(score)) {
    return(list(label = "Invalid", color = "#cccccc"))
  }
  
  if (score < cutpoints["moderate"]) {
    list(label = "Poor", color = "#D55E00")
  } else if (score < cutpoints["good"]) {
    list(label = "Moderate", color = "#E69F00")
  } else {
    list(label = "Good", color = "#009E73")
  }
}

## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ DSI Core: v2 robustness metrics and scoring ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Compute v2 robustness metrics (CORRECTED VERSION)
#' 
#' Adds influence, stability, identifiability checks on sorted data.
#' 
#' @param df Data frame for one group (will be sorted by year)
#' @param start_year Window start year
#' @param end_year Window end year
#' @param refs Reference parameters
#' @param cols Column names
#' @return Named list of v2 metrics
#' @export
compute_window_v2_metrics_corrected <- function(df, start_year, end_year,
                                               refs = default_dsi_refs(),
                                               cols = list(year = "year", catch = "catch",
                                                          effort = "effort", cpue = "cpue")) {
  
  in_window <- .year_in_window(df[[cols$year]], start_year, end_year)
  d <- df[in_window, ]
  
  d <- d[order(d[[cols$year]]), ]
  
  result <- list()
  
  cpue_vec <- d[[cols$cpue]]
  effort_vec <- d[[cols$effort]]
  catch_vec <- d[[cols$catch]]
  year_vec <- d[[cols$year]]
  
  log_result <- safe_log_cpue(cpue_vec)
  log_cpue <- log_result$log_cpue
  
  usable_mask <- is.finite(log_cpue) & is.finite(effort_vec)
  n_usable <- sum(usable_mask)
  
  if (n_usable < 3) {
    return(result)
  }
  
  fit_data <- data.frame(
    log_cpue = log_cpue[usable_mask],
    effort = effort_vec[usable_mask],
    year = year_vec[usable_mask]
  )
  
  fit <- tryCatch({
    stats::lm(log_cpue ~ effort, data = fit_data)
  }, error = function(e) NULL)
  
  if (is.null(fit)) {
    return(result)
  }
  
  cooks_d <- stats::cooks.distance(fit)
  leverage <- stats::hatvalues(fit)
  
  cook_threshold <- refs$cook_threshold_mult / n_usable
  lev_threshold <- refs$leverage_threshold_mult / n_usable
  
  f_cook <- mean(cooks_d > cook_threshold, na.rm = TRUE)
  f_lev <- mean(leverage > lev_threshold, na.rm = TRUE)
  
  result$f_cook <- f_cook
  result$f_lev <- f_lev
  
  p_inf <- (1 - clamp01(f_cook / refs$cook_lev_cap)) * 
           (1 - clamp01(f_lev / refs$cook_lev_cap))
  result$p_inf <- p_inf
  
  residuals_vals <- stats::residuals(fit)
  acf_result <- tryCatch({
    stats::acf(residuals_vals, lag.max = 1, plot = FALSE)$acf[2]
  }, error = function(e) NA_real_)
  
  s_acf <- 1 - clamp01(abs(acf_result) / refs$acf_threshold)
  result$s_acf <- s_acf
  
  if (n_usable >= 6) {
    y_vals <- fit_data$log_cpue
    n <- length(y_vals)
    mean_y <- mean(y_vals)
    sd_y <- stats::sd(y_vals)
    
    z_max <- 0
    for (k in 3:(n - 3)) {
      mean_before <- mean(y_vals[1:k])
      mean_after <- mean(y_vals[(k + 1):n])
      z <- abs(mean_before - mean_after) / sd_y
      if (z > z_max) z_max <- z
    }
    
    s_shift <- 1 - clamp01(z_max / refs$z_shift_threshold)
    result$z_shift <- z_max
    result$s_shift <- s_shift
  }
  
  fitted_vals <- stats::fitted(fit)
  effort_fit <- fit_data$effort
  
  cor_fit_e <- stats::cor(fitted_vals, effort_fit)
  s_fit_e <- clamp01(abs(cor_fit_e) / refs$fit_e_threshold)
  
  result$cor_fit_e <- cor_fit_e
  result$s_fit_e <- s_fit_e
  
  beta_original <- stats::coef(fit)[2]
  
  beta_loo <- numeric(n_usable)
  for (i in seq_len(n_usable)) {
    fit_loo <- stats::lm(log_cpue ~ effort, data = fit_data[-i, ])
    beta_loo[i] <- stats::coef(fit_loo)[2]
  }
  
  f_beta_pos <- mean(beta_loo >= 0, na.rm = TRUE)
  result$f_beta_pos <- f_beta_pos
  
  s_stab <- 1 - clamp01(f_beta_pos / refs$stab_threshold)
  result$s_stab <- s_stab
  
  result
}

#' Compute v2 robustness metrics (LEGACY VERSION)
#' 
#' Reproduces original with potential unsorted data issues.
#' 
#' @param df Data frame for one group
#' @param start_year Window start year
#' @param end_year Window end year
#' @param refs Reference parameters
#' @param cols Column names
#' @return Named list of v2 metrics
#' @keywords internal
compute_window_v2_metrics_legacy <- function(df, start_year, end_year,
                                            refs = default_dsi_refs(),
                                            cols = list(year = "year", catch = "catch",
                                                       effort = "effort", cpue = "cpue")) {
  
  in_window <- .year_in_window(df[[cols$year]], start_year, end_year)
  d <- df[in_window, ]
  
  d <- d[order(d[[cols$year]]), ]
  
  result <- list()
  
  cpue_vec <- d[[cols$cpue]]
  effort_vec <- d[[cols$effort]]
  catch_vec <- d[[cols$catch]]
  year_vec <- d[[cols$year]]
  
  log_result <- safe_log_cpue(cpue_vec)
  log_cpue <- log_result$log_cpue
  
  usable_mask <- is.finite(log_cpue) & is.finite(effort_vec)
  n_usable <- sum(usable_mask)
  
  if (n_usable < 3) {
    return(result)
  }
  
  fit_data <- data.frame(
    log_cpue = log_cpue[usable_mask],
    effort = effort_vec[usable_mask],
    year = year_vec[usable_mask]
  )
  
  fit <- tryCatch({
    stats::lm(log_cpue ~ effort, data = fit_data)
  }, error = function(e) NULL)
  
  if (is.null(fit)) {
    return(result)
  }
  
  cooks_d <- stats::cooks.distance(fit)
  leverage <- stats::hatvalues(fit)
  
  cook_threshold <- refs$cook_threshold_mult / n_usable
  lev_threshold <- refs$leverage_threshold_mult / n_usable
  
  f_cook <- mean(cooks_d > cook_threshold, na.rm = TRUE)
  f_lev <- mean(leverage > lev_threshold, na.rm = TRUE)
  
  result$f_cook <- f_cook
  result$f_lev <- f_lev
  
  p_inf <- (1 - clamp01(f_cook / refs$cook_lev_cap)) * 
           (1 - clamp01(f_lev / refs$cook_lev_cap))
  result$p_inf <- p_inf
  
  residuals_vals <- stats::residuals(fit)
  acf_result <- tryCatch({
    stats::acf(residuals_vals, lag.max = 1, plot = FALSE)$acf[2]
  }, error = function(e) NA_real_)
  
  s_acf <- 1 - clamp01(abs(acf_result) / refs$acf_threshold)
  result$s_acf <- s_acf
  
  if (n_usable >= 6) {
    y_vals <- fit_data$log_cpue
    n <- length(y_vals)
    mean_y <- mean(y_vals)
    sd_y <- stats::sd(y_vals)
    
    z_max <- 0
    for (k in 3:(n - 3)) {
      mean_before <- mean(y_vals[1:k])
      mean_after <- mean(y_vals[(k + 1):n])
      z <- abs(mean_before - mean_after) / sd_y
      if (z > z_max) z_max <- z
    }
    
    s_shift <- 1 - clamp01(z_max / refs$z_shift_threshold)
    result$z_shift <- z_max
    result$s_shift <- s_shift
  }
  
  fitted_vals <- stats::fitted(fit)
  effort_fit <- fit_data$effort
  
  cor_fit_e <- stats::cor(fitted_vals, effort_fit)
  s_fit_e <- clamp01(abs(cor_fit_e) / refs$fit_e_threshold)
  
  result$cor_fit_e <- cor_fit_e
  result$s_fit_e <- s_fit_e
  
  beta_original <- stats::coef(fit)[2]
  
  beta_loo <- numeric(n_usable)
  for (i in seq_len(n_usable)) {
    fit_loo <- stats::lm(log_cpue ~ effort, data = fit_data[-i, ])
    beta_loo[i] <- stats::coef(fit_loo)[2]
  }
  
  f_beta_pos <- mean(beta_loo >= 0, na.rm = TRUE)
  result$f_beta_pos <- f_beta_pos
  
  s_stab <- 1 - clamp01(f_beta_pos / refs$stab_threshold)
  result$s_stab <- s_stab
  
  result
}

#' Default DSI weight configuration
#' 
#' @param legacy If TRUE, use 0.95 sum (original bug). If FALSE, use 1.0.
#' @return List of component weights
#' @export
default_dsi_weights <- function(legacy = FALSE) {
  if (legacy) {
    list(
      w_slope = 0.35,
      w_e = 0.20,
      w_i = 0.20,
      w_n = 0.10,
      w_ce = 0.10
    )
  } else {
    list(
      w_slope = 0.35,
      w_e = 0.20,
      w_i = 0.20,
      w_n = 0.125,
      w_ce = 0.125
    )
  }
}

#' Compute DSI base score
#' 
#' @param metrics Named list of metrics from compute_window_metrics
#' @param weights DSI weights
#' @return DSI_base score (0-100)
#' @export
compute_dsi_base <- function(metrics, weights = default_dsi_weights()) {
  if (!metrics$valid) return(NA_real_)
  
  100 * (weights$w_slope * metrics$s_slope +
         weights$w_e * metrics$s_e +
         weights$w_i * metrics$s_i +
         weights$w_n * metrics$s_n +
         weights$w_ce * metrics$s_ce)
}

#' Compute DSI score (with outlier penalty)
#' 
#' @param metrics Named list of metrics
#' @param weights DSI weights
#' @return DSI score (0-100)
#' @export
compute_dsi <- function(metrics, weights = default_dsi_weights()) {
  dsi_base <- compute_dsi_base(metrics, weights)
  if (is.na(dsi_base)) return(NA_real_)
  
  p_out <- if (is.na(metrics$p_out)) 1.0 else metrics$p_out
  
  dsi_base * p_out
}

#' Compute DSI_v2 robust score
#' 
#' @param metrics Base metrics
#' @param v2_metrics v2 robustness metrics
#' @param weights DSI weights
#' @return DSI_v2 score (0-100)
#' @export
compute_dsi_v2_robust <- function(metrics, v2_metrics, weights = default_dsi_weights()) {
  dsi_base <- compute_dsi_base(metrics, weights)
  
  if (is.na(dsi_base) || dsi_base <= 0) return(NA_real_)
  
  p_miss <- ifelse(is.na(metrics$p_miss), 0.7, metrics$p_miss)
  p_out <- ifelse(is.na(metrics$p_out), 1.0, metrics$p_out)
  p_inf <- ifelse(is.na(v2_metrics$p_inf), 1.0, v2_metrics$p_inf)
  s_stab_val <- ifelse(is.na(v2_metrics$s_stab), 0.7, v2_metrics$s_stab)
  s_fit_e_val <- ifelse(is.na(v2_metrics$s_fit_e), 0.7, v2_metrics$s_fit_e)
  
  dsi_v2 <- dsi_base * p_miss * p_out * p_inf * 
            (0.85 + 0.15 * s_stab_val) * 
            (0.85 + 0.15 * s_fit_e_val)
  
  dsi_v2
}

#' Score a single window (convenience wrapper)
#' 
#' @param df Group data frame
#' @param start_year Window start
#' @param end_year Window end
#' @param method "corrected" or "legacy"
#' @param refs Reference parameters
#' @param weights Weight configuration
#' @param include_v2 Whether to compute v2 metrics
#' @return List with all metrics and scores
#' @export
score_window <- function(df, start_year, end_year, 
                        method = "corrected",
                        refs = default_dsi_refs(),
                        weights = default_dsi_weights(legacy = method == "legacy"),
                        include_v2 = TRUE) {
  
  if (method == "corrected") {
    metrics <- compute_window_metrics_corrected(df, start_year, end_year, 
                                               refs = refs)
  } else {
    metrics <- compute_window_metrics_legacy(df, start_year, end_year,
                                            refs = refs)
  }
  
  metrics$dsi_base <- compute_dsi_base(metrics, weights)
  metrics$dsi <- compute_dsi(metrics, weights)
  
  if (include_v2 && metrics$valid) {
    if (method == "corrected") {
      v2_metrics <- compute_window_v2_metrics_corrected(df, start_year, end_year, refs = refs)
    } else {
      v2_metrics <- compute_window_v2_metrics_legacy(df, start_year, end_year, refs = refs)
    }
    
    metrics <- c(metrics, v2_metrics)
    metrics$dsi_v2 <- compute_dsi_v2_robust(metrics, v2_metrics, weights)
  }
  
  metrics
}

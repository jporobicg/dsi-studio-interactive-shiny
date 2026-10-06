## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ DSI Core: window metrics computation ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Default reference values for DSI computation
#' 
#' @return List of reference parameters
#' @export
default_dsi_refs <- function() {
  list(
    beta_ref_base = 0.02,
    p_ref = 0.20,
    ec_ref = 1.0,
    ic_ref = 2.0,
    n_min_score = 8,
    n_full_score = 20,
    outlier_threshold = 2.0,
    outlier_cap = 0.20,
    cov_min = 0.5,
    ess_min = 6,
    ess_full = 20,
    cook_threshold_mult = 4,
    leverage_threshold_mult = 4,
    cook_lev_cap = 0.20,
    acf_threshold = 0.6,
    z_shift_threshold = 2.5,
    fit_e_threshold = 0.7,
    stab_threshold = 0.3,
    p_miss_cov_lo = 0.7,
    p_miss_cov_hi = 1.0,
    p_miss_ess_lo = 0.85,
    p_miss_ess_hi = 1.0,
    psi_ref = 4.0,
    ks_p_ref = 0.05,
    psi_n_bins = 10,
    psi_eps = 0.005
  )
}

#' Compute per-window metrics
#'
#' One implementation for both method profiles. The two documented
#' differences between the original scripts and the corrected method are
#' switches:
#' - `sort_by_year`: sort rows by year before fitting, so the lag-1 ACF of
#'   residuals (and hence ESS) is computed in time order. The original code
#'   used whatever row order `merge(..., sort = FALSE)` produced.
#' - `calendar_coverage`: coverage = usable calendar years / window length.
#'   The original used usable rows / rows present, so missing years did not
#'   reduce coverage.
#'
#' Scores use the reference points in `refs` (see [default_dsi_refs()]):
#' s_n = (n_usable - n_min_score) / (n_full_score - n_min_score) and
#' s_ess = (ess - ess_min) / (ess_full - ess_min). With the defaults these
#' are the original (n - 8) / 12 and (ess - 6) / 14.
#'
#' @param df Data frame for one group
#' @param start_year,end_year Window bounds (inclusive)
#' @param min_n Minimum number of valid rows (the original passes the window
#'   length minimum here too)
#' @param min_usable Minimum usable observations
#' @param refs Reference parameters (from default_dsi_refs)
#' @param cols Column name list
#' @param sort_by_year,calendar_coverage Corrected-method switches (see above)
#' @return Named list of metrics and validity info
#' @export
compute_window_metrics <- function(df, start_year, end_year,
                                   min_n = 8, min_usable = 6,
                                   refs = default_dsi_refs(),
                                   cols = list(year = "year", catch = "catch",
                                               effort = "effort", cpue = "cpue"),
                                   sort_by_year = TRUE,
                                   calendar_coverage = TRUE) {
  refs <- utils::modifyList(default_dsi_refs(), refs %||% list())
  in_window <- .year_in_window(df[[cols$year]], start_year, end_year)
  d <- df[in_window, ]

  calendar_length <- end_year - start_year + 1L
  n_rows <- nrow(d)

  result <- list(
    start_year = start_year,
    end_year = end_year,
    n_years = calendar_length,
    n_rows = n_rows,
    valid = TRUE,
    reasons_invalid = NA_character_
  )

  if (n_rows == 0) {
    result$valid <- FALSE
    result$reasons_invalid <- "no_rows_in_window"
    return(result)
  }

  if (sort_by_year) d <- d[order(d[[cols$year]]), ]

  cpue_vec <- d[[cols$cpue]]
  effort_vec <- d[[cols$effort]]
  catch_vec <- d[[cols$catch]]
  year_vec <- d[[cols$year]]

  log_result <- safe_log_cpue(cpue_vec)
  log_cpue <- log_result$log_cpue

  usable_mask <- is.finite(log_cpue) & is.finite(effort_vec)
  n_usable <- sum(usable_mask)
  n_valid <- sum(!is.na(log_cpue) & !is.na(effort_vec))

  result$n_usable <- n_usable
  result$n_valid <- n_valid

  if (calendar_coverage) {
    n_usable_years <- length(unique(year_vec[usable_mask]))
    frac_usable <- n_usable_years / calendar_length
  } else {
    n_usable_years <- NA
    frac_usable <- n_usable / n_rows
  }
  result$n_usable_years <- n_usable_years
  result$frac_usable <- frac_usable

  if (n_valid < 3) {
    result$valid <- FALSE
    result$reasons_invalid <- .append_reason(result$reasons_invalid, "too_few_valid_rows")
    return(result)
  }
  if (n_usable < min_usable) {
    result$valid <- FALSE
    result$reasons_invalid <- .append_reason(result$reasons_invalid, "n_usable_lt_min_usable")
    return(result)
  }
  if (n_valid < min_n) {
    result$valid <- FALSE
    result$reasons_invalid <- .append_reason(result$reasons_invalid, "n_valid_lt_min_n")
    return(result)
  }
  if (stats::var(effort_vec[usable_mask], na.rm = TRUE) == 0) {
    result$valid <- FALSE
    result$reasons_invalid <- .append_reason(result$reasons_invalid, "effort_zero_variance")
    return(result)
  }
  cpue_min <- min(cpue_vec[usable_mask], na.rm = TRUE)
  if (cpue_min <= 0) {
    result$valid <- FALSE
    result$reasons_invalid <- .append_reason(result$reasons_invalid, "cpue_min_leq_0")
    return(result)
  }

  rho_ce <- tryCatch(.safe_spearman(catch_vec, effort_vec), error = function(e) NA_real_)
  if (is.na(rho_ce)) {
    result$valid <- FALSE
    result$reasons_invalid <- .append_reason(result$reasons_invalid, "rho_ce_na")
    return(result)
  }
  result$rho_ce <- rho_ce

  fit_data <- data.frame(
    log_cpue = log_cpue[usable_mask],
    effort = effort_vec[usable_mask],
    year = year_vec[usable_mask]
  )
  fit <- tryCatch(stats::lm(log_cpue ~ effort, data = fit_data), error = function(e) e)
  if (inherits(fit, "error")) {
    result$valid <- FALSE
    result$reasons_invalid <- .append_reason(result$reasons_invalid, paste0("error:", conditionMessage(fit)))
    return(result)
  }

  beta <- stats::coef(fit)[2]
  summ <- summary(fit)
  p_value <- summ$coefficients[2, 4]
  result$beta <- beta
  result$p_value <- p_value
  result$r_squared <- summ$r.squared

  effort_mean <- mean(effort_vec[usable_mask], na.rm = TRUE)
  effort_range <- diff(range(effort_vec[usable_mask], na.rm = TRUE))
  ec <- effort_range / effort_mean
  cpue_max <- max(cpue_vec[usable_mask], na.rm = TRUE)
  ic <- cpue_max / cpue_min
  result$effort_mean <- effort_mean
  result$ec <- ec
  result$ic <- ic

  rstandard_vals <- stats::rstandard(fit)
  f_out <- mean(abs(rstandard_vals) > refs$outlier_threshold, na.rm = TRUE)
  result$f_out <- f_out

  residuals_vals <- stats::residuals(fit)
  acf_result <- tryCatch(stats::acf(residuals_vals, lag.max = 1, plot = FALSE)$acf[2],
                         error = function(e) NA_real_)
  result$acf1 <- acf_result
  ess <- n_usable * (1 - abs(acf_result))
  result$ess <- ess

  beta_ref <- refs$beta_ref_base / effort_mean
  if (beta >= 0) {
    s_slope <- 0
  } else {
    s_beta <- clamp01(-beta / beta_ref)
    s_p <- clamp01(1 - p_value / refs$p_ref)
    s_slope <- s_beta * s_p
  }

  result$s_slope <- s_slope
  result$s_e <- clamp01(ec / refs$ec_ref)
  result$s_i <- clamp01(log(ic) / log(refs$ic_ref))
  result$s_n <- clamp01((n_usable - refs$n_min_score) / (refs$n_full_score - refs$n_min_score))
  result$s_ce <- clamp01((rho_ce + 1) / 2)

  s_cov <- clamp01((frac_usable - refs$cov_min) / (1 - refs$cov_min))
  result$s_cov <- s_cov
  s_ess <- clamp01((ess - refs$ess_min) / (refs$ess_full - refs$ess_min))
  result$s_ess <- s_ess

  result$p_out <- 1 - clamp01(f_out / refs$outlier_cap)

  p_miss_cov <- refs$p_miss_cov_lo + (refs$p_miss_cov_hi - refs$p_miss_cov_lo) * s_cov
  p_miss_ess <- refs$p_miss_ess_lo + (refs$p_miss_ess_hi - refs$p_miss_ess_lo) * s_ess
  result$p_miss <- p_miss_cov * p_miss_ess

  result
}

#' Compute per-window metrics (CORRECTED VERSION)
#'
#' Year-sorted rows and calendar-year coverage. See [compute_window_metrics()].
#' @inheritParams compute_window_metrics
#' @export
compute_window_metrics_corrected <- function(df, start_year, end_year,
                                            min_n = 8, min_usable = 6,
                                            refs = default_dsi_refs(),
                                            cols = list(year = "year", catch = "catch",
                                                       effort = "effort", cpue = "cpue")) {
  compute_window_metrics(df, start_year, end_year, min_n, min_usable, refs, cols,
                         sort_by_year = TRUE, calendar_coverage = TRUE)
}

#' Compute per-window metrics (LEGACY VERSION)
#'
#' Reproduces the original scripts: ACF on rows in merge order and coverage
#' by rows present rather than calendar years. See [compute_window_metrics()].
#' @inheritParams compute_window_metrics
#' @keywords internal
compute_window_metrics_legacy <- function(df, start_year, end_year,
                                         min_n = 8, min_usable = 6,
                                         refs = default_dsi_refs(),
                                         cols = list(year = "year", catch = "catch",
                                                    effort = "effort", cpue = "cpue")) {
  compute_window_metrics(df, start_year, end_year, min_n, min_usable, refs, cols,
                         sort_by_year = FALSE, calendar_coverage = FALSE)
}

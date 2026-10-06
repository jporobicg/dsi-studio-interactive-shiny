## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ DSI Core: utility functions ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Clamp values to [0, 1]
#' @param x Numeric vector
#' @return Clamped values
clamp01 <- function(x) {
  pmin(1, pmax(0, x))
}

#' Safe log transformation of CPUE
#' 
#' @param cpue Numeric vector of CPUE values
#' @return List with log_cpue, n_invalid, invalid_idx
safe_log_cpue <- function(cpue) {
  is_bad <- is.na(cpue) | !is.finite(cpue) | cpue <= 0
  out <- rep(NA_real_, length(cpue))
  out[!is_bad] <- log(cpue[!is_bad])
  list(
    log_cpue = out,
    n_invalid = sum(is_bad),
    invalid_idx = which(is_bad)
  )
}

#' Safe Spearman correlation
#' 
#' @param x,y Numeric vectors
#' @return Spearman correlation or NA
.safe_spearman <- function(x, y) {
  ok <- is.finite(x) & is.finite(y)
  x <- x[ok]
  y <- y[ok]
  if (length(x) < 3) return(NA_real_)
  if (stats::sd(x) == 0 || stats::sd(y) == 0) return(NA_real_)
  suppressWarnings(stats::cor(x, y, method = "spearman"))
}

#' Append reason code
#' 
#' @param reasons Current reason string
#' @param reason New reason to append
#' @return Combined reason string
.append_reason <- function(reasons, reason) {
  if (is.na(reason) || !nzchar(reason)) return(reasons)
  if (is.na(reasons) || !nzchar(reasons)) return(reason)
  paste0(reasons, "; ", reason)
}

#' Check if year is in window
#' 
#' @param year Year vector
#' @param start_year Window start year
#' @param end_year Window end year
#' @return Logical vector
.year_in_window <- function(year, start_year, end_year) {
  !is.na(year) & year >= start_year & year <= end_year
}

#' Safe KS test p-value
#' 
#' @param x_ref Reference sample
#' @param x_new New sample
#' @return KS test p-value or NA
.safe_ks_pvalue <- function(x_ref, x_new) {
  x_ref <- x_ref[is.finite(x_ref)]
  x_new <- x_new[is.finite(x_new)]
  if (length(x_ref) < 5 || length(x_new) < 5) return(NA_real_)
  if (stats::sd(x_ref) == 0 && stats::sd(x_new) == 0) return(1)
  if (stats::sd(x_ref) == 0 || stats::sd(x_new) == 0) return(0)
  suppressWarnings(as.numeric(stats::ks.test(x_ref, x_new)$p.value))
}

#' Population Stability Index
#' 
#' @param x_ref Reference sample
#' @param x_new New sample
#' @param n_bins Number of bins
#' @param eps Smoothing constant
#' @return PSI value
.psi_numeric <- function(x_ref, x_new, n_bins = 10, eps = 0.005) {
  x_ref <- x_ref[is.finite(x_ref)]
  x_new <- x_new[is.finite(x_new)]
  if (length(x_ref) < 5 || length(x_new) < 5) return(NA_real_)
  
  n_bins_use <- min(n_bins, max(3, floor(length(x_ref) / 2)))
  qs <- stats::quantile(x_ref, probs = seq(0, 1, length.out = n_bins_use + 1), 
                       na.rm = TRUE, type = 7)
  qs <- unique(as.numeric(qs))
  if (length(qs) < 3) return(0)
  qs[1] <- -Inf
  qs[length(qs)] <- Inf
  
  b_ref <- cut(x_ref, breaks = qs, include.lowest = TRUE, right = TRUE)
  b_new <- cut(x_new, breaks = qs, include.lowest = TRUE, right = TRUE)
  
  p_ref <- as.numeric(table(b_ref)) / length(b_ref)
  p_new <- as.numeric(table(b_new)) / length(b_new)
  
  p_ref <- pmax(p_ref, eps)
  p_new <- pmax(p_new, eps)
  sum((p_new - p_ref) * log(p_new / p_ref))
}

#' Score drift between two periods
#' 
#' @param psi PSI value
#' @param ks_p KS test p-value
#' @param psi_ref PSI reference threshold
#' @param p_ref p-value reference threshold
#' @return Drift score
.score_drift <- function(psi, ks_p, psi_ref = 4.0, p_ref = 0.05) {
  if (is.na(psi) || is.na(ks_p)) return(NA_real_)
  s_psi <- 1 - clamp01(psi / psi_ref)
  s_p <- clamp01(ks_p / p_ref)
  s_psi * s_p
}

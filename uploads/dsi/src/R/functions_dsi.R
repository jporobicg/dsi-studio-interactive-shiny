clamp01 <- function(x) {
  pmin(1, pmax(0, x))
}

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

generate_windows <- function(years, min_n = 8, max_n = 20) {
  yrs <- sort(unique(years[!is.na(years) & is.finite(years)]))
  yrs <- as.integer(yrs)
  if (length(yrs) == 0) {
    return(data.frame(start_year = integer(0), end_year = integer(0), n_years = integer(0)))
  }

  last_year <- max(yrs, na.rm = TRUE)
  out <- vector("list", 0)
  idx <- 0L

  for (start_year in yrs) {
    len <- last_year - start_year + 1L
    if (len < min_n) next
    if (len > max_n) next

    idx <- idx + 1L
    out[[idx]] <- data.frame(
      start_year = start_year,
      end_year = last_year,
      n_years = len
    )
  }

  if (length(out) == 0) {
    return(data.frame(start_year = integer(0), end_year = integer(0), n_years = integer(0)))
  }
  do.call(rbind, out)
}

.safe_spearman <- function(x, y) {
  ok <- is.finite(x) & is.finite(y)
  x <- x[ok]
  y <- y[ok]
  if (length(x) < 3) return(NA_real_)
  if (stats::sd(x) == 0 || stats::sd(y) == 0) return(NA_real_)
  suppressWarnings(stats::cor(x, y, method = "spearman"))
}

.year_in_window <- function(year, start_year, end_year) {
  !is.na(year) & year >= start_year & year <= end_year
}

.append_reason <- function(reasons, reason) {
  if (is.na(reason) || !nzchar(reason)) return(reasons)
  if (is.na(reasons) || !nzchar(reasons)) return(reason)
  paste0(reasons, "; ", reason)
}

.safe_ks_pvalue <- function(x_ref, x_new) {
  x_ref <- x_ref[is.finite(x_ref)]
  x_new <- x_new[is.finite(x_new)]
  if (length(x_ref) < 5 || length(x_new) < 5) return(NA_real_)
  if (stats::sd(x_ref) == 0 && stats::sd(x_new) == 0) return(1)
  if (stats::sd(x_ref) == 0 || stats::sd(x_new) == 0) return(0)
  suppressWarnings(as.numeric(stats::ks.test(x_ref, x_new)$p.value))
}

.psi_numeric <- function(x_ref, x_new, n_bins = 10, eps = 0.005) {
  x_ref <- x_ref[is.finite(x_ref)]
  x_new <- x_new[is.finite(x_new)]
  if (length(x_ref) < 5 || length(x_new) < 5) return(NA_real_)

  n_bins_use <- min(n_bins, max(3, floor(length(x_ref) / 2)))
  qs <- stats::quantile(x_ref, probs = seq(0, 1, length.out = n_bins_use + 1), na.rm = TRUE, type = 7)
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

.score_drift <- function(psi, ks_p, psi_ref = 4.0, p_ref = 0.05) {
  if (is.na(psi) || is.na(ks_p)) return(NA_real_)
  s_psi <- 1 - clamp01(psi / psi_ref)
  s_p <- clamp01(ks_p / p_ref)
  clamp01(s_psi * s_p)
}

compute_window_metrics <- function(
    df,
    start_year,
    end_year,
    min_n = 8,
    min_usable = 6,
    refs = list(beta_ref_base = 0.02, p_ref = 0.20, p_miss_cov_lo = 0.7, p_miss_cov_hi = 0.3, p_miss_ess_lo = 0.85, p_miss_ess_hi = 0.15),
    cols = list(year = "year", catch = "catch", effort = "effort", cpue = "cpue")
) {
  out <- list(
    start_year = start_year,
    end_year = end_year,
    n_rows_window = NA_integer_,
    n_rows_valid = NA_integer_,
    n_total = NA_integer_,
    n_usable = NA_integer_,
    frac_usable = NA_real_,
    n_cpue = NA_integer_,
    n_effort = NA_integer_,
    n_catch = NA_integer_,
    n_invalid_cpue = NA_integer_,
    n_invalid_effort = NA_integer_,
    beta = NA_real_,
    p = NA_real_,
    r2 = NA_real_,
    ec = NA_real_,
    ic = NA_real_,
    s_e = NA_real_,
    s_i = NA_real_,
    s_n = NA_real_,
    rho_ce = NA_real_,
    s_ce = NA_real_,
    f_out = NA_real_,
    p_out = NA_real_,
    s_slope = NA_real_,
    S_cov = NA_real_,
    acf1 = NA_real_,
    ESS = NA_real_,
    S_ESS = NA_real_,
    P_miss = NA_real_,
    valid = FALSE,
    reasons_invalid = NA_character_
  )

  tryCatch({
    yr <- df[[cols$year]]
    in_w <- .year_in_window(yr, start_year, end_year)
    d0 <- df[in_w, , drop = FALSE]
    out$n_rows_window <- nrow(d0)

    if (nrow(d0) == 0) {
      out$reasons_invalid <- .append_reason(out$reasons_invalid, "no_rows_in_window")
      return(out)
    }

    cpue <- d0[[cols$cpue]]
    effort <- d0[[cols$effort]]
    catch <- d0[[cols$catch]]

    log_res <- safe_log_cpue(cpue)
    log_cpue <- log_res$log_cpue
    out$n_invalid_cpue <- log_res$n_invalid

    bad_eff <- is.na(effort) | !is.finite(effort)
    out$n_invalid_effort <- sum(bad_eff)

    ok <- is.finite(log_cpue) & !bad_eff
    d <- d0[ok, , drop = FALSE]
    out$n_rows_valid <- nrow(d)
    out$n_total <- nrow(d0)
    out$n_usable <- nrow(d)

    out$n_cpue <- sum(!is.na(cpue) & is.finite(cpue) & cpue > 0)
    out$n_effort <- sum(!is.na(effort) & is.finite(effort))
    out$n_catch <- sum(!is.na(catch) & is.finite(catch))

    if (out$n_usable < 3) {
      out$reasons_invalid <- .append_reason(out$reasons_invalid, "too_few_valid_rows")
      return(out)
    }

    if (out$n_usable < min_usable) {
      out$reasons_invalid <- .append_reason(out$reasons_invalid, "n_usable_lt_min_usable")
      return(out)
    }

    if (out$n_usable < min_n) {
      out$reasons_invalid <- .append_reason(out$reasons_invalid, "n_valid_lt_min_n")
      return(out)
    }

    out$frac_usable <- out$n_usable / out$n_total
    out$S_cov <- clamp01((out$frac_usable - 0.5) / 0.5)

    E <- d[[cols$effort]]
    if (stats::sd(E) == 0) {
      out$reasons_invalid <- .append_reason(out$reasons_invalid, "effort_zero_variance")
      return(out)
    }

    CPUE <- d[[cols$cpue]]
    if (min(CPUE, na.rm = TRUE) <= 0) {
      out$reasons_invalid <- .append_reason(out$reasons_invalid, "cpue_min_leq_0")
      return(out)
    }

    y <- log(CPUE)

    fit <- stats::lm(y ~ E)
    sm <- summary(fit)

    coefs <- sm$coefficients
    beta <- unname(coefs["E", "Estimate"])
    p <- unname(coefs["E", "Pr(>|t|)"])
    r2 <- unname(sm$r.squared)

    out$beta <- beta
    out$p <- p
    out$r2 <- r2

    ec <- (max(E, na.rm = TRUE) - min(E, na.rm = TRUE)) / mean(E, na.rm = TRUE)
    ic <- max(CPUE, na.rm = TRUE) / min(CPUE, na.rm = TRUE)

    out$ec <- ec
    out$ic <- ic

    out$s_e <- clamp01(ec / 1.0)
    out$s_i <- clamp01(log(ic) / log(2))

    n <- nrow(d)
    out$s_n <- clamp01((n - 8) / 12)

    ## Catch–effort realism uses catch/effort pairs in the window (cpue not required)
    rho_ce <- .safe_spearman(d0[[cols$catch]], d0[[cols$effort]])
    out$rho_ce <- rho_ce
    if (is.na(rho_ce)) {
      out$reasons_invalid <- .append_reason(out$reasons_invalid, "rho_ce_na")
      return(out)
    }
    out$s_ce <- clamp01((rho_ce + 1) / 2)

    rs <- stats::rstandard(fit)
    f_out <- mean(abs(rs) > 2, na.rm = TRUE)
    out$f_out <- f_out
    out$p_out <- 1 - clamp01(f_out / 0.20)

    res <- stats::residuals(fit)
    acf1 <- NA_real_
    if (length(res) >= 6) {
      ac <- stats::acf(res, plot = FALSE, lag.max = 1, na.action = stats::na.pass)
      if (length(ac$acf) >= 2) acf1 <- as.numeric(ac$acf[2])
    }
    out$acf1 <- acf1
    if (is.na(acf1)) {
      ESS <- n
    } else {
      ESS <- min(n, max(0, n * (1 - abs(acf1))))
    }
    out$ESS <- ESS
    out$S_ESS <- clamp01((ESS - 6) / 14)

    cov_lo <- if (!is.null(refs$p_miss_cov_lo)) refs$p_miss_cov_lo else 0.7
    cov_hi <- if (!is.null(refs$p_miss_cov_hi)) refs$p_miss_cov_hi else 0.3
    ess_lo <- if (!is.null(refs$p_miss_ess_lo)) refs$p_miss_ess_lo else 0.85
    ess_hi <- if (!is.null(refs$p_miss_ess_hi)) refs$p_miss_ess_hi else 0.15
    out$P_miss <- (cov_lo + cov_hi * out$S_cov) * (ess_lo + ess_hi * out$S_ESS)

    if (beta >= 0) {
      out$s_slope <- 0
    } else {
      beta_ref <- refs$beta_ref_base / mean(E, na.rm = TRUE)
      p_ref <- refs$p_ref
      out$s_slope <- clamp01((-beta) / beta_ref) * clamp01(1 - p / p_ref)
    }

    out$valid <- TRUE
    out
  }, error = function(e) {
    out$reasons_invalid <- .append_reason(out$reasons_invalid, paste0("error:", conditionMessage(e)))
    out
  })
}

compute_dsi_base <- function(metrics) {
  if (is.null(metrics$valid) || isFALSE(metrics$valid)) return(NA_real_)
  parts <- c(metrics$s_slope, metrics$s_e, metrics$s_i, metrics$s_n, metrics$s_ce)
  if (any(is.na(parts))) return(NA_real_)

  dsi_base <- 100 * (0.35 * metrics$s_slope +
    0.20 * metrics$s_e +
    0.20 * metrics$s_i +
    0.10 * metrics$s_n +
    0.10 * metrics$s_ce)

  clamp01(dsi_base / 100) * 100
}

compute_dsi <- function(metrics) {
  dsi_base <- compute_dsi_base(metrics)
  if (is.na(dsi_base) || is.na(metrics$p_out)) return(NA_real_)
  dsi <- dsi_base * metrics$p_out
  clamp01(dsi / 100) * 100
}

compute_window_v2_metrics <- function(
    df,
    start_year,
    end_year,
    cols = list(year = "year", catch = "catch", effort = "effort", cpue = "cpue")
) {
  out <- list(
    f_cook = NA_real_,
    f_lev = NA_real_,
    p_inf = NA_real_,
    acf1 = NA_real_,
    s_acf = NA_real_,
    z_shift = NA_real_,
    s_shift = NA_real_,
    psi_catch = NA_real_,
    ks_p_catch = NA_real_,
    psi_effort = NA_real_,
    ks_p_effort = NA_real_,
    psi_logcpue = NA_real_,
    ks_p_logcpue = NA_real_,
    s_drift = NA_real_,
    cor_fit_e = NA_real_,
    s_fit_e = NA_real_,
    f_beta_pos = NA_real_,
    s_stab = NA_real_,
    reasons_invalid_v2 = NA_character_
  )

  tryCatch({
    yr <- df[[cols$year]]
    in_w <- .year_in_window(yr, start_year, end_year)
    d0 <- df[in_w, , drop = FALSE]
    if (nrow(d0) == 0) {
      out$reasons_invalid_v2 <- .append_reason(out$reasons_invalid_v2, "no_rows_in_window")
      return(out)
    }

    cpue <- d0[[cols$cpue]]
    effort <- d0[[cols$effort]]

    log_res <- safe_log_cpue(cpue)
    log_cpue <- log_res$log_cpue
    bad_eff <- is.na(effort) | !is.finite(effort)
    ok <- is.finite(log_cpue) & !bad_eff
    d <- d0[ok, , drop = FALSE]

    if (nrow(d) < 5) {
      out$reasons_invalid_v2 <- .append_reason(out$reasons_invalid_v2, "too_few_valid_rows_v2")
      return(out)
    }

    d <- d[order(d[[cols$year]]), , drop = FALSE]
    E <- d[[cols$effort]]
    y <- log(d[[cols$cpue]])

    ## Dataset shift / drift within the window:
    ## compare early vs late observations by year (distributional, not only mean shift).
    yy <- d[[cols$year]]
    split_y <- stats::median(yy, na.rm = TRUE)
    is_early <- is.finite(yy) & yy <= split_y
    is_late <- is.finite(yy) & yy > split_y
    if (sum(is_early) >= 3 && sum(is_late) >= 3) {
      ## Catch drift (if available)
      if (!is.null(cols$catch) && (cols$catch %in% names(d))) {
        C <- d[[cols$catch]]
        C_ref <- C[is_early]
        C_new <- C[is_late]
        out$psi_catch <- .psi_numeric(C_ref, C_new, n_bins = 10)
        out$ks_p_catch <- .safe_ks_pvalue(C_ref, C_new)
      }

      E_ref <- E[is_early]
      E_new <- E[is_late]
      y_ref <- y[is_early]
      y_new <- y[is_late]

      out$psi_effort <- .psi_numeric(E_ref, E_new, n_bins = 10)
      out$ks_p_effort <- .safe_ks_pvalue(E_ref, E_new)
      out$psi_logcpue <- .psi_numeric(y_ref, y_new, n_bins = 10)
      out$ks_p_logcpue <- .safe_ks_pvalue(y_ref, y_new)

      sC <- if (is.finite(out$psi_catch) && is.finite(out$ks_p_catch)) .score_drift(out$psi_catch, out$ks_p_catch) else NA_real_
      sE <- .score_drift(out$psi_effort, out$ks_p_effort)
      sY <- .score_drift(out$psi_logcpue, out$ks_p_logcpue)
      s_all <- c(sC, sE, sY)
      s_all <- s_all[is.finite(s_all)]
      if (length(s_all) > 0) out$s_drift <- min(s_all)
    }

    fit <- stats::lm(y ~ E)
    n <- nrow(d)

    cd <- stats::cooks.distance(fit)
    f_cook <- mean(cd > (4 / n), na.rm = TRUE)

    hv <- stats::hatvalues(fit)
    p_par <- 2
    f_lev <- mean(hv > (2 * p_par / n), na.rm = TRUE)

    p_inf <- (1 - clamp01(f_cook / 0.20)) * (1 - clamp01(f_lev / 0.20))

    out$f_cook <- f_cook
    out$f_lev <- f_lev
    out$p_inf <- p_inf

    res <- stats::residuals(fit)
    acf1 <- NA_real_
    if (length(res) >= 3) {
      ac <- stats::acf(res, plot = FALSE, lag.max = 1, na.action = stats::na.pass)
      if (length(ac$acf) >= 2) acf1 <- as.numeric(ac$acf[2])
    }
    out$acf1 <- acf1
    out$s_acf <- if (is.na(acf1)) NA_real_ else 1 - clamp01(abs(acf1) / 0.6)

    sd_y <- stats::sd(y, na.rm = TRUE)
    if (!is.finite(sd_y) || sd_y == 0) {
      out$reasons_invalid_v2 <- .append_reason(out$reasons_invalid_v2, "sd_log_cpue_zero")
    } else {
      ord <- order(d[[cols$year]])
      y_ord <- y[ord]
      n2 <- length(y_ord)
      splits <- 3:(n2 - 2)
      if (length(splits) > 0) {
        deltas <- vapply(splits, function(k) {
          abs(mean(y_ord[1:k]) - mean(y_ord[(k + 1):n2]))
        }, numeric(1))
        max_abs_delta <- max(deltas, na.rm = TRUE)
        z_shift <- max_abs_delta / sd_y
        out$z_shift <- z_shift
        out$s_shift <- 1 - clamp01(z_shift / 2.5)
      }
    }

    fitted <- stats::fitted(fit)
    cor_fit_e <- NA_real_
    if (stats::sd(fitted, na.rm = TRUE) > 0 && stats::sd(E, na.rm = TRUE) > 0) {
      cor_fit_e <- suppressWarnings(stats::cor(fitted, E, use = "complete.obs"))
    }
    out$cor_fit_e <- cor_fit_e
    out$s_fit_e <- if (is.na(cor_fit_e)) NA_real_ else clamp01(abs(cor_fit_e) / 0.7)

    betas <- vapply(seq_len(n), function(i) {
      di <- d[-i, , drop = FALSE]
      Ei <- di[[cols$effort]]
      yi <- log(di[[cols$cpue]])
      if (length(unique(Ei)) < 2) return(NA_real_)
      fi <- stats::lm(yi ~ Ei)
      unname(stats::coef(fi)[2])
    }, numeric(1))

    f_beta_pos <- mean(betas >= 0, na.rm = TRUE)
    out$f_beta_pos <- f_beta_pos
    out$s_stab <- 1 - clamp01(f_beta_pos / 0.30)

    out
  }, error = function(e) {
    out$reasons_invalid_v2 <- .append_reason(out$reasons_invalid_v2, paste0("error:", conditionMessage(e)))
    out
  })
}

compute_dsi_v2 <- function(dsi, v2) {
  if (is.na(dsi)) return(NA_real_)
  parts <- c(v2$p_inf, v2$s_acf, v2$s_shift, v2$s_fit_e, v2$s_stab)
  if (any(is.na(parts))) return(NA_real_)

  dsi2 <- dsi *
    v2$p_inf *
    (0.85 + 0.15 * v2$s_acf) *
    (0.85 + 0.15 * v2$s_shift) *
    (0.85 + 0.15 * v2$s_fit_e) *
    (0.85 + 0.15 * v2$s_stab)

  clamp01(dsi2 / 100) * 100
}

## DSI_v2 robustness formula: DSI_base * P_miss * P_out * P_inf * (0.85+0.15*S_stab) * (0.85+0.15*S_fitE)
## NA defaults (conservative): P_miss -> 0.7, P_out -> 1, P_inf -> 1, S_stab -> 0.7, S_fitE -> 0.7
compute_dsi_v2_robust <- function(dsi_base, P_miss, p_out, v2) {
  if (is.na(dsi_base) || dsi_base <= 0) return(NA_real_)
  pm <- if (is.na(P_miss)) 0.7 else P_miss
  po <- if (is.na(p_out)) 1 else p_out
  pi <- if (is.null(v2) || is.na(v2$p_inf)) 1 else v2$p_inf
  ss <- if (is.null(v2) || is.na(v2$s_stab)) 0.7 else v2$s_stab
  se <- if (is.null(v2) || is.na(v2$s_fit_e)) 0.7 else v2$s_fit_e
  dsi2 <- dsi_base * pm * po * pi * (0.85 + 0.15 * ss) * (0.85 + 0.15 * se)
  clamp01(dsi2 / 100) * 100
}

default_selection_opts <- function() {
  list(
    min_usable = 6,
    min_frac_usable = 0.6,
    min_EC = 0.4,
    min_IC = 1.2,
    max_f_beta_pos = 0.3,
    min_eligible_windows = 3,
    min_DSI_v2_top1 = 70,
    max_DSI_v2_spread = 20
  )
}

select_best_window_per_species <- function(dsi_all, opts = default_selection_opts()) {
  empty_row <- data.frame(
    species = character(0), group_key = character(0), fleet = character(0),
    start_year = integer(0), end_year = integer(0), DSI_v2 = numeric(0),
    n_usable = integer(0), frac_usable = numeric(0), beta = numeric(0), p = numeric(0), EC = numeric(0), IC = numeric(0),
    READY = logical(0), selection_reason = character(0),
    stringsAsFactors = FALSE
  )
  if (nrow(dsi_all) == 0 || !("species" %in% names(dsi_all))) return(empty_row)
  species_list <- sort(unique(dsi_all$species))
  out <- vector("list", length(species_list))

  for (i in seq_along(species_list)) {
    sp <- species_list[i]
    dd <- dsi_all[dsi_all$species == sp, , drop = FALSE]

    ok_usable <- dd$n_usable >= opts$min_usable
    ok_beta <- is.finite(dd$beta) & dd$beta < 0
    ok_frac <- is.finite(dd$frac_usable) & dd$frac_usable >= opts$min_frac_usable
    ok_ec <- is.finite(dd$ec) & dd$ec >= opts$min_EC
    ok_ic <- is.finite(dd$ic) & dd$ic >= opts$min_IC
    ok_stab <- (is.finite(dd$f_beta_pos) & dd$f_beta_pos <= opts$max_f_beta_pos) |
      (is.finite(dd$s_stab) & dd$s_stab >= 0)
    eligible <- dd[ok_usable & ok_beta & ok_frac & ok_ec & ok_ic & ok_stab & is.finite(dd$dsi_v2), , drop = FALSE]

    if (nrow(eligible) == 0) {
      out[[i]] <- data.frame(
        species = sp, group_key = NA_character_, fleet = NA_character_,
        start_year = NA_integer_, end_year = NA_integer_, DSI_v2 = NA_real_,
        n_usable = NA_integer_, frac_usable = NA_real_, beta = NA_real_, p = NA_real_, EC = NA_real_, IC = NA_real_,
        READY = FALSE, selection_reason = "no_eligible_windows",
        stringsAsFactors = FALSE
      )
      next
    }

    ord <- order(-eligible$dsi_v2, -eligible$n_usable, eligible$beta, -eligible$ec, na.last = TRUE)
    eligible <- eligible[ord, , drop = FALSE]

    count_eligible <- nrow(eligible)
    dsi_v2_1 <- eligible$dsi_v2[1]
    dsi_v2_3 <- if (count_eligible >= 3) eligible$dsi_v2[3] else eligible$dsi_v2[count_eligible]
    spread <- dsi_v2_1 - dsi_v2_3

    ready <- count_eligible >= opts$min_eligible_windows &&
      dsi_v2_1 >= opts$min_DSI_v2_top1 &&
      is.finite(spread) && spread <= opts$max_DSI_v2_spread

    if (!ready) {
      reason <- character(0)
      if (count_eligible < opts$min_eligible_windows) reason <- c(reason, "few_eligible")
      if (dsi_v2_1 < opts$min_DSI_v2_top1) reason <- c(reason, "low_DSI_v2")
      if (!is.finite(spread) || spread > opts$max_DSI_v2_spread) reason <- c(reason, "unstable_spread")
      out[[i]] <- data.frame(
        species = sp, group_key = eligible$group_key[1], fleet = eligible$fleet[1],
        start_year = eligible$start_year[1], end_year = eligible$end_year[1],
        DSI_v2 = eligible$dsi_v2[1], n_usable = eligible$n_usable[1], frac_usable = eligible$frac_usable[1],
        beta = eligible$beta[1], p = eligible$p[1], EC = eligible$ec[1], IC = eligible$ic[1],
        READY = FALSE, selection_reason = paste(reason, collapse = "; "),
        stringsAsFactors = FALSE
      )
      next
    }

    best <- eligible[1, , drop = FALSE]
    out[[i]] <- data.frame(
      species = sp, group_key = best$group_key, fleet = best$fleet,
      start_year = best$start_year, end_year = best$end_year,
      DSI_v2 = best$dsi_v2, n_usable = best$n_usable, frac_usable = best$frac_usable,
      beta = best$beta, p = best$p, EC = best$ec, IC = best$ic,
      READY = TRUE, selection_reason = "auto_selected",
      stringsAsFactors = FALSE
    )
  }

  do.call(rbind, out)
}

get_best_window_for_species <- function(dsi_table, species, require_ready = TRUE) {
  if (nrow(dsi_table) == 0) return(list(start_year = NA, end_year = NA, data = NULL, reason = "no_data"))
  sel <- dsi_table[dsi_table$species == species, , drop = FALSE]
  if (nrow(sel) == 0) return(list(start_year = NA, end_year = NA, data = NULL, reason = "species_not_found"))
  sel <- sel[sel$READY %in% TRUE, , drop = FALSE]
  if (nrow(sel) == 0 && require_ready)
    return(list(start_year = NA, end_year = NA, data = NULL, reason = "species_not_ready"))
  if (nrow(sel) == 0)
    return(list(start_year = NA, end_year = NA, data = NULL, reason = "no_ready_row"))
  row <- sel[1, ]
  list(
    start_year = row$start_year,
    end_year = row$end_year,
    group_key = row$group_key,
    fleet = row$fleet,
    data = NULL,
    reason = row$selection_reason
  )
}

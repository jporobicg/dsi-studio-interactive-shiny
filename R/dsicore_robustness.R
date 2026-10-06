## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ DSI Core: random-catch null test, method comparison  ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Random-catch null test for one window
#'
#' CPUE = catch / effort shares effort with the regressor, so log(CPUE) on
#' effort tends to have a negative slope even when catch carries no signal.
#' This test breaks any catch-effort link by randomising catch inside the
#' window, recomputes CPUE = catch* / effort and re-scores the window with
#' exactly the same settings. If the observed DSI_v2 is not clearly above the
#' null distribution, the score mostly reflects the ratio artefact.
#'
#' @param grp_data Rows of one group (harmonised effort, as screened)
#' @param start_year,end_year Window
#' @param n_sim Number of randomisations
#' @param mode "permute" (shuffle observed catches among years) or
#'   "lognormal" (draw catch from a lognormal with the window's log-mean/sd)
#' @param seed RNG seed (results are reproducible)
#' @param score_args List of extra arguments for [score_window()]
#'   (method, fixes, refs, weights, min_n, min_usable)
#' @param progress Optional function(i, n) called during the loop
#' @return List with observed scores, the null scores, empirical p-value and
#'   summary statistics
#' @export
dsi_null_test <- function(grp_data, start_year, end_year, n_sim = 199,
                          mode = c("permute", "lognormal"), seed = 1,
                          score_args = list(), progress = NULL) {
  mode <- match.arg(mode)
  score <- function(d) do.call(score_window, c(list(df = d, start_year = start_year,
                                                    end_year = end_year), score_args))
  observed <- score(grp_data)
  in_w <- .year_in_window(grp_data$year, start_year, end_year)
  idx <- which(in_w & is.finite(grp_data$catch) & grp_data$catch > 0 &
                 is.finite(grp_data$effort) & grp_data$effort > 0)
  # observed score with CPUE rebuilt as catch / effort, for a like-for-like reference
  d_ce <- grp_data
  d_ce$cpue[in_w] <- d_ce$catch[in_w] / d_ce$effort[in_w]
  observed_ce <- score(d_ce)
  if (length(idx) < 3) stop("Too few rows with positive catch and effort in this window")
  old_seed <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv()) else NULL
  on.exit(if (!is.null(old_seed)) assign(".Random.seed", old_seed, envir = globalenv()), add = TRUE)
  set.seed(seed)
  lc <- log(grp_data$catch[idx])
  null_v2 <- null_dsi <- rep(NA_real_, n_sim)
  for (i in seq_len(n_sim)) {
    d <- d_ce
    new_catch <- if (mode == "permute") sample(grp_data$catch[idx]) else
      exp(stats::rnorm(length(idx), mean(lc), stats::sd(lc)))
    d$catch[idx] <- new_catch
    d$cpue[idx] <- new_catch / d$effort[idx]
    s <- score(d)
    null_v2[i] <- s$dsi_v2 %||% NA_real_
    null_dsi[i] <- s$dsi %||% NA_real_
    if (!is.null(progress) && i %% 10 == 0) progress(i, n_sim)
  }
  obs <- observed$dsi_v2 %||% NA_real_
  ok <- is.finite(null_v2)
  p_emp <- if (is.finite(obs) && any(ok)) (1 + sum(null_v2[ok] >= obs)) / (1 + sum(ok)) else NA_real_
  list(
    start_year = start_year, end_year = end_year, mode = mode, n_sim = n_sim, seed = seed,
    observed_dsi_v2 = obs, observed_dsi = observed$dsi %||% NA_real_,
    observed_ce_dsi_v2 = observed_ce$dsi_v2 %||% NA_real_,
    cpue_is_catch_over_effort = isTRUE(all.equal(observed$dsi_v2, observed_ce$dsi_v2)),
    null_dsi_v2 = null_v2, null_dsi = null_dsi,
    n_valid_null = sum(ok),
    null_median = if (any(ok)) stats::median(null_v2[ok]) else NA_real_,
    null_q95 = if (any(ok)) unname(stats::quantile(null_v2[ok], 0.95)) else NA_real_,
    p_value = p_emp,
    percentile = if (is.finite(obs) && any(ok)) mean(null_v2[ok] < obs) * 100 else NA_real_
  )
}

#' Legacy vs Corrected comparison with per-fix attribution
#'
#' Runs the same data through the legacy profile (all fixes off) and the
#' corrected profile (all fixes on), plus the corrected profile with each fix
#' reverted on its own. The drop from reverting fix k is that fix's
#' contribution to the corrected score. Fixes interact, so contributions do
#' not have to add up to the total legacy-to-corrected difference.
#'
#' @param df Raw data
#' @param col_map,group_cols,min_n,max_n,effort_semantics,refs,selection_opts,min_usable
#'   As in [run_dsi_workflow()]
#' @param anchor_mode Anchor used when the anchoring fix is on
#' @param weights Corrected-profile weights (the legacy run always uses 0.95-sum weights)
#' @param progress Optional function(message, value)
#' @return List: `legacy`, `corrected` (workflow results), `windows`
#'   (per-window join), `groups` (per-group best-window comparison),
#'   `attribution` (per fix summary), `per_fix_windows`
#' @export
dsi_compare_methods <- function(df, col_map, group_cols, min_n = 8, max_n = 20,
                                anchor_mode = "last_usable_year",
                                effort_semantics = "per_group_year",
                                refs = default_dsi_refs(), weights = NULL,
                                selection_opts = default_selection_opts(),
                                min_usable = 6, progress = NULL) {
  prog <- function(m, v) if (!is.null(progress)) progress(m, v)
  cat_fix <- dsi_fix_catalog()
  run <- function(fixes, w = NULL) {
    run_dsi_workflow(df, col_map, group_cols, min_n = min_n, max_n = max_n,
                     anchor_mode = anchor_mode, method = "corrected",
                     effort_semantics = effort_semantics, refs = refs,
                     weights = w, selection_opts = selection_opts,
                     fixes = fixes, min_usable = min_usable)
  }
  prog("Legacy profile...", 0.05)
  legacy <- run_dsi_workflow(df, col_map, group_cols, min_n = min_n, max_n = max_n,
                             anchor_mode = "last_year", method = "legacy",
                             effort_semantics = effort_semantics, refs = refs,
                             selection_opts = selection_opts, min_usable = min_usable)
  prog("Corrected profile...", 0.15)
  corr_w <- weights %||% default_dsi_weights(legacy = FALSE)
  corrected <- run(dsi_fix_flags("corrected"), corr_w)

  key <- c("group_key", "start_year", "end_year")
  keep <- function(x, sfx) {
    x <- x[, intersect(c(key, "valid", "dsi", "dsi_v2", "frac_usable", "acf1", "effort_mean", "f_beta_pos"), names(x))]
    names(x)[!names(x) %in% key] <- paste0(names(x)[!names(x) %in% key], sfx)
    x
  }
  windows <- dplyr::full_join(keep(legacy$dsi_all, "_legacy"), keep(corrected$dsi_all, "_corrected"), by = key)
  windows$d_dsi_v2 <- windows$dsi_v2_corrected - windows$dsi_v2_legacy
  windows$in_both <- !is.na(windows$valid_legacy) & !is.na(windows$valid_corrected)

  best_cols <- function(b, sfx) {
    b <- b[, c("group_key", "start_year", "end_year", "dsi_v2", "ready", "selection_reason")]
    names(b)[-1] <- paste0(names(b)[-1], sfx)
    b
  }
  groups <- dplyr::full_join(best_cols(legacy$dsi_best, "_legacy"),
                             best_cols(corrected$dsi_best, "_corrected"), by = "group_key")
  groups$d_best_dsi_v2 <- groups$dsi_v2_corrected - groups$dsi_v2_legacy
  groups$window_changed <- !(groups$start_year_legacy %in% groups$start_year_corrected &
                               groups$end_year_legacy %in% groups$end_year_corrected) |
    groups$start_year_legacy != groups$start_year_corrected |
    groups$end_year_legacy != groups$end_year_corrected
  groups$window_changed[is.na(groups$window_changed)] <- TRUE
  groups$ready_changed <- (groups$ready_legacy %in% TRUE) != (groups$ready_corrected %in% TRUE)

  per_fix <- list()
  attribution <- list()
  n_fix <- nrow(cat_fix)
  for (k in seq_len(n_fix)) {
    id <- cat_fix$id[k]
    prog(sprintf("Reverting fix %d of %d: %s", k, n_fix, cat_fix$label[k]), 0.2 + 0.75 * (k - 1) / n_fix)
    flags <- dsi_fix_flags("corrected"); flags[[id]] <- FALSE
    if (id == "weights_sum_one") {
      alt <- corrected
      alt$dsi_all <- rescore_with_weights(corrected$dsi_all, default_dsi_weights(legacy = TRUE))
      alt$dsi_best <- select_best_window(alt$dsi_all, selection_opts, stability_filter = TRUE)
    } else if (id == "stability_filter") {
      alt <- corrected
      alt$dsi_best <- select_best_window(corrected$dsi_all, selection_opts, stability_filter = FALSE)
    } else {
      alt <- run(flags, corr_w)
    }
    j <- dplyr::inner_join(corrected$dsi_all[, c(key, "dsi_v2")], alt$dsi_all[, c(key, "dsi_v2")],
                           by = key, suffix = c("_corrected", "_reverted"))
    j$delta <- j$dsi_v2_corrected - j$dsi_v2_reverted
    jb <- dplyr::inner_join(corrected$dsi_best[, c("group_key", "start_year", "end_year", "dsi_v2", "ready")],
                            alt$dsi_best[, c("group_key", "start_year", "end_year", "dsi_v2", "ready")],
                            by = "group_key", suffix = c("_corrected", "_reverted"))
    n_alt_only <- nrow(dplyr::anti_join(alt$dsi_all[, key], corrected$dsi_all[, key], by = key))
    n_cor_only <- nrow(dplyr::anti_join(corrected$dsi_all[, key], alt$dsi_all[, key], by = key))
    changed <- is.finite(j$delta) & abs(j$delta) > 1e-9 |
      xor(is.finite(j$dsi_v2_corrected), is.finite(j$dsi_v2_reverted))
    attribution[[k]] <- data.frame(
      id = id, label = cat_fix$label[k], stage = cat_fix$stage[k],
      windows_compared = nrow(j), windows_changed = sum(changed),
      windows_added_or_removed = n_alt_only + n_cor_only,
      mean_abs_delta = if (any(is.finite(j$delta))) mean(abs(j$delta[is.finite(j$delta)])) else 0,
      max_abs_delta = if (any(is.finite(j$delta))) max(abs(j$delta[is.finite(j$delta)])) else 0,
      groups_best_window_changed = sum(jb$start_year_corrected != jb$start_year_reverted |
                                         jb$end_year_corrected != jb$end_year_reverted, na.rm = TRUE),
      groups_ready_changed = sum((jb$ready_corrected %in% TRUE) != (jb$ready_reverted %in% TRUE)),
      stringsAsFactors = FALSE)
    j$fix <- id
    per_fix[[id]] <- j
  }
  prog("Done", 1)
  list(legacy = legacy, corrected = corrected, windows = windows, groups = groups,
       attribution = do.call(rbind, attribution), per_fix_windows = do.call(rbind, per_fix),
       catalog = cat_fix)
}

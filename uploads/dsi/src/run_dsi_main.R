## DSI screening main script (reproducible)
##
## Run from: 01_DSI_screening/

suppressPackageStartupMessages({
  library(ggplot2)
})

source(file.path("R", "functions_dsi.R"))

## ---- Parameters ----
input_path <- file.path("..", "Data", "Thai_main_groups.csv")

col_map <- list(
  year = "year",      # or set date = "date_col"
  date = NULL,
  species = "group",
  fleet = NULL,       # no fleet column in this dataset
  catch = "yield",
  effort = "effort",
  cpue = "cpue"
)

group_cols <- c("species") # no fleet dimension for this dataset

min_n <- 8
max_n <- 55
min_usable <- 6

beta_ref_base <- 0.02
p_ref <- 0.20

## P_miss = (p_miss_cov_lo + p_miss_cov_hi*S_cov) * (p_miss_ess_lo + p_miss_ess_hi*S_ESS)
p_miss_cov_lo <- 0.7
p_miss_cov_hi <- 0.3
p_miss_ess_lo <- 0.85
p_miss_ess_hi <- 0.15

use_dsi_v2 <- FALSE

## Best-window selection (Step 3)
min_frac_usable <- 0.6
min_EC <- 0.4
min_IC <- 1.2
max_f_beta_pos <- 0.3
min_eligible_windows <- 3
min_DSI_v2_top1 <- 70
max_DSI_v2_spread <- 20

out_dir <- "outputs"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

## ---- Optional plot style ----
if (file.exists("plot_style.R")) source("plot_style.R")
if (file.exists(file.path("R", "plot_style.R"))) source(file.path("R", "plot_style.R"))
if (exists("check_plot_style", mode = "function")) check_plot_style()

.theme_base <- function() {
  if (exists("theme_report", mode = "function")) return(theme_report())
  theme_minimal(base_size = 11) +
    theme(
      panel.grid.minor = element_blank(),
      legend.position = "right"
    )
}

.scale_fill_dsi <- function() {
  scale_fill_gradientn(
    colours = c("#b2182b", "#ef8a62", "#f7f7f7", "#67a9cf", "#2166ac"),
    limits = c(0, 100),
    oob = function(x, ...) pmin(100, pmax(0, x))
  )
}

.scale_colour_group <- function(values = NULL) {
  if (exists("species_cols", mode = "function")) {
    return(scale_colour_manual(values = species_cols()))
  }
  if (!is.null(values)) return(scale_colour_manual(values = values))
  scale_colour_discrete()
}

## ---- Quiet logging (warnings/messages) ----
.warn_log <- character(0)
.msg_log <- character(0)
.warn_log_path <- file.path(out_dir, "run_warnings.txt")
.msg_log_path <- file.path(out_dir, "run_messages.txt")

.with_log <- function(expr) {
  expr_sub <- substitute(expr)
  withCallingHandlers(
    eval(expr_sub, envir = parent.frame()),
    warning = function(w) {
      .warn_log <<- c(.warn_log, conditionMessage(w))
      invokeRestart("muffleWarning")
    },
    message = function(m) {
      .msg_log <<- c(.msg_log, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
}

## ---- Read + standardize ----
.with_log({
  stopifnot(file.exists(input_path))
  raw <- read.csv(input_path, stringsAsFactors = FALSE, check.names = FALSE)
})

standardize_columns <- function(df, map) {
  out <- df

  get_col <- function(key) map[[key]]

  if (!is.null(get_col("year"))) {
    y <- out[[get_col("year")]]
    out$year <- as.integer(y)
  } else if (!is.null(get_col("date"))) {
    d <- out[[get_col("date")]]
    d <- as.Date(d)
    out$year <- as.integer(format(d, "%Y"))
  } else {
    stop("col_map must specify either 'year' or 'date'.")
  }

  if (!is.null(get_col("species")) && (get_col("species") %in% names(out))) {
    out$species <- as.character(out[[get_col("species")]])
  } else {
    out$species <- "ALL"
  }

  if (!is.null(get_col("fleet")) && (get_col("fleet") %in% names(out))) {
    out$fleet <- as.character(out[[get_col("fleet")]])
  } else {
    out$fleet <- "ALL_FLEET"
  }

  req <- c("catch", "effort", "cpue")
  for (k in req) {
    cn <- get_col(k)
    if (is.null(cn) || !(cn %in% names(out))) stop(paste0("Missing mapped column: ", k))
    out[[k]] <- suppressWarnings(as.numeric(out[[cn]]))
  }

  out
}

## effort is defined by year x fleet; merge to species rows
effort_by_fleet_year <- function(df) {
  stopifnot(all(c("year", "fleet", "effort") %in% names(df)))
  df2 <- df[is.finite(df$year) & !is.na(df$fleet), c("year", "fleet", "effort"), drop = FALSE]

  f <- interaction(df2$year, df2$fleet, drop = TRUE)
  spl <- split(df2, f)

  out <- lapply(spl, function(d) {
    e <- d$effort
    e_ok <- e[is.finite(e)]
    e_val <- if (length(e_ok) == 0) NA_real_ else e_ok[1]
    n_non_na <- length(e_ok)
    n_unique <- if (length(e_ok) == 0) 0L else length(unique(e_ok))
    data.frame(
      year = d$year[1],
      fleet = d$fleet[1],
      effort_fleet_year = e_val,
      effort_n_non_na = n_non_na,
      effort_n_unique = n_unique,
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, out)
}

.with_log({
  dat <- standardize_columns(raw, col_map)

  e_tbl <- effort_by_fleet_year(dat)
  dat$effort_raw <- dat$effort
  dat <- merge(dat, e_tbl, by = c("year", "fleet"), all.x = TRUE, sort = FALSE)
  dat$effort <- dat$effort_fleet_year

  if (length(group_cols) == 0) {
    dat$..group_id.. <- "ALL"
    group_cols_use <- "..group_id.."
  } else {
    group_cols_use <- intersect(group_cols, names(dat))
    if (length(group_cols_use) == 0) {
      dat$..group_id.. <- "ALL"
      group_cols_use <- "..group_id.."
    }
  }

  make_group_key <- function(df, cols) {
    if (length(cols) == 1) return(df[[cols]])
    apply(df[, cols, drop = FALSE], 1, function(r) paste(r, collapse = " | "))
  }

  dat$group_key <- make_group_key(dat, group_cols_use)

  ## ---- Compute all windows ----
  refs <- list(
    beta_ref_base = beta_ref_base,
    p_ref = p_ref,
    p_miss_cov_lo = p_miss_cov_lo,
    p_miss_cov_hi = p_miss_cov_hi,
    p_miss_ess_lo = p_miss_ess_lo,
    p_miss_ess_hi = p_miss_ess_hi
  )

  groups <- sort(unique(dat$group_key))
  all_rows <- vector("list", 0)
  row_i <- 0L

  for (g in groups) {
    d_g <- dat[dat$group_key == g, , drop = FALSE]
    years_g <- sort(unique(d_g$year[is.finite(d_g$year)]))
    wins <- generate_windows(years_g, min_n = min_n, max_n = max_n)
    if (nrow(wins) == 0) next

    for (k in seq_len(nrow(wins))) {
      w <- wins[k, ]
      m <- compute_window_metrics(
        df = d_g,
        start_year = w$start_year,
        end_year = w$end_year,
        min_n = min_n,
        min_usable = min_usable,
        refs = refs,
        cols = list(year = "year", catch = "catch", effort = "effort", cpue = "cpue")
      )
      dsi_base <- compute_dsi_base(m)
      dsi <- compute_dsi(m)

      v2 <- NULL
      dsi_v2 <- NA_real_
      if (isTRUE(m$valid) && !is.na(dsi)) {
        v2 <- compute_window_v2_metrics(
          df = d_g,
          start_year = w$start_year,
          end_year = w$end_year,
          cols = list(year = "year", effort = "effort", cpue = "cpue")
        )
        dsi_v2 <- compute_dsi_v2_robust(dsi_base, m$P_miss, m$p_out, v2)
      }

      row_i <- row_i + 1L
      all_rows[[row_i]] <- data.frame(
        group_key = g,
        start_year = m$start_year,
        end_year = m$end_year,
        n_years = w$n_years,
        n_rows_window = m$n_rows_window,
        n_rows_valid = m$n_rows_valid,
        n_total = m$n_total,
        n_usable = m$n_usable,
        frac_usable = m$frac_usable,
        n_cpue = m$n_cpue,
        n_effort = m$n_effort,
        n_catch = m$n_catch,
        n_invalid_cpue = m$n_invalid_cpue,
        n_invalid_effort = m$n_invalid_effort,
        S_cov = m$S_cov,
        acf1 = m$acf1,
        ESS = m$ESS,
        S_ESS = m$S_ESS,
        P_miss = m$P_miss,
        beta = m$beta,
        p = m$p,
        r2 = m$r2,
        ec = m$ec,
        ic = m$ic,
        s_e = m$s_e,
        s_i = m$s_i,
        s_n = m$s_n,
        rho_ce = m$rho_ce,
        s_ce = m$s_ce,
        f_out = m$f_out,
        p_out = m$p_out,
        s_slope = m$s_slope,
        dsi_base = dsi_base,
        dsi = dsi,
        f_cook = if (!is.null(v2)) v2$f_cook else NA_real_,
        f_lev = if (!is.null(v2)) v2$f_lev else NA_real_,
        p_inf = if (!is.null(v2)) v2$p_inf else NA_real_,
        acf1_v2 = if (!is.null(v2)) v2$acf1 else NA_real_,
        s_acf = if (!is.null(v2)) v2$s_acf else NA_real_,
        z_shift = if (!is.null(v2)) v2$z_shift else NA_real_,
        s_shift = if (!is.null(v2)) v2$s_shift else NA_real_,
        cor_fit_e = if (!is.null(v2)) v2$cor_fit_e else NA_real_,
        s_fit_e = if (!is.null(v2)) v2$s_fit_e else NA_real_,
        f_beta_pos = if (!is.null(v2)) v2$f_beta_pos else NA_real_,
        s_stab = if (!is.null(v2)) v2$s_stab else NA_real_,
        dsi_v2 = dsi_v2,
        valid = m$valid,
        reasons_invalid = m$reasons_invalid,
        stringsAsFactors = FALSE
      )
    }
  }

dsi_all <- if (length(all_rows) == 0) {
  data.frame()
} else {
  do.call(rbind, all_rows)
}

if (nrow(dsi_all) > 0) {
  tmp <- strsplit(as.character(dsi_all$group_key), " \\| ", fixed = FALSE)
  dsi_all$species <- sapply(tmp, function(x) trimws(x[1]))
  dsi_all$fleet <- sapply(tmp, function(x) if (length(x) >= 2) trimws(x[2]) else "ALL_FLEET")
}

write.csv(dsi_all, file.path(out_dir, "dsi_all_windows.csv"), row.names = FALSE)

## ---- Best window per species (selection C) ----
selection_opts <- list(
  min_usable = min_usable,
  min_frac_usable = min_frac_usable,
  min_EC = min_EC,
  min_IC = min_IC,
  max_f_beta_pos = max_f_beta_pos,
  min_eligible_windows = min_eligible_windows,
  min_DSI_v2_top1 = min_DSI_v2_top1,
  max_DSI_v2_spread = max_DSI_v2_spread
)
best_window_selected <- select_best_window_per_species(dsi_all, selection_opts)
write.csv(best_window_selected, file.path(out_dir, "dsi_best_window_selected.csv"), row.names = FALSE)

## ---- Top 10 windows per species (by DSI_v2) ----
rank_col <- if (isTRUE(use_dsi_v2)) "dsi_v2" else "dsi"
top_rows <- vector("list", 0)
ti <- 0L
species_list_top <- if (nrow(dsi_all) > 0) sort(unique(dsi_all$species)) else character(0)
for (sp in species_list_top) {
  dd <- dsi_all[dsi_all$species == sp, , drop = FALSE]
  dd <- dd[is.finite(dd[[rank_col]]), , drop = FALSE]
  if (nrow(dd) == 0) next
  dd <- dd[order(dd[[rank_col]], decreasing = TRUE), , drop = FALSE]
  dd <- utils::head(dd, 10)
  ti <- ti + 1L
  top_rows[[ti]] <- dd
}

dsi_top <- if (length(top_rows) == 0) data.frame() else do.call(rbind, top_rows)
write.csv(dsi_top, file.path(out_dir, "dsi_top_windows.csv"), row.names = FALSE)

## ---- Plots ----
.safe_filename <- function(x) {
  x <- gsub("[^A-Za-z0-9_\\-]+", "_", x)
  x <- gsub("_+", "_", x)
  x
}

plot_heatmap <- function(dd, score_col, title, out_path) {
  if (nrow(dd) == 0 || all(is.na(dd[[score_col]]))) {
    p <- ggplot() + geom_blank() + labs(title = title, subtitle = "No valid windows") + .theme_base()
    ggsave(out_path, p, width = 7.5, height = 5.5, dpi = 300)
    return(invisible(NULL))
  }

  dd2 <- dd
  dd2$score_value <- dd2[[score_col]]

  p <- ggplot(dd2, aes(x = start_year, y = end_year, fill = score_value)) +
    geom_tile(color = NA) +
    labs(title = title, x = "Start year", y = "End year", fill = score_col) +
    .scale_fill_dsi() +
    .theme_base()

  ggsave(out_path, p, width = 7.5, height = 5.5, dpi = 300)
}

plot_dsi_by_species <- function(dsi_all, species_id, all_fleets, out_path) {
  dd <- dsi_all[dsi_all$species == species_id, , drop = FALSE]
  x_range <- if (nrow(dd) > 0) range(dd$start_year, na.rm = TRUE) else c(2000L, 2020L)
  mid_x <- mean(x_range)
  base_df <- data.frame(
    fleet = factor(all_fleets, levels = all_fleets),
    start_year = mid_x,
    value = 50,
    stringsAsFactors = FALSE
  )
  if (nrow(dd) == 0) {
    base_df$label <- "Not enough data"
    p <- ggplot(base_df, aes(x = start_year, y = value)) +
      facet_wrap(~fleet, drop = FALSE, ncol = 2) +
      geom_blank() +
      geom_text(aes(label = label), size = 3.5, colour = "grey40") +
      coord_cartesian(ylim = c(0, 100)) +
      labs(title = paste0("DSI / DSI_v2 by fleet: ", species_id), x = "Start year", y = "Score") +
      .theme_base()
    ggsave(out_path, p, width = 10, height = 6, dpi = 300)
    return(invisible(NULL))
  }
  dd$fleet <- factor(dd$fleet, levels = all_fleets)
  long <- rbind(
    data.frame(start_year = dd$start_year, value = dd$dsi, metric = "DSI", fleet = dd$fleet),
    data.frame(start_year = dd$start_year, value = dd$dsi_v2, metric = "DSI_v2", fleet = dd$fleet)
  )
  long <- long[is.finite(long$value), , drop = FALSE]
  fleets_no_valid <- character(0)
  for (f in all_fleets) {
    sub <- dd[as.character(dd$fleet) == f, , drop = FALSE]
    if (nrow(sub) == 0 || !any(is.finite(sub$dsi) | is.finite(sub$dsi_v2))) fleets_no_valid <- c(fleets_no_valid, f)
  }
  if (length(fleets_no_valid) > 0) {
    empty_df <- data.frame(
      fleet = factor(fleets_no_valid, levels = all_fleets),
      label = "Not enough data",
      x = mid_x,
      y = 50,
      stringsAsFactors = FALSE
    )
  } else {
    empty_df <- data.frame(fleet = factor(levels = all_fleets), label = character(0),
                           x = numeric(0), y = numeric(0), stringsAsFactors = FALSE)
  }
  p <- ggplot(base_df, aes(x = start_year, y = value)) +
    facet_wrap(~fleet, drop = FALSE, ncol = 2) +
    geom_blank() +
    scale_x_continuous(limits = x_range) +
    coord_cartesian(ylim = c(0, 100)) +
    labs(title = paste0("DSI / DSI_v2 vs start year: ", species_id), x = "Start year", y = "Score", colour = NULL) +
    .theme_base()
  if (nrow(long) > 0) {
    p <- p +
      geom_line(data = long, aes(x = start_year, y = value, colour = metric), linewidth = 1, na.rm = TRUE) +
      geom_point(data = long, aes(x = start_year, y = value, colour = metric), size = 2, na.rm = TRUE)
  }
  if (nrow(empty_df) > 0) {
    p <- p + geom_text(data = empty_df, aes(x = x, y = y, label = label), inherit.aes = FALSE, size = 3.5, colour = "grey40")
  }
  ggsave(out_path, p, width = 10, height = 6, dpi = 300)
}

## ---- Selected window data (for READY species) ----
selected_dir <- file.path(out_dir, "selected_window_data")
dir.create(selected_dir, showWarnings = FALSE, recursive = TRUE)
ready_rows <- best_window_selected[best_window_selected$READY %in% TRUE, , drop = FALSE]
for (i in seq_len(nrow(ready_rows))) {
  row <- ready_rows[i, ]
  g <- row$group_key
  sy <- row$start_year
  ey <- row$end_year
  sp <- row$species
  sub <- dat[dat$group_key == g & dat$year >= sy & dat$year <= ey, , drop = FALSE]
  sub$usable <- (is.finite(sub$cpue) & sub$cpue > 0 & is.finite(sub$effort))
  write.csv(sub, file.path(selected_dir, paste0(.safe_filename(sp), "_selected_window.csv")), row.names = FALSE)
}

plot_best_timeseries <- function(d_g, best_row, out_path) {
  sy <- best_row$start_year
  ey <- best_row$end_year

  d <- d_g[is.finite(d_g$year), c("year", "catch", "cpue", "effort"), drop = FALSE]
  d <- d[order(d$year), , drop = FALSE]

  long <- rbind(
    data.frame(year = d$year, metric = "catch", value = d$catch),
    data.frame(year = d$year, metric = "cpue", value = d$cpue),
    data.frame(year = d$year, metric = "effort", value = d$effort)
  )

  p <- ggplot(long, aes(x = year, y = value)) +
    annotate("rect", xmin = sy, xmax = ey, ymin = -Inf, ymax = Inf, fill = "grey80", alpha = 0.5) +
    geom_line(na.rm = TRUE) +
    facet_wrap(~metric, scales = "free_y", ncol = 1) +
    labs(title = "Catch / CPUE / Effort time-series", x = "Year", y = NULL) +
    .theme_base()

  .with_log(ggsave(out_path, p, width = 8, height = 8, dpi = 300))
}

plot_best_cooks <- function(d_g, best_row, out_path) {
  sy <- best_row$start_year
  ey <- best_row$end_year
  in_w <- d_g$year >= sy & d_g$year <= ey

  log_res <- safe_log_cpue(d_g$cpue)
  ok <- in_w & is.finite(log_res$log_cpue) & is.finite(d_g$effort)
  d <- d_g[ok, , drop = FALSE]
  if (nrow(d) < 3 || stats::sd(d$effort) == 0) {
    p <- ggplot() + geom_blank() + labs(title = "Cook's distance", subtitle = "Insufficient valid data") + .theme_base()
    ggsave(out_path, p, width = 7.5, height = 5.5, dpi = 300)
    return(invisible(NULL))
  }

  fit <- stats::lm(log(d$cpue) ~ d$effort)
  cd <- stats::cooks.distance(fit)
  dd <- data.frame(year = d$year, cooks_d = as.numeric(cd))

  p <- ggplot(dd, aes(x = year, y = cooks_d)) +
    geom_col(width = 0.8) +
    geom_hline(yintercept = 4 / nrow(d), linetype = 2, color = "red") +
    labs(title = "Diagnostics: Cook's distance (best window)", x = "Year", y = "Cook's D") +
    .theme_base()

  ggsave(out_path, p, width = 7.5, height = 5.5, dpi = 300)
}

all_fleets <- if (nrow(dsi_all) > 0) sort(unique(dsi_all$fleet)) else character(0)
species_list <- if (nrow(dsi_all) > 0) sort(unique(dsi_all$species)) else character(0)
for (sp in species_list) {
  .with_log(plot_dsi_by_species(dsi_all, sp, all_fleets, file.path(out_dir, paste0("dsi_by_species__", .safe_filename(sp), ".png"))))
}

for (g in groups) {
  d_g <- dat[dat$group_key == g, , drop = FALSE]
  dd <- dsi_all[dsi_all$group_key == g, , drop = FALSE]

  safe_g <- .safe_filename(g)
  .with_log(plot_heatmap(dd, "dsi", paste0("DSI heatmap: ", g), file.path(out_dir, paste0("heatmap_dsi__", safe_g, ".png"))))
  if (isTRUE(use_dsi_v2)) {
    .with_log(plot_heatmap(dd, "dsi_v2", paste0("DSI_v2 heatmap: ", g), file.path(out_dir, paste0("heatmap_dsi_v2__", safe_g, ".png"))))
  }

  dd_rank <- dd[is.finite(dd[[rank_col]]), , drop = FALSE]
  if (nrow(dd_rank) == 0) next
  best <- dd_rank[order(dd_rank[[rank_col]], decreasing = TRUE), , drop = FALSE][1, ]

  .with_log(plot_best_timeseries(
    d_g, best,
    file.path(out_dir, paste0("best_timeseries__", safe_g, ".png"))
  ))
  if (isTRUE(use_dsi_v2)) {
    .with_log(plot_best_cooks(
      d_g, best,
      file.path(out_dir, paste0("best_cooks__", safe_g, ".png"))
    ))
  }
}

})

if (length(.warn_log) > 0) writeLines(unique(.warn_log), .warn_log_path)
if (length(.msg_log) > 0) writeLines(unique(.msg_log), .msg_log_path)

## ---- Sanity check ----
if (nrow(best_window_selected) > 0) {
  n_ready <- sum(best_window_selected$READY %in% TRUE, na.rm = TRUE)
  n_selected <- n_ready
  cat("DSI screening sanity check:\n")
  cat("  Species processed: ", nrow(best_window_selected), "\n")
  cat("  READY (auto-select): ", n_ready, "\n")
  cat("  Selected (window data written): ", n_selected, "\n")
  cat("  Failure reasons:\n")
  print(table(best_window_selected$selection_reason, useNA = "ifany"))
}

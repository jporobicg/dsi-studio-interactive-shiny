## DSI screening for species × fleet (Gulf of Thailand long table)
##
## Run from: DSI_test/01_DSI_screening/
## Input:    ../Data/all_species_combined.csv

suppressPackageStartupMessages({
  library(ggplot2)
})

source(file.path("R", "functions_dsi.R"))

## ---- Parameters ----
input_path <- file.path("..", "Data", "all_species_combined.csv")

col_map <- list(
  year = "year",
  date = NULL,
  species = "species",
  fleet = "gear",
  catch = "catch",
  effort = "effort",
  cpue = "cpue"
)

group_cols <- c("species", "fleet")

min_n <- 8
max_n <- 20
min_usable <- 6

beta_ref_base <- 0.02
p_ref <- 0.20

## P_miss = (p_miss_cov_lo + p_miss_cov_hi*S_cov) * (p_miss_ess_lo + p_miss_ess_hi*S_ESS)
p_miss_cov_lo <- 0.7
p_miss_cov_hi <- 0.3
p_miss_ess_lo <- 0.85
p_miss_ess_hi <- 0.15

out_dir <- "outputs"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

## ---- Read + standardize ----
stopifnot(file.exists(input_path))
raw <- read.csv(input_path, stringsAsFactors = FALSE, check.names = FALSE)

standardize_columns <- function(df, map) {
  out <- df
  get_col <- function(key) map[[key]]

  if (!is.null(get_col("year"))) {
    out$year <- as.integer(out[[get_col("year")]])
  } else if (!is.null(get_col("date"))) {
    d <- as.Date(out[[get_col("date")]])
    out$year <- as.integer(format(d, "%Y"))
  } else {
    stop("col_map must specify either 'year' or 'date'.")
  }

  out$species <- as.character(out[[get_col("species")]])
  out$fleet <- as.character(out[[get_col("fleet")]])

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
  df2 <- df[is.finite(df$year) & !is.na(df$fleet), c("year", "fleet", "effort"), drop = FALSE]
  f <- interaction(df2$year, df2$fleet, drop = TRUE)
  spl <- split(df2, f)
  out <- lapply(spl, function(d) {
    e <- d$effort
    e_ok <- e[is.finite(e)]
    e_val <- if (length(e_ok) == 0) NA_real_ else e_ok[1]
    data.frame(
      year = d$year[1],
      fleet = d$fleet[1],
      effort_fleet_year = e_val,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, out)
}

dat <- standardize_columns(raw, col_map)
e_tbl <- effort_by_fleet_year(dat)
dat <- merge(dat, e_tbl, by = c("year", "fleet"), all.x = TRUE, sort = FALSE)
dat$effort <- dat$effort_fleet_year

dat$group_key <- apply(dat[, group_cols, drop = FALSE], 1, function(r) paste(r, collapse = " | "))

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
    if (isTRUE(m$valid) && is.finite(dsi)) {
      v2 <- compute_window_v2_metrics(
        df = d_g,
        start_year = w$start_year,
        end_year = w$end_year,
        cols = list(year = "year", catch = "catch", effort = "effort", cpue = "cpue")
      )
      dsi_v2 <- compute_dsi_v2_robust(dsi_base, m$P_miss, m$p_out, v2)
    }

    row_i <- row_i + 1L
    all_rows[[row_i]] <- data.frame(
      group_key = g,
      start_year = m$start_year,
      end_year = m$end_year,
      n_years = w$n_years,
      n_usable = m$n_usable,
      frac_usable = m$frac_usable,
      beta = m$beta,
      p = m$p,
      ec = m$ec,
      ic = m$ic,
      rho_ce = m$rho_ce,
      dsi_base = dsi_base,
      dsi = dsi,
      dsi_v2 = dsi_v2,
      z_shift = if (!is.null(v2)) v2$z_shift else NA_real_,
      s_shift = if (!is.null(v2)) v2$s_shift else NA_real_,
      psi_catch = if (!is.null(v2)) v2$psi_catch else NA_real_,
      ks_p_catch = if (!is.null(v2)) v2$ks_p_catch else NA_real_,
      psi_effort = if (!is.null(v2)) v2$psi_effort else NA_real_,
      ks_p_effort = if (!is.null(v2)) v2$ks_p_effort else NA_real_,
      psi_logcpue = if (!is.null(v2)) v2$psi_logcpue else NA_real_,
      ks_p_logcpue = if (!is.null(v2)) v2$ks_p_logcpue else NA_real_,
      s_drift = if (!is.null(v2)) v2$s_drift else NA_real_,
      valid = m$valid,
      stringsAsFactors = FALSE
    )
  }
}

dsi_all <- if (length(all_rows) == 0) data.frame() else do.call(rbind, all_rows)
if (nrow(dsi_all) > 0) {
  tmp <- strsplit(as.character(dsi_all$group_key), " \\| ", fixed = FALSE)
  dsi_all$species <- sapply(tmp, function(x) trimws(x[1]))
  dsi_all$fleet <- sapply(tmp, function(x) trimws(x[2]))
}

write.csv(dsi_all, file.path(out_dir, "dsi_all_windows_fleet_species.csv"), row.names = FALSE)
cat("Saved:", file.path(out_dir, "dsi_all_windows_fleet_species.csv"), "\n")


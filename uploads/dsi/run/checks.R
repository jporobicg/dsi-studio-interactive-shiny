## Targeted behaviour checks of functions_dsi.R. Uses the user's EXAMPLE CSVs plus clearly-labelled SYNTHETIC cases.
source("01_DSI_screening/R/functions_dsi.R")
cat("\n## 1. Effort collapse in run_dsi_main.R (fleet absent -> ALL_FLEET)\n")
raw <- read.csv("Data/Thai_main_groups.csv")
first_eff <- tapply(raw$effort, raw$year, function(e) e[1])
for (g in unique(raw$group)) { r <- raw[raw$group == g, ]; cat(g, ": share of years where merged effort != own effort =", round(mean(abs(first_eff[as.character(r$year)] - r$effort) > 1e-9), 2), "\n") }

cat("\n## 2. Row order after merge(sort=FALSE)\n")
dat <- raw; dat$fleet <- "ALL_FLEET"
e_tbl <- aggregate(effort ~ year + fleet, dat, function(e) e[1]); names(e_tbl)[3] <- "eff2"
m <- merge(dat, e_tbl, by = c("year", "fleet"), all.x = TRUE, sort = FALSE)
for (g in unique(m$group)) cat(g, "years sorted within group after merge:", !is.unsorted(m$year[m$group == g]), "\n")
dat2 <- read.csv("Data/all_species_combined.csv"); dat2$fleet <- dat2$gear
et <- aggregate(effort ~ year + fleet, dat2, function(e) e[1]); names(et)[3] <- "eff2"
m2 <- merge(dat2, et, by = c("year", "fleet"), all.x = TRUE, sort = FALSE)
cat("species x fleet groups with unsorted years after merge:", sum(tapply(m2$year, paste(m2$species, m2$fleet), is.unsorted)), "of", length(unique(paste(m2$species, m2$fleet))), "\n")

cat("\n## 3. SYNTHETIC: generic properties\n")
set.seed(1)
sim <- function(n = 15, slope = -0.004, sd = 0.15, E = seq(50, 250, length.out = n)) {
  y <- 2 + slope * E + rnorm(n, 0, sd); data.frame(year = 2000 + seq_len(n) - 1, effort = E, cpue = exp(y), catch = exp(y) * E)
}
res <- t(replicate(500, {
  d <- sim(); m <- compute_window_metrics(d, 2000, 2014, refs = list(beta_ref_base = 0.02, p_ref = 0.2))
  v2 <- compute_window_v2_metrics(d, 2000, 2014)
  c(dsi_base = compute_dsi_base(m), dsi = compute_dsi(m), p_out = m$p_out, P_miss = m$P_miss, p_inf = v2$p_inf, s_fit_e = v2$s_fit_e,
    s_slope = m$s_slope, dsi_v2 = compute_dsi_v2_robust(compute_dsi_base(m), m$P_miss, m$p_out, v2), f_cook = v2$f_cook, f_lev = v2$f_lev, s_drift = v2$s_drift)
}))
print(round(apply(res, 2, quantile, c(.05, .25, .5, .75, .95), na.rm = TRUE), 3))
cat("s_fit_e unique values:", unique(round(res[, "s_fit_e"], 6)), "\n")
cat("share with p_out < 1:", mean(res[, "p_out"] < 1), " share p_inf<=0.5:", mean(res[, "p_inf"] <= 0.5), "\n")
cat("Max achievable DSI_base (all component scores = 1): ", 100 * (0.35 + .2 + .2 + .1 + .1), "\n")

cat("\n## 4. SYNTHETIC: spurious slope. catch independent of effort (iid lognormal), cpue = catch/effort\n")
sp <- t(replicate(300, { n <- 15; E <- seq(50, 250, length.out = n) * exp(rnorm(n, 0, .05)); C <- exp(rnorm(n, 5, .2))
  d <- data.frame(year = 2000:2014, effort = E, catch = C, cpue = C / E); m <- compute_window_metrics(d, 2000, 2014, refs = list(beta_ref_base = 0.02, p_ref = 0.2))
  c(beta_neg = m$beta < 0, p = m$p, dsi = compute_dsi(m), s_ce = m$s_ce) }))
cat("share beta<0:", mean(sp[, 1]), " median p:", signif(median(sp[, 2]), 3), " median DSI:", round(median(sp[, 3], na.rm = TRUE), 1), " share DSI>=50:", mean(sp[, 3] >= 50, na.rm = TRUE), "\n")

cat("\n## 5. SYNTHETIC: coverage ignores absent years\n")
d <- sim(20); d_gap <- d[-c(3, 4, 5, 6, 7), ]; d_na <- d; d_na$cpue[3:7] <- NA
mg <- compute_window_metrics(d_gap, 2000, 2019, refs = list(beta_ref_base = .02, p_ref = .2)); mn <- compute_window_metrics(d_na, 2000, 2019, refs = list(beta_ref_base = .02, p_ref = .2))
cat("rows absent: frac_usable =", mg$frac_usable, " P_miss =", round(mg$P_miss, 3), " | rows present with NA cpue: frac_usable =", mn$frac_usable, " P_miss =", round(mn$P_miss, 3), "\n")

cat("\n## 6. SYNTHETIC: v1 ACF/ESS depends on row order (unsorted rows)\n")
d <- sim(15, sd = .1); d$cpue <- d$cpue * exp(0.3 * sin(seq_len(15) / 2)); ds <- d[sample(15), ]
a <- compute_window_metrics(d, 2000, 2014, refs = list(beta_ref_base = .02, p_ref = .2)); b <- compute_window_metrics(ds, 2000, 2014, refs = list(beta_ref_base = .02, p_ref = .2))
cat("acf1 sorted =", round(a$acf1, 3), " shuffled =", round(b$acf1, 3), "; ESS", round(a$ESS, 1), "vs", round(b$ESS, 1), "\n")

cat("\n## 7. Selection stability filter no-op\n")
dd <- data.frame(species = "X", group_key = "X", fleet = "F", start_year = 2000:2002, end_year = 2020, dsi_v2 = c(90, 85, 80), n_usable = 15, frac_usable = 1, beta = -0.01, p = .01, ec = 1, ic = 3, f_beta_pos = 0.9, s_stab = 0)
print(select_best_window_per_species(dd)[, c("species", "DSI_v2", "READY", "selection_reason")])
cat("(f_beta_pos = 0.9 > max 0.3, yet READY because s_stab >= 0 is always TRUE)\n")

cat("\n## 8. generate_windows\n"); print(generate_windows(c(2000:2005, 2010:2020), min_n = 8, max_n = 20))
cat("\n## 9. compute_dsi_v2_robust returns NA (not 0) when dsi_base == 0:", compute_dsi_v2_robust(0, 1, 1, NULL), "\n")
cat("\n## 10. PSI scale: early vs late halves fully separated (n=7 each): psi =", round(.psi_numeric(1:7, 8:14), 2), " score_drift(psi, ks_p) =", .score_drift(.psi_numeric(1:7, 8:14), .safe_ks_pvalue(1:7, 8:14)), "\n")

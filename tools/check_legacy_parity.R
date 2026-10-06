## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Legacy parity check: DSI Studio "legacy" profile vs the     ~ ##
## ~ original scripts in uploads/dsi/src (run live, not cached)  ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
##
## Run from the repository root:   Rscript tools/check_legacy_parity.R
##
## For each case the script
##   1. copies the ORIGINAL script + functions_dsi.R into a temp dir and runs it,
##   2. also loads the reference CSV shipped in uploads/dsi/run/... (if present),
##   3. runs run_dsi_workflow(method = "legacy") from R/ with the same settings,
##   4. joins on (group_key, start_year, end_year) and reports matches.
## Exit status is non-zero if any case fails, so it can be used in CI.

suppressMessages({ library(dplyr); library(readr) })

repo <- normalizePath(".")
stopifnot(file.exists(file.path(repo, "R", "dsicore_workflow.R")))
for (f in sort(list.files(file.path(repo, "R"), pattern = "^dsicore_.*[.]R$", full.names = TRUE))) source(f)

src_dir  <- file.path(repo, "uploads", "dsi", "src")
data_dir <- file.path(repo, "uploads", "dsi", "data")
ref_dir  <- file.path(repo, "uploads", "dsi", "run", "01_DSI_screening")
out_dir  <- file.path(repo, "parity")
dir.create(out_dir, showWarnings = FALSE)

run_original <- function(script, data_file, out_csv) {
  tmp <- tempfile("dsi_orig_")
  dir.create(file.path(tmp, "run", "R"), recursive = TRUE)
  dir.create(file.path(tmp, "Data"))
  file.copy(file.path(src_dir, script), file.path(tmp, "run"))
  file.copy(file.path(src_dir, "R", "functions_dsi.R"), file.path(tmp, "run", "R"))
  file.copy(file.path(data_dir, data_file), file.path(tmp, "Data"))
  log <- file.path(tmp, "run.log")
  old <- setwd(file.path(tmp, "run")); on.exit(setwd(old), add = TRUE)
  status <- system2(file.path(R.home("bin"), "Rscript"), script, stdout = log, stderr = log)
  if (status != 0) stop("original script failed: ", script, "\n", paste(tail(readLines(log), 20), collapse = "\n"))
  read.csv(file.path(tmp, "run", "outputs", out_csv), stringsAsFactors = FALSE)
}

compare <- function(label, orig, new, tol = 1e-8) {
  if (!"group_key" %in% names(orig) && "species" %in% names(orig)) orig$group_key <- orig$species
  if (!"p_value" %in% names(orig) && "p" %in% names(orig)) orig$p_value <- orig$p
  orig$group_key <- as.character(orig$group_key)
  if (!"group_key" %in% names(orig)) stop("no group_key in original output")
  o <- orig %>% select(group_key, start_year, end_year, valid, beta, p_value, dsi, dsi_v2)
  n <- new  %>% select(group_key, start_year, end_year, valid, beta, p_value, dsi, dsi_v2)
  m <- full_join(o, n, by = c("group_key", "start_year", "end_year"), suffix = c("_orig", "_new"))
  both <- m %>% filter(!is.na(valid_orig), !is.na(valid_new))
  d <- function(a, b) ifelse(is.na(a) & is.na(b), 0, abs(a - b))
  both <- both %>% mutate(
    d_beta = d(beta_orig, beta_new), d_p = d(p_value_orig, p_value_new),
    d_dsi = d(dsi_orig, dsi_new), d_dsi_v2 = d(dsi_v2_orig, dsi_v2_new),
    match = valid_orig == valid_new & d_beta <= tol & d_p <= tol & d_dsi <= tol & d_dsi_v2 <= tol)
  both$match[is.na(both$match)] <- FALSE
  mx <- function(x) if (all(is.na(x))) NA else max(x, na.rm = TRUE)
  res <- list(label = label, n_orig = nrow(o), n_new = nrow(n), n_joined = nrow(both),
              only_orig = sum(is.na(m$valid_new)), only_new = sum(is.na(m$valid_orig)),
              n_match = sum(both$match), max_d_dsi = mx(both$d_dsi), max_d_dsi_v2 = mx(both$d_dsi_v2),
              max_d_beta = mx(both$d_beta), max_d_p = mx(both$d_p))
  res$pass <- res$n_orig == res$n_new && res$only_orig == 0 && res$only_new == 0 && res$n_match == res$n_orig
  cat(sprintf("%-44s orig=%d app=%d matched=%d/%d  max|d| DSI=%.3g DSI_v2=%.3g beta=%.3g p=%.3g  %s\n",
              label, res$n_orig, res$n_new, res$n_match, res$n_orig, res$max_d_dsi, res$max_d_dsi_v2,
              res$max_d_beta, res$max_d_p, if (res$pass) "PASS" else "FAIL"))
  write_csv(both, file.path(out_dir, paste0("parity_", gsub("[^A-Za-z0-9]+", "_", label), ".csv")))
  res
}

cases <- list(
  list(name = "main_groups", script = "run_dsi_main.R", data = "Thai_main_groups.csv",
       out = "dsi_all_windows.csv", ref = file.path(ref_dir, "outputs_main", "dsi_all_windows.csv"),
       col_map = list(year = "year", species = "group", catch = "yield", effort = "effort", cpue = "cpue"),
       group_cols = "species", min_n = 8, max_n = 55),
  list(name = "species_x_fleet", script = "run_dsi_species_fleet.R", data = "all_species_combined.csv",
       out = "dsi_all_windows_fleet_species.csv",
       ref = file.path(ref_dir, "outputs_species_fleet", "dsi_all_windows__all_species.csv"),
       col_map = list(year = "year", species = "species", fleet = "gear", catch = "catch", effort = "effort", cpue = "cpue"),
       group_cols = c("species", "fleet"), min_n = 8, max_n = 20)
)

results <- list()
cat("========== LEGACY PARITY CHECK ==========\n")
for (cs in cases) {
  df <- read_csv(file.path(data_dir, cs$data), show_col_types = FALSE)
  app <- run_dsi_workflow(df = df, col_map = cs$col_map, group_cols = cs$group_cols,
                          min_n = cs$min_n, max_n = cs$max_n, anchor_mode = "last_year",
                          method = "legacy")$dsi_all
  orig_live <- run_original(cs$script, cs$data, cs$out)
  results[[length(results) + 1]] <- compare(paste0(cs$name, ": live original vs app legacy"), orig_live, app)
  if (file.exists(cs$ref)) {
    ref <- read.csv(cs$ref, stringsAsFactors = FALSE)
    results[[length(results) + 1]] <- compare(paste0(cs$name, ": shipped reference CSV vs app"), ref, app)
  }
}
summ <- bind_rows(lapply(results, as.data.frame))
write_csv(summ, file.path(out_dir, "parity_summary.csv"))
ok <- all(summ$pass)
cat(if (ok) "\nPARITY VERIFIED: all cases match to < 1e-8\n" else "\nPARITY FAILED\n")
quit(status = if (ok) 0 else 1)

## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Legacy Parity Check (using existing outputs) ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

.libPaths(c("~/R/library", .libPaths()))
library(dplyr)
library(readr)

cat("========== LEGACY PARITY CHECK ==========\n\n")

cat("Using pre-generated outputs from original scripts\n")
cat("Loading original outputs from uploads/dsi/run/01_DSI_screening/outputs_main/\n\n")

df_original <- read_csv("uploads/dsi/run/01_DSI_screening/outputs_main/dsi_all_windows.csv", 
                       show_col_types = FALSE)

cat(sprintf("Original outputs: %d windows\n", nrow(df_original)))
cat(sprintf("Original valid: %d windows\n", sum(df_original$valid, na.rm = TRUE)))

cat("\nRunning new legacy implementation...\n")

setwd(".")
source("R/dsicore_utils.R")
source("R/dsicore_data.R")
source("R/dsicore_windows.R")
source("R/dsicore_metrics.R")
source("R/dsicore_scoring.R")
source("R/dsicore_selection.R")
source("R/dsicore_workflow.R")

df_main <- read_csv("inst/demo_data/Thai_main_groups.csv", show_col_types = FALSE)

col_map <- list(
  year = "year",
  species = "group",
  catch = "yield",
  effort = "effort",
  cpue = "cpue"
)

results_new <- run_dsi_workflow(
  df = df_main,
  col_map = col_map,
  group_cols = "species",
  min_n = 8,
  max_n = 55,
  anchor_mode = "last_year",
  method = "legacy",
  effort_semantics = "per_fleet_year"
)

df_new <- results_new$dsi_all

cat(sprintf("New implementation: %d windows\n", nrow(df_new)))
cat(sprintf("New valid: %d windows\n", sum(df_new$valid, na.rm = TRUE)))

write_csv(df_new, "parity_check_new_legacy.csv")

cat("\nComparing results...\n")

df_orig_comp <- df_original %>%
  select(species, start_year, end_year, valid, beta, p, dsi, dsi_v2) %>%
  rename(group_key = species, p_value = p) %>%
  arrange(group_key, start_year, end_year)

df_new_comp <- df_new %>%
  select(group_key, start_year, end_year, valid, beta, p_value, dsi, dsi_v2) %>%
  arrange(group_key, start_year, end_year)

comparison <- df_orig_comp %>%
  inner_join(df_new_comp, by = c("group_key", "start_year", "end_year"), 
           suffix = c("_orig", "_new"))

comparison <- comparison %>%
  mutate(
    diff_beta = abs(beta_orig - beta_new),
    diff_p_value = abs(p_value_orig - p_value_new),
    diff_dsi = abs(dsi_orig - dsi_new),
    diff_dsi_v2 = abs(dsi_v2_orig - dsi_v2_new)
  )

valid_comparison <- comparison %>%
  filter(valid_orig == TRUE & valid_new == TRUE)

cat("\n========== COMPARISON RESULTS ==========\n\n")

cat(sprintf("Total windows compared: %d\n", nrow(comparison)))
cat(sprintf("Valid in both: %d\n", nrow(valid_comparison)))

if (nrow(valid_comparison) > 0) {
  cat("\nMaximum absolute differences:\n")
  cat(sprintf("  Beta:     %.10e\n", max(valid_comparison$diff_beta, na.rm = TRUE)))
  cat(sprintf("  P-value:  %.10e\n", max(valid_comparison$diff_p_value, na.rm = TRUE)))
  cat(sprintf("  DSI:      %.10e\n", max(valid_comparison$diff_dsi, na.rm = TRUE)))
  cat(sprintf("  DSI_v2:   %.10e\n", max(valid_comparison$diff_dsi_v2, na.rm = TRUE)))
  
  cat("\nMean absolute differences:\n")
  cat(sprintf("  Beta:     %.10e\n", mean(valid_comparison$diff_beta, na.rm = TRUE)))
  cat(sprintf("  P-value:  %.10e\n", mean(valid_comparison$diff_p_value, na.rm = TRUE)))
  cat(sprintf("  DSI:      %.10e\n", mean(valid_comparison$diff_dsi, na.rm = TRUE)))
  cat(sprintf("  DSI_v2:   %.10e\n", mean(valid_comparison$diff_dsi_v2, na.rm = TRUE)))
  
  mismatches <- valid_comparison %>%
    filter(diff_dsi > 0.01 | diff_dsi_v2 > 0.01)
  
  cat(sprintf("\nWindows with DSI or DSI_v2 difference > 0.01: %d\n", nrow(mismatches)))
  
  if (nrow(mismatches) > 0) {
    cat("\nTop 10 largest mismatches:\n")
    top_mismatches <- head(mismatches %>% 
                  arrange(desc(pmax(diff_dsi, diff_dsi_v2))) %>%
                  select(group_key, start_year, end_year, 
                        dsi_orig, dsi_new, diff_dsi,
                        dsi_v2_orig, dsi_v2_new, diff_dsi_v2), 10)
    print(top_mismatches)
  }
  
  perfect_matches <- sum(valid_comparison$diff_beta < 1e-10 & 
                        valid_comparison$diff_p_value < 1e-10 &
                        valid_comparison$diff_dsi < 1e-10 &
                        valid_comparison$diff_dsi_v2 < 1e-10,
                        na.rm = TRUE)
  
  cat(sprintf("\nPerfect matches (all diffs < 1e-10): %d / %d (%.1f%%)\n",
             perfect_matches, nrow(valid_comparison),
             100 * perfect_matches / nrow(valid_comparison)))
}

write_csv(comparison, "parity_check_comparison.csv")

cat("\n========== PARITY CHECK COMPLETE ==========\n")
cat("Results saved to:\n")
cat("  - parity_check_new_legacy.csv (new implementation)\n")
cat("  - parity_check_comparison.csv (detailed comparison)\n\n")

if (nrow(valid_comparison) > 0 && 
    max(valid_comparison$diff_dsi, na.rm = TRUE) < 0.01 &&
    max(valid_comparison$diff_dsi_v2, na.rm = TRUE) < 0.01) {
  cat("✓ PARITY VERIFIED: Legacy implementation matches original within tolerance\n")
} else {
  cat("✗ PARITY FAILED: Significant differences detected\n")
}

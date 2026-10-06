## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Legacy Parity Check ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

.libPaths(c("~/R/library", .libPaths()))
library(dplyr)
library(readr)

cat("========== LEGACY PARITY CHECK ==========\n\n")

cat("Step 1: Running original scripts...\n")

setwd("/workspace/uploads/dsi/src")
source("R/functions_dsi.R")

df_main <- read_csv("../data/Thai_main_groups.csv", show_col_types = FALSE)

col_map <- list(
  year = "year",
  species = "group",
  catch = "yield",
  effort = "effort",
  cpue = "cpue"
)

df_std <- standardize_columns(df_main, col_map)
df_std <- effort_by_fleet_year(df_std)
df_std$group_key <- make_group_key(df_std, "species")

groups <- unique(df_std$group_key)
refs <- default_dsi_refs()

all_windows_original <- list()

for (grp in groups) {
  grp_data <- df_std[df_std$group_key == grp, ]
  years <- grp_data$year
  
  windows <- generate_windows(years, min_n = 8, max_n = 55)
  
  for (i in seq_len(nrow(windows))) {
    win_row <- windows[i, ]
    
    metrics <- compute_window_metrics(
      grp_data,
      win_row$start_year,
      win_row$end_year,
      min_n = 8,
      min_usable = 6,
      refs = refs
    )
    
    metrics$group_key <- grp
    
    if (metrics$valid) {
      v2_metrics <- compute_window_v2_metrics(
        grp_data,
        win_row$start_year,
        win_row$end_year
      )
      
      metrics$dsi_base <- compute_dsi_base(metrics)
      metrics$dsi <- compute_dsi(metrics)
      
      dsi_v2 <- compute_dsi_v2_robust(
        metrics$dsi_base,
        metrics$p_miss,
        metrics$p_out,
        v2_metrics
      )
      
      metrics <- c(metrics, v2_metrics)
      metrics$dsi_v2 <- dsi_v2
    } else {
      metrics$dsi_base <- NA
      metrics$dsi <- NA
      metrics$dsi_v2 <- NA
    }
    
    all_windows_original[[length(all_windows_original) + 1]] <- metrics
  }
}

df_original <- bind_rows(lapply(all_windows_original, as.data.frame))

cat(sprintf("Original: %d windows\n", nrow(df_original)))
cat(sprintf("Original valid: %d windows\n", sum(df_original$valid, na.rm = TRUE)))

write_csv(df_original, "/workspace/parity_check_original.csv")

cat("\nStep 2: Running new legacy implementation...\n")

setwd("/workspace")
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

cat(sprintf("New: %d windows\n", nrow(df_new)))
cat(sprintf("New valid: %d windows\n", sum(df_new$valid, na.rm = TRUE)))

write_csv(df_new, "/workspace/parity_check_new.csv")

cat("\nStep 3: Comparing results...\n")

df_orig_comp <- df_original %>%
  select(group_key, start_year, end_year, valid, beta, p_value, dsi, dsi_v2) %>%
  arrange(group_key, start_year, end_year)

df_new_comp <- df_new %>%
  select(group_key, start_year, end_year, valid, beta, p_value, dsi, dsi_v2) %>%
  arrange(group_key, start_year, end_year)

comparison <- df_orig_comp %>%
  left_join(df_new_comp, by = c("group_key", "start_year", "end_year"), 
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

cat(sprintf("Total windows: %d\n", nrow(comparison)))
cat(sprintf("Valid in both: %d\n", nrow(valid_comparison)))

cat("\nMaximum absolute differences:\n")
cat(sprintf("  Beta:     %.10f\n", max(valid_comparison$diff_beta, na.rm = TRUE)))
cat(sprintf("  P-value:  %.10f\n", max(valid_comparison$diff_p_value, na.rm = TRUE)))
cat(sprintf("  DSI:      %.10f\n", max(valid_comparison$diff_dsi, na.rm = TRUE)))
cat(sprintf("  DSI_v2:   %.10f\n", max(valid_comparison$diff_dsi_v2, na.rm = TRUE)))

cat("\nMean absolute differences:\n")
cat(sprintf("  Beta:     %.10f\n", mean(valid_comparison$diff_beta, na.rm = TRUE)))
cat(sprintf("  P-value:  %.10f\n", mean(valid_comparison$diff_p_value, na.rm = TRUE)))
cat(sprintf("  DSI:      %.10f\n", mean(valid_comparison$diff_dsi, na.rm = TRUE)))
cat(sprintf("  DSI_v2:   %.10f\n", mean(valid_comparison$diff_dsi_v2, na.rm = TRUE)))

mismatches <- valid_comparison %>%
  filter(diff_dsi > 0.01 | diff_dsi_v2 > 0.01)

cat(sprintf("\nWindows with DSI difference > 0.01: %d\n", nrow(mismatches)))

if (nrow(mismatches) > 0) {
  cat("\nTop 10 mismatches:\n")
  print(head(mismatches %>% 
              arrange(desc(diff_dsi_v2)) %>%
              select(group_key, start_year, end_year, dsi_orig, dsi_new, 
                    diff_dsi, dsi_v2_orig, dsi_v2_new, diff_dsi_v2), 10))
}

write_csv(comparison, "/workspace/parity_check_comparison.csv")

cat("\n========== PARITY CHECK COMPLETE ==========\n")
cat("Results saved to:\n")
cat("  - parity_check_original.csv\n")
cat("  - parity_check_new.csv\n")
cat("  - parity_check_comparison.csv\n")

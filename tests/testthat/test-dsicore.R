## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ DSI Core Tests ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

library(testthat)

test_that("clamp01 works correctly", {
  expect_equal(clamp01(c(-1, 0, 0.5, 1, 2)), c(0, 0, 0.5, 1, 1))
  expect_equal(clamp01(NA), NA_real_)
})

test_that("safe_log_cpue handles invalid values", {
  cpue <- c(10, 0, -5, NA, Inf, 5)
  result <- safe_log_cpue(cpue)
  
  expect_equal(length(result$log_cpue), 6)
  expect_equal(result$n_invalid, 4)
  expect_true(is.finite(result$log_cpue[1]))
  expect_true(is.na(result$log_cpue[2]))
})

test_that("standardize_columns maps correctly", {
  df <- data.frame(
    yr = 2000:2005,
    sp = "TestSpecies",
    c = 100:105,
    e = 50:55,
    u = 2
  )
  
  col_map <- list(
    year = "yr",
    species = "sp",
    catch = "c",
    effort = "e",
    cpue = "u"
  )
  
  df_std <- standardize_columns(df, col_map)
  
  expect_equal(names(df_std), c("year", "species", "fleet", "catch", "effort", "cpue"))
  expect_equal(df_std$year, 2000:2005)
  expect_equal(df_std$species, rep("TestSpecies", 6))
  expect_equal(df_std$fleet, rep("ALL_FLEET", 6))
})

test_that("window generation legacy vs corrected differ", {
  years <- 2010:2025
  usable_years <- 2010:2020
  
  windows_legacy <- generate_windows_legacy(years, min_n = 8, max_n = 15)
  
  windows_corrected <- generate_windows_corrected(
    years, 
    min_n = 8, 
    max_n = 15,
    anchor_mode = "last_usable_year",
    usable_years = usable_years
  )
  
  expect_true(all(windows_legacy$end_year == 2025))
  
  expect_true(all(windows_corrected$end_year == 2020))
})

test_that("DSI weights sum correctly", {
  weights_legacy <- default_dsi_weights(legacy = TRUE)
  weights_corrected <- default_dsi_weights(legacy = FALSE)
  
  sum_legacy <- with(weights_legacy, w_slope + w_e + w_i + w_n + w_ce)
  sum_corrected <- with(weights_corrected, w_slope + w_e + w_i + w_n + w_ce)
  
  expect_equal(sum_legacy, 0.95)
  
  expect_equal(sum_corrected, 1.0)
})

test_that("effort harmonization differs between methods", {
  df <- data.frame(
    year = rep(2020:2022, each = 2),
    species = rep(c("A", "B"), 3),
    fleet = "F1",
    catch = 100,
    effort = c(10, 20, 10, 20, 10, 20),
    cpue = 1
  )
  
  df_corrected <- harmonize_effort_corrected(df, "per_group_year", c("species", "fleet"))
  
  df_legacy <- harmonize_effort_legacy(df)
  
  expect_true("effort_conflicts" %in% names(df_corrected))
  expect_true("effort_conflicts" %in% names(df_legacy))
})

test_that("compute_window_metrics handles valid window", {
  df <- data.frame(
    year = 2010:2020,
    species = "TestSp",
    fleet = "TestFleet",
    catch = seq(100, 200, length.out = 11),
    effort = seq(50, 150, length.out = 11),
    cpue = seq(100, 200, length.out = 11) / seq(50, 150, length.out = 11)
  )
  
  metrics <- compute_window_metrics_corrected(df, 2010, 2020)
  
  expect_true(metrics$valid)
  expect_equal(metrics$start_year, 2010)
  expect_equal(metrics$end_year, 2020)
  expect_equal(metrics$n_usable, 11)
  expect_true(is.finite(metrics$beta))
  
  dsi <- compute_dsi(metrics)
  expect_true(is.finite(dsi))
})

test_that("DSI band assignment is correct", {
  band_poor <- get_dsi_band(40)
  band_moderate <- get_dsi_band(60)
  band_good <- get_dsi_band(80)
  band_invalid <- get_dsi_band(NA)
  
  expect_equal(band_poor$label, "Poor")
  expect_equal(band_moderate$label, "Moderate")
  expect_equal(band_good$label, "Good")
  expect_equal(band_invalid$label, "Invalid")
})

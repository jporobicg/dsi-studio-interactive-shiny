## Tests for the audit, effort, method-flag, robustness and formatting features.

demo <- function(name = "Thai_main_groups.csv") {
  read.csv(file.path(dsi_repo_root, "inst", "demo_data", name), stringsAsFactors = FALSE)
}
thai_map <- list(year = "year", species = "group", catch = "yield", effort = "effort", cpue = "cpue")
thai_std <- function() {
  d <- standardize_columns(demo(), thai_map)
  d$group_key <- make_group_key(d, "species")
  d
}

test_that("check_cpue_scale: constant x1000 scale is info, not a warning", {
  d <- thai_std()
  r <- check_cpue_scale(d, "species")
  expect_equal(r$finding_name, "cpue_unit_scale")
  expect_equal(r$finding$severity, "info")
  expect_equal(r$scale, 1000)
})

test_that("check_cpue_scale: exact catch/effort gives no finding", {
  d <- thai_std(); d$cpue <- d$catch / d$effort
  expect_null(check_cpue_scale(d, "species")$finding)
})

test_that("check_cpue_scale: real mismatch within a group is a warning", {
  d <- thai_std(); set.seed(3)
  d$cpue <- d$catch / d$effort * exp(rnorm(nrow(d), 0, 0.3))
  r <- check_cpue_scale(d, "species")
  expect_equal(r$finding_name, "cpue_not_catch_over_effort")
  expect_equal(r$finding$severity, "warning")
})

test_that("audit_data no longer warns about the Thai x1000 CPUE", {
  a <- audit_data(thai_std(), "species")
  sev <- vapply(a, function(x) x$severity, "")
  expect_false(any(sev == "warning"))
  expect_true("cpue_unit_scale" %in% names(a))
})

test_that("effort semantics change the effort used when effort differs between groups", {
  d <- thai_std(); d$fleet <- "ALL"
  imp <- effort_semantics_impact(d, "species")
  expect_equal(imp$rows_changed[imp$option == "per_row"], 0)
  expect_equal(imp$rows_changed[imp$option == "per_group_year"], 0)
  expect_gt(imp$rows_changed[imp$option == "per_fleet_year"], 0)
})

test_that("effort semantics change DSI results through run_dsi_workflow", {
  a <- run_dsi_workflow(demo(), thai_map, group_cols = "species", method = "corrected",
                        min_n = 8, max_n = 20, effort_semantics = "per_group_year")
  b <- run_dsi_workflow(demo(), thai_map, group_cols = "species", method = "corrected",
                        min_n = 8, max_n = 20, effort_semantics = "per_fleet_year")
  m <- merge(a$dsi_all, b$dsi_all, by = c("group_key", "start_year", "end_year"))
  expect_gt(sum(abs(m$dsi_v2.x - m$dsi_v2.y) > 1e-6, na.rm = TRUE), 0)
})

test_that("fix flags: legacy all off, corrected all on, overrides apply", {
  cat <- dsi_fix_catalog()
  expect_true(all(!unlist(dsi_fix_flags("legacy"))))
  expect_true(all(unlist(dsi_fix_flags("corrected"))))
  expect_setequal(names(dsi_fix_flags("corrected")), cat$id)
  f <- dsi_fix_flags("corrected", effort_harmonisation = FALSE)
  expect_false(f$effort_harmonisation)
})

test_that("rescore_with_weights reproduces DSI with default weights and changes with others", {
  r <- run_dsi_workflow(demo(), thai_map, group_cols = "species", method = "corrected", min_n = 8, max_n = 20)
  same <- rescore_with_weights(r$dsi_all, default_dsi_weights())
  expect_equal(same$dsi_v2, r$dsi_all$dsi_v2, tolerance = 1e-8)
  w <- default_dsi_weights(); w[] <- 1 / length(w)
  diff <- rescore_with_weights(r$dsi_all, w)
  expect_gt(max(abs(diff$dsi_v2 - r$dsi_all$dsi_v2), na.rm = TRUE), 0.1)
})

test_that("advanced refs change scores (n_full_score)", {
  a <- run_dsi_workflow(demo(), thai_map, group_cols = "species", method = "corrected", min_n = 8, max_n = 20)
  b <- run_dsi_workflow(demo(), thai_map, group_cols = "species", method = "corrected", min_n = 8, max_n = 20,
                        refs = list(n_full_score = 12))
  expect_false(isTRUE(all.equal(a$dsi_all$dsi_v2, b$dsi_all$dsi_v2)))
})

test_that("dsi_null_test is reproducible and returns a valid p-value", {
  d <- run_dsi_workflow(demo(), thai_map, group_cols = "species", method = "corrected", min_n = 8, max_n = 20)$data_std
  g <- d[d$group_key == "Pelagic", ]
  r1 <- dsi_null_test(g, 2009, 2024, n_sim = 39, seed = 11)
  r2 <- dsi_null_test(g, 2009, 2024, n_sim = 39, seed = 11)
  expect_equal(r1$null_dsi_v2, r2$null_dsi_v2)
  expect_true(r1$p_value > 0 && r1$p_value <= 1)
  expect_equal(length(r1$null_dsi_v2), 39)
  r3 <- dsi_null_test(g, 2009, 2024, n_sim = 19, mode = "lognormal", seed = 2)
  expect_true(is.finite(r3$null_median))
})

test_that("dsi_compare_methods attributes differences to fixes", {
  cmp <- dsi_compare_methods(demo(), thai_map, "species", min_n = 8, max_n = 20)
  expect_true(all(c("legacy", "corrected", "windows", "groups", "attribution", "per_fix_windows") %in% names(cmp)))
  expect_setequal(cmp$attribution$id, dsi_fix_catalog()$id)
  eff <- cmp$attribution[cmp$attribution$id == "effort_harmonisation", ]
  expect_gt(eff$windows_changed, 0)
})

test_that("format_beta uses readable scientific notation", {
  suppressMessages({ library(shiny); library(bslib) })
  sys.source(file.path(dsi_repo_root, "R", "app_theme.R"), envir = environment())
  expect_equal(format_beta(-2.17e-5), "\u22122.17 \u00d7 10\u207b\u2075")
  expect_equal(format_beta(0.0123), "0.0123")
  expect_equal(format_beta(NA), "\u2014")
})

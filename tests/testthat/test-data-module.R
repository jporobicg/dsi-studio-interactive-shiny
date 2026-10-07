## Server-side tests of the data step: detection and automatic mapping.

new_state <- function() shiny::reactiveValues(
  data_raw = NULL, data_std = NULL, col_map = NULL, group_cols = NULL, dataset_name = NULL,
  effort_semantics = "per_group_year", effort_detect = NULL, audit = NULL, dsi_results = NULL,
  screen_settings = NULL, current_group = NULL, current_window = NULL, overrides = list(),
  decisions = list(), null_tests = list(), comparison = NULL, steps_completed = character(0))

test_that("loading the example data maps columns and detects effort level automatically", {
  st <- new_state()
  shiny::testServer(mod_data_input_server, args = list(app_state = st), {
    session$setInputs(load_demo_fleet = 1)
    expect_equal(st$col_map, list(year = "year", species = "species", fleet = "gear",
                                  catch = "catch", effort = "effort", cpue = "cpue"))
    expect_equal(st$group_cols, c("species", "fleet"))
    expect_equal(st$effort_semantics, "per_fleet_year")
    expect_true("data" %in% st$steps_completed)
    session$setInputs(load_demo_main = 1)
    expect_equal(st$col_map$catch, "yield")
    expect_equal(st$effort_semantics, "per_group_year")
    expect_equal(nrow(st$data_std), 153)
  })
})

test_that("a wide CSV upload is reshaped and applied; mapping edits re-apply", {
  st <- new_state()
  f <- tempfile(fileext = ".csv")
  write.csv(data.frame(Year = 2001:2015, `Effort (days)` = 100 + 1:15, Anchovy = 1:15 * 3, Pelagic = 15:1 * 2,
                       check.names = FALSE), f, row.names = FALSE)
  shiny::testServer(mod_data_input_server, args = list(app_state = st), {
    session$setInputs(file_upload = data.frame(name = "wide.csv", size = file.size(f), type = "text/csv", datapath = f))
    expect_equal(nrow(st$data_raw), 30)
    expect_equal(st$col_map$species, "group")
    expect_equal(st$effort_semantics, "per_fleet_year")
    ep <- src$epoch
    vals <- c(year = "year", species = "group", fleet = "", catch = "catch", effort = "effort", cpue = "")
    do.call(session$setInputs, stats::setNames(as.list(vals), paste0("map_", names(vals), "_", ep)))
    session$elapse(500)
    expect_equal(st$col_map$species, "group")
    vals["species"] <- ""
    do.call(session$setInputs, stats::setNames(as.list(vals), paste0("map_", names(vals), "_", ep)))
    session$elapse(500)
    expect_null(st$group_cols)
    expect_equal(st$col_map, list(year = "year", catch = "catch", effort = "effort"))
  })
})

test_that("an uncertain mapping is not applied until the user applies it", {
  st <- new_state()
  f <- tempfile(fileext = ".csv")
  write.csv(data.frame(Year = 2001:2015, Anchovy = 1:15, Pelagic = 15:1), f, row.names = FALSE)
  shiny::testServer(mod_data_input_server, args = list(app_state = st), {
    session$setInputs(file_upload = data.frame(name = "catch_only.csv", size = 1, type = "text/csv", datapath = f))
    expect_null(st$data_std)
    expect_true(src$info$needs_input)
  })
})

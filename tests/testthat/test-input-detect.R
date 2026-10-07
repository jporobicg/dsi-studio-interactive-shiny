## Tests for column matching, layout detection, wide reshaping and effort
## level detection used when data are loaded.

fixture <- function(name) test_path("fixtures", name)
std_of <- function(df) {
  m <- guess_column_mapping(df)
  list(std = standardize_columns(df, m), grp = intersect(c("species", "fleet"), names(m)), map = m)
}

## ---- names ----

test_that("normalize_column_name drops units, accents, punctuation and suffixes", {
  expect_equal(normalize_column_name(c("Catch (t)", "catch_t", "Yield_tonnes", "gear_code", "sp_code",
                                       "CPUE [kg/day]", "Days fished", "A\u00f1o", "Ann\u00e9e", "Species_ID", "  Effort.KG ")),
               c("catch", "catch", "yield", "gear", "sp", "cpue", "days_fished", "ano", "annee", "species", "effort"))
  expect_equal(normalize_column_name("t"), "t")
})

test_that("match_columns finds roles from synonyms in several languages", {
  m <- match_columns(c("Year", "Gear_code", "Species", "Landings (t)", "Days fished", "CPUE"))
  expect_equal(m$map, list(year = "Year", species = "Species", fleet = "Gear_code", catch = "Landings (t)",
                           effort = "Days fished", cpue = "CPUE"))
  expect_true(m$confident)
  es <- match_columns(c("A\u00f1o", "arte", "especie", "captura", "esfuerzo"))$map
  expect_equal(unname(unlist(es[c("year", "fleet", "species", "catch", "effort")])),
               c("A\u00f1o", "arte", "especie", "captura", "esfuerzo"))
  fr <- match_columns(c("annee", "metier", "taxon", "captures", "trips"))$map
  expect_equal(fr$year, "annee"); expect_equal(fr$fleet, "metier"); expect_equal(fr$species, "taxon")
  expect_equal(fr$catch, "captures"); expect_equal(fr$effort, "trips")
  cases <- list(c("yr", "year"), c("season", "year"), c("catch_t", "catch"), c("Catch (t)", "catch"),
                c("yield", "catch"), c("fishing_days", "effort"), c("hours", "effort"), c("hooks", "effort"),
                c("catch_rate", "cpue"), c("index", "cpue"), c("stock", "species"), c("group", "species"),
                c("fleet", "fleet"), c("total_landings_kg", "catch"), c("effort_hours", "effort"))
  for (cc in cases) expect_equal(names(match_columns(cc[1])$map), cc[2], info = cc[1])
})

test_that("match_columns avoids false matches", {
  m <- match_columns(c("year", "cpue", "effort"))$map
  expect_null(m$catch); expect_equal(m$cpue, "cpue")
  m <- match_columns(c("year", "catch_kg_per_day", "effort"))$map
  expect_null(m$catch); expect_equal(m$cpue, "catch_kg_per_day")
  m <- match_columns(c("year", "catch_per_unit_effort", "landings", "effort"))$map
  expect_equal(m$catch, "landings"); expect_equal(m$cpue, "catch_per_unit_effort")
  expect_length(match_columns(c("vessel_name", "port", "price"))$map, 0)
  ## two candidates for one role are flagged
  m <- match_columns(c("year", "catch", "landings", "effort"))
  expect_equal(m$map$catch, "catch")
  expect_equal(m$alternatives$catch, "landings")
  expect_false(m$confident)
})

test_that("match_columns uses the data: numbers for numeric roles, years for year", {
  df <- data.frame(when = 2001:2010, catch = c("a", "b"), tonnes = 1:10, effort = 1:10, stringsAsFactors = FALSE)
  m <- match_columns(df)
  expect_null(m$map$catch)
  expect_equal(m$map$year, "when"); expect_equal(m$confidence[["year"]], "data")
  expect_false(m$confident)
  df2 <- data.frame(year = 1:10, catch = 1:10, effort = 1:10)
  expect_null(match_columns(df2)$map$year)
})

test_that("guess_column_mapping maps both example datasets", {
  expect_equal(guess_column_mapping(dsi_demo_data("Thai_main_groups.csv")),
               list(year = "year", species = "group", catch = "yield", effort = "effort", cpue = "cpue"))
  expect_equal(guess_column_mapping(dsi_demo_data("all_species_combined.csv")),
               list(year = "year", species = "species", fleet = "gear", catch = "catch", effort = "effort", cpue = "cpue"))
  expect_true(match_columns(dsi_demo_data("all_species_combined.csv"))$confident)
})

## ---- effort level ----

test_that("detect_effort_level: Thai groups keep their own effort", {
  s <- std_of(dsi_demo_data("Thai_main_groups.csv"))
  d <- detect_effort_level(s$std, s$grp, list(species = "group"))
  expect_equal(d$semantics, "per_group_year")
  expect_equal(d$n_cells, 52); expect_equal(d$n_const, 0)
  expect_match(d$message, "differs between groups in every year")
})

test_that("detect_effort_level: species x fleet effort is a fleet quantity", {
  s <- std_of(dsi_demo_data("all_species_combined.csv"))
  d <- detect_effort_level(s$std, s$grp, list(species = "species", fleet = "gear"))
  expect_equal(d$semantics, "per_fleet_year"); expect_equal(d$level, "fleet_year")
  expect_equal(c(d$n_cells, d$n_const), c(271, 271))
  expect_equal(d$n_missing, 29); expect_equal(d$n_unfilled, 29); expect_equal(d$n_filled, 0)
  expect_false(d$mixed)
  expect_match(d$message, "identical for all species in each gear-year")
})

synthetic <- function(n_years = 20, shared = TRUE, n_differ = 0, fleet = TRUE, na_rows = 0) {
  g <- expand.grid(year = 2000 + seq_len(n_years), species = c("A", "B", "C"), stringsAsFactors = FALSE)
  g$fleet <- if (fleet) "F1" else "ALL_FLEET"
  g$catch <- 10 + seq_len(nrow(g))
  base <- 100 + g$year - 2000
  g$effort <- if (shared) base else base * match(g$species, c("A", "B", "C"))
  if (n_differ > 0) { yrs <- unique(g$year)[seq_len(n_differ)]; ix <- g$year %in% yrs & g$species == "B"; g$effort[ix] <- g$effort[ix] + 7 }
  if (na_rows > 0) g$effort[which(g$species == "C")[seq_len(na_rows)]] <- NA
  g$cpue <- g$catch / g$effort
  g
}

test_that("detect_effort_level: synthetic cases", {
  d <- detect_effort_level(synthetic(), c("species", "fleet"))
  expect_equal(d$semantics, "per_fleet_year")
  d <- detect_effort_level(synthetic(fleet = FALSE), "species")
  expect_equal(d$semantics, "per_fleet_year"); expect_equal(d$level, "year")
  expect_match(d$message, "one shared effort per year")
  ## tiny float noise counts as equal
  s <- synthetic(); s$effort <- s$effort * (1 + 1e-10 * match(s$species, c("A", "B", "C")))
  expect_equal(detect_effort_level(s, c("species", "fleet"))$n_const, 20)
  ## 1 of 20 fleet-years differ: still shared (95%), flagged as mixed
  d <- detect_effort_level(synthetic(n_differ = 1), c("species", "fleet"))
  expect_equal(d$semantics, "per_fleet_year"); expect_true(d$mixed); expect_match(d$message, "19 of 20")
  ## 8 of 20 differ: own effort, flagged
  d <- detect_effort_level(synthetic(n_differ = 8), c("species", "fleet"))
  expect_equal(d$semantics, "per_group_year"); expect_true(d$mixed); expect_match(d$message, "only 12 of 20")
  ## different effort per species
  expect_equal(detect_effort_level(synthetic(shared = FALSE), c("species", "fleet"))$semantics, "per_group_year")
  ## gaps that can be filled from the same fleet-year
  d <- detect_effort_level(synthetic(na_rows = 3), c("species", "fleet"))
  expect_equal(d$n_filled, 3); expect_match(d$message, "3 missing values filled")
  ## single series
  one <- synthetic(); one <- one[one$species == "A", ]
  expect_equal(detect_effort_level(one, character(0))$level, "series")
})

test_that("detected fleet effort fills gaps when used as effort semantics", {
  s <- synthetic(na_rows = 3)
  imp <- effort_semantics_impact(s, c("species", "fleet"))
  expect_equal(imp$rows_filled[imp$option == "per_fleet_year"], 3)
  expect_equal(imp$rows_changed[imp$option == "per_fleet_year"], 0)
})

## ---- layout ----

test_that("detect_data_layout and describe_structure on the example data", {
  th <- dsi_demo_data("Thai_main_groups.csv"); sf <- dsi_demo_data("all_species_combined.csv")
  expect_equal(detect_data_layout(th)$shape, "long")
  expect_equal(detect_data_layout(sf)$shape, "long")
  a <- describe_structure(th, guess_column_mapping(th))
  expect_equal(a$structure, "groups"); expect_equal(a$n_species, 3)
  expect_match(a$text, "3 groups, one series each, 1971")
  b <- describe_structure(sf, guess_column_mapping(sf))
  expect_equal(b$structure, "species_fleet"); expect_equal(c(b$n_species, b$n_fleets), c(8, 6))
  one <- th[th$group == "Pelagic", c("year", "yield", "effort")]
  expect_equal(detect_data_layout(one)$shape, "long")
  expect_equal(describe_structure(one, guess_column_mapping(one))$structure, "single")
})

test_that("a long single series with extra numeric columns is not taken as wide", {
  df <- data.frame(year = 2001:2012, catch = 1:12, effort = 1:12, price = 1:12, vessels = 1:12)
  expect_equal(detect_data_layout(df)$shape, "long")
})

test_that("wide: years as rows, one column per group (single quantity)", {
  df <- data.frame(Year = 1990:2001, Anchovy = 1:12, Demersal = 2:13, Pelagic = 3:14)
  l <- detect_data_layout(df)
  expect_equal(l$shape, "wide_years_rows")
  expect_equal(l$value_cols, c("Anchovy", "Demersal", "Pelagic"))
  expect_false(l$value_role_certain)
  r <- reshape_to_long(df, l)
  expect_equal(dim(r), c(36, 3)); expect_equal(names(r), c("year", "group", "catch"))
  expect_equal(attr(r, "reshape_note"), "Reshaped from wide: 3 groups \u00d7 12 years")
  r2 <- reshape_to_long(df, l, value_role = "effort")
  expect_true("effort" %in% names(r2))
  expect_equal(r$catch[r$group == "Demersal"], 2:13)
})

test_that("wide: years as rows with a shared effort column", {
  df <- data.frame(year = 1990:2001, effort_days = 101:112, Anchovy = 1:12, Pelagic = 3:14)
  l <- detect_data_layout(df)
  expect_equal(l$shape, "wide_years_rows"); expect_true(l$value_role_certain); expect_equal(l$value_role, "catch")
  r <- reshape_to_long(df, l)
  expect_equal(r$effort[r$group == "Pelagic"], 101:112)
  m <- match_columns(r); expect_true(m$confident)
  s <- standardize_columns(r, m$map)
  expect_equal(detect_effort_level(s, "species")$semantics, "per_fleet_year")
})

test_that("wide: years as rows with group + quantity in column names", {
  df <- data.frame(year = 1990:2001, `Anchovy catch (t)` = 1:12, `Anchovy effort` = 21:32,
                   `Pelagic catch (t)` = 3:14, `Pelagic effort` = 41:52, check.names = FALSE)
  l <- detect_data_layout(df)
  expect_equal(l$shape, "wide_years_rows")
  r <- reshape_to_long(df, l)
  expect_setequal(names(r), c("year", "group", "catch", "effort"))
  expect_equal(r$effort[r$group == "Pelagic"], 41:52)
})

test_that("wide: years as columns with a variable column", {
  w <- data.frame(species = rep(c("A", "B"), each = 2), variable = rep(c("Catch (t)", "Effort"), 2))
  for (y in 1990:1999) w[[as.character(y)]] <- c(1, 10, 2, 20) * (y - 1989)
  l <- detect_data_layout(w)
  expect_equal(l$shape, "wide_years_cols"); expect_equal(l$var_col, "variable"); expect_equal(l$group_cols, "species")
  r <- reshape_to_long(w, l)
  expect_equal(nrow(r), 20); expect_setequal(names(r), c("year", "species", "catch", "effort"))
  expect_equal(r$effort[r$species == "B" & r$year == 1995], 120)
  expect_match(attr(r, "reshape_note"), "2 groups \u00d7 10 years")
})

test_that("wide: years as columns without a variable column, X-prefixed names", {
  w <- data.frame(group = c("A", "B", "C"), X2001 = 1:3, X2002 = 4:6, X2003 = 7:9, X2004 = 1:3)
  l <- detect_data_layout(w)
  expect_equal(l$shape, "wide_years_cols"); expect_null(l$var_col); expect_false(l$value_role_certain)
  r <- reshape_to_long(w, l, value_role = "catch")
  expect_equal(sort(unique(r$year)), 2001:2004); expect_equal(r$catch[r$group == "B" & r$year == 2002], 5)
})

## ---- Excel sheets ----

test_that("sheet_roles reads quantities from sheet names", {
  expect_equal(unname(sheet_roles(c("Catch", "Effort (days)", "Notes", "CPUE", "Landings"))),
               c("catch", "effort", NA, "cpue", "catch"))
})

test_that("combine_sheets: wide catch sheet + long effort sheet per group", {
  p <- fixture("catch_effort_sheets.xlsx")
  sh <- readxl::excel_sheets(p)
  roles <- sheet_roles(sh)
  tabs <- list(catch = readxl::read_excel(p, names(roles)[roles %in% "catch"]),
               effort = readxl::read_excel(p, names(roles)[roles %in% "effort"]))
  out <- combine_sheets(tabs, c("Catch", "Effort (days)"))
  expect_equal(nrow(out), 36); expect_setequal(names(out), c("year", "group", "catch", "effort"))
  expect_equal(out$effort[out$group == "Pelagic" & out$year == 1991], 33)
  expect_match(attr(out, "reshape_note"), "'Catch' \\(wide, 3 groups")
  m <- match_columns(out); expect_true(m$confident)
  s <- standardize_columns(out, m$map)
  expect_equal(detect_effort_level(s, "species")$semantics, "per_group_year")
})

test_that("combine_sheets: long landings by species x gear + effort by gear", {
  p <- fixture("species_gear_sheets.xlsx")
  out <- combine_sheets(list(catch = readxl::read_excel(p, "Landings"), effort = readxl::read_excel(p, "Effort")))
  expect_equal(nrow(out), 72)
  m <- match_columns(out); expect_true(m$confident)
  expect_equal(m$map$fleet, "gear")
  s <- standardize_columns(out, m$map)
  d <- detect_effort_level(s, c("species", "fleet"), list(species = "species", fleet = "gear"))
  expect_equal(d$semantics, "per_fleet_year")
  expect_match(attr(out, "reshape_note"), "by year and gear")
})

## ---- reshaped data give the same DSI as the long original ----

test_that("Thai data reshaped to wide and back gives identical DSI results", {
  th <- dsi_demo_data("Thai_main_groups.csv")
  map <- list(year = "year", species = "group", catch = "yield", effort = "effort", cpue = "cpue")
  ref <- run_dsi_workflow(th, map, group_cols = "species", min_n = 8, max_n = 20)
  wide <- tidyr::pivot_longer(th[, c("year", "group", "yield", "effort")], c("yield", "effort"), names_to = "variable")
  wide <- as.data.frame(tidyr::pivot_wider(wide, names_from = "year", values_from = "value"))
  l <- detect_data_layout(wide)
  expect_equal(l$shape, "wide_years_cols")
  long <- reshape_to_long(wide, l)
  m <- match_columns(long)
  expect_true(m$confident)
  res <- run_dsi_workflow(long, m$map, group_cols = "species", min_n = 8, max_n = 20)
  a <- ref$dsi_all[order(ref$dsi_all$group_key, ref$dsi_all$start_year, ref$dsi_all$end_year), ]
  b <- res$dsi_all[order(res$dsi_all$group_key, res$dsi_all$start_year, res$dsi_all$end_year), ]
  expect_equal(nrow(a), nrow(b))
  expect_equal(a$dsi_v2, b$dsi_v2, tolerance = 1e-10)
})

test_that("read_table_file reads semicolon files with decimal commas", {
  f <- tempfile(fileext = ".csv")
  writeLines(c("A\u00f1o;Captura (t);Esfuerzo", "2001;1,5;10", "2002;2,5;12"), f, useBytes = TRUE)
  df <- read_table_file(f)
  expect_equal(df[[2]], c(1.5, 2.5))
  expect_equal(names(match_columns(df)$map), c("year", "catch", "effort"))
})

test_that("reshaping drops rows with no values at all", {
  df <- data.frame(year = 2001:2010, effort = 1:10, A = c(NA, NA, 3:10), B = 1:10)
  r <- reshape_to_long(df)
  expect_equal(nrow(r), 20)
  df$effort <- NULL
  r <- reshape_to_long(df)
  expect_equal(nrow(r), 18)
  expect_equal(min(r$year[r$group == "A"]), 2003)
})

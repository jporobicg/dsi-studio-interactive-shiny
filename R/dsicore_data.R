## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ DSI Core: data preparation ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Standardize column names and types
#' 
#' Maps user column names to internal schema and converts types.
#' 
#' @param df Input data frame
#' @param col_map Named list mapping roles to column names
#' @return Data frame with standardized columns
#' @export
standardize_columns <- function(df, col_map) {
  n_rows <- nrow(df)
  
  if ("year" %in% names(col_map)) {
    year_vals <- as.integer(df[[col_map$year]])
  } else if ("date" %in% names(col_map)) {
    dates <- as.Date(df[[col_map$date]])
    year_vals <- as.integer(format(dates, "%Y"))
  } else {
    stop("col_map must include 'year' or 'date'")
  }
  
  if ("species" %in% names(col_map) && !is.null(col_map$species)) {
    species_vals <- as.character(df[[col_map$species]])
  } else {
    species_vals <- rep("ALL", n_rows)
  }
  
  if ("fleet" %in% names(col_map) && !is.null(col_map$fleet)) {
    fleet_vals <- as.character(df[[col_map$fleet]])
  } else {
    fleet_vals <- rep("ALL_FLEET", n_rows)
  }
  
  catch_vals <- suppressWarnings(as.numeric(df[[col_map$catch]]))
  effort_vals <- suppressWarnings(as.numeric(df[[col_map$effort]]))
  
  if ("cpue" %in% names(col_map) && !is.null(col_map$cpue)) {
    cpue_vals <- suppressWarnings(as.numeric(df[[col_map$cpue]]))
  } else {
    cpue_vals <- catch_vals / effort_vals
  }
  
  data.frame(
    year = year_vals,
    species = species_vals,
    fleet = fleet_vals,
    catch = catch_vals,
    effort = effort_vals,
    cpue = cpue_vals,
    stringsAsFactors = FALSE
  )
}

#' Harmonize effort values
#' 
#' CORRECTED version that properly handles per-group effort.
#' 
#' @param df Data frame with year, species, fleet, effort
#' @param effort_semantics How to handle effort: "per_fleet_year", "per_group_year", "per_row"
#' @param group_cols Grouping columns
#' @return Data frame with harmonized effort and conflict flags
#' @export
harmonize_effort_corrected <- function(df, effort_semantics = "per_group_year", 
                                      group_cols = c("species", "fleet")) {
  df$effort_original <- df$effort
  df$effort_conflicts <- FALSE
  
  if (effort_semantics == "per_row") {
    return(df)
  }
  
  if (effort_semantics == "per_fleet_year") {
    agg_cols <- c("year", "fleet")
  } else {
    agg_cols <- c("year", group_cols)
  }
  
  effort_summary <- df %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(agg_cols))) %>%
    dplyr::summarise(
      effort_mean = mean(effort, na.rm = TRUE),
      effort_n_unique = dplyr::n_distinct(effort[is.finite(effort)]),
      .groups = "drop"
    )
  
  df <- df %>%
    dplyr::left_join(effort_summary, by = agg_cols)
  
  df$effort_conflicts <- df$effort_n_unique > 1
  df$effort <- df$effort_mean
  df$effort_mean <- NULL
  
  df
}

#' Harmonize effort values (LEGACY VERSION)
#' 
#' Reproduces the original bug: takes first value per fleet-year,
#' then applies to all species. When no fleet column, uses first 
#' group's effort for all groups.
#' 
#' @param df Data frame with year, species, fleet, effort
#' @return Data frame with harmonized effort (buggy)
#' @keywords internal
harmonize_effort_legacy <- function(df) {
  df$effort_original <- df$effort
  
  effort_by_fy <- df %>%
    dplyr::group_by(year, fleet) %>%
    dplyr::summarise(
      effort = dplyr::first(effort[is.finite(effort)]),
      effort_n_unique = dplyr::n_distinct(effort[is.finite(effort)]),
      .groups = "drop"
    )
  
  df <- df %>%
    dplyr::select(-effort) %>%
    dplyr::left_join(effort_by_fy, by = c("year", "fleet"))
  
  df$effort_conflicts <- FALSE
  df
}

#' Create group key from grouping columns
#' 
#' @param df Data frame
#' @param group_cols Column names to group by
#' @return Character vector of group keys
#' @export
make_group_key <- function(df, group_cols = c("species", "fleet")) {
  if (length(group_cols) == 0) {
    return(rep("ALL", nrow(df)))
  }
  
  parts <- lapply(group_cols, function(col) as.character(df[[col]]))
  do.call(paste, c(parts, sep = " | "))
}

#' Audit data quality
#' 
#' Check for common data issues and return findings.
#' 
#' @param df Standardized data frame
#' @param group_cols Grouping columns
#' @return List of audit findings
#' @export
audit_data <- function(df, group_cols = c("species", "fleet")) {
  findings <- list()
  
  dup_check <- df %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(c("year", group_cols)))) %>%
    dplyr::filter(dplyr::n() > 1) %>%
    dplyr::ungroup()
  
  if (nrow(dup_check) > 0) {
    findings$duplicates <- list(
      n = nrow(dup_check),
      message = sprintf("%d duplicate year x group combinations found", nrow(dup_check)),
      severity = "warning",
      data = dup_check
    )
  }
  
  effort_conflicts <- df %>%
    dplyr::filter(effort_conflicts == TRUE) %>%
    dplyr::distinct(year, fleet, effort_n_unique)
  
  if (nrow(effort_conflicts) > 0) {
    findings$effort_conflicts <- list(
      n = nrow(effort_conflicts),
      message = sprintf("Effort varies within year x fleet in %d cases", nrow(effort_conflicts)),
      severity = "warning",
      data = effort_conflicts
    )
  }
  
  cpue_derived_check <- df %>%
    dplyr::mutate(
      cpue_calc = catch / effort,
      cpue_match = abs(cpue - cpue_calc) < 1e-6
    ) %>%
    dplyr::filter(!is.na(cpue) & !is.na(cpue_calc) & !cpue_match)
  
  if (nrow(cpue_derived_check) > 0) {
    findings$cpue_mismatch <- list(
      n = nrow(cpue_derived_check),
      message = sprintf("CPUE != catch/effort in %d rows", nrow(cpue_derived_check)),
      severity = "info",
      data = cpue_derived_check
    )
  }
  
  trailing_missing <- df %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(group_cols))) %>%
    dplyr::arrange(year) %>%
    dplyr::mutate(
      usable_cpue = !is.na(cpue) & is.finite(cpue) & cpue > 0,
      last_usable_year = max(year[usable_cpue], na.rm = TRUE),
      max_year = max(year, na.rm = TRUE),
      trailing_years = max_year - last_usable_year
    ) %>%
    dplyr::ungroup() %>%
    dplyr::filter(trailing_years > 0) %>%
    dplyr::distinct(dplyr::across(dplyr::all_of(c(group_cols, "last_usable_year", 
                                                   "max_year", "trailing_years"))))
  
  if (nrow(trailing_missing) > 0) {
    findings$trailing_missing <- list(
      n = nrow(trailing_missing),
      message = sprintf("%d groups have trailing years with no usable CPUE", 
                       nrow(trailing_missing)),
      severity = "warning",
      data = trailing_missing
    )
  }
  
  findings
}

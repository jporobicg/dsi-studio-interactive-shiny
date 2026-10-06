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
#' Uses base R merge with sort=FALSE to replicate exact row ordering.
#' 
#' @param df Data frame with year, species, fleet, effort
#' @return Data frame with harmonized effort (buggy)
#' @keywords internal
harmonize_effort_legacy <- function(df) {
  df$effort_raw <- df$effort
  
  df2 <- df[is.finite(df$year) & !is.na(df$fleet), c("year", "fleet", "effort"), drop = FALSE]
  
  f <- interaction(df2$year, df2$fleet, drop = TRUE)
  spl <- split(df2, f)
  
  out_list <- lapply(spl, function(d) {
    e <- d$effort
    e_ok <- e[is.finite(e)]
    e_val <- if (length(e_ok) == 0) NA_real_ else e_ok[1]
    n_non_na <- length(e_ok)
    n_unique <- if (length(e_ok) == 0) 0L else length(unique(e_ok))
    data.frame(
      year = d$year[1],
      fleet = d$fleet[1],
      effort_fleet_year = e_val,
      effort_n_non_na = n_non_na,
      effort_n_unique = n_unique,
      stringsAsFactors = FALSE,
      row.names = NULL
    )
  })
  
  e_tbl <- do.call(rbind, out_list)
  rownames(e_tbl) <- NULL
  
  df_tmp <- df
  df_tmp$effort <- NULL
  df <- merge(df_tmp, e_tbl, by = c("year", "fleet"), all.x = TRUE, sort = FALSE)
  df$effort <- df$effort_fleet_year
  
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
  
  # effort_conflicts/effort_n_unique only exist after effort
  # harmonisation; the Audit tab passes un-harmonised data_std, so the filter
  # threw "object 'effort_conflicts' not found" inside an observer and Shiny
  # killed the whole session right after "Apply Mapping".
  if (all(c("effort_conflicts", "effort_n_unique") %in% names(df))) {
    effort_conflicts <- df %>%
      dplyr::filter(effort_conflicts == TRUE) %>%
      dplyr::distinct(year, fleet, effort_n_unique)
  } else {
    effort_conflicts <- df[0, , drop = FALSE]
  }
  
  if (nrow(effort_conflicts) > 0) {
    findings$effort_conflicts <- list(
      n = nrow(effort_conflicts),
      message = sprintf("Effort varies within year x fleet in %d cases", nrow(effort_conflicts)),
      severity = "warning",
      data = effort_conflicts
    )
  }
  
  cpue_check <- check_cpue_scale(df, group_cols)
  if (!is.null(cpue_check$finding)) {
    findings[[cpue_check$finding_name]] <- cpue_check$finding
  }

  effort_struct <- effort_structure(df, group_cols)
  if (effort_struct$n_cells_differ > 0) {
    findings$effort_differs_within_fleet_year <- list(
      n = effort_struct$n_cells_differ,
      message = sprintf(paste0(
        "Effort differs between %s in %d of %d cells. ",
        "Keep the default ('One effort per ... and year') or 'Each row keeps its own effort' under Effort Semantics. ",
        "Use the shared option only if effort is really a %s-level quantity: the original scripts copied one ",
        "group's effort to all groups, which is the bug the corrected method fixes."),
        if (effort_struct$has_fleet) "species of the same fleet and year" else "groups in the same year",
        effort_struct$n_cells_differ, effort_struct$n_cells,
        if (effort_struct$has_fleet) "fleet" else "year"),
      severity = "info",
      data = effort_struct$cells
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

#' Check whether a mapped CPUE column is catch / effort (up to a unit scale)
#'
#' DSI fits log(CPUE) on effort and uses the CPUE max/min ratio, so a constant
#' multiplier on CPUE within a group (e.g. CPUE in kg per day = 1000 x tonnes
#' per day) changes nothing. Only a ratio CPUE / (catch / effort) that varies
#' within a group means the CPUE column is not the catch/effort in the data.
#'
#' @param df Standardised data (year, species, fleet, catch, effort, cpue)
#' @param group_cols Grouping columns
#' @param tol Relative tolerance for "constant" (default 1%, allows rounding)
#' @return List with `finding_name`, `finding` (NULL if CPUE = catch/effort),
#'   overall `scale`, and per-group table `groups`
#' @export
check_cpue_scale <- function(df, group_cols = c("species", "fleet"), tol = 0.01) {
  ok <- is.finite(df$cpue) & is.finite(df$catch) & is.finite(df$effort) &
    df$cpue > 0 & df$catch > 0 & df$effort > 0
  if (!any(ok)) return(list(finding = NULL, finding_name = NULL, scale = NA_real_, groups = NULL))
  d <- df[ok, , drop = FALSE]
  d$ratio <- d$cpue / (d$catch / d$effort)
  d$group_key <- make_group_key(d, group_cols)
  nice_scale <- function(x) {
    p10 <- 10^round(log10(x))
    if (abs(x / p10 - 1) <= tol) p10 else signif(x, 3)
  }
  grp <- d %>%
    dplyr::group_by(group_key) %>%
    dplyr::summarise(
      n_rows = dplyr::n(),
      ratio_median = stats::median(ratio),
      n_off = sum(abs(ratio / stats::median(ratio) - 1) > tol),
      ratio_min = min(ratio), ratio_max = max(ratio),
      .groups = "drop") %>%
    dplyr::mutate(consistent = n_off <= pmax(0, floor(0.02 * n_rows)))
  overall <- stats::median(d$ratio)
  all_one <- all(abs(d$ratio - 1) <= tol)
  if (all_one) {
    return(list(finding = NULL, finding_name = NULL, scale = 1, groups = grp))
  }
  if (all(grp$consistent)) {
    scales <- unique(vapply(grp$ratio_median, nice_scale, numeric(1)))
    msg <- if (length(scales) == 1) {
      sprintf(paste0("CPUE = catch / effort x %s in all %d rows: a constant unit scale. ",
                     "No action needed. DSI is scale-invariant (log-CPUE slope and CPUE ratios)."),
              format(scales, big.mark = ",", scientific = FALSE), nrow(d))
    } else {
      sprintf(paste0("CPUE = catch / effort times a constant within each group (scales: %s). ",
                     "No action needed. DSI is computed per group and is scale-invariant."),
              paste(format(utils::head(sort(scales), 6), big.mark = ",", scientific = FALSE), collapse = ", "))
    }
    return(list(
      finding_name = "cpue_unit_scale",
      finding = list(n = nrow(d), message = msg, severity = "info",
                     data = as.data.frame(grp[, c("group_key", "n_rows", "ratio_median")])),
      scale = if (length(scales) == 1) scales else NA_real_, groups = grp))
  }
  bad <- grp[!grp$consistent, ]
  list(
    finding_name = "cpue_not_catch_over_effort",
    finding = list(
      n = sum(bad$n_rows),
      message = sprintf(paste0(
        "CPUE is not catch / effort (even up to a constant) in %d of %d groups (%d rows): ",
        "CPUE / (catch / effort) varies within the group (e.g. %s: %s to %s). ",
        "The CPUE column may be standardised, or effort may not be the effort behind this CPUE. ",
        "Check the mapping. DSI uses the CPUE column, but the catch-effort correlation uses catch and effort."),
        nrow(bad), nrow(grp), sum(bad$n_rows), bad$group_key[1],
        signif(bad$ratio_min[1], 3), signif(bad$ratio_max[1], 3)),
      severity = "warning",
      data = as.data.frame(bad[, c("group_key", "n_rows", "n_off", "ratio_min", "ratio_median", "ratio_max")])),
    scale = NA_real_, groups = grp)
}

#' Describe how effort is structured across groups
#'
#' @param df Standardised data
#' @param group_cols Grouping columns
#' @return List with counts of year x fleet cells where groups report
#'   different effort, and the cells themselves
#' @export
effort_structure <- function(df, group_cols = c("species", "fleet")) {
  has_fleet <- "fleet" %in% group_cols
  cells <- df %>%
    dplyr::filter(is.finite(effort)) %>%
    dplyr::group_by(year, fleet) %>%
    dplyr::summarise(n_groups = dplyr::n(), n_distinct_effort = dplyr::n_distinct(effort),
                     effort_min = min(effort), effort_max = max(effort), .groups = "drop")
  multi <- cells[cells$n_groups > 1, ]
  differ <- multi[multi$n_distinct_effort > 1, ]
  list(has_fleet = has_fleet, n_cells = nrow(multi), n_cells_differ = nrow(differ),
       cells = as.data.frame(utils::head(differ, 500)))
}

#' Preview the effect of each Effort Semantics option
#'
#' @param df Standardised data
#' @param group_cols Grouping columns
#' @return Data frame: option, rows whose effort changes, rows whose missing
#'   effort is filled, cells with conflicting values
#' @export
effort_semantics_impact <- function(df, group_cols = c("species", "fleet")) {
  opts <- c("per_row", "per_group_year", "per_fleet_year")
  do.call(rbind, lapply(opts, function(o) {
    h <- harmonize_effort_corrected(df, o, group_cols)
    before <- df$effort; after <- h$effort
    changed <- is.finite(before) & is.finite(after) & abs(after - before) > 1e-9 * pmax(1, abs(before))
    filled <- !is.finite(before) & is.finite(after)
    data.frame(option = o, rows_changed = sum(changed), rows_filled = sum(filled),
               conflicts = sum(h$effort_conflicts %in% TRUE), stringsAsFactors = FALSE)
  }))
}

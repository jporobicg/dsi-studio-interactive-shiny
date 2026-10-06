## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ DSI Studio: App utilities ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Guess column mapping from data frame
#' 
#' @param df Data frame
#' @return List of column mappings
#' @export
guess_column_mapping <- function(df) {
  names_lower <- tolower(names(df))
  
  map <- list()
  
  year_candidates <- c("year", "yr", "ano", "annee")
  date_candidates <- c("date", "fecha", "datum")
  
  year_match <- which(names_lower %in% year_candidates)[1]
  date_match <- which(names_lower %in% date_candidates)[1]
  
  if (!is.na(year_match)) {
    map$year <- names(df)[year_match]
  } else if (!is.na(date_match)) {
    map$date <- names(df)[date_match]
  }
  
  species_candidates <- c("species", "sp", "especie", "group", "grupo", "stock")
  species_match <- which(names_lower %in% species_candidates)[1]
  if (!is.na(species_match)) {
    map$species <- names(df)[species_match]
  }
  
  fleet_candidates <- c("fleet", "gear", "flota", "arte", "metier")
  fleet_match <- which(names_lower %in% fleet_candidates)[1]
  if (!is.na(fleet_match)) {
    map$fleet <- names(df)[fleet_match]
  }
  
  catch_candidates <- c("catch", "captures", "yield", "captura", "desembarques", "landings")
  catch_match <- which(names_lower %in% catch_candidates)[1]
  if (!is.na(catch_match)) {
    map$catch <- names(df)[catch_match]
  }
  
  effort_candidates <- c("effort", "esfuerzo", "days", "trips", "hooks")
  effort_match <- which(names_lower %in% effort_candidates)[1]
  if (!is.na(effort_match)) {
    map$effort <- names(df)[effort_match]
  }
  
  cpue_candidates <- c("cpue", "cpua", "index", "abundance", "indice")
  cpue_match <- which(names_lower %in% cpue_candidates)[1]
  if (!is.na(cpue_match)) {
    map$cpue <- names(df)[cpue_match]
  }
  
  map
}

#' Compute data hash for caching
#' 
#' @param df Data frame
#' @return Character hash
#' @export
compute_data_hash <- function(df) {
  digest::digest(df, algo = "xxhash64")
}

#' Create a simple sparkline SVG
#' 
#' @param values Numeric vector
#' @param width Width in pixels
#' @param height Height in pixels
#' @param color Line color
#' @return HTML string with SVG
#' @export
create_sparkline_svg <- function(values, width = 80, height = 30, color = "#3498DB") {
  if (length(values) < 2 || all(is.na(values))) {
    return(sprintf('<svg width="%d" height="%d"></svg>', width, height))
  }
  
  values <- values[!is.na(values)]
  if (length(values) < 2) {
    return(sprintf('<svg width="%d" height="%d"></svg>', width, height))
  }
  
  x_scale <- width / (length(values) - 1)
  y_range <- diff(range(values, na.rm = TRUE))
  if (y_range == 0) y_range <- 1
  y_min <- min(values, na.rm = TRUE)
  
  points <- sapply(seq_along(values), function(i) {
    x <- (i - 1) * x_scale
    y <- height - ((values[i] - y_min) / y_range * height * 0.8 + height * 0.1)
    sprintf("%.1f,%.1f", x, y)
  })
  
  path_d <- paste0("M ", paste(points, collapse = " L "))
  
  sprintf(
    '<svg width="%d" height="%d" style="display:inline-block;vertical-align:middle;">
      <path d="%s" fill="none" stroke="%s" stroke-width="1.5"/>
    </svg>',
    width, height, path_d, color
  )
}

#' Load demo dataset
#' 
#' @param dataset_name Name of demo dataset ("main_groups" or "species_fleet")
#' @return Data frame
#' @export
load_demo_data <- function(dataset_name = "main_groups") {
  demo_path <- system.file("demo_data", package = "dsiapp")
  
  if (dataset_name == "main_groups") {
    file_path <- file.path(demo_path, "Thai_main_groups.csv")
  } else if (dataset_name == "species_fleet") {
    file_path <- file.path(demo_path, "all_species_combined.csv")
  } else {
    stop("Unknown dataset name")
  }
  
  if (demo_path == "" || !file.exists(file_path)) {
    file_path <- file.path("inst/demo_data", 
                          ifelse(dataset_name == "main_groups", 
                                "Thai_main_groups.csv",
                                "all_species_combined.csv"))
  }
  
  if (!file.exists(file_path)) {
    stop("Demo data file not found")
  }
  
  readr::read_csv(file_path, show_col_types = FALSE)
}

#' Pick first column whose lower-cased name matches one of the candidates
#' 
#' [LOCAL FIX] guess_column() is called by mod_data_input.R but was never defined.
#' 
#' @param col_names Character vector of column names
#' @param candidates Character vector of candidate names to match
#' @return Character string of matched column name, or empty string
#' @keywords internal
guess_column <- function(col_names, candidates) {
  hit <- col_names[tolower(col_names) %in% tolower(candidates)]
  if (length(hit) > 0) hit[1] else ""
}

## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ DSI Studio: App utilities ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Guess column mapping from data frame
#' 
#' Loose name matching (units, punctuation and common suffixes ignored,
#' English/Spanish/French synonyms). See [match_columns()] for details and
#' confidence levels.
#' 
#' @param df Data frame
#' @return List of column mappings (role -> column name)
#' @export
guess_column_mapping <- function(df) {
  match_columns(df)$map
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
#' Reads one of the example datasets shipped in `inst/demo_data`.
#' 
#' @param dataset_name Name of demo dataset ("main_groups" or "species_fleet")
#' @return Data frame (tibble)
#' @export
load_demo_data <- function(dataset_name = c("main_groups", "species_fleet")) {
  dataset_name <- match.arg(dataset_name)
  file_name <- switch(dataset_name,
    main_groups = "Thai_main_groups.csv",
    species_fleet = "all_species_combined.csv"
  )
  file_path <- system.file("demo_data", file_name, package = "dsiStudio")
  if (!nzchar(file_path) || !file.exists(file_path)) {
    stop("Demo data file not found: ", file_name)
  }
  
  readr::read_csv(file_path, show_col_types = FALSE)
}

#' Pick first column whose lower-cased name matches one of the candidates
#' 
#' @param col_names Character vector of column names
#' @param candidates Character vector of candidate names to match
#' @return Character string of matched column name, or empty string
#' @keywords internal
guess_column <- function(col_names, candidates) {
  hit <- col_names[tolower(col_names) %in% tolower(candidates)]
  if (length(hit) > 0) hit[1] else ""
}

## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ DSI Core: window generation ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Generate time windows (CORRECTED VERSION)
#' 
#' Creates candidate time windows with flexible anchoring.
#' 
#' @param years Vector of years in the data
#' @param min_n Minimum window length (calendar years)
#' @param max_n Maximum window length (calendar years)
#' @param anchor_mode "last_year", "last_usable_year", or "free"
#' @param usable_years Vector of years with usable CPUE (for last_usable_year mode)
#' @return Data frame with start_year, end_year, n_years
#' @export
generate_windows_corrected <- function(years, min_n = 8, max_n = 20, 
                                      anchor_mode = "last_usable_year",
                                      usable_years = NULL) {
  yrs <- sort(unique(years[!is.na(years) & is.finite(years)]))
  yrs <- as.integer(yrs)
  
  if (length(yrs) == 0) {
    return(data.frame(start_year = integer(0), end_year = integer(0), n_years = integer(0)))
  }
  
  if (anchor_mode == "last_usable_year") {
    if (is.null(usable_years) || length(usable_years) == 0) {
      anchor_year <- max(yrs, na.rm = TRUE)
    } else {
      usable_yrs <- sort(unique(usable_years[!is.na(usable_years) & is.finite(usable_years)]))
      anchor_year <- max(usable_yrs, na.rm = TRUE)
    }
    
    out <- vector("list", 0)
    idx <- 0L
    for (start_year in yrs) {
      if (start_year > anchor_year) next
      len <- anchor_year - start_year + 1L
      if (len < min_n || len > max_n) next
      
      idx <- idx + 1L
      out[[idx]] <- data.frame(
        start_year = start_year,
        end_year = anchor_year,
        n_years = len
      )
    }
    
  } else if (anchor_mode == "last_year") {
    last_year <- max(yrs, na.rm = TRUE)
    
    out <- vector("list", 0)
    idx <- 0L
    for (start_year in yrs) {
      len <- last_year - start_year + 1L
      if (len < min_n || len > max_n) next
      
      idx <- idx + 1L
      out[[idx]] <- data.frame(
        start_year = start_year,
        end_year = last_year,
        n_years = len
      )
    }
    
  } else if (anchor_mode == "free") {
    out <- vector("list", 0)
    idx <- 0L
    
    for (start_year in yrs) {
      for (end_year in yrs) {
        if (end_year <= start_year) next
        len <- end_year - start_year + 1L
        if (len < min_n || len > max_n) next
        
        idx <- idx + 1L
        out[[idx]] <- data.frame(
          start_year = start_year,
          end_year = end_year,
          n_years = len
        )
      }
    }
  } else {
    stop("anchor_mode must be 'last_year', 'last_usable_year', or 'free'")
  }
  
  if (length(out) == 0) {
    return(data.frame(start_year = integer(0), end_year = integer(0), n_years = integer(0)))
  }
  
  do.call(rbind, out)
}

#' Generate time windows (LEGACY VERSION)
#' 
#' Reproduces original behavior: all windows end at last year present,
#' regardless of CPUE availability.
#' 
#' @param years Vector of years in the data
#' @param min_n Minimum window length
#' @param max_n Maximum window length
#' @return Data frame with start_year, end_year, n_years
#' @keywords internal
generate_windows_legacy <- function(years, min_n = 8, max_n = 20) {
  yrs <- sort(unique(years[!is.na(years) & is.finite(years)]))
  yrs <- as.integer(yrs)
  
  if (length(yrs) == 0) {
    return(data.frame(start_year = integer(0), end_year = integer(0), n_years = integer(0)))
  }
  
  last_year <- max(yrs, na.rm = TRUE)
  out <- vector("list", 0)
  idx <- 0L
  
  for (start_year in yrs) {
    len <- last_year - start_year + 1L
    if (len < min_n) next
    if (len > max_n) next
    
    idx <- idx + 1L
    out[[idx]] <- data.frame(
      start_year = start_year,
      end_year = last_year,
      n_years = len
    )
  }
  
  if (length(out) == 0) {
    return(data.frame(start_year = integer(0), end_year = integer(0), n_years = integer(0)))
  }
  
  do.call(rbind, out)
}

#' Get all windows for all groups
#' 
#' @param df Standardized data frame
#' @param group_cols Grouping columns
#' @param min_n Minimum window length
#' @param max_n Maximum window length
#' @param anchor_mode Anchor mode (for corrected version)
#' @param method "corrected" or "legacy"
#' @return Data frame with group_key, start_year, end_year, n_years
#' @export
generate_all_windows <- function(df, group_cols = c("species", "fleet"),
                                min_n = 8, max_n = 20,
                                anchor_mode = "last_usable_year",
                                method = "corrected") {
  df$group_key <- make_group_key(df, group_cols)
  
  groups <- unique(df$group_key)
  
  all_windows <- lapply(groups, function(grp) {
    grp_data <- df[df$group_key == grp, ]
    years <- grp_data$year
    
    if (method == "corrected" && anchor_mode == "last_usable_year") {
      usable_mask <- !is.na(grp_data$cpue) & is.finite(grp_data$cpue) & 
                     grp_data$cpue > 0 & is.finite(grp_data$effort)
      usable_years <- grp_data$year[usable_mask]
      
      windows <- generate_windows_corrected(years, min_n, max_n, 
                                           anchor_mode, usable_years)
    } else if (method == "corrected") {
      windows <- generate_windows_corrected(years, min_n, max_n, anchor_mode)
    } else {
      windows <- generate_windows_legacy(years, min_n, max_n)
    }
    
    if (nrow(windows) > 0) {
      windows$group_key <- grp
      windows
    } else {
      NULL
    }
  })
  
  all_windows <- all_windows[!sapply(all_windows, is.null)]
  
  if (length(all_windows) == 0) {
    return(data.frame(group_key = character(0), start_year = integer(0), 
                     end_year = integer(0), n_years = integer(0)))
  }
  
  do.call(rbind, all_windows)
}

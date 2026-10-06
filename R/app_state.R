## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ DSI Studio: shared app state helpers         ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

DSI_STEPS <- data.frame(
  id = c("data", "audit", "screen", "explore", "decide", "report"),
  title = c("Data", "Audit", "Screen", "Explore", "Decide", "Report"),
  subtitle = c("Load and map your data", "Review data quality", "Score all candidate windows",
               "Inspect, adjust and test", "Accept, flag or reject", "Export results"),
  stringsAsFactors = FALSE
)

#' Which steps can be opened, given what has been completed
#' @keywords internal
dsi_step_unlocked <- function(step, state) {
  switch(step,
    data = TRUE,
    audit = !is.null(state$data_std),
    screen = !is.null(state$data_std) && "audit" %in% state$steps_completed,
    explore = , decide = , report = !is.null(state$dsi_results),
    FALSE)
}


#' Mark a step as completed
#' @keywords internal
mark_done <- function(state, step) {
  if (!step %in% state$steps_completed) state$steps_completed <- c(state$steps_completed, step)
}

#' Invalidate everything downstream of a step (new data, new mapping, new screening)
#' @keywords internal
reset_downstream <- function(state, from = c("data", "mapping", "screen")) {
  from <- match.arg(from)
  keep <- switch(from, data = character(0), mapping = "data", screen = c("data", "audit", "screen"))
  state$steps_completed <- intersect(state$steps_completed, keep)
  if (from %in% c("data", "mapping")) {
    state$dsi_results <- NULL
    state$screen_settings <- NULL
    state$audit <- NULL
  }
  if (from == "data") {
    state$data_std <- NULL; state$col_map <- NULL; state$group_cols <- NULL
  }
  state$current_group <- NULL; state$current_window <- NULL
  state$overrides <- list(); state$decisions <- list(); state$null_tests <- list()
  state$comparison <- NULL
}

#' Short status lines shown under each step in the rail
#' @keywords internal
step_rail_meta <- function(s) {
  m <- list()
  if (!is.null(s$data_raw)) {
    m$data <- sprintf("%s \u00b7 %s rows", s$dataset_name %||% "data", format(nrow(s$data_raw), big.mark = ","))
    if (is.null(s$data_std)) m$data <- paste0(m$data, " \u00b7 not mapped yet")
  }
  if (!is.null(s$audit)) {
    sev <- vapply(s$audit, function(x) x$severity, "")
    m$audit <- if (length(sev) == 0) "no issues" else sprintf("%d warning%s \u00b7 %d info", sum(sev == "warning"),
                                                              if (sum(sev == "warning") == 1) "" else "s", sum(sev != "warning"))
  }
  r <- s$dsi_results
  if (!is.null(r) && !is.null(r$dsi_all)) {
    m$screen <- sprintf("%d groups \u00b7 %d windows \u00b7 %d READY", length(unique(r$dsi_all$group_key)),
                        nrow(r$dsi_all), sum(r$dsi_best$ready %in% TRUE))
    n_ov <- length(s$overrides)
    if (!is.null(s$current_group)) m$explore <- paste0(s$current_group, if (n_ov) sprintf(" \u00b7 %d adjusted", n_ov) else "")
    nd <- length(s$decisions)
    if (nd > 0) {
      acts <- vapply(s$decisions, function(d) d$action, "")
      m$decide <- sprintf("%d/%d decided \u00b7 %d\u2713 %d\u2691 %d\u2717", nd, nrow(r$dsi_best),
                          sum(acts == "accept"), sum(acts == "flag"), sum(acts == "reject"))
    } else m$decide <- sprintf("0/%d decided", nrow(r$dsi_best))
    if (s$export_count > 0) m$report <- sprintf("%d export%s generated", s$export_count, if (s$export_count == 1) "" else "s")
  }
  m
}

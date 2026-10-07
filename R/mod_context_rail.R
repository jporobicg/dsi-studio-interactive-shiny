## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Module: Context rail                        ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Context rail UI
#' @param id Module namespace id
#' @export
mod_context_rail_ui <- function(id) {
  ns <- NS(id)
  uiOutput(ns("rail"))
}

.ctx <- function(label, value, sub = NULL, id = NULL) {
  empty <- is.null(value) || identical(value, "\u2014")
  div(class = "context-item", id = id,
      div(class = "context-label", label),
      div(class = paste("context-value", if (empty) "empty"), if (empty) "\u2014" else value),
      if (!is.null(sub)) div(class = "context-sub", sub))
}

#' Context values shared by the rail and the compact strip
#' @keywords internal
context_values <- function(s) {
  v <- list()
  if (!is.null(s$data_raw)) {
    v$dataset <- s$dataset_name %||% "Loaded data"
    v$dataset_sub <- sprintf("%s rows \u00d7 %d cols%s", format(nrow(s$data_raw), big.mark = ","), ncol(s$data_raw),
                             if (is.null(s$data_std)) " \u00b7 not mapped" else "")
  }
  if (!is.null(s$col_map)) v$mapping <- paste(names(s$col_map), unlist(s$col_map), sep = "\u2192", collapse = ", ")
  v$method <- c(corrected = "Corrected", legacy = "Legacy (original)")[[s$method %||% "corrected"]]
  v$effort <- c(per_row = "own effort per row", per_group_year = "per group-year", per_fleet_year = if ("fleet" %in% s$group_cols) "shared per fleet-year" else "shared per year")[[s$effort_semantics %||% "per_group_year"]]
  r <- s$dsi_results
  if (!is.null(r) && !is.null(r$dsi_all)) {
    v$groups <- length(unique(r$dsi_all$group_key))
    v$windows <- nrow(r$dsi_all)
    v$ready <- sum(r$dsi_best$ready %in% TRUE)
    nd <- length(s$decisions)
    if (nd) {
      acts <- vapply(s$decisions, function(d) d$action, "")
      v$decided <- sprintf("%d of %d", nd, nrow(r$dsi_best))
      v$decided_sub <- sprintf("%d accepted \u00b7 %d flagged \u00b7 %d rejected", sum(acts == "accept"), sum(acts == "flag"), sum(acts == "reject"))
    } else v$decided <- sprintf("0 of %d", nrow(r$dsi_best))
  }
  if (!is.null(s$current_group)) v$group <- s$current_group
  w <- s$current_window
  if (!is.null(w)) {
    v$window <- sprintf("%d\u2013%d", w$start_year, w$end_year)
    v$score <- w$dsi_v2 %||% NA
  }
  v
}

#' Compact context strip (shown instead of the rail on narrow screens)
#' @keywords internal
context_strip_ui <- function(s) {
  v <- context_values(s)
  if (is.null(v$dataset)) return(NULL)
  chip <- function(k, val) if (!is.null(val)) span(class = "chip", k, tags$b(val))
  div(class = "context-strip",
      chip("Data", v$dataset), chip("Method", v$method), chip("Groups", v$groups), chip("READY", v$ready),
      chip("Decided", v$decided), chip("Group", v$group), chip("Window", v$window),
      if (!is.null(v$score)) chip("DSI_v2", format_dsi_score(v$score, 1)))
}

#' Context rail server
#' @param id Module namespace id
#' @param app_state Shared [shiny::reactiveValues()] holding the app state
#' @export
mod_context_rail_server <- function(id, app_state) {
  moduleServer(id, function(input, output, session) {
    output$rail <- renderUI({
      v <- context_values(app_state)
      score_ui <- if (!is.null(v$score)) {
        if (is.finite(v$score)) tagList(span(class = "dsi-number", format_dsi_score(v$score, 1)), " ",
                                        span(class = paste0("dsi-band-", band_class(v$score), " ", band_class(v$score), "-text"), get_dsi_band(v$score)$label))
        else "invalid"
      }
      tagList(
        .ctx("Dataset", v$dataset, v$dataset_sub, id = "ctx-dataset"),
        .ctx("Mapping", v$mapping, id = "ctx-mapping"),
        .ctx("Method", v$method, paste("Effort:", v$effort), id = "ctx-method"),
        .ctx("Groups \u00b7 windows", if (!is.null(v$groups)) sprintf("%d \u00b7 %d", v$groups, v$windows), id = "ctx-groups"),
        .ctx("READY groups", v$ready, id = "ctx-ready"),
        .ctx("Current group", v$group, id = "ctx-group"),
        .ctx("Current window", v$window, id = "ctx-window"),
        .ctx("DSI_v2", score_ui, id = "ctx-score"),
        .ctx("Decisions", v$decided, v$decided_sub, id = "ctx-decisions"))
    })
  })
}

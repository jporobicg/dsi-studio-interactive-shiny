## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Module: Audit                               ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

.audit_titles <- c(
  duplicates = "Duplicate rows",
  effort_conflicts = "Effort conflicts",
  cpue_unit_scale = "CPUE unit scale",
  cpue_not_catch_over_effort = "CPUE is not catch / effort",
  effort_differs_within_fleet_year = "Effort differs between groups",
  trailing_missing = "Trailing years without usable CPUE"
)

#' Audit UI
#' @param id Module namespace id
#' @export
mod_audit_ui <- function(id) {
  ns <- NS(id)
  tagList(
    step_header("Review data quality",
      "Checks on the mapped data before scoring. Warnings need a look. Info items explain how the data will be read.",
      number = 2),
    uiOutput(ns("audit_content")),
    div(class = "step-footer", next_step_button("screen", "Continue to Screen"))
  )
}

#' Audit server
#' @param id Module namespace id
#' @param app_state Shared [shiny::reactiveValues()] holding the app state
#' @export
mod_audit_server <- function(id, app_state) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    output$audit_content <- renderUI({
      if (is.null(app_state$data_std)) return(div(class = "callout", "Map your data in step 1 first."))
      audit <- app_state$audit %||% list()
      ds <- app_state$data_std
      gk <- make_group_key(ds, app_state$group_cols)
      overview <- dsi_card(title = "Overview",
        div(class = "metric-row",
          metric_box(format(nrow(ds), big.mark = ","), "Rows"),
          metric_box(length(unique(gk)), "Groups"),
          metric_box(sprintf("%d\u2013%d", min(ds$year, na.rm = TRUE), max(ds$year, na.rm = TRUE)), "Years"),
          metric_box(sum(!is.finite(ds$cpue) | ds$cpue <= 0, na.rm = TRUE), "Unusable CPUE"),
          metric_box(sum(!is.finite(ds$effort)), "Missing effort")))
      if (length(audit) == 0) {
        return(tagList(overview, div(class = "callout ok", "No data quality issues detected.")))
      }
      sev <- vapply(audit, function(x) x$severity, "")
      ord <- order(sev != "warning")
      cards <- lapply(names(audit)[ord], function(nm) {
        f <- audit[[nm]]
        div(class = paste("audit-finding", if (f$severity %in% c("warning", "error")) "warning" else "info"),
          id = paste0("audit-", nm),
          h5(paste0(.audit_titles[[nm]] %||% nm, " \u00b7 ", f$severity)),
          p(f$message),
          if (!is.null(f$data) && nrow(f$data) > 0)
            tags$details(tags$summary(style = "cursor:pointer;font-size:13px;", sprintf("Show details (%d rows)", nrow(f$data))),
                         DT::dataTableOutput(ns(paste0("tbl_", nm)))))
      })
      tagList(overview,
        dsi_card(title = sprintf("Findings: %d warning%s, %d info", sum(sev == "warning"),
                                 if (sum(sev == "warning") == 1) "" else "s", sum(sev != "warning")), cards))
    })
    observe({
      audit <- app_state$audit %||% list()
      for (nm in names(audit)) local({
        n <- nm; d <- audit[[nm]]$data
        output[[paste0("tbl_", n)]] <- DT::renderDataTable(
          DT::datatable(d, rownames = FALSE, options = list(pageLength = 5, scrollX = TRUE, dom = "tp")))
      })
    })
  })
}

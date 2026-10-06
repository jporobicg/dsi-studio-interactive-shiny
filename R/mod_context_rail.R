## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Module: Context Rail ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Context rail UI
#' 
#' Persistent context sidebar showing current state.
#' 
#' @param id Module ID
#' @export
mod_context_rail_ui <- function(id) {
  ns <- NS(id)
  
  div(
    class = "context-rail",
    
    div(
      class = "context-item",
      div(class = "context-label", "Dataset"),
      div(class = "context-value", textOutput(ns("dataset_name"), inline = TRUE))
    ),
    
    div(
      class = "context-item",
      div(class = "context-label", "Method"),
      div(class = "context-value", textOutput(ns("method_profile"), inline = TRUE))
    ),
    
    div(
      class = "context-item",
      div(class = "context-label", "Groups"),
      div(class = "context-value", textOutput(ns("n_groups"), inline = TRUE))
    ),
    
    div(
      class = "context-item",
      div(class = "context-label", "Current Group"),
      div(class = "context-value", textOutput(ns("current_group"), inline = TRUE))
    ),
    
    div(
      class = "context-item",
      div(class = "context-label", "Current Window"),
      div(class = "context-value", textOutput(ns("current_window"), inline = TRUE))
    ),
    
    div(
      class = "context-item",
      div(class = "context-label", "DSI Score"),
      div(
        class = "context-value",
        uiOutput(ns("current_score"))
      )
    ),
    
    div(
      class = "context-item",
      div(class = "context-label", "Decision Status"),
      div(class = "context-value", textOutput(ns("decision_status"), inline = TRUE))
    ),
    
    div(
      class = "context-item",
      div(class = "context-label", "Ready Groups"),
      div(class = "context-value", textOutput(ns("ready_groups"), inline = TRUE))
    )
  )
}

#' Context rail server
#' 
#' @param id Module ID
#' @param app_state Reactive values with application state
#' @export
mod_context_rail_server <- function(id, app_state) {
  moduleServer(id, function(input, output, session) {
    
    output$dataset_name <- renderText({
      if (is.null(app_state$data_std)) {
        "No data loaded"
      } else {
        # Show dataset name if available, otherwise show row count
        if (!is.null(app_state$dataset_name) && nzchar(app_state$dataset_name)) {
          app_state$dataset_name
        } else {
          sprintf("Loaded data (%d rows)", nrow(app_state$data_std))
        }
      }
    })
    
    output$method_profile <- renderText({
      if (app_state$method == "corrected") {
        "Corrected"
      } else if (app_state$method == "legacy") {
        "Report v1 (legacy)"
      } else {
        "Custom"
      }
    })
    
    output$n_groups <- renderText({
      if (is.null(app_state$dsi_results)) {
        "—"
      } else {
        n <- length(unique(app_state$dsi_results$dsi_all$group_key))
        sprintf("%d", n)
      }
    })
    
    output$current_group <- renderText({
      if (is.null(app_state$current_group)) {
        "—"
      } else {
        app_state$current_group
      }
    })
    
    output$current_window <- renderText({
      if (is.null(app_state$current_window)) {
        "—"
      } else {
        sprintf("%d–%d", 
               app_state$current_window$start_year,
               app_state$current_window$end_year)
      }
    })
    
    output$current_score <- renderUI({
      if (is.null(app_state$current_window)) {
        return("—")
      }
      
      score <- app_state$current_window$dsi_v2
      if (is.na(score)) score <- app_state$current_window$dsi
      
      if (is.na(score) || !is.finite(score)) {
        return(span(class = "dsi-band-invalid", "Invalid"))
      }
      
      band <- get_dsi_band(score)
      band_class <- paste0("dsi-band-", tolower(band$label))
      
      tagList(
        span(class = "dsi-number", format_dsi_score(score, 0)),
        " ",
        span(class = band_class, band$label)
      )
    })
    
    output$decision_status <- renderText({
      if (is.null(app_state$dsi_results)) {
        return("—")
      }
      
      best <- app_state$dsi_results$dsi_best
      if (is.null(best) || nrow(best) == 0) {
        return("—")
      }
      
      n_ready <- sum(best$ready == TRUE, na.rm = TRUE)
      n_total <- nrow(best)
      
      sprintf("%d of %d decided", n_ready, n_total)
    })
    
    output$ready_groups <- renderText({
      if (is.null(app_state$dsi_results)) {
        return("0")
      }
      
      best <- app_state$dsi_results$dsi_best
      if (is.null(best) || nrow(best) == 0) {
        return("0")
      }
      
      n_ready <- sum(best$ready == TRUE, na.rm = TRUE)
      sprintf("%d", n_ready)
    })
  })
}

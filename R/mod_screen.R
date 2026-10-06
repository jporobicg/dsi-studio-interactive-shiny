## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Module: Screen (Redesigned) ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Screen UI
#' @param id Module ID
#' @export
mod_screen_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    div(class = "step-header",
      h2("Run DSI Screening"),
      p(class = "step-purpose",
        "Configure screening parameters and compute DSI scores for all time windows. ",
        "This typically takes 5-15 seconds depending on data size."
      )
    ),
    
    layout_columns(
      col_widths = c(4, 8),
      
      div(class = "dsi-card",
        h3("Settings"),
        
        selectInput(ns("method"), "Method Profile",
                   choices = c("Corrected" = "corrected",
                             "Report v1 (legacy)" = "legacy"),
                   selected = "corrected"),
        
        p(style = "font-size: 13px; color: #7F8C8D; margin-bottom: 20px;",
          "Corrected: fixes known bugs. Legacy: reproduces original code."),
        
        numericInput(ns("min_n"), "Minimum window (years)", 
                    value = 8, min = 3, max = 30),
        
        numericInput(ns("max_n"), "Maximum window (years)",
                    value = 20, min = 5, max = 50),
        
        tags$hr(style = "margin: 24px 0; border-top: 1px solid #E8E8E8;"),
        
        actionButton(ns("run_screen"), "Run Screening",
                    icon = icon("play"),
                    class = "btn-primary-action",
                    style = "width: 100%;")
      ),
      
      div(class = "dsi-card",
        h3("Progress"),
        uiOutput(ns("screening_status")),
        uiOutput(ns("results_summary"))
      )
    )
  )
}

#' Screen server
#' @param id Module ID
#' @param app_state Application state
#' @export
mod_screen_server <- function(id, app_state) {
  moduleServer(id, function(input, output, session) {
    
    dsi_results <- reactiveVal(NULL)
    screening_in_progress <- reactiveVal(FALSE)
    
    observeEvent(input$method, {
      app_state$method <- input$method
    })
    
    observeEvent(input$run_screen, {
      req(app_state$data_std)
      req(app_state$col_map)
      
      screening_in_progress(TRUE)
      
      withProgress(message = "Running DSI screening...", value = 0, {
        results <- tryCatch({
          run_dsi_workflow(
            df = app_state$data_raw,
            col_map = app_state$col_map,
            group_cols = app_state$group_cols,
            min_n = input$min_n,
            max_n = input$max_n,
            anchor_mode = "last_usable_year",
            method = input$method,
            effort_semantics = "per_fleet_year"
          )
        }, error = function(e) {
          showNotification(paste("Error:", e$message), type = "error")
          NULL
        })
        
        if (!is.null(results)) {
          dsi_results(results)
          showNotification("Screening completed!", type = "message")
        }
      })
      
      screening_in_progress(FALSE)
    })
    
    output$screening_status <- renderUI({
      if (screening_in_progress()) {
        div(style = "text-align: center; padding: 40px 20px;",
          div(class = "spinner-border", role = "status",
              style = "width: 48px; height: 48px; color: #3498DB;"),
          p(style = "margin-top: 16px; color: #7F8C8D;", "Computing DSI scores...")
        )
      } else if (!is.null(dsi_results())) {
        div(style = "text-align: center; padding: 20px;",
          div(style = "font-size: 36px; color: #009E73; margin-bottom: 8px;",
              icon("check-circle")),
          div(style = "font-weight: 600; color: #009E73;",
              "Screening Complete")
        )
      } else {
        p(style = "color: #7F8C8D; text-align: center; padding: 20px;",
          "Ready to run. Click button to begin.")
      }
    })
    
    output$results_summary <- renderUI({
      req(dsi_results())
      
      results <- dsi_results()
      n_groups <- length(unique(results$dsi_all$group_key))
      n_windows <- nrow(results$dsi_all)
      n_valid <- sum(results$dsi_all$valid, na.rm = TRUE)
      n_ready <- sum(results$dsi_best$ready == TRUE, na.rm = TRUE)
      median_dsi <- median(results$dsi_all$dsi[results$dsi_all$valid], na.rm = TRUE)
      
      div(style = "margin-top: 24px; padding-top: 24px; border-top: 1px solid #E8E8E8;",
        h4(style = "font-size: 14px; font-weight: 600; margin-bottom: 16px;",
           "Results Summary"),
        
        div(class = "metric-row",
          div(class = "metric-box",
            div(class = "metric-value", n_groups),
            div(class = "metric-label", "Groups")
          ),
          div(class = "metric-box",
            div(class = "metric-value", n_windows),
            div(class = "metric-label", "Windows")
          ),
          div(class = "metric-box",
            div(class = "metric-value", n_valid),
            div(class = "metric-label", "Valid")
          ),
          div(class = "metric-box",
            div(class = "metric-value", style = "color: #009E73;", n_ready),
            div(class = "metric-label", "READY")
          ),
          div(class = "metric-box",
            div(class = "metric-value", format_dsi_score(median_dsi, 0)),
            div(class = "metric-label", "Median DSI")
          )
        )
      )
    })
    
    return(list(
      dsi_results = dsi_results
    ))
  })
}

## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Module: Screen ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Screen UI
#' 
#' @param id Module ID
#' @export
mod_screen_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    h3("DSI Screening"),
    
    layout_columns(
      col_widths = c(4, 8),
      
      card(
        card_header("Settings"),
        card_body(
          selectInput(
            ns("method"),
            "Method Profile",
            choices = c(
              "Corrected" = "corrected",
              "Report v1 (legacy)" = "legacy"
            ),
            selected = "corrected"
          ),
          
          helpText("Corrected: fixes known bugs. Legacy: reproduces original code exactly."),
          
          hr(),
          
          h5("Window Settings"),
          
          numericInput(ns("min_n"), "Minimum window length (years)", 
                      value = 8, min = 3, max = 30),
          
          numericInput(ns("max_n"), "Maximum window length (years)",
                      value = 20, min = 5, max = 50),
          
          selectInput(
            ns("anchor_mode"),
            "Window anchoring",
            choices = c(
              "Last usable year" = "last_usable_year",
              "Last year present" = "last_year",
              "Free start and end" = "free"
            ),
            selected = "last_usable_year"
          ),
          
          hr(),
          
          actionButton(ns("run_screen"), "Run Screening",
                      icon = icon("play"),
                      class = "btn-primary w-100")
        )
      ),
      
      card(
        card_header("Progress"),
        card_body(
          uiOutput(ns("screening_status")),
          
          uiOutput(ns("results_summary"))
        )
      )
    )
  )
}

#' Screen server
#' 
#' @param id Module ID
#' @param app_state Application state
#' @export
mod_screen_server <- function(id, app_state) {
  moduleServer(id, function(input, output, session) {
    
    dsi_results <- reactiveVal(NULL)
    screening_in_progress <- reactiveVal(FALSE)
    screening_message <- reactiveVal("")
    screening_progress <- reactiveVal(0)
    
    observeEvent(input$method, {
      app_state$method <- input$method
    })
    
    observeEvent(input$run_screen, {
      req(app_state$data_std)
      req(app_state$col_map)
      
      screening_in_progress(TRUE)
      screening_message("Starting screening...")
      screening_progress(0)
      
      withProgress(message = "Running DSI screening...", value = 0, {
        
        progress_callback <- function(msg, value = NULL) {
          screening_message(msg)
          if (!is.null(value)) {
            screening_progress(value)
            setProgress(value, detail = msg)
          }
        }
        
        results <- tryCatch({
          run_dsi_workflow(
            df = app_state$data_raw,
            col_map = app_state$col_map,
            group_cols = app_state$group_cols,
            min_n = input$min_n,
            max_n = input$max_n,
            anchor_mode = input$anchor_mode,
            method = input$method,
            effort_semantics = "per_group_year",
            progress_callback = progress_callback
          )
        }, error = function(e) {
          showNotification(paste("Screening error:", e$message), type = "error")
          NULL
        })
        
        if (!is.null(results)) {
          dsi_results(results)
          screening_message("Screening complete!")
          screening_progress(1)
          
          showNotification("Screening completed successfully", type = "message")
        }
      })
      
      screening_in_progress(FALSE)
    })
    
    output$screening_status <- renderUI({
      if (screening_in_progress()) {
        tagList(
          p(screening_message()),
          progressBar(
            id = "screen_progress",
            value = screening_progress() * 100,
            status = "primary",
            striped = TRUE,
            animated = TRUE
          )
        )
      } else if (!is.null(dsi_results())) {
        div(
          class = "alert alert-success",
          icon("check-circle"),
          " Screening complete"
        )
      } else {
        p("Configure settings and click 'Run Screening' to begin.")
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
      median_dsi_v2 <- median(results$dsi_all$dsi_v2[results$dsi_all$valid], na.rm = TRUE)
      
      card(
        card_header("Results Summary"),
        card_body(
          layout_column_wrap(
            width = 1/3,
            
            div(
              class = "metric-card",
              div(class = "metric-value", n_groups),
              div(class = "metric-label", "Groups")
            ),
            
            div(
              class = "metric-card",
              div(class = "metric-value", n_windows),
              div(class = "metric-label", "Windows")
            ),
            
            div(
              class = "metric-card",
              div(class = "metric-value", n_valid),
              div(class = "metric-label", "Valid")
            ),
            
            div(
              class = "metric-card",
              div(class = "metric-value", n_ready),
              div(class = "metric-label", "READY")
            ),
            
            div(
              class = "metric-card",
              div(class = "metric-value dsi-number", format_dsi_score(median_dsi, 0)),
              div(class = "metric-label", "Median DSI")
            ),
            
            div(
              class = "metric-card",
              div(class = "metric-value dsi-number", format_dsi_score(median_dsi_v2, 0)),
              div(class = "metric-label", "Median DSI_v2")
            )
          )
        )
      )
    })
    
    return(list(
      dsi_results = dsi_results
    ))
  })
}

progressBar <- function(id, value, status = "primary", striped = FALSE, animated = FALSE) {
  striped_class <- if (striped) "progress-bar-striped" else ""
  animated_class <- if (animated) "progress-bar-animated" else ""
  
  div(
    class = "progress",
    div(
      class = paste("progress-bar", paste0("bg-", status), striped_class, animated_class),
      role = "progressbar",
      style = sprintf("width: %d%%", value),
      `aria-valuenow` = value,
      `aria-valuemin` = 0,
      `aria-valuemax` = 100
    )
  )
}

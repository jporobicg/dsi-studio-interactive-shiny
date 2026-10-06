## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ DSI Studio: Main Application (Redesigned) ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

library(shiny)
library(bslib)
library(dplyr)
library(tidyr)
library(ggplot2)
library(readr)
library(echarts4r)

source("R/dsicore_utils.R")
source("R/dsicore_data.R")
source("R/dsicore_windows.R")
source("R/dsicore_metrics.R")
source("R/dsicore_scoring.R")
source("R/dsicore_selection.R")
source("R/dsicore_workflow.R")
source("R/app_theme.R")
source("R/app_utils.R")
source("R/mod_data_input.R")
source("R/mod_audit.R")
source("R/mod_screen.R")
source("R/mod_explore.R")
source("R/mod_context_rail.R")

#' Run DSI Studio application
#' @param port Port number (optional)
#' @export
run_dsi_studio <- function(port = NULL) {
  app <- shinyApp(
    ui = dsi_studio_ui(),
    server = dsi_studio_server
  )
  
  if (!is.null(port)) {
    runApp(app, port = port, host = "0.0.0.0")
  } else {
    runApp(app, host = "0.0.0.0")
  }
}

#' UI definition
#' @keywords internal
dsi_studio_ui <- function() {
  page_fillable(
    theme = dsi_theme(),
    title = "DSI Studio",
    
    dsi_custom_css(),
    
    layout_sidebar(
      # Step rail sidebar
      sidebar = sidebar(
        width = 260,
        class = "step-rail",
        style = "padding: 0;",
        
        div(style = "padding: 24px; border-bottom: 1px solid #E0E0E0;",
          h4(style = "margin: 0; font-size: 18px; font-weight: 600;", "DSI Studio"),
          p(style = "margin: 4px 0 0 0; font-size: 12px; color: #7F8C8D;", 
            "Data Suitability Index")
        ),
        
        actionLink("step_data", 
          div(class = "step-item active", id = "step-data-item",
            span(class = "step-number", "1"),
            div(style = "display: inline-block; vertical-align: middle;",
              div(class = "step-title", "Data"),
              div(class = "step-subtitle", "Load and map your data")
            )
          )
        ),
        
        actionLink("step_audit",
          div(class = "step-item locked", id = "step-audit-item",
            span(class = "step-number", "2"),
            div(style = "display: inline-block; vertical-align: middle;",
              div(class = "step-title", "Audit"),
              div(class = "step-subtitle", "Review data quality")
            )
          )
        ),
        
        actionLink("step_screen",
          div(class = "step-item locked", id = "step-screen-item",
            span(class = "step-number", "3"),
            div(style = "display: inline-block; vertical-align: middle;",
              div(class = "step-title", "Screen"),
              div(class = "step-subtitle", "Run DSI computation")
            )
          )
        ),
        
        actionLink("step_explore",
          div(class = "step-item locked", id = "step-explore-item",
            span(class = "step-number", "4"),
            div(style = "display: inline-block; vertical-align: middle;",
              div(class = "step-title", "Explore"),
              div(class = "step-subtitle", "Review results")
            )
          )
        )
      ),
      
      # Main content area
      layout_sidebar(
        # Context rail
        sidebar = sidebar(
          position = "right",
          width = 240,
          class = "context-rail",
          
          mod_context_rail_ui("context")
        ),
        
        # Main content
        div(class = "main-content",
          uiOutput("current_step_content")
        )
      )
    )
  )
}

#' Server logic
#' @keywords internal
dsi_studio_server <- function(input, output, session) {
  
  app_state <- reactiveValues(
    current_step = "data",
    data_raw = NULL,
    data_std = NULL,
    col_map = NULL,
    group_cols = NULL,
    audit = NULL,
    dsi_results = NULL,
    current_group = NULL,
    current_window = NULL,
    method = "corrected",
    steps_completed = c()
  )
  
  # Step navigation
  observeEvent(input$step_data, {
    app_state$current_step <- "data"
    update_step_ui(session, "data", app_state$steps_completed)
  })
  
  observeEvent(input$step_audit, {
    if ("data" %in% app_state$steps_completed) {
      app_state$current_step <- "audit"
      update_step_ui(session, "audit", app_state$steps_completed)
    }
  })
  
  observeEvent(input$step_screen, {
    if ("audit" %in% app_state$steps_completed) {
      app_state$current_step <- "screen"
      update_step_ui(session, "screen", app_state$steps_completed)
    }
  })
  
  observeEvent(input$step_explore, {
    if ("screen" %in% app_state$steps_completed) {
      app_state$current_step <- "explore"
      update_step_ui(session, "explore", app_state$steps_completed)
    }
  })
  
  # Render current step content
  output$current_step_content <- renderUI({
    step <- app_state$current_step
    
    if (step == "data") {
      mod_data_input_ui("data_input")
    } else if (step == "audit") {
      mod_audit_ui("audit")
    } else if (step == "screen") {
      mod_screen_ui("screen")
    } else if (step == "explore") {
      mod_explore_ui("explore")
    }
  })
  
  # Module servers
  data_input_return <- mod_data_input_server("data_input", app_state)
  
  observe({
    if (!is.null(data_input_return$data_std())) {
      app_state$data_std <- data_input_return$data_std()
      app_state$col_map <- data_input_return$col_map()
      app_state$group_cols <- data_input_return$group_cols()
      app_state$data_raw <- data_input_return$data_raw()
      
      # Mark data step as completed
      if (!"data" %in% app_state$steps_completed) {
        app_state$steps_completed <- c(app_state$steps_completed, "data")
        update_step_ui(session, "data", app_state$steps_completed)
      }
    }
  })
  
  mod_audit_server("audit", app_state)
  
  # Mark audit as completed when viewed
  observe({
    if (app_state$current_step == "audit" && 
        !is.null(app_state$data_std) &&
        !"audit" %in% app_state$steps_completed) {
      app_state$steps_completed <- c(app_state$steps_completed, "audit")
      update_step_ui(session, "audit", app_state$steps_completed)
    }
  })
  
  screen_return <- mod_screen_server("screen", app_state)
  
  observe({
    if (!is.null(screen_return$dsi_results())) {
      app_state$dsi_results <- screen_return$dsi_results()
      
      # Mark screen as completed
      if (!"screen" %in% app_state$steps_completed) {
        app_state$steps_completed <- c(app_state$steps_completed, "screen")
        update_step_ui(session, "screen", app_state$steps_completed)
      }
    }
  })
  
  mod_explore_server("explore", app_state)
  
  mod_context_rail_server("context", app_state)
}

#' Update step UI classes
#' @keywords internal
update_step_ui <- function(session, current, completed) {
  steps <- c("data", "audit", "screen", "explore")
  
  for (step in steps) {
    classes <- "step-item"
    
    if (step == current) {
      classes <- paste(classes, "active")
    }
    
    if (step %in% completed) {
      classes <- paste(classes, "completed")
    }
    
    # Lock steps that aren't accessible
    step_index <- which(steps == step)
    prev_step <- if (step_index > 1) steps[step_index - 1] else NULL
    
    if (!is.null(prev_step) && !(prev_step %in% completed) && step != current) {
      classes <- paste(classes, "locked")
    }
    
    session$sendCustomMessage("updateStepClass", list(
      step = step,
      classes = classes
    ))
  }
}

# Add custom JavaScript for step updates
tags$script(HTML("
  Shiny.addCustomMessageHandler('updateStepClass', function(message) {
    var elem = document.getElementById('step-' + message.step + '-item');
    if (elem) {
      elem.className = message.classes;
    }
  });
"))

if (!interactive()) {
  run_dsi_studio(port = 43210)
}

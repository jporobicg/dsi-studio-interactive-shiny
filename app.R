## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ DSI Studio: Main Application ~ ##
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
source("R/mod_decide.R")
source("R/mod_report.R")
source("R/mod_context_rail.R")

#' Run DSI Studio application
#' 
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
  # [LOCAL FIX 6] page_fillable() squeezed every tab into the viewport height:
  # at 1440x900 the Explore detail cards, time-series chart (~30px) and
  # diagnostics plot (~50px) and the Decide cards were crushed/clipped.
  # Use a normal scrolling page and a non-fillable sidebar layout.
  page_fluid(
    theme = dsi_theme(),
    title = "DSI Studio",
    
    tags$head(
      tags$link(rel = "stylesheet", href = "css/custom.css")
    ),
    
    dsi_custom_css(),
    dsi_step_class_js(),
    dsi_context_rail_js(),
    
    layout_sidebar(
      fillable = FALSE,  # [LOCAL FIX 6]
      sidebar = sidebar(
        width = 260,
        mod_context_rail_ui("context")
      ),
      
      navset_card_tab(
        id = "main_nav",
        
        nav_panel(
          title = "1. Data",
          icon = icon("database"),
          mod_data_input_ui("data_input")
        ),
        
        nav_panel(
          title = "2. Audit",
          icon = icon("check-circle"),
          mod_audit_ui("audit")
        ),
        
        nav_panel(
          title = "3. Screen",
          icon = icon("search"),
          mod_screen_ui("screen")
        ),
        
        nav_panel(
          title = "4. Explore",
          icon = icon("chart-line"),
          mod_explore_ui("explore")
        ),
        
        nav_panel(
          title = "5. Decide",
          icon = icon("gavel"),
          mod_decide_ui("decide")
        ),
        
        nav_panel(
          title = "6. Report",
          icon = icon("file-export"),
          mod_report_ui("report")
        )
      )
    )
  )
}

#' Server logic
#' @keywords internal
dsi_studio_server <- function(input, output, session) {
  
  app_state <- reactiveValues(
    data_raw = NULL,
    data_std = NULL,
    col_map = NULL,
    group_cols = NULL,
    audit = NULL,
    dsi_results = NULL,
    current_group = NULL,
    current_window = NULL,
    method = "corrected"
  )
  
  data_input_return <- mod_data_input_server("data_input", app_state)
  
  observe({
    if (!is.null(data_input_return$data_std())) {
      app_state$data_std <- data_input_return$data_std()
      app_state$col_map <- data_input_return$col_map()
      app_state$group_cols <- data_input_return$group_cols()
    }
  })
  
  mod_audit_server("audit", app_state)
  
  screen_return <- mod_screen_server("screen", app_state)
  
  observe({
    if (!is.null(screen_return$dsi_results())) {
      app_state$dsi_results <- screen_return$dsi_results()
    }
  })
  
  mod_explore_server("explore", app_state)
  
  mod_decide_server("decide", app_state)
  
  mod_report_server("report", app_state)
  
  mod_context_rail_server("context", app_state)
}

## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Custom UI helpers ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Custom CSS for DSI Studio
#' @keywords internal
dsi_custom_css <- function() {
  tags$style(HTML("
    /* Additional custom styles can be added here */
  "))
}

#' JavaScript for step class updates
#' 
#' [LOCAL FIX] was a bare top-level tags$script() that never reached the UI
#' @keywords internal
dsi_step_class_js <- function() {
  tags$script(HTML("
    Shiny.addCustomMessageHandler('updateStepClass', function(message) {
      var elem = document.getElementById('step-' + message.step + '-item');
      if (elem) {
        elem.className = 'step-item ' + message.class;
      }
    });
  "))
}

#' JavaScript for context rail updates
#' 
#' [LOCAL FIX] was a bare top-level tags$script() that never reached the UI
#' @keywords internal
dsi_context_rail_js <- function() {
  tags$script(HTML("
    Shiny.addCustomMessageHandler('updateContext', function(message) {
      var elem = document.getElementById(message.id);
      if (elem) {
        elem.innerText = message.value;
      }
    });
  "))
}

## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ App launcher ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

# [LOCAL FIX] original ended with `if (!interactive()) run_dsi_studio(port = 43210)`,
# which nests runApp() and binds 0.0.0.0 when launched via shiny::runApp(dir).
# Return the app object so runApp(dir, host=, port=) controls the binding.
shinyApp(ui = dsi_studio_ui(), server = dsi_studio_server)

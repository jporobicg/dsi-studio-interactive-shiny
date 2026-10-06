## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Module: Report & Export ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Report UI
#' 
#' Export interface for generating reports and reproducible outputs.
#' 
#' @param id Module ID
#' @export
mod_report_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    h3("Report & Export"),
    
    p("Generate reproducible outputs including configuration, results CSVs, and R scripts."),
    
    card(
      card_header("Export Options"),
      card_body(
        checkboxGroupInput(
          ns("export_items"),
          "Select items to export:",
          choices = c(
            "Configuration YAML" = "config_yaml",
            "Results CSV (all windows)" = "csv_all",
            "Results CSV (best windows)" = "csv_best",
            "Decision ledger CSV" = "csv_decisions",
            "Standalone R script" = "r_script",
            "HTML summary report" = "html_report"
          ),
          selected = c("config_yaml", "csv_all", "csv_best", "r_script")
        ),
        
        textInput(
          ns("export_prefix"),
          "Output file prefix:",
          value = format(Sys.Date(), "dsi_export_%Y%m%d"),
          width = "100%"
        ),
        
        actionButton(ns("generate_export"), "Generate Export Package",
                    icon = icon("download"),
                    class = "btn-primary mt-2")
      )
    ),
    
    uiOutput(ns("export_status"))
  )
}

#' Report server
#' 
#' @param id Module ID
#' @param app_state Application state
#' @export
mod_report_server <- function(id, app_state) {
  moduleServer(id, function(input, output, session) {
    
    export_ready <- reactiveVal(FALSE)
    export_path <- reactiveVal(NULL)
    
    output$export_status <- renderUI({
      if (!export_ready()) {
        return(NULL)
      }
      
      ns <- session$ns
      
      card(
        card_header("Export Ready", class = "bg-success text-white"),
        card_body(
          p(sprintf("Export package created at: %s", export_path())),
          downloadButton(ns("download_export"), "Download Export Package",
                        class = "btn-success")
        )
      )
    })
    
    observeEvent(input$generate_export, {
      req(app_state$dsi_results)
      req(input$export_items)
      
      withProgress(message = "Generating export package...", {
        
        tryCatch({
          # Create temporary directory for export
          export_dir <- file.path(tempdir(), paste0(input$export_prefix, "_", format(Sys.time(), "%H%M%S")))
          dir.create(export_dir, showWarnings = FALSE, recursive = TRUE)
          
          incProgress(0.1, detail = "Writing configuration...")
          
          # Generate configuration YAML
          if ("config_yaml" %in% input$export_items) {
            config <- list(
              dataset = list(
                name = app_state$dataset_name %||% "unknown",
                hash = compute_data_hash(app_state$data_std),
                rows = nrow(app_state$data_std),
                columns = names(app_state$data_std)
              ),
              column_mapping = app_state$col_map,
              method = app_state$method %||% "corrected",
              timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
              r_version = R.version.string,
              package_versions = list(
                dsiapp = "0.1.0"
              )
            )
            
            yaml::write_yaml(config, file.path(export_dir, "dsi_config.yaml"))
          }
          
          incProgress(0.3, detail = "Writing results CSVs...")
          
          # Export all windows CSV
          if ("csv_all" %in% input$export_items) {
            readr::write_csv(
              app_state$dsi_results$dsi_all,
              file.path(export_dir, "dsi_all_windows.csv")
            )
          }
          
          # Export best windows CSV
          if ("csv_best" %in% input$export_items) {
            readr::write_csv(
              app_state$dsi_results$dsi_best,
              file.path(export_dir, "dsi_best_windows.csv")
            )
          }
          
          incProgress(0.5, detail = "Writing decision ledger...")
          
          # Export decisions CSV
          if ("csv_decisions" %in% input$export_items && !is.null(app_state$decisions)) {
            decisions_df <- do.call(rbind, lapply(app_state$decisions, function(d) {
              data.frame(
                group_key = d$group_key,
                action = d$action,
                rationale = d$rationale,
                timestamp = format(d$timestamp, "%Y-%m-%d %H:%M:%S"),
                stringsAsFactors = FALSE
              )
            }))
            
            readr::write_csv(
              decisions_df,
              file.path(export_dir, "dsi_decision_ledger.csv")
            )
          }
          
          incProgress(0.7, detail = "Writing R script...")
          
          # Generate standalone R script
          if ("r_script" %in% input$export_items) {
            r_script <- sprintf('
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ DSI Analysis: Standalone Reproduction Script ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

# Generated by DSI Studio on %s
# This script reproduces the DSI analysis without the Shiny app

library(dplyr)
library(readr)

# Load data
# Replace this path with your actual data file
# data <- read_csv("your_data.csv")

# Column mapping
col_map <- list(
  year = "%s",
  species = "%s",
  fleet = "%s",
  catch = "%s",
  effort = "%s",
  cpue = "%s"
)

# Method: %s

# Load the dsicore functions from DSI Studio
# source("path/to/dsicore_*.R")

# Run the analysis workflow
# results <- run_dsi_workflow(data, col_map, method = "%s")

# Save results
# write_csv(results$dsi_all, "dsi_all_windows.csv")
# write_csv(results$dsi_best, "dsi_best_windows.csv")

# End of script
',
              format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
              app_state$col_map$year %||% "year",
              app_state$col_map$species %||% "species",
              app_state$col_map$fleet %||% "fleet",
              app_state$col_map$catch %||% "catch",
              app_state$col_map$effort %||% "effort",
              app_state$col_map$cpue %||% "cpue",
              app_state$method %||% "corrected",
              app_state$method %||% "corrected"
            )
            
            writeLines(r_script, file.path(export_dir, "reproduce_dsi_analysis.R"))
          }
          
          incProgress(0.9, detail = "Creating zip archive...")
          
          # Create zip file
          zip_path <- paste0(export_dir, ".zip")
          zip::zip(
            zipfile = zip_path,
            files = list.files(export_dir, full.names = TRUE),
            mode = "cherry-pick"
          )
          
          export_path(zip_path)
          export_ready(TRUE)
          
          incProgress(1, detail = "Complete!")
          
          showNotification("Export package generated successfully!", type = "message", duration = 3)
          
        }, error = function(e) {
          showNotification(paste("Export error:", e$message), type = "error", duration = 5)
        })
      })
    })
    
    output$download_export <- downloadHandler(
      filename = function() {
        basename(export_path())
      },
      content = function(file) {
        file.copy(export_path(), file)
      }
    )
  })
}

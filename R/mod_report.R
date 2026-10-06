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
              screening = app_state$screen_settings,  # [LOCAL FIX 5]
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
          # [LOCAL FIX 5] the generated script was entirely commented out (no data,
          # no functions, no window settings), so it reproduced nothing. Bundle the
          # input data, the dsicore functions and the settings, and emit a script
          # that re-runs the workflow and compares against the exported CSV.
          if ("r_script" %in% input$export_items) {
            dir.create(file.path(export_dir, "data"), showWarnings = FALSE)
            readr::write_csv(app_state$data_raw, file.path(export_dir, "data", "input_data.csv"))
            dir.create(file.path(export_dir, "dsicore"), showWarnings = FALSE)
            file.copy(list.files("R", pattern = "^dsicore_.*\\.R$", full.names = TRUE),
                      file.path(export_dir, "dsicore"))
            ss <- app_state$screen_settings
            settings <- list(
              column_mapping = app_state$col_map,
              group_cols = ss$group_cols %||% app_state$group_cols,
              min_n = ss$min_n, max_n = ss$max_n, anchor_mode = ss$anchor_mode,
              method = ss$method %||% app_state$method %||% "corrected",
              effort_semantics = ss$effort_semantics %||% "per_group_year"
            )
            yaml::write_yaml(settings, file.path(export_dir, "dsi_settings.yaml"))
            r_script <- c(
              "## DSI Analysis: standalone reproduction script",
              paste0("## Generated by DSI Studio on ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
              "## Run from the unzipped export folder:  Rscript reproduce_dsi_analysis.R",
              "suppressMessages({library(dplyr); library(tidyr); library(readr); library(yaml)})",
              "for (f in sort(list.files('dsicore', pattern = '[.]R$', full.names = TRUE))) source(f)",
              "s <- yaml::read_yaml('dsi_settings.yaml')",
              "col_map <- Filter(Negate(is.null), s$column_mapping)",
              "data <- readr::read_csv('data/input_data.csv', show_col_types = FALSE)",
              "res <- run_dsi_workflow(df = data, col_map = col_map, group_cols = unlist(s$group_cols),",
              "                        min_n = s$min_n, max_n = s$max_n, anchor_mode = s$anchor_mode,",
              "                        method = s$method, effort_semantics = s$effort_semantics)",
              "readr::write_csv(res$dsi_all, 'reproduced_dsi_all_windows.csv')",
              "readr::write_csv(res$dsi_best, 'reproduced_dsi_best_windows.csv')",
              "if (file.exists('dsi_all_windows.csv')) {",
              "  ref <- readr::read_csv('dsi_all_windows.csv', show_col_types = FALSE)",
              "  new <- readr::read_csv('reproduced_dsi_all_windows.csv', show_col_types = FALSE)",
              "  k <- c('group_key', 'start_year', 'end_year')",
              "  m <- dplyr::inner_join(ref, new, by = k, suffix = c('.ref', '.new'))",
              "  d <- function(v) max(abs(m[[paste0(v, '.ref')]] - m[[paste0(v, '.new')]]), na.rm = TRUE)",
              "  cat(sprintf('windows: exported=%d reproduced=%d matched=%d\\n', nrow(ref), nrow(new), nrow(m)))",
              "  cat(sprintf('max |diff| dsi=%.3g dsi_v2=%.3g beta=%.3g p=%.3g\\n', d('dsi'), d('dsi_v2'), d('beta'), d('p_value')))",
              "  ok <- nrow(ref) == nrow(new) && nrow(m) == nrow(ref) && d('dsi') < 1e-8 && d('dsi_v2') < 1e-8",
              "  cat(if (ok) 'REPRODUCED: scores match the export\\n' else 'MISMATCH: scores differ from the export\\n')",
              "}"
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

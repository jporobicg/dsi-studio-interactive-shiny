## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Module: Report & Export                     ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Report UI
#' @export
mod_report_ui <- function(id) {
  ns <- NS(id)
  tagList(
    step_header("Export results",
      "A self-contained HTML report to share, and a reproducible package: results tables, decisions, settings, your data and a standalone R script that recomputes every score.",
      number = 6),
    uiOutput(ns("report_summary")),
    div(class = "dsi-grid-2",
      dsi_card(title = "HTML summary report",
        p(class = "help", "One file, no external links: scores, selected windows, decisions, key charts, null tests and the method comparison (if run), audit findings and settings."),
        downloadButton(ns("dl_html"), "Download HTML report", class = "btn-primary")),
      dsi_card(title = "Reproducible export package (ZIP)",
        checkboxGroupInput(ns("export_items"), NULL,
          choices = c("Configuration YAML" = "config_yaml", "Results CSV (all windows)" = "csv_all",
                      "Results CSV (best + selected windows)" = "csv_best", "Decision ledger CSV" = "csv_decisions",
                      "Standalone R script + data" = "r_script", "HTML summary report" = "html_report"),
          selected = c("config_yaml", "csv_all", "csv_best", "csv_decisions", "r_script", "html_report")),
        textInput(ns("export_prefix"), "File prefix", value = format(Sys.Date(), "dsi_export_%Y%m%d"), width = "100%"),
        downloadButton(ns("dl_zip"), "Download export ZIP", class = "btn-primary")))
  )
}

#' Settings list used in YAML and the report
#' @keywords internal
dsi_export_settings <- function(app_state) {
  st <- app_state$screen_settings %||% list()
  cfg <- app_state$dsi_results$config
  list(
    method = cfg$method, min_n = cfg$min_n, max_n = cfg$max_n, anchor_mode = cfg$anchor_mode,
    effort_semantics = cfg$effort_semantics, group_cols = cfg$group_cols,
    column_mapping = cfg$col_map, min_usable = cfg$min_usable,
    weights = cfg$weights, refs = cfg$refs, selection_opts = cfg$selection_opts, fixes = cfg$fixes,
    modified_params = st$modified_params %||% character(0)
  )
}

#' Write the HTML report for the current state
#' @keywords internal
dsi_write_report <- function(app_state, file) {
  s <- dsi_export_settings(app_state)
  short <- list(Dataset = app_state$dataset_name, Method = s$method, `Window length` = sprintf("%d\u2013%d years", s$min_n, s$max_n),
                Anchoring = s$anchor_mode, `Effort semantics` = s$effort_semantics,
                Grouping = paste(s$group_cols %||% "none", collapse = " \u00d7 "),
                `Column mapping` = paste(names(s$column_mapping), unlist(s$column_mapping), sep = " = ", collapse = "; "),
                Weights = paste(names(s$weights), unlist(s$weights), sep = " = ", collapse = "; "),
                `Changed advanced parameters` = if (length(s$modified_params)) paste(s$modified_params, collapse = ", ") else "none")
  dsi_build_html_report(app_state$dsi_results, file, dataset_name = app_state$dataset_name %||% "dataset",
                        settings = short, overrides = app_state$overrides, decisions = app_state$decisions,
                        audit = app_state$audit, null_tests = app_state$null_tests, comparison = app_state$comparison)
}

#' Report server
#' @export
mod_report_server <- function(id, app_state) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    output$report_summary <- renderUI({
      r <- app_state$dsi_results
      if (is.null(r)) return(div(class = "callout", "Run screening first."))
      nd <- length(app_state$decisions); ng <- nrow(r$dsi_best)
      dsi_card(title = "What will be exported",
        div(class = "metric-row",
          metric_box(ng, "Groups"), metric_box(nrow(r$dsi_all), "Windows"),
          metric_box(sum(r$dsi_best$ready %in% TRUE), "READY"),
          metric_box(sprintf("%d/%d", nd, ng), "Decided"),
          metric_box(length(app_state$overrides), "Adjusted windows"),
          metric_box(length(app_state$null_tests), "Null tests")),
        if (nd < ng) div(class = "callout warn", sprintf("%d group(s) have no saved decision. They are exported as undecided.", ng - nd)))
    })

    output$dl_html <- downloadHandler(
      filename = function() paste0(input$export_prefix %||% "dsi", "_report.html"),
      content = function(file) {
        req(app_state$dsi_results)
        dsi_write_report(app_state, file)
        app_state$export_count <- app_state$export_count + 1
        mark_done(app_state, "report")
      })

    output$dl_zip <- downloadHandler(
      filename = function() paste0(input$export_prefix %||% "dsi_export", ".zip"),
      content = function(file) {
        req(app_state$dsi_results)
        items <- input$export_items
        res <- app_state$dsi_results
        dir <- file.path(tempfile("dsi_export_"), input$export_prefix %||% "dsi_export")
        dir.create(dir, recursive = TRUE)
        s <- dsi_export_settings(app_state)
        summ <- dsi_group_summary(res, app_state$overrides, app_state$decisions)
        if ("config_yaml" %in% items) {
          yaml::write_yaml(list(
            dataset = list(name = app_state$dataset_name %||% "unknown", hash = compute_data_hash(app_state$data_raw),
                           rows = nrow(app_state$data_raw), columns = names(app_state$data_raw)),
            settings = s, generated = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), r_version = R.version.string,
            packages = list(shiny = as.character(utils::packageVersion("shiny")), dplyr = as.character(utils::packageVersion("dplyr")))),
            file.path(dir, "dsi_config.yaml"))
        }
        if ("csv_all" %in% items) readr::write_csv(res$dsi_all, file.path(dir, "dsi_all_windows.csv"))
        if ("csv_best" %in% items) {
          readr::write_csv(res$dsi_best, file.path(dir, "dsi_best_windows.csv"))
          readr::write_csv(summ, file.path(dir, "dsi_selected_windows.csv"))
        }
        if ("csv_decisions" %in% items) {
          led <- summ[, c("group_key", "selected_window", "window_source", "selected_dsi_v2", "ready", "decision", "rationale")]
          led$timestamp <- vapply(led$group_key, function(g) {
            d <- app_state$decisions[[g]]; if (is.null(d)) NA_character_ else format(d$timestamp, "%Y-%m-%d %H:%M:%S") }, "")
          readr::write_csv(led, file.path(dir, "dsi_decision_ledger.csv"))
        }
        if (length(app_state$null_tests)) {
          readr::write_csv(do.call(rbind, lapply(names(app_state$null_tests), function(g) {
            x <- app_state$null_tests[[g]]
            data.frame(group_key = g, start_year = x$start_year, end_year = x$end_year, mode = x$mode, n_sim = x$n_sim,
                       seed = x$seed, observed_dsi_v2 = x$observed_dsi_v2, null_median = x$null_median,
                       null_q95 = x$null_q95, p_value = x$p_value) })), file.path(dir, "dsi_null_tests.csv"))
        }
        if (!is.null(app_state$comparison)) {
          readr::write_csv(app_state$comparison$attribution, file.path(dir, "comparison_fix_attribution.csv"))
          readr::write_csv(app_state$comparison$windows, file.path(dir, "comparison_windows.csv"))
          readr::write_csv(app_state$comparison$groups, file.path(dir, "comparison_groups.csv"))
        }
        if ("html_report" %in% items) dsi_write_report(app_state, file.path(dir, "dsi_report.html"))
        if ("r_script" %in% items) {
          dir.create(file.path(dir, "data")); dir.create(file.path(dir, "dsicore"))
          readr::write_csv(app_state$data_raw, file.path(dir, "data", "input_data.csv"))
          file.copy(list.files("R", pattern = "^dsicore_.*[.]R$", full.names = TRUE), file.path(dir, "dsicore"))
          yaml::write_yaml(s, file.path(dir, "dsi_settings.yaml"), precision = 17)
          if (!file.exists(file.path(dir, "dsi_selected_windows.csv"))) readr::write_csv(summ, file.path(dir, "dsi_selected_windows.csv"))
          writeLines(dsi_reproduce_script(), file.path(dir, "reproduce_dsi_analysis.R"))
        }
        old <- setwd(dirname(dir)); on.exit(setwd(old), add = TRUE)
        zip::zip(file, files = basename(dir), recurse = TRUE)
        app_state$export_count <- app_state$export_count + 1
        mark_done(app_state, "report")
      }, contentType = "application/zip")
  })
}

#' Standalone reproduction script written into the export
#' @keywords internal
dsi_reproduce_script <- function() {
  c(
    "## DSI analysis: standalone reproduction script (generated by DSI Studio)",
    paste0("## Generated ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    "## Run from the unzipped export folder:  Rscript reproduce_dsi_analysis.R",
    "## Needs: dplyr, tidyr, readr, yaml",
    "suppressMessages({library(dplyr); library(tidyr); library(readr); library(yaml)})",
    "for (f in sort(list.files('dsicore', pattern = '[.]R$', full.names = TRUE))) source(f)",
    "s <- yaml::read_yaml('dsi_settings.yaml')",
    "col_map <- Filter(Negate(is.null), s$column_mapping)",
    "data <- readr::read_csv('data/input_data.csv', show_col_types = FALSE)",
    "res <- run_dsi_workflow(df = data, col_map = col_map, group_cols = unlist(s$group_cols),",
    "                        min_n = s$min_n, max_n = s$max_n, anchor_mode = s$anchor_mode,",
    "                        method = s$method, effort_semantics = s$effort_semantics,",
    "                        refs = s$refs, weights = s$weights, selection_opts = s$selection_opts,",
    "                        fixes = s$fixes, min_usable = s$min_usable)",
    "readr::write_csv(res$dsi_all, 'reproduced_dsi_all_windows.csv')",
    "readr::write_csv(res$dsi_best, 'reproduced_dsi_best_windows.csv')",
    "ok <- TRUE",
    "if (file.exists('dsi_all_windows.csv')) {",
    "  ref <- readr::read_csv('dsi_all_windows.csv', show_col_types = FALSE)",
    "  new <- readr::read_csv('reproduced_dsi_all_windows.csv', show_col_types = FALSE)",
    "  k <- c('group_key', 'start_year', 'end_year')",
    "  m <- dplyr::inner_join(ref, new, by = k, suffix = c('.ref', '.new'))",
    "  d <- function(v) { x <- abs(m[[paste0(v, '.ref')]] - m[[paste0(v, '.new')]]); if (all(is.na(x))) 0 else max(x, na.rm = TRUE) }",
    "  na_mismatch <- sum(is.na(m$dsi_v2.ref) != is.na(m$dsi_v2.new))",
    "  cat(sprintf('all windows: exported=%d reproduced=%d matched=%d\\n', nrow(ref), nrow(new), nrow(m)))",
    "  cat(sprintf('max |diff| dsi=%.3g dsi_v2=%.3g beta=%.3g p=%.3g; NA pattern mismatches=%d\\n', d('dsi'), d('dsi_v2'), d('beta'), d('p_value'), na_mismatch))",
    "  ok <- ok && nrow(ref) == nrow(new) && nrow(m) == nrow(ref) && d('dsi') < 1e-8 && d('dsi_v2') < 1e-8 && na_mismatch == 0",
    "}",
    "if (file.exists('dsi_best_windows.csv')) {",
    "  ref <- readr::read_csv('dsi_best_windows.csv', show_col_types = FALSE)",
    "  m <- dplyr::inner_join(ref, res$dsi_best, by = 'group_key', suffix = c('.ref', '.new'))",
    "  same <- m$start_year.ref == m$start_year.new & m$end_year.ref == m$end_year.new & m$ready.ref == m$ready.new",
    "  cat(sprintf('best windows: %d/%d groups same window and READY status (READY: %d)\\n', sum(same), nrow(ref), sum(res$dsi_best$ready)))",
    "  ok <- ok && all(same) && nrow(m) == nrow(ref)",
    "}",
    "if (file.exists('dsi_selected_windows.csv')) {",
    "  sel <- readr::read_csv('dsi_selected_windows.csv', show_col_types = FALSE)",
    "  sc <- vapply(seq_len(nrow(sel)), function(i) {",
    "    g <- res$data_std[res$data_std$group_key == sel$group_key[i], ]",
    "    x <- score_window(g, sel$selected_start[i], sel$selected_end[i], refs = s$refs, weights = s$weights,",
    "                      fixes = s$fixes, min_n = s$min_n, min_usable = s$min_usable)",
    "    if (is.null(x$dsi_v2)) NA_real_ else x$dsi_v2 }, numeric(1))",
    "  dd <- abs(sc - sel$selected_dsi_v2); dd[is.na(sc) & is.na(sel$selected_dsi_v2)] <- 0",
    "  cat(sprintf('selected windows (incl. %d user-adjusted): max |diff| dsi_v2=%.3g\\n', sum(sel$window_source == 'user-selected'), max(dd, na.rm = TRUE)))",
    "  ok <- ok && all(!is.na(dd)) && max(dd) < 1e-8",
    "}",
    "cat(if (ok) 'REPRODUCED: scores match the export\\n' else 'MISMATCH: scores differ from the export\\n')",
    "invisible(ok)"
  )
}

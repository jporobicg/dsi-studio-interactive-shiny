## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Module: Data input, column mapping, effort  ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Data input UI
#' @export
mod_data_input_ui <- function(id) {
  ns <- NS(id)
  tagList(
    step_header("Load and map your data",
      "Upload a long table with one row per year (and per species/fleet). Then tell DSI Studio which column holds year, group, catch, effort and CPUE. Column names can be anything.",
      number = 1),
    uiOutput(ns("load_ui")),
    uiOutput(ns("data_preview_ui")),
    uiOutput(ns("column_mapping_ui")),
    uiOutput(ns("effort_semantics_ui")),
    uiOutput(ns("next_ui"))
  )
}

#' Data input server
#' @export
mod_data_input_server <- function(id, app_state) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    set_data <- function(df, name) {
      reset_downstream(app_state, "data")
      app_state$data_raw <- as.data.frame(df)
      app_state$dataset_name <- name
      app_state$effort_semantics <- "per_group_year"
    }

    observeEvent(input$load_demo_main, set_data(load_demo_data("main_groups"), "Thai main groups (example)"))
    observeEvent(input$load_demo_fleet, set_data(load_demo_data("species_fleet"), "Species \u00d7 fleet (example)"))
    observeEvent(input$file_upload, {
      req(input$file_upload)
      ext <- tolower(tools::file_ext(input$file_upload$name))
      df <- tryCatch({
        if (ext %in% c("csv", "txt")) readr::read_csv(input$file_upload$datapath, show_col_types = FALSE, guess_max = 10000)
        else if (ext %in% c("xlsx", "xls")) readxl::read_excel(input$file_upload$datapath)
        else stop("Unsupported file type: ", ext)
      }, error = function(e) { showNotification(paste("Error loading file:", conditionMessage(e)), type = "error"); NULL })
      if (!is.null(df)) set_data(df, input$file_upload$name)
    })

    output$load_ui <- renderUI({
      has <- !is.null(app_state$data_raw)
      upload <- fileInput(ns("file_upload"), NULL, accept = c(".csv", ".txt", ".xlsx", ".xls"),
                          buttonLabel = "Choose file\u2026", placeholder = "CSV or Excel", width = "100%")
      tiles <- div(class = "demo-tiles",
        tags$button(type = "button", id = ns("load_demo_main"), class = "demo-tile action-button",
          span(class = "demo-tile-badge", "Example data"),
          h4("Thai main groups"),
          p("Anchovy, demersal and pelagic groups. One series per group, no fleet column."),
          div(class = "demo-tile-meta", "153 rows \u00b7 1971\u20132024 \u00b7 year, group, yield, effort, cpue")),
        tags$button(type = "button", id = ns("load_demo_fleet"), class = "demo-tile action-button",
          span(class = "demo-tile-badge", "Example data"),
          h4("Species \u00d7 fleet"),
          p("8 species across 6 gears, so DSI is screened for each species-fleet combination."),
          div(class = "demo-tile-meta", "1,874 rows \u00b7 1971\u20132023 \u00b7 species, gear, year, catch, effort, cpue")))
      if (!has) {
        tagList(
          div(class = "empty-state",
            h3("Start with your own catch & effort table"),
            p("Any column names work: you map them in the next step. Long format: one row per year \u00d7 group."),
            upload),
          div(class = "muted", style = "font-size:13px;margin:0 0 6px;", "Or try an example dataset (for demonstration only):"),
          tiles, br())
      } else {
        dsi_card(class = "dataset-card",
          div(class = "dataset-banner",
            div(div(class = "name", app_state$dataset_name),
                div(class = "muted", sprintf("%s rows \u00d7 %d columns", format(nrow(app_state$data_raw), big.mark = ","),
                                             ncol(app_state$data_raw)))),
            div(style = "min-width:260px;flex:1;max-width:420px;", upload)),
          tags$details(tags$summary(class = "muted", style = "font-size:13px;cursor:pointer;", "Load an example dataset instead"),
                       div(style = "margin-top:10px;", tiles)))
      }
    })

    output$data_preview_ui <- renderUI({
      req(app_state$data_raw)
      dsi_card(title = "Preview", DT::dataTableOutput(ns("data_table")))
    })
    output$data_table <- DT::renderDataTable({
      req(app_state$data_raw)
      DT::datatable(head(app_state$data_raw, 200), rownames = FALSE,
                    options = list(pageLength = 6, scrollX = TRUE, dom = "tip"))
    })

    output$column_mapping_ui <- renderUI({
      req(app_state$data_raw)
      df <- app_state$data_raw
      g <- guess_column_mapping(df)
      ch <- c("(none)" = "", names(df))
      sel <- function(role, label, required = FALSE, help = NULL)
        div(selectInput(ns(paste0("map_", role)), tagList(label, if (required) span(class = "req", " *")),
                        choices = ch, selected = g[[role]] %||% "", width = "100%"),
            if (!is.null(help)) div(class = "muted", style = "font-size:12px;margin:-10px 0 10px;", help))
      n_guessed <- sum(vapply(c("year", "catch", "effort"), function(k) !is.null(g[[k]]), TRUE))
      dsi_card(title = "Column mapping",
        p(class = "help", if (n_guessed == 3) "Columns were matched by name. Please check them."
          else "Some required columns could not be matched by name. Pick them below. * = required."),
        div(class = "map-grid",
          sel("year", "Year", TRUE, "Integer year of the observation"),
          sel("species", "Species / group", FALSE, "Optional. Each value is screened separately"),
          sel("fleet", "Fleet / gear", FALSE, "Optional. Crossed with species if both are set"),
          sel("catch", "Catch", TRUE, "Catch or landings (any unit)"),
          sel("effort", "Effort", TRUE, "Fishing effort (any unit)"),
          sel("cpue", "CPUE", FALSE, "Optional. Computed as catch/effort if empty")),
        uiOutput(ns("mapping_check")),
        actionButton(ns("apply_mapping"), "Apply mapping", icon = icon("check"), class = "btn-primary"))
    })

    current_map <- reactive({
      val <- function(k) { v <- input[[paste0("map_", k)]]; if (is.null(v) || !nzchar(v)) NULL else v }
      list(year = val("year"), species = val("species"), fleet = val("fleet"),
           catch = val("catch"), effort = val("effort"), cpue = val("cpue"))
    })

    validate_map <- function(map, df) {
      probs <- character(0)
      for (k in c("year", "catch", "effort")) if (is.null(map[[k]])) probs <- c(probs, sprintf("%s column is required", tools::toTitleCase(k)))
      used <- unlist(map)
      if (any(duplicated(used))) probs <- c(probs, sprintf("Column '%s' is mapped to more than one role", used[duplicated(used)][1]))
      for (k in c("year", "catch", "effort", "cpue")) {
        if (!is.null(map[[k]])) {
          v <- suppressWarnings(as.numeric(df[[map[[k]]]]))
          frac <- mean(is.finite(v) | is.na(df[[map[[k]]]]))
          if (frac < 0.9) probs <- c(probs, sprintf("'%s' (%s) is not numeric", map[[k]], k))
        }
      }
      if (!is.null(map$year) && length(probs) == 0) {
        y <- suppressWarnings(as.integer(df[[map$year]]))
        if (any(!is.na(y) & (y < 1800 | y > 2200))) probs <- c(probs, sprintf("'%s' does not look like years", map$year))
      }
      probs
    }

    output$mapping_check <- renderUI({
      req(app_state$data_raw)
      probs <- validate_map(current_map(), app_state$data_raw)
      if (length(probs)) div(class = "callout warn", tags$ul(style = "margin:0;padding-left:18px;", lapply(probs, tags$li)))
      else if (!is.null(app_state$data_std)) {
        ds <- app_state$data_std
        gk <- make_group_key(ds, app_state$group_cols)
        div(class = "callout ok", sprintf("Mapped: %d group%s (%s), years %d\u2013%d, CPUE %s.",
          length(unique(gk)), if (length(unique(gk)) == 1) "" else "s",
          if (is.null(app_state$group_cols)) "single series" else paste(app_state$group_cols, collapse = " \u00d7 "),
          min(ds$year, na.rm = TRUE), max(ds$year, na.rm = TRUE),
          if (is.null(app_state$col_map$cpue)) "computed as catch/effort" else paste0("from '", app_state$col_map$cpue, "'")))
      }
    })

    observeEvent(input$apply_mapping, {
      req(app_state$data_raw)
      map <- current_map()
      probs <- validate_map(map, app_state$data_raw)
      if (length(probs)) { showNotification(paste(probs, collapse = "; "), type = "error"); return() }
      df_std <- tryCatch(standardize_columns(app_state$data_raw, Filter(Negate(is.null), map)),
                         error = function(e) { showNotification(paste("Mapping error:", conditionMessage(e)), type = "error"); NULL })
      if (is.null(df_std)) return()
      grp <- c(if (!is.null(map$species)) "species", if (!is.null(map$fleet)) "fleet")
      reset_downstream(app_state, "mapping")
      app_state$col_map <- Filter(Negate(is.null), map)
      app_state$group_cols <- if (length(grp)) grp else NULL
      app_state$data_std <- df_std
      app_state$audit <- audit_data(df_std, app_state$group_cols)
      mark_done(app_state, "data")
      showNotification("Mapping applied. Review Effort Semantics below, then continue to Audit.", type = "message", duration = 4)
    })

    output$effort_semantics_ui <- renderUI({
      req(app_state$data_std)
      ds <- app_state$data_std
      gc <- app_state$group_cols
      imp <- effort_semantics_impact(ds, gc)
      has_fleet <- "fleet" %in% gc
      lab <- c(
        per_row = "Each row keeps its own effort",
        per_group_year = sprintf("One effort per %s and year (duplicates averaged)", if (is.null(gc)) "series" else paste(gc, collapse = " \u00d7 ")),
        per_fleet_year = if (has_fleet) "Effort is a fleet quantity: shared by all species in a fleet-year (averaged, gaps filled)"
                         else "One effort shared by all groups in a year (averaged across groups)")
      desc <- function(o) {
        r <- imp[imp$option == o, ]
        if (r$rows_changed == 0 && r$rows_filled == 0) span(class = "muted", "No effort values change for this dataset.")
        else span(class = if (o == "per_fleet_year") "poor-text" else "moderate-text",
                  sprintf("Changes effort in %d row%s%s.", r$rows_changed, if (r$rows_changed == 1) "" else "s",
                          if (r$rows_filled > 0) sprintf(", fills %d missing", r$rows_filled) else ""))
      }
      choice_names <- lapply(names(lab), function(o) tagList(strong(lab[[o]]), br(), desc(o)))
      dsi_card(title = "Effort semantics",
        p(class = "help", "How should effort be read? This changes the effort values used in every DSI computation. The impact line shows what each option would do to your data."),
        radioButtons(ns("effort_semantics"), NULL, choiceNames = choice_names, choiceValues = names(lab),
                     selected = isolate(app_state$effort_semantics), width = "100%"))
    })
    observeEvent(input$effort_semantics, {
      if (!identical(input$effort_semantics, app_state$effort_semantics)) {
        app_state$effort_semantics <- input$effort_semantics
      }
    }, ignoreInit = TRUE)

    output$next_ui <- renderUI({
      req(app_state$data_std)
      div(class = "step-footer", next_step_button("audit", "Continue to Audit"))
    })
  })
}

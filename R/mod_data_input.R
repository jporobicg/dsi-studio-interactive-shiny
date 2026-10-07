## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Module: Data input, column mapping, effort  ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

DSI_MAP_ROLES <- c("year", "species", "fleet", "catch", "effort", "cpue")
DSI_ROLE_LABELS <- c(year = "Year", species = "Species / group", fleet = "Fleet / gear",
                     catch = "Catch", effort = "Effort", cpue = "CPUE")

#' Check a column mapping against the data
#' @param map Named list role -> column (NULL for unmapped)
#' @param df Data frame
#' @return Character vector of problems (empty when the mapping is usable)
#' @keywords internal
validate_column_map <- function(map, df) {
  probs <- character(0)
  for (k in c("year", "catch", "effort")) if (is.null(map[[k]])) probs <- c(probs, sprintf("%s column is required", tools::toTitleCase(k)))
  used <- unlist(map)
  if (any(duplicated(used))) probs <- c(probs, sprintf("Column '%s' is mapped to more than one role", used[duplicated(used)][1]))
  gone <- setdiff(used, names(df))
  if (length(gone)) return(c(probs, sprintf("Column '%s' is not in the data", gone[1])))
  for (k in c("year", "catch", "effort", "cpue")) {
    if (!is.null(map[[k]])) {
      v <- suppressWarnings(as.numeric(df[[map[[k]]]]))
      frac <- mean(is.finite(v) | is.na(df[[map[[k]]]]))
      if (!isTRUE(frac >= 0.9)) probs <- c(probs, sprintf("'%s' (%s) is not numeric", map[[k]], k))
    }
  }
  if (!is.null(map$year) && length(probs) == 0) {
    y <- suppressWarnings(as.integer(df[[map$year]]))
    if (any(!is.na(y) & (y < 1800 | y > 2200))) probs <- c(probs, sprintf("'%s' does not look like years", map$year))
  }
  probs
}

## Mapping without empty roles, in a fixed order (for comparisons)
.clean_map <- function(map) {
  map <- map[intersect(DSI_MAP_ROLES, names(map))]
  Filter(function(v) !is.null(v) && nzchar(v), map)
}

#' Data input UI
#' @param id Module namespace id
#' @export
mod_data_input_ui <- function(id) {
  ns <- NS(id)
  tagList(
    step_header("Load and map your data",
      "Upload a catch and effort table (or two files / Excel sheets), long or wide. DSI Studio detects the layout -- including a two-row fleet \u00d7 species catch header -- the columns and the effort level. Check the summary and change anything that is wrong.",
      number = 1),
    uiOutput(ns("load_ui")),
    uiOutput(ns("sheet_ui")),
    uiOutput(ns("detect_ui")),
    uiOutput(ns("data_preview_ui")),
    uiOutput(ns("column_mapping_ui")),
    uiOutput(ns("effort_semantics_ui")),
    uiOutput(ns("next_ui"))
  )
}

#' Data input server
#' @param id Module namespace id
#' @param app_state Shared [shiny::reactiveValues()] holding the app state
#' @export
mod_data_input_server <- function(id, app_state) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    ## epoch changes with every new table so inputs from the previous table
    ## can never be applied to the new one
    src <- reactiveValues(epoch = 0, raw = NULL, name = NULL, info = NULL, match = NULL, auto = FALSE,
                          path = NULL, file = NULL, sheets = NULL, sheet_sel = NULL)

    ## ---- building the long table ----
    build_info <- function(df, value_role = NULL) {
      df <- as.data.frame(df, stringsAsFactors = FALSE, check.names = FALSE)
      lay <- detect_data_layout(df)
      if (identical(lay$shape, "long")) return(list(data = df, layout = lay, note = NULL, ask_role = FALSE, needs_input = FALSE))
      long <- reshape_to_long(df, lay, value_role)
      note <- attr(long, "reshape_note"); attr(long, "reshape_note") <- NULL
      ask <- is.null(lay$var_col) && is.null(lay$compound)
      list(data = long, layout = lay, note = note, ask_role = ask,
           value_role = value_role %||% lay$value_role,
           needs_input = ask && is.null(value_role) && !isTRUE(lay$value_role_certain))
    }

    apply_map <- function(map, auto = FALSE) {
      map <- .clean_map(map)
      df_std <- tryCatch(standardize_columns(app_state$data_raw, map),
                         error = function(e) { showNotification(paste("Mapping error:", conditionMessage(e)), type = "error"); NULL })
      if (is.null(df_std)) return(FALSE)
      grp <- intersect(c("species", "fleet"), names(map))
      labels <- lapply(map[grp], function(x) .role_label(x, "group"))
      det <- detect_effort_level(df_std, grp, labels)
      reset_downstream(app_state, "mapping")
      app_state$effort_semantics <- det$semantics
      app_state$effort_detect <- det
      app_state$col_map <- map
      app_state$group_cols <- if (length(grp)) grp else NULL
      app_state$data_std <- df_std
      app_state$audit <- audit_data(df_std, app_state$group_cols)
      mark_done(app_state, "data")
      src$auto <- auto
      TRUE
    }

    clear_map <- function() {
      reset_downstream(app_state, "mapping")
      app_state$steps_completed <- setdiff(app_state$steps_completed, "data")
      app_state$data_std <- NULL; app_state$col_map <- NULL; app_state$group_cols <- NULL
      app_state$effort_detect <- NULL
    }

    set_data <- function(info, name) {
      reset_downstream(app_state, "data")
      src$epoch <- src$epoch + 1
      src$info <- info
      src$auto <- FALSE
      app_state$data_raw <- as.data.frame(info$data, stringsAsFactors = FALSE, check.names = FALSE)
      app_state$dataset_name <- name
      app_state$effort_semantics <- "per_group_year"
      app_state$effort_detect <- NULL
      m <- match_columns(app_state$data_raw)
      src$match <- m
      if (m$confident && !isTRUE(info$needs_input) && !length(validate_column_map(m$map, app_state$data_raw)))
        apply_map(m$map, auto = TRUE)
    }

    load_table <- function(df, name, value_role = NULL) {
      src$raw <- as.data.frame(df, stringsAsFactors = FALSE, check.names = FALSE)
      src$name <- name
      info <- tryCatch(build_info(src$raw, value_role), error = function(e) {
        showNotification(paste("Could not reshape the table:", conditionMessage(e)), type = "warning")
        list(data = src$raw, layout = list(shape = "long"), note = NULL, ask_role = FALSE, needs_input = FALSE)
      })
      set_data(info, name)
    }

    read_sheet <- function(sheet) as.data.frame(readxl::read_excel(src$path, sheet = sheet, .name_repair = "minimal"), check.names = FALSE)

    load_workbook <- function(sel) {
      src$sheet_sel <- sel
      if (identical(sel$mode, "combine")) {
        roles <- c(catch = sel$catch, effort = sel$effort, cpue = sel$cpue)
        roles <- roles[!is.na(roles) & nzchar(roles)]
        out <- tryCatch({
          tabs <- lapply(roles, read_sheet)
          combine_sheets(tabs, labels = unname(roles))
        }, error = function(e) { showNotification(paste("Could not combine sheets:", conditionMessage(e)), type = "error"); NULL })
        if (is.null(out)) return()
        note <- attr(out, "reshape_note"); attr(out, "reshape_note") <- NULL
        src$raw <- NULL
        set_data(list(data = out, layout = list(shape = "sheets"), note = note, ask_role = FALSE, needs_input = FALSE),
                 sprintf("%s (%s)", src$file, paste(roles, collapse = " + ")))
      } else {
        df <- tryCatch(read_sheet(sel$single), error = function(e) {
          showNotification(paste("Error reading sheet:", conditionMessage(e)), type = "error"); NULL })
        if (!is.null(df)) load_table(df, if (length(src$sheets) > 1) sprintf("%s (%s)", src$file, sel$single) else src$file)
      }
    }

    observeEvent(input$load_demo_main, {
      src$sheets <- NULL
      load_table(load_demo_data("main_groups"), "Thai main groups (example)")
    })
    observeEvent(input$load_demo_fleet, {
      src$sheets <- NULL
      load_table(load_demo_data("species_fleet"), "Species \u00d7 fleet (example)")
    })
    ## Classify two tables as catch + effort (layout and file names)
    classify_pair <- function(dfs, names) {
      roles <- sheet_roles(tools::file_path_sans_ext(basename(names)))
      lay <- lapply(dfs, detect_data_layout)
      catch_i <- which(vapply(lay, function(l) identical(l$shape, "wide_fleet_species"), logical(1)))
      if (!length(catch_i)) catch_i <- which(roles %in% "catch")
      if (!length(catch_i)) catch_i <- which(vapply(lay, function(l) isTRUE(l$value_role_certain) &&
                                                                   identical(l$value_role, "catch"), logical(1)))
      effort_i <- which(roles %in% "effort")
      ci <- if (length(catch_i)) catch_i[1] else 0L
      if (!length(effort_i)) {
        effort_i <- which(vapply(seq_along(lay), function(i)
          identical(lay[[i]]$shape, "wide_years_rows") && i != ci, logical(1)))
      }
      if (!length(effort_i)) effort_i <- setdiff(seq_along(dfs), ci)
      if (!length(catch_i) || !length(effort_i) || catch_i[1] == effort_i[1])
        stop("Could not tell which file is catch and which is effort. Name them catch/effort, or use an Excel workbook with two sheets.")
      list(catch = dfs[[catch_i[1]]], effort = dfs[[effort_i[1]]],
           catch_name = names[catch_i[1]], effort_name = names[effort_i[1]])
    }

    load_pair <- function(catch_df, effort_df, catch_name, effort_name, label = NULL) {
      out <- tryCatch(combine_sheets(list(catch = catch_df, effort = effort_df),
                                     labels = c(catch_name, effort_name)),
                      error = function(e) {
                        showNotification(paste("Could not combine catch and effort:", conditionMessage(e)), type = "error")
                        NULL })
      if (is.null(out)) return()
      note <- attr(out, "reshape_note"); attr(out, "reshape_note") <- NULL
      src$raw <- NULL; src$sheets <- NULL
      nm <- label %||% sprintf("%s + %s", catch_name, effort_name)
      set_data(list(data = out, layout = list(shape = "sheets"), note = note, ask_role = FALSE, needs_input = FALSE), nm)
    }

    observeEvent(input$file_upload, {
      req(input$file_upload)
      f <- input$file_upload
      n <- nrow(f)
      if (n >= 2) {
        ext <- tolower(tools::file_ext(f$name))
        if (!all(ext %in% c("csv", "txt", "tsv", "xlsx", "xls"))) {
          showNotification("Two-file upload supports CSV/TXT or Excel only.", type = "error"); return()
        }
        dfs <- vector("list", n); ok <- TRUE
        for (i in seq_len(n)) {
          e <- ext[i]
          dfs[[i]] <- tryCatch({
            if (e %in% c("xlsx", "xls")) {
              sh <- readxl::excel_sheets(f$datapath[i])[1]
              as.data.frame(readxl::read_excel(f$datapath[i], sheet = sh, .name_repair = "minimal"),
                            check.names = FALSE)
            } else read_table_file(f$datapath[i])
          }, error = function(err) {
            showNotification(paste("Error loading", f$name[i], ":", conditionMessage(err)), type = "error")
            ok <<- FALSE; NULL })
        }
        if (!ok || any(vapply(dfs, is.null, logical(1)))) return()
        pair <- tryCatch(classify_pair(dfs[1:2], f$name[1:2]), error = function(e) {
          showNotification(conditionMessage(e), type = "error"); NULL })
        if (is.null(pair)) return()
        load_pair(pair$catch, pair$effort, pair$catch_name, pair$effort_name)
        return()
      }
      ext <- tolower(tools::file_ext(f$name[1]))
      if (ext %in% c("xlsx", "xls")) {
        sheets <- tryCatch(readxl::excel_sheets(f$datapath[1]), error = function(e) {
          showNotification(paste("Error loading file:", conditionMessage(e)), type = "error"); NULL })
        if (is.null(sheets)) return()
        src$path <- f$datapath[1]; src$file <- f$name[1]; src$sheets <- sheets
        roles <- sheet_roles(sheets)
        cs <- names(roles)[roles %in% "catch"][1]; es <- names(roles)[roles %in% "effort"][1]
        cp <- names(roles)[roles %in% "cpue"][1]
        sel <- if (length(sheets) > 1 && !is.na(cs) && !is.na(es))
          list(mode = "combine", single = sheets[1], catch = cs, effort = es, cpue = if (is.na(cp)) "" else cp)
        else list(mode = "single", single = sheets[1], catch = sheets[1], effort = sheets[min(2, length(sheets))], cpue = "")
        load_workbook(sel)
      } else if (ext %in% c("csv", "txt", "tsv")) {
        src$sheets <- NULL
        df <- tryCatch(read_table_file(f$datapath[1]), error = function(e) {
          showNotification(paste("Error loading file:", conditionMessage(e)), type = "error"); NULL })
        if (!is.null(df)) load_table(df, f$name[1])
      } else showNotification(paste("Unsupported file type:", ext), type = "error")
    })

    ## ---- load card ----
    output$load_ui <- renderUI({
      has <- !is.null(app_state$data_raw)
      upload <- fileInput(ns("file_upload"), NULL, multiple = TRUE,
                          accept = c(".csv", ".txt", ".tsv", ".xlsx", ".xls"),
                          buttonLabel = "Choose file\u2026", placeholder = "CSV / Excel (one or two files)", width = "100%")
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
            p("Any column names work. Long or wide tables, a two-row fleet \u00d7 species catch header, two CSV files (catch + effort), or an Excel workbook with catch and effort sheets are detected."),
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

    ## ---- workbook sheets ----
    output$sheet_ui <- renderUI({
      req(src$sheets, length(src$sheets) > 1, !is.null(app_state$data_raw))
      src$path
      sel <- isolate(src$sheet_sel)
      sh <- src$sheets
      dsi_card(title = "Workbook sheets",
        p(class = "help", sprintf("%d sheets found. Use one sheet, or combine a catch sheet and an effort sheet (long, wide, or a two-row fleet \u00d7 species catch header). They are joined by year and group.", length(sh))),
        radioButtons(ns("sheet_mode"), NULL, inline = TRUE, selected = sel$mode,
                     choices = c("One sheet" = "single", "Catch and effort on separate sheets" = "combine")),
        conditionalPanel(sprintf("input['%s'] == 'single'", ns("sheet_mode")),
          div(style = "max-width:320px;", selectInput(ns("sheet_single"), "Sheet", choices = sh, selected = sel$single))),
        conditionalPanel(sprintf("input['%s'] == 'combine'", ns("sheet_mode")),
          div(class = "map-grid",
            selectInput(ns("sheet_catch"), "Catch sheet", choices = sh, selected = sel$catch),
            selectInput(ns("sheet_effort"), "Effort sheet", choices = sh, selected = sel$effort),
            selectInput(ns("sheet_cpue"), "CPUE sheet (optional)", choices = c("(none)" = "", sh), selected = sel$cpue))))
    })
    observeEvent(list(input$sheet_mode, input$sheet_single, input$sheet_catch, input$sheet_effort, input$sheet_cpue), {
      req(src$sheets, input$sheet_mode)
      sel <- list(mode = input$sheet_mode, single = input$sheet_single %||% src$sheet_sel$single,
                  catch = input$sheet_catch %||% src$sheet_sel$catch, effort = input$sheet_effort %||% src$sheet_sel$effort,
                  cpue = input$sheet_cpue %||% "")
      if (!all(c(sel$single, sel$catch, sel$effort) %in% src$sheets)) return()
      old <- src$sheet_sel
      same <- identical(sel$mode, old$mode) &&
        if (sel$mode == "single") identical(sel$single, old$single)
        else identical(sel[c("catch", "effort", "cpue")], old[c("catch", "effort", "cpue")])
      if (same) return()
      if (sel$mode == "combine" && identical(sel$catch, sel$effort)) {
        showNotification("Pick different sheets for catch and effort.", type = "warning"); return()
      }
      load_workbook(sel)
    }, ignoreInit = TRUE)

    ## ---- detection summary ----
    output$detect_ui <- renderUI({
      req(app_state$data_raw, src$info)
      info <- src$info; df <- app_state$data_raw; m <- src$match
      applied <- !is.null(app_state$data_std)
      map <- if (applied) app_state$col_map else .clean_map(m$map)
      st <- describe_structure(df, map)
      shape <- if (!is.null(info$note)) info$note else "Long table (one row per year and group)"
      short <- c(year = "year", species = "species/group", fleet = "fleet", catch = "catch", effort = "effort", cpue = "CPUE")
      map_txt <- paste(vapply(names(map), function(k) sprintf("%s = '%s'", short[[k]], map[[k]]), ""), collapse = ", ")
      issues <- character(0)
      if (!applied) {
        miss <- setdiff(c("year", "catch", "effort"), names(map))
        if (length(miss)) issues <- c(issues, sprintf("No column found for %s.", paste(miss, collapse = ", ")))
        loose <- names(m$confidence)[m$confidence != "name" & names(m$confidence) %in% names(map)]
        for (k in loose) issues <- c(issues, sprintf("%s matched loosely to '%s'.", DSI_ROLE_LABELS[[k]], map[[k]]))
        for (k in intersect(names(m$alternatives), names(map)))
          issues <- c(issues, sprintf("%s could also be %s.", DSI_ROLE_LABELS[[k]], paste0("'", m$alternatives[[k]], "'", collapse = " or ")))
        if (isTRUE(info$ask_role) && "effort" %in% miss && !identical(info$value_role, "effort"))
          issues <- c(issues, if (length(src$sheets) > 1) "To take effort from another sheet, choose 'Catch and effort on separate sheets' above."
                              else "Add an effort column (one value per year), or load an Excel workbook with catch and effort sheets.")
        if (isTRUE(info$needs_input)) issues <- c(issues, "Check what the values in the group columns are.")
        if (!length(issues)) issues <- "Check the mapping below and apply it."
      }
      line <- function(label, ...) div(style = "margin:2px 0;", strong(label), " ", ...)
      role_pick <- if (isTRUE(info$ask_role))
        div(style = "max-width:320px;margin-top:6px;",
            selectInput(ns(paste0("value_role_", src$epoch)), "Values in the group columns are",
                        choices = c("Catch" = "catch", "Effort" = "effort", "CPUE" = "cpue"),
                        selected = info$value_role %||% "catch"))
      dsi_card(title = "What was detected", class = "detect-card",
        div(class = paste("callout", if (applied) "ok" else "warn"), style = "margin-top:0;",
          line("Layout:", sprintf("%s. %s.", shape, st$text)),
          if (length(map)) line("Columns:", map_txt),
          if (applied && !is.null(app_state$effort_detect)) line("Effort:", app_state$effort_detect$message),
          if (applied) div(style = "margin-top:6px;", if (isTRUE(src$auto)) "Mapping applied automatically. Change it below if anything is wrong." else "Mapping applied. Change it below if needed.")
          else div(style = "margin-top:6px;", tags$ul(style = "margin:0;padding-left:18px;", lapply(issues, tags$li)))),
        role_pick)
    })
    observeEvent(input[[paste0("value_role_", src$epoch)]], {
      v <- input[[paste0("value_role_", src$epoch)]]
      req(v, src$raw, src$info$ask_role)
      if (identical(v, src$info$value_role)) return()
      info <- tryCatch(build_info(src$raw, v), error = function(e) NULL)
      if (!is.null(info)) set_data(info, src$name)
    }, ignoreInit = TRUE)

    ## ---- preview ----
    output$data_preview_ui <- renderUI({
      req(app_state$data_raw)
      dsi_card(title = "Preview",
        if (!is.null(src$info$note)) p(class = "help", "The table below is the long table built from your file."),
        DT::dataTableOutput(ns("data_table")))
    })
    output$data_table <- DT::renderDataTable({
      req(app_state$data_raw)
      DT::datatable(head(app_state$data_raw, 200), rownames = FALSE,
                    options = list(pageLength = 6, scrollX = TRUE, dom = "tip"))
    })

    ## ---- column mapping ----
    map_id <- function(role) paste0("map_", role, "_", src$epoch)
    output$column_mapping_ui <- renderUI({
      req(app_state$data_raw)
      ep <- src$epoch
      df <- app_state$data_raw
      g <- isolate(src$match$map) %||% list()
      ch <- c("(none)" = "", names(df))
      sel <- function(role, required = FALSE, help = NULL)
        div(selectInput(ns(paste0("map_", role, "_", ep)), tagList(DSI_ROLE_LABELS[[role]], if (required) span(class = "req", " *")),
                        choices = ch, selected = g[[role]] %||% "", width = "100%"),
            if (!is.null(help)) div(class = "muted", style = "font-size:12px;margin:-10px 0 10px;", help))
      auto <- isolate(isTRUE(src$auto) && !is.null(app_state$data_std))
      body <- tagList(
        p(class = "help", if (auto) "Columns were matched by name. Changes are applied as you make them."
          else "Pick the column for each role. * = required."),
        div(class = "map-grid",
          sel("year", TRUE, "Integer year of the observation"),
          sel("species", FALSE, "Optional. Each value is screened separately"),
          sel("fleet", FALSE, "Optional. Crossed with species if both are set"),
          sel("catch", TRUE, "Catch or landings (any unit)"),
          sel("effort", TRUE, "Fishing effort (any unit)"),
          sel("cpue", FALSE, "Optional. Computed as catch/effort if empty")),
        uiOutput(ns("mapping_check")),
        uiOutput(ns("apply_ui")))
      if (auto)
        tags$details(class = "dsi-card dsi-advanced map-details",
          tags$summary("Column mapping", span(class = "muted", style = "font-weight:400;font-size:13px;", "matched automatically \u00b7 open to change")),
          div(class = "adv-body", body))
      else dsi_card(title = "Column mapping", body)
    })

    current_map <- reactive({
      req(app_state$data_raw)
      vals <- lapply(DSI_MAP_ROLES, function(k) input[[map_id(k)]])
      if (any(vapply(vals, is.null, logical(1)))) return(NULL)
      names(vals) <- DSI_MAP_ROLES
      lapply(vals, function(v) if (nzchar(v)) v else NULL)
    })
    map_debounced <- debounce(current_map, 300)

    output$mapping_check <- renderUI({
      req(app_state$data_raw)
      map <- current_map(); req(map)
      probs <- validate_column_map(map, app_state$data_raw)
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

    output$apply_ui <- renderUI({
      if (!is.null(app_state$data_std)) return(NULL)
      actionButton(ns("apply_mapping"), "Apply mapping", icon = icon("check"), class = "btn-primary")
    })

    observeEvent(input$apply_mapping, {
      req(app_state$data_raw)
      map <- current_map(); req(map)
      probs <- validate_column_map(map, app_state$data_raw)
      if (length(probs)) { showNotification(paste(probs, collapse = "; "), type = "error"); return() }
      if (apply_map(map, auto = FALSE))
        showNotification("Mapping applied. Check effort below, then continue to Audit.", type = "message", duration = 4)
    })

    ## once a mapping is in place, edits are applied straight away
    observeEvent(map_debounced(), {
      map <- map_debounced()
      if (is.null(map) || is.null(app_state$data_raw) || is.null(app_state$col_map)) return()
      if (identical(.clean_map(map), .clean_map(app_state$col_map))) return()
      if (length(validate_column_map(map, app_state$data_raw))) { clear_map(); return() }
      if (apply_map(map, auto = FALSE)) showNotification("Mapping updated.", type = "message", duration = 2)
    }, ignoreInit = TRUE)

    ## ---- effort semantics ----
    output$effort_semantics_ui <- renderUI({
      req(app_state$data_std)
      ds <- app_state$data_std
      gc <- app_state$group_cols
      det <- app_state$effort_detect
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
      detected <- det$semantics %||% ""
      choice_names <- lapply(names(lab), function(o) tagList(strong(lab[[o]]),
        if (o == detected) span(class = "muted", " (detected)"), br(), desc(o)))
      dsi_card(title = "Effort semantics",
        if (!is.null(det)) div(class = paste("callout", if (isTRUE(det$mixed)) "warn" else "ok"), style = "margin-top:0;", det$message),
        p(class = "help", style = "margin-top:0;", "How should effort be read? This changes the effort values used in every DSI computation. The impact line shows what each option would do to your data."),
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

## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Module: Data Input ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Data input UI
#' 
#' @param id Module ID
#' @export
mod_data_input_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    h3("Data Input & Mapping"),
    
    card(
      card_header("1. Load Data"),
      card_body(
        fileInput(ns("file_upload"), "Upload CSV or XLSX",
                 accept = c(".csv", ".xlsx", ".xls"),
                 width = "100%"),
        
        actionButton(ns("load_demo_main"), "Load Demo: Main Groups",
                    icon = icon("database"),
                    class = "btn-outline-primary btn-sm"),
        
        actionButton(ns("load_demo_fleet"), "Load Demo: Species × Fleet",
                    icon = icon("database"),
                    class = "btn-outline-primary btn-sm ms-2")
      )
    ),
    
    uiOutput(ns("data_preview_ui")),
    
    uiOutput(ns("column_mapping_ui")),
    
    uiOutput(ns("effort_semantics_ui"))
  )
}

#' Data input server
#' 
#' @param id Module ID
#' @param app_state Application state
#' @export
mod_data_input_server <- function(id, app_state) {
  moduleServer(id, function(input, output, session) {
    
    data_raw <- reactiveVal(NULL)
    data_std <- reactiveVal(NULL)
    col_map <- reactiveVal(NULL)
    group_cols <- reactiveVal(NULL)
    
    observeEvent(input$load_demo_main, {
      df <- load_demo_data("main_groups")
      data_raw(df)
      app_state$data_raw <- df
      app_state$dataset_name <- "Thai Main Groups (demo)"
    })
    
    observeEvent(input$load_demo_fleet, {
      df <- load_demo_data("species_fleet")
      data_raw(df)
      app_state$data_raw <- df
      app_state$dataset_name <- "Species × Fleet (demo)"
    })
    
    observeEvent(input$file_upload, {
      req(input$file_upload)
      
      ext <- tools::file_ext(input$file_upload$name)
      
      df <- tryCatch({
        if (ext == "csv") {
          readr::read_csv(input$file_upload$datapath, show_col_types = FALSE)
        } else if (ext %in% c("xlsx", "xls")) {
          readxl::read_excel(input$file_upload$datapath)
        } else {
          NULL
        }
      }, error = function(e) {
        showNotification(paste("Error loading file:", e$message), type = "error")
        NULL
      })
      
      if (!is.null(df)) {
        data_raw(df)
        app_state$data_raw <- df
        app_state$dataset_name <- input$file_upload$name
      }
    })
    
    output$data_preview_ui <- renderUI({
      req(data_raw())
      
      ns <- session$ns
      
      card(
        card_header("Data Preview"),
        card_body(
          p(sprintf("%d rows × %d columns", nrow(data_raw()), ncol(data_raw()))),
          DT::dataTableOutput(ns("data_table"))
        )
      )
    })
    
    output$data_table <- DT::renderDataTable({
      req(data_raw())
      
      DT::datatable(
        head(data_raw(), 100),
        options = list(
          pageLength = 10,
          scrollX = TRUE,
          dom = 'tp'
        ),
        rownames = FALSE
      )
    })
    
    output$column_mapping_ui <- renderUI({
      req(data_raw())
      
      ns <- session$ns
      df <- data_raw()
      
      guessed_map <- guess_column_mapping(df)
      
      col_choices <- c("(none)" = "", names(df))
      
      card(
        card_header("2. Column Mapping"),
        card_body(
          layout_column_wrap(
            width = 1/3,
            
            selectInput(ns("map_year"), "Year column",
                       choices = col_choices,
                       selected = guessed_map$year %||% ""),
            
            selectInput(ns("map_species"), "Species column",
                       choices = col_choices,
                       selected = guessed_map$species %||% ""),
            
            selectInput(ns("map_fleet"), "Fleet column (optional)",
                       choices = col_choices,
                       selected = guessed_map$fleet %||% ""),
            
            selectInput(ns("map_catch"), "Catch column",
                       choices = col_choices,
                       selected = guessed_map$catch %||% ""),
            
            selectInput(ns("map_effort"), "Effort column",
                       choices = col_choices,
                       selected = guessed_map$effort %||% ""),
            
            selectInput(ns("map_cpue"), "CPUE column (optional)",
                       choices = col_choices,
                       selected = guessed_map$cpue %||% "")
          ),
          
          div(
            style = "margin-top: 1rem;",
            actionButton(ns("apply_mapping"), "Apply Mapping & Continue",
                        icon = icon("arrow-right"),
                        class = "btn-primary")
          )
        )
      )
    })
    
    observeEvent(input$apply_mapping, {
      req(data_raw())
      
      map <- list(
        year = if (nzchar(input$map_year)) input$map_year else NULL,
        species = if (nzchar(input$map_species)) input$map_species else NULL,
        fleet = if (nzchar(input$map_fleet)) input$map_fleet else NULL,
        catch = if (nzchar(input$map_catch)) input$map_catch else NULL,
        effort = if (nzchar(input$map_effort)) input$map_effort else NULL,
        cpue = if (nzchar(input$map_cpue)) input$map_cpue else NULL
      )
      
      if (is.null(map$year) || is.null(map$catch) || is.null(map$effort)) {
        showNotification("Year, Catch, and Effort columns are required", type = "error")
        return()
      }
      
      df_std <- tryCatch({
        standardize_columns(data_raw(), map)
      }, error = function(e) {
        showNotification(paste("Standardization error:", e$message), type = "error")
        NULL
      })
      
      if (!is.null(df_std)) {
        data_std(df_std)
        col_map(map)
        
        grp_cols <- c()
        if (!is.null(map$species)) grp_cols <- c(grp_cols, "species")
        if (!is.null(map$fleet)) grp_cols <- c(grp_cols, "fleet")
        if (length(grp_cols) == 0) grp_cols <- NULL
        
        group_cols(grp_cols)
        
        showNotification("Data standardized successfully! You can now proceed to Audit.", type = "message", duration = 3)
      }
    })
    
    output$effort_semantics_ui <- renderUI({
      req(data_std())
      
      ns <- session$ns
      
      card(
        card_header("3. Effort Semantics"),
        card_body(
          radioButtons(
            ns("effort_semantics"),
            "How is effort defined?",
            choices = c(
              "Per group (species × fleet)" = "per_group_year",
              "Per fleet only (shared across species)" = "per_fleet_year",
              "Per row (each row has unique effort)" = "per_row"
            ),
            selected = "per_group_year"
          ),
          
          helpText("Choose how effort values should be interpreted. If in doubt, use 'Per group'.")
        )
      )
    })
    
    return(list(
      data_raw = data_raw,
      data_std = data_std,
      col_map = col_map,
      group_cols = group_cols
    ))
  })
}

## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Module: Data Input (Redesigned) ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Data Input UI
#' @param id Module ID
#' @export
mod_data_input_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    div(class = "step-header",
      h2("Load Your Data"),
      p(class = "step-purpose",
        "Upload your catch and effort time series, or explore with example datasets. ",
        "We'll help you map columns and prepare data for analysis."
      )
    ),
    
    uiOutput(ns("data_content"))
  )
}

#' Data Input Server
#' @param id Module ID
#' @param app_state Application state
#' @export
mod_data_input_server <- function(id, app_state) {
  moduleServer(id, function(input, output, session) {
    
    ns <- session$ns
    
    data_raw <- reactiveVal(NULL)
    data_std <- reactiveVal(NULL)
    col_map <- reactiveVal(NULL)
    group_cols <- reactiveVal(NULL)
    
    output$data_content <- renderUI({
      if (is.null(data_raw())) {
        # Empty state
        tagList(
          div(class = "empty-state",
            div(class = "empty-state-icon", icon("database")),
            h3("Ready to Begin"),
            p("Drop your CSV or Excel file here, or try an example dataset to explore DSI screening."),
            fileInput(ns("file_upload"), NULL,
                     accept = c(".csv", ".xlsx", ".xls"),
                     buttonLabel = "Choose File",
                     placeholder = "No file selected")
          ),
          
          h3(style = "margin-top: 40px; margin-bottom: 16px; font-size: 18px; font-weight: 600;",
             "Example Datasets"),
          p(style = "color: #7F8C8D; margin-bottom: 24px;",
            "Start with curated examples to understand DSI screening. These are marked as example data."),
          
          div(class = "demo-tiles",
            actionButton(ns("load_demo_main"),
              div(class = "demo-tile",
                div(class = "demo-tile-badge", "EXAMPLE DATA"),
                h4("Thai Main Groups"),
                p("Three species groups (Anchovy, Demersal, Pelagic) with complete time series 1971–2024. Clean data, one READY result."),
                div(class = "demo-tile-meta", "153 rows · 3 groups · 54 years")
              ),
              class = "btn-link", style = "all: unset; display: block;"
            ),
            
            actionButton(ns("load_demo_fleet"),
              div(class = "demo-tile",
                div(class = "demo-tile-badge", "EXAMPLE DATA"),
                h4("Species × Fleet Matrix"),
                p("Eight species across six gear types. Includes trailing missing CPUE (2019–2023) to demonstrate audit warnings."),
                div(class = "demo-tile-meta", "1874 rows · 48 groups · 53 years")
              ),
              class = "btn-link", style = "all: unset; display: block;"
            )
          ),
          
          div(class = "dsi-card", style = "margin-top: 32px;",
            h3("Expected Columns"),
            p(style = "margin-bottom: 12px; color: #7F8C8D; font-size: 14px;",
              "Your data should contain time series with:"),
            tags$ul(style = "margin: 0; padding-left: 20px; color: #7F8C8D; font-size: 14px;",
              tags$li(style = "margin-bottom: 6px;", tags$strong("Year"), " or Date"),
              tags$li(style = "margin-bottom: 6px;", tags$strong("Catch"), " (landings, yield)"),
              tags$li(style = "margin-bottom: 6px;", tags$strong("Effort"), " (days, hours, trips)"),
              tags$li(style = "margin-bottom: 6px;", tags$strong("CPUE"), " (optional, derived from Catch/Effort)"),
              tags$li(style = "margin-bottom: 6px;", tags$strong("Species"), " and/or ", tags$strong("Fleet"), " (optional grouping)")
            )
          )
        )
      } else {
        # Mapping UI
        tagList(
          div(class = "dsi-card",
            h3("Data Loaded"),
            p(style = "color: #7F8C8D;",
              sprintf("%d rows loaded. Map columns to proceed.", nrow(data_raw()))
            )
          ),
          
          div(class = "dsi-card",
            h3("Column Mapping"),
            
            layout_columns(
              col_widths = c(6, 6),
              
              selectInput(ns("col_year"), "Year",
                         choices = c("", names(data_raw())),
                         selected = guess_column(names(data_raw()), c("year", "yr", "date"))),
              
              selectInput(ns("col_catch"), "Catch",
                         choices = c("", names(data_raw())),
                         selected = guess_column(names(data_raw()), c("catch", "yield", "landings"))),
              
              selectInput(ns("col_effort"), "Effort",
                         choices = c("", names(data_raw())),
                         selected = guess_column(names(data_raw()), c("effort", "days", "hours"))),
              
              selectInput(ns("col_cpue"), "CPUE (optional)",
                         choices = c("Auto-derive" = "", names(data_raw())),
                         selected = guess_column(names(data_raw()), c("cpue", "catch_per_unit"))),
              
              selectInput(ns("col_species"), "Species (optional)",
                         choices = c("None" = "", names(data_raw())),
                         selected = guess_column(names(data_raw()), c("species", "sp", "group", "stock"))),
              
              selectInput(ns("col_fleet"), "Fleet (optional)",
                         choices = c("None" = "", names(data_raw())),
                         selected = guess_column(names(data_raw()), c("fleet", "gear", "method")))
            ),
            
            div(style = "margin-top: 24px; padding-top: 24px; border-top: 1px solid #E8E8E8;",
              actionButton(ns("apply_mapping"),
                          "Apply Mapping & Continue",
                          class = "btn-primary-action",
                          icon = icon("arrow-right"))
            )
          )
        )
      }
    })
    
    # Load demo data
    observeEvent(input$load_demo_main, {
      df <- readr::read_csv("inst/demo_data/Thai_main_groups.csv", show_col_types = FALSE)
      data_raw(df)
    })
    
    observeEvent(input$load_demo_fleet, {
      df <- readr::read_csv("inst/demo_data/all_species_combined.csv", show_col_types = FALSE)
      data_raw(df)
    })
    
    # Handle file upload
    observeEvent(input$file_upload, {
      req(input$file_upload)
      
      ext <- tools::file_ext(input$file_upload$name)
      
      df <- tryCatch({
        if (ext == "csv") {
          readr::read_csv(input$file_upload$datapath, show_col_types = FALSE)
        } else if (ext %in% c("xlsx", "xls")) {
          readxl::read_excel(input$file_upload$datapath)
        }
      }, error = function(e) {
        showNotification(paste("Error reading file:", e$message), type = "error")
        NULL
      })
      
      if (!is.null(df)) {
        data_raw(df)
      }
    })
    
    # Apply mapping
    observeEvent(input$apply_mapping, {
      req(data_raw())
      req(input$col_year, input$col_catch, input$col_effort)
      
      col_map_list <- list(
        year = input$col_year,
        catch = input$col_catch,
        effort = input$col_effort,
        cpue = if (input$col_cpue != "") input$col_cpue else NULL,
        species = if (input$col_species != "") input$col_species else NULL,
        fleet = if (input$col_fleet != "") input$col_fleet else NULL
      )
      
      # Standardize
      df_std <- standardize_columns(data_raw(), col_map_list)
      
      # Determine grouping columns
      group_cols_vec <- c()
      if (!is.null(col_map_list$species)) group_cols_vec <- c(group_cols_vec, "species")
      if (!is.null(col_map_list$fleet)) group_cols_vec <- c(group_cols_vec, "fleet")
      
      data_std(df_std)
      col_map(col_map_list)
      group_cols(group_cols_vec)
      
      showNotification("Data mapped successfully!", type = "message")
    })
    
    return(list(
      data_raw = data_raw,
      data_std = data_std,
      col_map = col_map,
      group_cols = group_cols
    ))
  })
}

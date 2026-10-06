## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Module: Context Rail (Redesigned) ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Context Rail UI
#' @param id Module ID
#' @export
mod_context_rail_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    div(class = "context-section",
      div(class = "context-label", "DATASET"),
      div(class = "context-value", id = ns("dataset_name"),
          span(class = "empty", "No data loaded"))
    ),
    
    div(class = "context-section",
      div(class = "context-label", "ROWS"),
      div(class = "context-value", id = ns("dataset_rows"),
          span(class = "empty", "—"))
    ),
    
    div(class = "context-section",
      div(class = "context-label", "GROUPS"),
      div(class = "context-value", id = ns("dataset_groups"),
          span(class = "empty", "—"))
    ),
    
    div(class = "context-section",
      div(class = "context-label", "TIME RANGE"),
      div(class = "context-value", id = ns("dataset_years"),
          span(class = "empty", "—"))
    ),
    
    hr(style = "border-top: 1px solid #E8E8E8; margin: 24px 0;"),
    
    div(class = "context-section",
      div(class = "context-label", "METHOD"),
      div(class = "context-value", id = ns("method_name"),
          span(class = "empty", "—"))
    ),
    
    div(class = "context-section",
      div(class = "context-label", "WINDOWS EVALUATED"),
      div(class = "context-value", id = ns("windows_count"),
          span(class = "empty", "—"))
    ),
    
    div(class = "context-section",
      div(class = "context-label", "MEDIAN DSI"),
      div(class = "context-value", id = ns("median_dsi"),
          span(class = "empty", "—"))
    ),
    
    div(class = "context-section",
      div(class = "context-label", "READY GROUPS"),
      div(class = "context-value", id = ns("ready_count"),
          span(class = "empty", "—"))
    )
  )
}

#' Context Rail Server
#' @param id Module ID
#' @param app_state Application state
#' @export
mod_context_rail_server <- function(id, app_state) {
  moduleServer(id, function(input, output, session) {
    
    # Update context when data changes
    observe({
      if (!is.null(app_state$data_std)) {
        df <- app_state$data_std
        
        # Dataset name
        session$sendCustomMessage("updateContext", list(
          id = session$ns("dataset_name"),
          value = "Loaded data",
          empty = FALSE
        ))
        
        # Rows
        session$sendCustomMessage("updateContext", list(
          id = session$ns("dataset_rows"),
          value = format(nrow(df), big.mark = ","),
          empty = FALSE
        ))
        
        # Groups
        if (length(app_state$group_cols) > 0) {
          df$group_key <- make_group_key(df, app_state$group_cols)
          n_groups <- length(unique(df$group_key))
          session$sendCustomMessage("updateContext", list(
            id = session$ns("dataset_groups"),
            value = as.character(n_groups),
            empty = FALSE
          ))
        } else {
          session$sendCustomMessage("updateContext", list(
            id = session$ns("dataset_groups"),
            value = "1",
            empty = FALSE
          ))
        }
        
        # Years
        years <- range(df$year, na.rm = TRUE)
        session$sendCustomMessage("updateContext", list(
          id = session$ns("dataset_years"),
          value = sprintf("%d–%d", years[1], years[2]),
          empty = FALSE
        ))
      }
    })
    
    # Update method
    observe({
      method_label <- switch(app_state$method,
        "corrected" = "Corrected",
        "legacy" = "Legacy",
        "—"
      )
      
      session$sendCustomMessage("updateContext", list(
        id = session$ns("method_name"),
        value = method_label,
        empty = FALSE
      ))
    })
    
    # Update results when screening completes
    observe({
      if (!is.null(app_state$dsi_results)) {
        results <- app_state$dsi_results
        
        # Windows count
        n_windows <- nrow(results$dsi_all)
        n_valid <- sum(results$dsi_all$valid, na.rm = TRUE)
        session$sendCustomMessage("updateContext", list(
          id = session$ns("windows_count"),
          value = sprintf("%d (%d valid)", n_windows, n_valid),
          empty = FALSE
        ))
        
        # Median DSI
        valid_dsi <- results$dsi_all$dsi[results$dsi_all$valid]
        if (length(valid_dsi) > 0) {
          median_val <- median(valid_dsi, na.rm = TRUE)
          session$sendCustomMessage("updateContext", list(
            id = session$ns("median_dsi"),
            value = sprintf("%.1f", median_val),
            empty = FALSE
          ))
        }
        
        # READY count
        n_ready <- sum(results$dsi_best$ready == TRUE, na.rm = TRUE)
        session$sendCustomMessage("updateContext", list(
          id = session$ns("ready_count"),
          value = as.character(n_ready),
          empty = FALSE
        ))
      }
    })
  })
}

# Add JavaScript to update context values
tags$script(HTML("
  Shiny.addCustomMessageHandler('updateContext', function(message) {
    var elem = document.getElementById(message.id);
    if (elem) {
      if (message.empty) {
        elem.innerHTML = '<span class=\"empty\">' + message.value + '</span>';
      } else {
        elem.textContent = message.value;
        elem.className = 'context-value';
      }
    }
  });
"))

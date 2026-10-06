## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Module: Audit ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Audit UI
#' 
#' @param id Module ID
#' @export
mod_audit_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    h3("Data Quality Audit"),
    
    uiOutput(ns("audit_content"))
  )
}

#' Audit server
#' 
#' @param id Module ID
#' @param app_state Application state
#' @export
mod_audit_server <- function(id, app_state) {
  moduleServer(id, function(input, output, session) {
    
    audit_results <- reactive({
      req(app_state$data_std)
      
      audit_data(app_state$data_std, app_state$group_cols)
    })
    
    output$audit_content <- renderUI({
      req(app_state$data_std)
      
      ns <- session$ns
      audit <- audit_results()
      
      if (length(audit) == 0) {
        return(card(
          card_body(
            div(
              class = "alert alert-success",
              icon("check-circle"),
              " No data quality issues detected. Ready to proceed!"
            )
          )
        ))
      }
      
      finding_cards <- lapply(names(audit), function(finding_name) {
        finding <- audit[[finding_name]]
        
        severity_class <- switch(
          finding$severity,
          "warning" = "audit-finding warning",
          "error" = "audit-finding warning",
          "audit-finding info"
        )
        
        div(
          class = severity_class,
          h5(finding_name),
          p(finding$message),
          if (!is.null(finding$data) && nrow(finding$data) > 0) {
            tagList(
              details(
                summary("Show details"),
                DT::dataTableOutput(ns(paste0("audit_table_", finding_name)))
              )
            )
          }
        )
      })
      
      card(
        card_header("Audit Findings"),
        card_body(
          do.call(tagList, finding_cards)
        )
      )
    })
    
    observe({
      audit <- audit_results()
      
      for (finding_name in names(audit)) {
        finding <- audit[[finding_name]]
        
        local({
          fn <- finding_name
          fd <- finding$data
          
          output[[paste0("audit_table_", fn)]] <- DT::renderDataTable({
            if (!is.null(fd) && nrow(fd) > 0) {
              DT::datatable(
                fd,
                options = list(
                  pageLength = 5,
                  scrollX = TRUE,
                  dom = 'tp'
                ),
                rownames = FALSE
              )
            }
          })
        })
      }
    })
    
    observeEvent(app_state$data_std, {
      app_state$audit <- audit_results()
    })
  })
}

## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Module: Audit (Redesigned) ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Audit UI
#' @param id Module ID
#' @export
mod_audit_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    div(class = "step-header",
      h2("Data Quality Audit"),
      p(class = "step-purpose",
        "Review data quality findings. Address any issues before proceeding to screening."
      )
    ),
    
    uiOutput(ns("audit_content"))
  )
}

#' Audit server
#' @param id Module ID
#' @param app_state Application state
#' @export
mod_audit_server <- function(id, app_state) {
  moduleServer(id, function(input, output, session) {
    
    audit_findings <- reactive({
      req(app_state$data_std)
      audit_data(app_state$data_std, app_state$group_cols)
    })
    
    output$audit_content <- renderUI({
      req(app_state$data_std)
      
      findings <- audit_findings()
      
      if (length(findings) == 0) {
        div(class = "dsi-card",
          div(style = "text-align: center; padding: 40px 20px;",
            div(style = "font-size: 48px; color: #009E73; margin-bottom: 16px;",
                icon("check-circle")),
            h3(style = "color: #009E73; margin-bottom: 8px;", "No Issues Found"),
            p(style = "color: #7F8C8D;",
              "Your data passed all quality checks. You can proceed to screening.")
          )
        )
      } else {
        tagList(
          div(class = "dsi-card",
            h3(sprintf("%d Finding%s", length(findings), 
                      if (length(findings) > 1) "s" else "")),
            
            lapply(findings, function(finding) {
              severity_color <- switch(finding$severity,
                "warning" = "#E69F00",
                "info" = "#3498DB",
                "#7F8C8D"
              )
              
              div(style = "padding: 16px; margin-top: 16px; background: white; border-left: 4px solid; border-left-color: %s; border-radius: 4px;",
                div(style = "display: flex; align-items: start;",
                  div(style = "margin-right: 12px; font-size: 20px; color: %s;",
                      icon(if (finding$severity == "warning") "exclamation-triangle" else "info-circle")),
                  div(style = "flex: 1;",
                    div(style = "font-weight: 600; margin-bottom: 4px;", 
                        finding$title),
                    div(style = "color: #7F8C8D; font-size: 14px;",
                        finding$message)
                  )
                )
              )
            })
          )
        )
      }
    })
  })
}

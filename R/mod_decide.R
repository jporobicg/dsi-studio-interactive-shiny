## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Module: Decide ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Decide UI
#' 
#' Decision interface for accepting/flagging/rejecting windows.
#' 
#' @param id Module ID
#' @export
mod_decide_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    h3("Decide: Accept, Flag, or Reject"),
    
    p("Review each group and decide whether to accept the suggested window, flag it for review, or reject it."),
    
    uiOutput(ns("decision_content"))
  )
}

#' Decide server
#' 
#' @param id Module ID
#' @param app_state Application state
#' @export
mod_decide_server <- function(id, app_state) {
  moduleServer(id, function(input, output, session) {
    
    decisions <- reactiveVal(list())
    
    output$decision_content <- renderUI({
      req(app_state$dsi_results)
      
      ns <- session$ns
      
      best <- app_state$dsi_results$dsi_best
      
      if (is.null(best) || nrow(best) == 0) {
        return(card(
          card_header("No Results"),
          card_body("Please run the Screen step first to generate results.")
        ))
      }
      
      # Get current decisions
      current_decisions <- decisions()
      
      # Create decision UI for each group
      decision_cards <- lapply(seq_len(nrow(best)), function(i) {
        row <- best[i, ]
        grp <- row$group_key
        
        # Get current decision for this group
        current <- current_decisions[[grp]]
        if (is.null(current)) {
          current <- list(
            action = if (row$ready) "accept" else "flag",
            rationale = ""
          )
        }
        
        card(
          card_header(
            div(
              style = "display: flex; justify-content: space-between; align-items: center;",
              span(style = "font-weight: bold;", as.character(grp)),
              span(
                style = "font-size: 0.9rem;",
                sprintf("DSI: %.1f | Window: %d–%d | Ready: %s",
                       row$dsi_v2, row$start_year, row$end_year,
                       ifelse(row$ready, "Yes", "No"))
              )
            )
          ),
          card_body(
            layout_columns(
              col_widths = c(8, 4),
              
              div(
                radioButtons(
                  ns(paste0("action_", i)),
                  "Decision:",
                  choices = c(
                    "Accept" = "accept",
                    "Flag for review" = "flag",
                    "Reject" = "reject"
                  ),
                  selected = current$action,
                  inline = TRUE
                ),
                
                textAreaInput(
                  ns(paste0("rationale_", i)),
                  "Rationale (optional):",
                  value = current$rationale,
                  rows = 2,
                  width = "100%"
                )
              ),
              
              div(
                style = "font-size: 0.85rem;",
                tags$dl(
                  tags$dt("Selection reason:"),
                  tags$dd(row$selection_reason %||% "—"),
                  tags$dt("Eligible:"),
                  tags$dd(ifelse(row$eligible, "Yes", "No")),
                  tags$dt("β:"),
                  tags$dd(sprintf("%.3g (p = %.3g)", row$beta, row$p_value))
                )
              )
            )
          )
        )
      })
      
      tagList(
        decision_cards,
        
        div(
          style = "margin-top: 2rem; text-align: center;",
          actionButton(ns("save_decisions"), "Save All Decisions",
                      icon = icon("save"),
                      class = "btn-primary btn-lg")
        )
      )
    })
    
    # Save decisions when button clicked
    observeEvent(input$save_decisions, {
      req(app_state$dsi_results)
      
      best <- app_state$dsi_results$dsi_best
      
      decision_list <- list()
      
      for (i in seq_len(nrow(best))) {
        grp <- best$group_key[i]
        
        action_input <- input[[paste0("action_", i)]]
        rationale_input <- input[[paste0("rationale_", i)]]
        
        decision_list[[as.character(grp)]] <- list(
          group_key = grp,
          action = action_input %||% "flag",
          rationale = rationale_input %||% "",
          timestamp = Sys.time()
        )
      }
      
      decisions(decision_list)
      app_state$decisions <- decision_list
      
      showNotification(
        sprintf("Saved decisions for %d groups", length(decision_list)),
        type = "message",
        duration = 3
      )
    })
    
    return(reactive({
      list(
        decisions = decisions()
      )
    }))
  })
}

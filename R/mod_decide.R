## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Module: Decide                              ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Decide UI
#' @param id Module namespace id
#' @export
mod_decide_ui <- function(id) {
  ns <- NS(id)
  tagList(
    step_header("Accept, flag or reject",
      "One decision per group for the window it will use: the screened best window, or the window you pinned in Explore. READY groups are pre-set to Accept, others to Flag. Nothing counts as decided until you save.",
      number = 5),
    div(class = "decide-toolbar",
      div(class = "dsi-seg", radioButtons(ns("filter"), NULL, inline = TRUE,
        choices = c("All" = "all", "READY" = "ready", "Not ready" = "notready", "Adjusted windows" = "adjusted"))),
      actionButton(ns("accept_ready"), "Accept all READY", class = "btn-outline-primary btn-sm"),
      actionButton(ns("save_decisions"), "Save decisions", icon = icon("floppy-disk"), class = "btn-primary btn-sm"),
      uiOutput(ns("saved_note"), inline = TRUE)),
    uiOutput(ns("decision_content")),
    div(class = "step-footer", actionButton(ns("save_decisions2"), "Save decisions", icon = icon("floppy-disk"), class = "btn-primary me-2"),
        next_step_button("report", "Continue to Report"))
  )
}

#' Decide server
#' @param id Module namespace id
#' @param app_state Shared [shiny::reactiveValues()] holding the app state
#' @export
mod_decide_server <- function(id, app_state) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    safe_id <- function(i) paste0("g", i)

    summ <- reactive({
      req(app_state$dsi_results)
      dsi_group_summary(app_state$dsi_results, app_state$overrides, isolate(app_state$decisions))
    })

    output$decision_content <- renderUI({
      if (is.null(app_state$dsi_results)) return(div(class = "callout", "Run screening first."))
      s <- summ()
      dec <- isolate(app_state$decisions)
      keep <- switch(input$filter %||% "all", all = rep(TRUE, nrow(s)), ready = s$ready, notready = !s$ready,
                     adjusted = s$window_source == "user-selected")
      if (!any(keep)) return(div(class = "callout", "No groups match this filter."))
      cards <- lapply(which(keep), function(i) {
        r <- s[i, ]
        prev_action <- isolate(input[[paste0("action_", safe_id(i))]])
        prev_note <- isolate(input[[paste0("note_", safe_id(i))]])
        act <- prev_action %||% (dec[[r$group_key]]$action %||% if (r$ready) "accept" else "flag")
        note <- prev_note %||% (dec[[r$group_key]]$rationale %||% "")
        dsi_card(class = "decide-card", id = paste0("decide-card-", i),
          title = r$group_key,
          actions = tagList(
            if (r$ready) span(class = "badge-pill badge-ready", "READY") else span(class = "badge-pill badge-notready", "Not ready"),
            if (r$window_source == "user-selected") span(class = "badge-pill badge-user", "Adjusted window"),
            if (!is.null(dec[[r$group_key]])) span(class = "badge-pill", style = "background:#EEF5EC;color:#3C763D;", paste("saved:", dec[[r$group_key]]$action))),
          div(class = "decide-row",
            tags$dl(class = "kv",
              tags$dt("Window"), tags$dd(r$selected_window, if (r$window_source == "user-selected") span(class = "muted", style = "font-weight:400;", sprintf(" (best: %s)", r$best_window))),
              tags$dt("DSI_v2"), tags$dd(span(class = paste0(band_class(r$selected_dsi_v2), "-text"), format_dsi_score(r$selected_dsi_v2, 1))),
              tags$dt("\u03b2 / p"), tags$dd(sprintf("%s / %s", format_beta(r$beta), format_p(r$p_value))),
              tags$dt("Selection"), tags$dd(style = "font-weight:400;", r$selection_reason)),
            div(
              div(class = "dsi-seg", radioButtons(ns(paste0("action_", safe_id(i))), NULL, inline = TRUE,
                choices = c("Accept" = "accept", "Flag" = "flag", "Reject" = "reject"), selected = act)),
              textAreaInput(ns(paste0("note_", safe_id(i))), NULL, value = note, rows = 2, width = "100%",
                            placeholder = "Rationale (optional)"))))
      })
      tagList(cards)
    })

    observeEvent(input$accept_ready, {
      s <- summ()
      for (i in which(s$ready)) updateRadioButtons(session, paste0("action_", safe_id(i)), selected = "accept")
      showNotification(sprintf("%d READY group(s) set to Accept. Save to record.", sum(s$ready)), type = "message", duration = 3)
    })

    save <- function() {
      s <- summ()
      dec <- app_state$decisions
      n <- 0
      for (i in seq_len(nrow(s))) {
        a <- input[[paste0("action_", safe_id(i))]]
        if (is.null(a)) next   # card filtered out and never rendered: keep previous decision
        dec[[s$group_key[i]]] <- list(group_key = s$group_key[i], action = a,
                                      rationale = input[[paste0("note_", safe_id(i))]] %||% "",
                                      start_year = s$selected_start[i], end_year = s$selected_end[i],
                                      window_source = s$window_source[i], dsi_v2 = s$selected_dsi_v2[i],
                                      timestamp = Sys.time())
        n <- n + 1
      }
      app_state$decisions <- dec
      if (length(dec) >= nrow(s)) mark_done(app_state, "decide")
      showNotification(sprintf("Saved %d decision(s); %d of %d groups decided.", n, length(dec), nrow(s)), type = "message", duration = 3)
    }
    observeEvent(input$save_decisions, save())
    observeEvent(input$save_decisions2, save())

    output$saved_note <- renderUI({
      req(app_state$dsi_results)
      nd <- length(app_state$decisions); nt <- nrow(app_state$dsi_results$dsi_best)
      span(class = "muted", style = "font-size:13px;", id = ns("decided_count"), sprintf("%d of %d decided", nd, nt))
    })
  })
}

## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ DSI Studio: main application (step rail)    ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

library(shiny)
library(bslib)
library(dplyr)
library(tidyr)
library(ggplot2)
library(readr)
library(echarts4r)

for (f in c("dsicore_utils", "dsicore_data", "dsicore_windows", "dsicore_metrics", "dsicore_scoring",
            "dsicore_selection", "dsicore_methods", "dsicore_workflow", "dsicore_robustness",
            "app_theme", "app_utils", "app_state", "app_report_html", "mod_data_input", "mod_audit", "mod_screen",
            "mod_explore", "mod_compare", "mod_decide", "mod_report", "mod_context_rail")) {
  source(file.path("R", paste0(f, ".R")))
}

#' Run DSI Studio application
#' @param port Port number (optional)
#' @export
run_dsi_studio <- function(port = NULL) {
  app <- shinyApp(ui = dsi_studio_ui(), server = dsi_studio_server)
  runApp(app, port = port %||% getOption("shiny.port"), host = "0.0.0.0", launch.browser = FALSE)
}

#' UI definition
#' @keywords internal
dsi_studio_ui <- function() {
  page(
    theme = dsi_theme(),
    title = "DSI Studio",
    tags$head(tags$meta(name = "viewport", content = "width=device-width, initial-scale=1")),
    dsi_custom_css(),
    dsi_app_js(),
    div(class = "dsi-shell",
      tags$nav(class = "step-rail", `aria-label` = "Workflow steps",
        div(class = "rail-brand", h1("DSI Studio"), p("Data Suitability Index")),
        uiOutput("step_rail")
      ),
      tags$main(class = "dsi-main",
        div(class = "dsi-main-inner",
          uiOutput("context_strip"),
          navset_hidden(
            id = "step_panels",
            nav_panel_hidden("data", mod_data_input_ui("data_input")),
            nav_panel_hidden("audit", mod_audit_ui("audit")),
            nav_panel_hidden("screen", mod_screen_ui("screen")),
            nav_panel_hidden("explore", mod_explore_ui("explore")),
            nav_panel_hidden("decide", mod_decide_ui("decide")),
            nav_panel_hidden("report", mod_report_ui("report"))
          )
        )
      ),
      tags$aside(class = "context-rail", `aria-label` = "Current context", mod_context_rail_ui("context"))
    )
  )
}

#' @keywords internal
dsi_studio_server <- function(input, output, session) {
  app_state <- reactiveValues(
    current_step = "data",
    data_raw = NULL, data_std = NULL, col_map = NULL, group_cols = NULL,
    dataset_name = NULL, effort_semantics = "per_group_year",
    audit = NULL, dsi_results = NULL, screen_settings = NULL,
    current_group = NULL, current_window = NULL,
    overrides = list(), decisions = list(), null_tests = list(), comparison = NULL,
    method = "corrected", steps_completed = character(0), export_count = 0
  )

  go_to <- function(step) {
    if (!step %in% DSI_STEPS$id) return()
    if (!dsi_step_unlocked(step, app_state)) {
      showNotification(sprintf("'%s' is locked until the previous steps are done.",
                               DSI_STEPS$title[DSI_STEPS$id == step]), type = "warning", duration = 3)
      return()
    }
    app_state$current_step <- step
  }
  observeEvent(input$step_nav, go_to(input$step_nav))
  session$userData$go_to <- go_to

  observeEvent(app_state$current_step, {
    nav_select("step_panels", app_state$current_step)
    session$sendCustomMessage("dsiStepChanged", list(step = app_state$current_step))
    step <- app_state$current_step
    # Visiting Audit (with mapped data) or Explore (with results) completes it
    if (step == "audit" && !is.null(app_state$data_std)) mark_done(app_state, "audit")
    if (step == "explore" && !is.null(app_state$dsi_results)) mark_done(app_state, "explore")
  })

  output$step_rail <- renderUI({
    st <- app_state$current_step
    done <- app_state$steps_completed
    metas <- step_rail_meta(app_state)
    tagList(lapply(seq_len(nrow(DSI_STEPS)), function(i) {
      id <- DSI_STEPS$id[i]
      unlocked <- dsi_step_unlocked(id, app_state)
      cls <- paste(c("step-item", if (id == st) "active", if (id %in% done) "done",
                     if (!unlocked) "locked" else "open"), collapse = " ")
      tags$a(href = "#", class = cls, id = paste0("step-", id, "-item"), `data-step` = id,
        `aria-current` = if (id == st) "step" else NULL,
        `aria-disabled` = if (!unlocked) "true" else NULL,
        onclick = "Shiny.setInputValue('step_nav', this.dataset.step, {priority: 'event'}); return false;",
        span(class = "step-number", if (id %in% done) HTML("&#10003;") else i),
        div(class = "step-text",
          div(class = "step-title", DSI_STEPS$title[i],
              if (!unlocked) span(class = "step-lock", HTML("&#128274;"))),
          div(class = "step-subtitle", DSI_STEPS$subtitle[i]),
          if (!is.null(metas[[id]])) div(class = "step-meta", metas[[id]])))
    }))
  })

  output$context_strip <- renderUI(context_strip_ui(app_state))

  mod_data_input_server("data_input", app_state)
  mod_audit_server("audit", app_state)
  mod_screen_server("screen", app_state)
  mod_explore_server("explore", app_state)
  mod_decide_server("decide", app_state)
  mod_report_server("report", app_state)
  mod_context_rail_server("context", app_state)
}

#' App JavaScript
#' @keywords internal
dsi_app_js <- function() {
  tags$script(HTML("
    Shiny.addCustomMessageHandler('dsiStepChanged', function(msg) {
      window.scrollTo({top: 0, behavior: 'instant'});
      setTimeout(function() {
        var el = document.getElementById('step-' + msg.step + '-item');
        if (el && window.innerWidth < 768) el.scrollIntoView({inline: 'center', block: 'nearest'});
        window.dispatchEvent(new Event('resize'));
      }, 60);
    });
    Shiny.addCustomMessageHandler('dsiSetWindow', function(msg) {
      var el = document.getElementById(msg.id);
      if (el && el.__dsiSetWindow) el.__dsiSetWindow(msg.start, msg.end);
    });
  "))
}

shinyApp(ui = dsi_studio_ui(), server = dsi_studio_server)

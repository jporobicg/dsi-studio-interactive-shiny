## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ DSI Studio: main application entry point   ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Run DSI Studio application
#' 
#' Launch the DSI Studio interactive Shiny application.
#' 
#' @param port Port number (optional)
#' @param host Host address (default "0.0.0.0")
#' @param launch.browser Whether to launch browser (default FALSE)
#' @return No return value; runs the Shiny app
#' @export
#' @examples
#' \dontrun{
#'   run_app()
#'   run_app(port = 3838, launch.browser = TRUE)
#' }
run_app <- function(port = NULL, host = "0.0.0.0", launch.browser = FALSE) {
  app <- shiny::shinyApp(ui = dsi_studio_ui(), server = dsi_studio_server)
  shiny::runApp(
    app, 
    port = port %||% getOption("shiny.port"), 
    host = host, 
    launch.browser = launch.browser
  )
}

#' UI definition
#' @keywords internal
dsi_studio_ui <- function() {
  bslib::page(
    theme = dsi_theme(),
    title = "DSI Studio",
    shiny::tags$head(shiny::tags$meta(name = "viewport", content = "width=device-width, initial-scale=1")),
    dsi_custom_css(),
    dsi_app_js(),
    shiny::div(class = "dsi-shell",
      shiny::tags$nav(class = "step-rail", `aria-label` = "Workflow steps",
        shiny::div(class = "rail-brand", shiny::h1("DSI Studio"), shiny::p("Data Suitability Index")),
        shiny::uiOutput("step_rail")
      ),
      shiny::tags$main(class = "dsi-main",
        shiny::div(class = "dsi-main-inner",
          shiny::uiOutput("context_strip"),
          bslib::navset_hidden(
            id = "step_panels",
            bslib::nav_panel_hidden("data", mod_data_input_ui("data_input")),
            bslib::nav_panel_hidden("audit", mod_audit_ui("audit")),
            bslib::nav_panel_hidden("screen", mod_screen_ui("screen")),
            bslib::nav_panel_hidden("explore", mod_explore_ui("explore")),
            bslib::nav_panel_hidden("decide", mod_decide_ui("decide")),
            bslib::nav_panel_hidden("report", mod_report_ui("report"))
          )
        )
      ),
      shiny::tags$aside(class = "context-rail", `aria-label` = "Current context", mod_context_rail_ui("context"))
    )
  )
}

#' Server logic
#' @keywords internal
dsi_studio_server <- function(input, output, session) {
  app_state <- shiny::reactiveValues(
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
      shiny::showNotification(sprintf("'%s' is locked until the previous steps are done.",
                               DSI_STEPS$title[DSI_STEPS$id == step]), type = "warning", duration = 3)
      return()
    }
    app_state$current_step <- step
  }
  shiny::observeEvent(input$step_nav, go_to(input$step_nav))
  session$userData$go_to <- go_to

  shiny::observeEvent(app_state$current_step, {
    bslib::nav_select("step_panels", app_state$current_step)
    session$sendCustomMessage("dsiStepChanged", list(step = app_state$current_step))
    step <- app_state$current_step
    # Visiting Audit (with mapped data) or Explore (with results) completes it
    if (step == "audit" && !is.null(app_state$data_std)) mark_done(app_state, "audit")
    if (step == "explore" && !is.null(app_state$dsi_results)) mark_done(app_state, "explore")
  })

  output$step_rail <- shiny::renderUI({
    st <- app_state$current_step
    done <- app_state$steps_completed
    metas <- step_rail_meta(app_state)
    shiny::tagList(lapply(seq_len(nrow(DSI_STEPS)), function(i) {
      id <- DSI_STEPS$id[i]
      unlocked <- dsi_step_unlocked(id, app_state)
      cls <- paste(c("step-item", if (id == st) "active", if (id %in% done) "done",
                     if (!unlocked) "locked" else "open"), collapse = " ")
      shiny::tags$a(href = "#", class = cls, id = paste0("step-", id, "-item"), `data-step` = id,
        `aria-current` = if (id == st) "step" else NULL,
        `aria-disabled` = if (!unlocked) "true" else NULL,
        onclick = "Shiny.setInputValue('step_nav', this.dataset.step, {priority: 'event'}); return false;",
        shiny::span(class = "step-number", if (id %in% done) shiny::HTML("&#10003;") else i),
        shiny::div(class = "step-text",
          shiny::div(class = "step-title", DSI_STEPS$title[i],
              if (!unlocked) shiny::span(class = "step-lock", shiny::HTML("&#128274;"))),
          shiny::div(class = "step-subtitle", DSI_STEPS$subtitle[i]),
          if (!is.null(metas[[id]])) shiny::div(class = "step-meta", metas[[id]])))
    }))
  })

  output$context_strip <- shiny::renderUI(context_strip_ui(app_state))

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
  shiny::tags$script(shiny::HTML("
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

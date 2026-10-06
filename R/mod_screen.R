## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Module: Screen (settings + advanced params) ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Advanced parameter specification
#'
#' Single source of truth for the Advanced panel: defaults come from the
#' corrected method's default_dsi_weights(), default_dsi_refs() and
#' default_selection_opts().
#' @keywords internal
dsi_param_spec <- function() {
  w <- default_dsi_weights(legacy = FALSE); r <- default_dsi_refs(); s <- default_selection_opts()
  rows <- list(
    list("weights", "w_slope", "Weight: slope (CPUE falls with effort)", w$w_slope, 0.01),
    list("weights", "w_e", "Weight: effort contrast", w$w_e, 0.01),
    list("weights", "w_i", "Weight: CPUE contrast", w$w_i, 0.01),
    list("weights", "w_n", "Weight: sample size", w$w_n, 0.005),
    list("weights", "w_ce", "Weight: catch-effort correlation", w$w_ce, 0.005),
    list("validity", "min_usable", "Min usable years in a window", 6, 1),
    list("refs", "beta_ref_base", "Slope reference (\u03b2 \u00d7 mean effort)", r$beta_ref_base, 0.005),
    list("refs", "p_ref", "p-value reference", r$p_ref, 0.01),
    list("refs", "ec_ref", "Effort contrast for full score", r$ec_ref, 0.1),
    list("refs", "ic_ref", "CPUE max/min for full score", r$ic_ref, 0.1),
    list("refs", "n_min_score", "Usable years scoring 0", r$n_min_score, 1),
    list("refs", "n_full_score", "Usable years scoring 1", r$n_full_score, 1),
    list("refs", "cov_min", "Coverage scoring 0", r$cov_min, 0.05),
    list("refs", "ess_min", "ESS scoring 0", r$ess_min, 1),
    list("refs", "ess_full", "ESS scoring 1", r$ess_full, 1),
    list("penalties", "outlier_threshold", "Outlier |std. residual| >", r$outlier_threshold, 0.1),
    list("penalties", "outlier_cap", "Outlier share for full penalty", r$outlier_cap, 0.01),
    list("penalties", "cook_threshold_mult", "Cook's D threshold (k / n)", r$cook_threshold_mult, 0.5),
    list("penalties", "leverage_threshold_mult", "Leverage threshold (k / n)", r$leverage_threshold_mult, 0.5),
    list("penalties", "cook_lev_cap", "Influential share for full penalty", r$cook_lev_cap, 0.01),
    list("penalties", "fit_e_threshold", "|cor(fitted, effort)| for full score", r$fit_e_threshold, 0.05),
    list("penalties", "stab_threshold", "LOO positive-slope share for 0", r$stab_threshold, 0.05),
    list("selection", "min_frac_usable", "Eligible: min coverage", s$min_frac_usable, 0.05),
    list("selection", "min_ec", "Eligible: min effort contrast", s$min_ec, 0.05),
    list("selection", "min_ic", "Eligible: min CPUE max/min", s$min_ic, 0.05),
    list("selection", "max_f_beta_pos", "Eligible: max LOO positive slopes", s$max_f_beta_pos, 0.05),
    list("selection", "min_eligible_windows", "READY: min eligible windows", s$min_eligible_windows, 1),
    list("selection", "min_dsi_v2_top1", "READY: min best DSI_v2", s$min_dsi_v2_top1, 1),
    list("selection", "max_dsi_v2_spread", "READY: max top-1 \u2212 top-3 spread", s$max_dsi_v2_spread, 1)
  )
  data.frame(group = vapply(rows, `[[`, "", 1), id = vapply(rows, `[[`, "", 2),
             label = vapply(rows, `[[`, "", 3), default = vapply(rows, function(x) as.numeric(x[[4]]), 0),
             step = vapply(rows, function(x) as.numeric(x[[5]]), 0), stringsAsFactors = FALSE)
}

#' Sections of the Advanced parameters panel
#'
#' Display grouping only: the spec groups (used to build refs, weights and
#' selection options) are unchanged.
#' @keywords internal
dsi_param_sections <- function() {
  list(
    list(id = "weights", title = "Score weights", groups = "weights",
         help = "Relative weight of each component in DSI. Corrected defaults sum to 1; the Legacy profile always uses the original weights (sum 0.95)."),
    list(id = "thresholds", title = "Scoring thresholds", groups = "refs",
         help = "Reference points that map each metric to a 0\u20131 component score."),
    list(id = "window_rules", title = "Window rules", groups = c("validity", "selection"),
         help = "Which windows are valid, which are eligible to be suggested, and when a group is READY."),
    list(id = "penalties", title = "Penalties (DSI_v2)", groups = "penalties",
         help = "Robustness multipliers applied on top of DSI to give DSI_v2.")
  )
}

#' @keywords internal
.adv_label <- function(x) { x <- sub("^Weight: ", "", x); paste0(toupper(substr(x, 1, 1)), substring(x, 2)) }

#' @keywords internal
.fmt_default <- function(x) format(x, trim = TRUE, drop0trailing = TRUE, scientific = FALSE)

#' Screen UI
#' @export
mod_screen_ui <- function(id) {
  ns <- NS(id)
  spec <- dsi_param_spec()
  adv_sections <- lapply(dsi_param_sections(), function(sec) {
    sp <- spec[spec$group %in% sec$groups, ]
    tags$section(class = "adv-section", id = ns(paste0("adv-", sec$id)),
      tags$h4(sec$title),
      p(class = "adv-help", sec$help),
      div(class = "adv-rows", lapply(seq_len(nrow(sp)), function(i)
        div(class = "adv-row",
          numericInput(ns(paste0("p_", sp$id[i])),
                       tagList(span(class = "adv-label", .adv_label(sp$label[i])),
                               span(class = "adv-default", paste("default", .fmt_default(sp$default[i])))),
                       value = sp$default[i], step = sp$step[i])))),
      if (sec$id == "weights") uiOutput(ns("weight_sum")))
  })
  open_js <- sprintf("var d=document.getElementById('%s'); d.open=true; d.scrollIntoView({block:'start'}); return false;", ns("advanced"))
  tagList(
    step_header("Score all candidate windows",
      "Every group gets one score per candidate window (start year to end year). The best eligible window is suggested and marked READY if it passes the READY rules.",
      number = 3),
    div(class = "dsi-grid-2",
      dsi_card(title = "Settings",
        div(class = "dsi-seg",
          radioButtons(ns("method"), "Method profile",
                       choices = c("Corrected" = "corrected", "Legacy (original scripts)" = "legacy"),
                       selected = "corrected", inline = TRUE)),
        uiOutput(ns("method_help")),
        div(class = "dsi-grid-2", style = "gap:0 16px;",
          numericInput(ns("min_n"), "Minimum window length (years)", value = 8, min = 3, max = 60),
          numericInput(ns("max_n"), "Maximum window length (years)", value = 20, min = 5, max = 80)),
        selectInput(ns("anchor_mode"), "Window anchoring",
                    choices = c("End at last year with usable CPUE" = "last_usable_year",
                                "End at last year present" = "last_year",
                                "Free start and end (all windows)" = "free"),
                    selected = "last_usable_year", width = "100%"),
        uiOutput(ns("effort_line")),
        div(class = "adv-launch",
          span(class = "adv-launch-title", "Advanced parameters"), uiOutput(ns("adv_badge2"), inline = TRUE),
          tags$a(href = "#", class = "adv-launch-link", id = ns("open_advanced"), onclick = open_js, "Review / edit \u2193")),
        actionButton(ns("run_screen"), "Run screening", icon = icon("play"), class = "btn-primary w-100 mt-3")),
      dsi_card(title = "Results", uiOutput(ns("stale_note")), uiOutput(ns("results_summary")))
    ),
    tags$details(class = "dsi-card dsi-advanced", id = ns("advanced"),
      tags$summary(span(class = "adv-summary-title", "Advanced parameters"), uiOutput(ns("adv_badge"), inline = TRUE)),
      div(class = "adv-body",
        p(class = "adv-intro",
          "Defaults are those of the corrected method. Change them only for a documented sensitivity analysis; changed values are highlighted and saved in the export."),
        div(class = "adv-sections", adv_sections),
        uiOutput(ns("adv_mod_css")),
        div(class = "adv-footer",
          actionButton(ns("reset_params"), "Reset to defaults", icon = icon("rotate-left"), class = "btn-outline-secondary"),
          actionButton(ns("run_screen2"), "Run screening with these settings", icon = icon("play"), class = "btn-primary")))),
    uiOutput(ns("next_ui"))
  )
}

#' Screen server
#' @export
mod_screen_server <- function(id, app_state) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    spec <- dsi_param_spec()

    observeEvent(input$method, app_state$method <- input$method)

    output$method_help <- renderUI({
      if (identical(input$method, "legacy"))
        div(class = "callout warn", "Legacy reproduces Javier's original scripts exactly, including their bugs (effort copied across groups, 0.95 weights, broken stability filter, windows anchored at the last year). Use it for comparison only.")
      else div(class = "muted", style = "font-size:12.5px;margin:-6px 0 12px;", "Corrected applies all six fixes listed in Explore \u2192 Legacy vs Corrected.")
    })

    output$effort_line <- renderUI({
      es <- app_state$effort_semantics
      lab <- c(per_row = "each row keeps its own effort", per_group_year = "one effort per group and year",
               per_fleet_year = if ("fleet" %in% app_state$group_cols) "effort shared within fleet-year"
                                else "one effort shared by all groups in a year")[[es]]
      div(class = "muted", style = "font-size:12.5px;",
          "Effort semantics: ", strong(lab),
          if (identical(input$method, "legacy")) " (ignored by Legacy, which copies the first value per year \u00d7 fleet)",
          " \u00b7 ", tags$a(href = "#", onclick = "Shiny.setInputValue('step_nav','data',{priority:'event'});return false;", "change in Data"))
    })

    params <- reactive({
      v <- stats::setNames(lapply(spec$id, function(i) input[[paste0("p_", i)]]), spec$id)
      v <- lapply(seq_along(v), function(k) if (is.null(v[[k]]) || is.na(v[[k]])) spec$default[k] else as.numeric(v[[k]]))
      stats::setNames(v, spec$id)
    })
    modified <- reactive({
      p <- params(); spec$id[abs(unlist(p) - spec$default) > 1e-12]
    })
    adv_badge_ui <- function() {
      m <- modified()
      if (length(m)) span(class = "badge-pill badge-mod", title = paste(m, collapse = ", "), sprintf("%d changed", length(m)))
      else span(class = "muted", style = "font-weight:400;font-size:12px;", "defaults")
    }
    output$adv_badge <- renderUI(adv_badge_ui())
    output$adv_badge2 <- renderUI(adv_badge_ui())
    output$adv_mod_css <- renderUI({
      m <- modified()
      if (length(m)) tags$style(paste0(sprintf("#%s", ns(paste0("p_", m))), collapse = ", ") |>
                                  paste("{ border-color: #E69F00; background: #FFF8E6; font-weight: 600; }"))
    })
    output$weight_sum <- renderUI({
      p <- params(); s <- p$w_slope + p$w_e + p$w_i + p$w_n + p$w_ce
      div(class = if (abs(s - 1) > 1e-9) "callout warn" else "muted", style = "font-size:12px;",
          sprintf("Weights sum to %.3f%s", s, if (abs(s - 1) > 1e-9) ". DSI will not reach 100." else "."))
    })
    observeEvent(input$reset_params, {
      for (i in seq_len(nrow(spec))) updateNumericInput(session, paste0("p_", spec$id[i]), value = spec$default[i])
    })

    current_settings <- reactive({
      p <- params()
      list(
        method = input$method, min_n = as.integer(input$min_n), max_n = as.integer(input$max_n),
        anchor_mode = input$anchor_mode, effort_semantics = app_state$effort_semantics,
        group_cols = app_state$group_cols,
        weights = if (identical(input$method, "legacy")) default_dsi_weights(legacy = TRUE)
                  else p[c("w_slope", "w_e", "w_i", "w_n", "w_ce")],
        refs = utils::modifyList(default_dsi_refs(), p[spec$id[spec$group %in% c("refs", "penalties")]]),
        selection_opts = utils::modifyList(default_selection_opts(), p[spec$id[spec$group == "selection"]]),
        min_usable = as.integer(p$min_usable),
        modified_params = modified())
    })

    observeEvent(input$run_screen, run_screening())
    observeEvent(input$run_screen2, run_screening())
    run_screening <- function() {
      req(app_state$data_raw, app_state$col_map)
      st <- current_settings()
      if (is.na(st$min_n) || is.na(st$max_n) || st$min_n > st$max_n) {
        showNotification("Minimum window length must be <= maximum.", type = "error"); return()
      }
      withProgress(message = "Running DSI screening", value = 0, {
        res <- tryCatch(
          run_dsi_workflow(df = app_state$data_raw, col_map = app_state$col_map, group_cols = st$group_cols,
                           min_n = st$min_n, max_n = st$max_n, anchor_mode = st$anchor_mode,
                           method = st$method, effort_semantics = st$effort_semantics,
                           refs = st$refs, weights = st$weights, selection_opts = st$selection_opts,
                           min_usable = st$min_usable,
                           progress_callback = function(msg, value) if (!is.null(value)) setProgress(value, detail = msg)),
          error = function(e) { showNotification(paste("Screening error:", conditionMessage(e)), type = "error"); NULL })
      })
      if (is.null(res)) return()
      if (is.null(res$dsi_all)) { showNotification(res$error %||% "No windows generated. Check window lengths.", type = "error"); return() }
      reset_downstream(app_state, "screen")
      app_state$screen_settings <- st
      app_state$dsi_results <- res
      mark_done(app_state, "screen")
      showNotification(sprintf("Screening complete: %d windows.", nrow(res$dsi_all)), type = "message")
    }

    output$stale_note <- renderUI({
      req(app_state$screen_settings)
      old <- app_state$screen_settings; new <- current_settings()
      keys <- c("method", "min_n", "max_n", "anchor_mode", "effort_semantics", "weights", "refs", "selection_opts", "min_usable")
      changed <- keys[!vapply(keys, function(k) isTRUE(all.equal(old[[k]], new[[k]])), TRUE)]
      if (length(changed)) div(class = "callout warn", sprintf("Settings changed since the last run (%s). Run screening again to update the results.",
                                                               paste(changed, collapse = ", ")))
    })

    output$results_summary <- renderUI({
      r <- app_state$dsi_results
      if (is.null(r)) return(p(class = "muted", "Configure the settings and click Run screening."))
      a <- r$dsi_all; b <- r$dsi_best; st <- app_state$screen_settings
      tagList(
        div(class = "metric-row",
          metric_box(length(unique(a$group_key)), "Groups"),
          metric_box(nrow(a), "Windows"),
          metric_box(sum(a$valid, na.rm = TRUE), "Valid"),
          metric_box(sum(b$ready %in% TRUE), "READY", "ready"),
          metric_box(format_dsi_score(max(b$dsi_v2, na.rm = TRUE), 1), "Top DSI_v2"),
          metric_box(format_dsi_score(stats::median(a$dsi_v2[a$valid], na.rm = TRUE), 0), "Median DSI_v2")),
        p(class = "muted", style = "font-size:12.5px;margin-top:10px;",
          sprintf("%s profile \u00b7 windows %d\u2013%d years \u00b7 %s%s", tools::toTitleCase(st$method), st$min_n, st$max_n,
                  st$anchor_mode, if (length(st$modified_params)) sprintf(" \u00b7 %d advanced parameter(s) changed: %s",
                  length(st$modified_params), paste(st$modified_params, collapse = ", ")) else "")))
    })

    output$next_ui <- renderUI({
      req(app_state$dsi_results)
      div(class = "step-footer", next_step_button("explore", "Continue to Explore"))
    })
  })
}

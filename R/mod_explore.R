## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Module: Explore (grid, window slider,       ~ ##
## ~ diagnostics, null test, comparison)         ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Why a single (possibly user-chosen) window is or is not eligible
#' @keywords internal
window_eligibility <- function(m, opts = default_selection_opts()) {
  if (!isTRUE(m$valid)) return(paste("invalid:", m$reasons_invalid))
  r <- character(0)
  if (m$n_usable < opts$min_n_usable) r <- c(r, sprintf("n_usable %d < %d", m$n_usable, opts$min_n_usable))
  if (!(m$beta < 0)) r <- c(r, "slope not negative")
  if (m$frac_usable < opts$min_frac_usable) r <- c(r, sprintf("coverage %.2f < %.2f", m$frac_usable, opts$min_frac_usable))
  if (m$ec < opts$min_ec) r <- c(r, sprintf("effort contrast %.2f < %.2f", m$ec, opts$min_ec))
  if (m$ic < opts$min_ic) r <- c(r, sprintf("CPUE contrast %.2f < %.2f", m$ic, opts$min_ic))
  if (!is.null(m$f_beta_pos) && is.finite(m$f_beta_pos) && m$f_beta_pos > opts$max_f_beta_pos)
    r <- c(r, sprintf("unstable slope (LOO positive %.0f%%)", 100 * m$f_beta_pos))
  r
}

#' Explore UI
#' @export
mod_explore_ui <- function(id) {
  ns <- NS(id)
  tagList(
    step_header("Inspect, adjust and test",
      "Pick a group to see its time series. Drag the window slider to try other windows: DSI is recomputed. Use the random-catch null test to check the score is not just the catch/effort artefact. The Legacy vs Corrected view shows what the bug fixes change.",
      number = 4),
    div(class = "dsi-seg", style = "margin-bottom:18px;",
      radioButtons(ns("view"), NULL, inline = TRUE,
                   choices = c("Score grid" = "grid", "Legacy vs Corrected" = "compare"), selected = "grid")),
    conditionalPanel(sprintf("input['%s'] == 'grid'", ns("view")),
      dsi_card(title = "Suitability score grid", uiOutput(ns("grid_help")), uiOutput(ns("score_grid_ui"))),
      uiOutput(ns("detail_view"))),
    conditionalPanel(sprintf("input['%s'] == 'compare'", ns("view")), mod_compare_ui(ns("compare"))),
    div(class = "step-footer", next_step_button("decide", "Continue to Decide"))
  )
}

#' Explore server
#' @export
mod_explore_server <- function(id, app_state) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    mod_compare_server("compare", app_state)

    output$grid_help <- renderUI({
      req(app_state$dsi_results)
      p(class = "help", "Score = DSI_v2 of the suggested window. Colour = band (Good \u2265 70, Moderate 50\u201370, Poor < 50). A green ring means READY. The line is DSI_v2 across candidate windows. Click a cell to explore.")
    })

    output$score_grid_ui <- renderUI({
      r <- app_state$dsi_results
      if (is.null(r)) return(div(class = "callout", "Run screening in step 3 first."))
      all_w <- r$dsi_all; best <- r$dsi_best
      sel <- app_state$current_group
      gc <- app_state$group_cols
      spark <- function(g) {
        w <- all_w[all_w$group_key == g & all_w$valid %in% TRUE & is.finite(all_w$dsi_v2), ]
        w <- w[order(w$start_year), ]
        if (nrow(w) < 2) return(NULL)
        HTML(sub("<svg ", "<svg class=\"spark\" preserveAspectRatio=\"none\" viewBox=\"0 0 120 28\" ",
                 create_sparkline_svg(w$dsi_v2, 120, 28, "#555")))
      }
      click_js <- function(g) sprintf("Shiny.setInputValue('%s', %s, {priority: 'event'});", ns("cell_click"),
                                      jsonlite::toJSON(g, auto_unbox = TRUE))
      legend <- div(class = "grid-legend",
        span(tags$i(style = "background:#009E73"), "Good \u2265 70"), span(tags$i(style = "background:#E69F00"), "Moderate 50\u201370"),
        span(tags$i(style = "background:#D55E00"), "Poor < 50"), span(tags$i(style = "background:#ccc"), "No valid window"),
        span(tags$i(style = "background:#fff;box-shadow:inset 0 0 0 2px #009E73"), "READY"))
      if (all(c("species", "fleet") %in% gc)) {
        parts <- strsplit(as.character(best$group_key), " | ", fixed = TRUE)
        best$sp <- vapply(parts, `[`, "", 1); best$fl <- vapply(parts, `[`, "", 2)
        sps <- sort(unique(best$sp)); fls <- sort(unique(best$fl))
        cells <- list(div(class = "mx-head", "Species \\ Fleet"), lapply(fls, function(f) div(class = "mx-head", title = f, f)))
        for (s in sps) {
          cells[[length(cells) + 1]] <- div(class = "mx-row-label", title = s, s)
          for (f in fls) {
            g <- paste0(s, " | ", f)
            b <- best[best$group_key == g, ]
            if (nrow(b) == 0) { cells[[length(cells) + 1]] <- div(class = "mx-cell empty", title = "No data", "\u00b7"); next }
            v <- b$dsi_v2[1]
            if (!is.finite(v)) { cells[[length(cells) + 1]] <- div(class = "mx-cell invalid", title = paste(g, "- no valid window"), "\u2014"); next }
            bc <- band_class(v)
            cells[[length(cells) + 1]] <- div(
              class = paste("mx-cell", bc, if (isTRUE(b$ready[1])) "ready", if (identical(sel, g)) "selected"),
              title = sprintf("%s: DSI_v2 %.1f, %d\u2013%d%s", g, v, b$start_year[1], b$end_year[1], if (isTRUE(b$ready[1])) ", READY" else ""),
              `data-group` = g, onclick = click_js(g),
              div(class = "mx-score", sprintf("%.0f", v)), div(class = "mx-band", get_dsi_band(v)$label), spark(g))
          }
        }
        tagList(div(class = "matrix-wrap",
          div(class = "dsi-matrix", style = sprintf("grid-template-columns: minmax(34px, max-content) repeat(%d, minmax(0, 1fr));", length(fls)),
              cells)), legend)
      } else {
        groups <- unique(as.character(best$group_key))
        tagList(div(class = "score-grid", lapply(groups, function(g) {
          b <- best[best$group_key == g, ][1, ]
          v <- b$dsi_v2
          bc <- if (is.finite(v)) band_class(v) else "invalid"
          div(class = paste("score-cell", bc, if (identical(sel, g)) "selected"), `data-group` = g,
              onclick = if (is.finite(v)) click_js(g),
              div(class = "score-cell-title", title = g, g),
              div(class = paste0("score-cell-value ", bc, "-text"), format_dsi_score(v, 1)),
              div(class = paste0("score-cell-band ", bc, "-text"), get_dsi_band(v)$label,
                  if (isTRUE(b$ready)) span(class = "badge-pill badge-ready", style = "margin-left:6px;", "READY")),
              div(class = "score-cell-meta", if (is.finite(v)) sprintf("%d\u2013%d \u00b7 %d windows", b$start_year, b$end_year,
                                                                         sum(all_w$group_key == g)) else "no valid window"),
              spark(g))
        })), legend)
      }
    })

    observeEvent(input$cell_click, {
      g <- input$cell_click
      b <- app_state$dsi_results$dsi_best
      b <- b[b$group_key == g, ]
      if (nrow(b) == 0 || !is.finite(b$dsi_v2[1])) return()
      app_state$current_group <- g
    })

    ## ---- per-group data and windows ----
    grp_data <- reactive({
      req(app_state$dsi_results, app_state$current_group)
      ds <- app_state$dsi_results$data_std
      d <- ds[ds$group_key == app_state$current_group, ]
      d[order(d$year), ]
    })
    best_row <- reactive({
      req(app_state$dsi_results, app_state$current_group)
      b <- app_state$dsi_results$dsi_best
      b[b$group_key == app_state$current_group, ][1, ]
    })
    cfg <- reactive(app_state$dsi_results$config)
    score_args <- reactive({
      c <- cfg()
      list(refs = c$refs, weights = c$weights, fixes = c$fixes, min_n = c$min_n, min_usable = c$min_usable %||% 6)
    })

    sel_window <- reactiveVal(NULL)
    init_window <- function() {
      ov <- isolate(app_state$overrides[[app_state$current_group]])
      b <- isolate(best_row())
      as.integer(if (!is.null(ov)) c(ov$start_year, ov$end_year) else c(b$start_year, b$end_year))
    }
    observeEvent(list(app_state$current_group, app_state$dsi_results), {
      req(app_state$current_group)
      sel_window(init_window())
    }, priority = 10)

    sel_scored <- reactive({
      w <- sel_window(); req(w)
      m <- do.call(score_window, c(list(df = grp_data(), start_year = w[1], end_year = w[2]), score_args()))
      m$group_key <- app_state$current_group
      m
    })
    observe({ app_state$current_window <- sel_scored() })

    ## chart -> server (debounced in JS and here)
    ts_input <- debounce(reactive(input$ts_window), 250)
    observeEvent(ts_input(), {
      v <- ts_input(); req(v$start, v$end, identical(v$group, app_state$current_group))
      w <- as.integer(c(v$start, v$end))
      if (!identical(w, as.integer(sel_window()))) {
        sel_window(w)
        updateSliderInput(session, "win_range", value = w)
      }
    })
    ## range slider -> server and chart
    range_input <- debounce(reactive(input$win_range), 300)
    observeEvent(range_input(), {
      w <- as.integer(range_input()); req(length(w) == 2)
      if (!identical(w, as.integer(sel_window()))) {
        sel_window(w)
        session$sendCustomMessage("dsiSetWindow", list(id = ns("ts_chart"), start = w[1], end = w[2]))
      }
    })
    set_window <- function(w) {
      sel_window(as.integer(w))
      updateSliderInput(session, "win_range", value = as.integer(w))
      session$sendCustomMessage("dsiSetWindow", list(id = ns("ts_chart"), start = w[1], end = w[2]))
    }
    observeEvent(input$reset_window, { b <- best_row(); set_window(c(b$start_year, b$end_year)) })
    observeEvent(input$use_window, {
      m <- sel_scored(); g <- app_state$current_group
      ov <- app_state$overrides
      b <- best_row()
      if (m$start_year == b$start_year && m$end_year == b$end_year) ov[[g]] <- NULL else ov[[g]] <- m
      app_state$overrides <- ov
      showNotification(if (is.null(ov[[g]])) "Decide will use the screened best window." else
        sprintf("Decide will use %d\u2013%d for %s.", m$start_year, m$end_year, g), type = "message", duration = 3)
    })

    ## ---- detail view ----
    output$detail_view <- renderUI({
      req(app_state$dsi_results)
      if (is.null(app_state$current_group)) return(div(class = "callout", "Click a cell in the grid to inspect a group."))
      g <- app_state$current_group
      b <- isolate(best_row())
      d <- isolate(grp_data())
      w0 <- init_window()
      yr <- range(d$year, na.rm = TRUE)
      tagList(
        div(class = "detail-head", h3(g),
            if (isTRUE(b$ready)) span(class = "badge-pill badge-ready", "READY") else span(class = "badge-pill badge-notready", "Not ready"),
            span(class = "muted", style = "font-size:13px;", b$selection_reason)),
        div(class = "dsi-grid-3",
          dsi_card(title = "Screened best window",
            tags$dl(class = "kv",
              tags$dt("Window"), tags$dd(sprintf("%d\u2013%d", b$start_year, b$end_year)),
              tags$dt("DSI_v2"), tags$dd(span(class = paste0(band_class(b$dsi_v2), "-text"), format_dsi_score(b$dsi_v2, 1))),
              tags$dt("DSI"), tags$dd(format_dsi_score(b$dsi, 1)),
              tags$dt("Usable years"), tags$dd(b$n_usable),
              tags$dt("\u03b2 (slope)"), tags$dd(format_beta(b$beta)),
              tags$dt("p-value"), tags$dd(format_p(b$p_value)))),
          dsi_card(title = "Your window", id = ns("your_window_card"), uiOutput(ns("your_window"))),
          dsi_card(title = "Component scores", echarts4rOutput(ns("component_chart"), height = "230px"))),
        br(),
        dsi_card(title = "Time series and window selector",
          p(class = "help", "Drag the handles of the blue window bar under the chart (or the slider below it) to change the window. The shaded band and \"Your window\" update after you stop dragging."),
          echarts4rOutput(ns("ts_chart"), height = "430px"),
          div(class = "win-range",
            sliderInput(ns("win_range"), "Window", min = yr[1], max = yr[2], value = w0, step = 1, sep = "", width = "100%", ticks = FALSE)),
          div(class = "win-toolbar",
            actionButton(ns("use_window"), "Use this window in Decide", icon = icon("thumbtack"), class = "btn-primary btn-sm"),
            actionButton(ns("reset_window"), "Reset to screened best", icon = icon("rotate-left"), class = "btn-outline-secondary btn-sm"),
            uiOutput(ns("override_note"), inline = TRUE))),
        div(class = "dsi-grid-2",
          dsi_card(title = "DSI_v2 across candidate windows", echarts4rOutput(ns("windows_chart"), height = "280px")),
          dsi_card(title = "Diagnostics for your window", plotOutput(ns("diagnostic_plot"), height = "280px"))),
        br(),
        dsi_card(title = "Random-catch null test",
          p(class = "help", "Catch is randomised within your window and CPUE rebuilt as catch / effort. Because effort is in the denominator, log(CPUE) falls with effort even for random catch. A robust window scores clearly above this null distribution."),
          div(class = "win-toolbar",
            div(style = "width:150px;", selectInput(ns("null_n"), "Randomisations", c(99, 199, 499, 999), selected = 199, width = "100%")),
            div(style = "width:230px;", selectInput(ns("null_mode"), "Randomise catch by", c("Permuting observed catches" = "permute", "Lognormal draws" = "lognormal"), width = "100%")),
            div(style = "width:110px;", numericInput(ns("null_seed"), "Seed", 1, width = "100%")),
            actionButton(ns("run_null"), "Run null test", icon = icon("shuffle"), class = "btn-primary", style = "margin-top:14px;")),
          uiOutput(ns("null_summary")),
          conditionalPanel("output.null_has_result", ns = ns, echarts4rOutput(ns("null_chart"), height = "300px")))
      )
    })

    output$override_note <- renderUI({
      g <- app_state$current_group; req(g)
      ov <- app_state$overrides[[g]]
      if (!is.null(ov)) span(class = "badge-pill badge-user", sprintf("Decide uses %d\u2013%d", ov$start_year, ov$end_year))
    })

    output$your_window <- renderUI({
      m <- sel_scored(); b <- best_row()
      same <- m$start_year == b$start_year && m$end_year == b$end_year
      d <- if (is.finite(m$dsi_v2 %||% NA) && is.finite(b$dsi_v2)) m$dsi_v2 - b$dsi_v2 else NA
      el <- window_eligibility(m, cfg()$selection_opts)
      tagList(
        div(class = "compare-scores",
          div(div(class = "metric-label", "DSI_v2"),
              div(class = paste("big", paste0(band_class(m$dsi_v2 %||% NA), "-text")), id = ns("your_dsi_v2"), format_dsi_score(m$dsi_v2 %||% NA, 1))),
          div(div(class = "metric-label", "vs best"),
              div(class = paste("big", if (is.finite(d) && d > 0.05) "delta-up" else if (is.finite(d) && d < -0.05) "delta-down"),
                  if (same) "=" else if (is.finite(d)) sprintf("%+.1f", d) else "\u2014"))),
        tags$dl(class = "kv", style = "margin-top:10px;",
          tags$dt("Window"), tags$dd(id = ns("your_window_years"), sprintf("%d\u2013%d (%d yrs)", m$start_year, m$end_year, m$n_years)),
          tags$dt("DSI"), tags$dd(format_dsi_score(m$dsi %||% NA, 1)),
          tags$dt("\u03b2 / p"), tags$dd(sprintf("%s / %s", format_beta(m$beta %||% NA), format_p(m$p_value %||% NA))),
          tags$dt("Eligible"), tags$dd(if (length(el) == 0) span(class = "good-text", "yes") else span(class = "poor-text", title = paste(el, collapse = "; "), paste(el, collapse = "; ")))),
        dsi_v2_limiters_ui(m))
    })

    output$component_chart <- renderEcharts4r({
      m <- sel_scored(); b <- best_row()
      comp <- c("s_slope", "s_e", "s_i", "s_n", "s_ce")
      lab <- c("Slope", "Effort contrast", "CPUE contrast", "Sample size", "Catch-effort")
      val <- function(x, k) { v <- x[[k]]; if (is.null(v) || !is.finite(v)) 0 else round(v, 3) }
      df <- data.frame(component = factor(lab, levels = rev(lab)),
                       best = sapply(comp, function(k) val(b, k)), yours = sapply(comp, function(k) val(m, k)))
      df <- df[nrow(df):1, ]
      df |> e_charts(component) |>
        e_bar(best, name = "Best window", itemStyle = list(color = "#BDC3C7")) |>
        e_bar(yours, name = "Your window", itemStyle = list(color = "#3498DB")) |>
        e_flip_coords() |> e_x_axis(max = 1, min = 0, interval = 0.5) |>
        e_grid(left = 96, right = 18, top = 36, bottom = 22) |>
        e_legend(top = 0, left = "center", itemWidth = 12, itemHeight = 10, textStyle = list(fontSize = 11)) |>
        e_tooltip(trigger = "axis") |> e_animation(FALSE)
    })

    output$ts_chart <- renderEcharts4r({
      req(app_state$current_group)
      d <- grp_data()
      w0 <- init_window()
      ts_window_chart(d, w0, ns("ts_window"), app_state$current_group, min_span = (cfg()$min_n %||% 8) - 1)
    })

    output$windows_chart <- renderEcharts4r({
      req(app_state$current_group)
      a <- app_state$dsi_results$dsi_all
      a <- a[a$group_key == app_state$current_group & a$valid %in% TRUE & is.finite(a$dsi_v2), ]
      req(nrow(a) > 0)
      m <- sel_scored()
      a$label <- sprintf("%d\u2013%d", a$start_year, a$end_year)
      a <- a[order(a$start_year, a$end_year), ]
      a$x <- if (length(unique(a$end_year)) == 1) a$start_year else seq_len(nrow(a))
      a |> e_charts(x) |>
        e_line(dsi_v2, name = "DSI_v2", symbolSize = 5, itemStyle = list(color = "#3498DB"), bind = label) |>
        e_mark_line(data = list(yAxis = 70), title = "70", lineStyle = list(type = "dotted", color = "#009E73"), symbol = "none") |>
        e_mark_line(data = list(yAxis = m$dsi_v2 %||% 0), title = "yours", lineStyle = list(color = "#E69F00"), symbol = "none") |>
        e_y_axis(min = 0, max = 100) |> e_x_axis(min = "dataMin", max = "dataMax", name = if (length(unique(a$end_year)) == 1) "start year" else "window",
                                                axisLabel = list(formatter = htmlwidgets::JS("function(v){return String(v);}"))) |>
        e_tooltip(formatter = htmlwidgets::JS("function(p){return p.name + '<br/>DSI_v2 ' + Number(p.value[1]).toFixed(1);}")) |>
        e_legend(show = FALSE) |> e_grid(left = 40, right = 40, top = 20, bottom = 40) |> e_animation(FALSE)
    })

    output$diagnostic_plot <- renderPlot({
      w <- sel_window(); req(w)
      d <- grp_data(); d <- d[d$year >= w[1] & d$year <= w[2], ]
      d$log_cpue <- safe_log_cpue(d$cpue)$log_cpue
      d <- d[is.finite(d$log_cpue) & is.finite(d$effort), ]
      if (nrow(d) < 3) { plot.new(); text(0.5, 0.5, "Too few usable years for diagnostics"); return() }
      fit <- lm(log_cpue ~ effort, data = d)
      d$fitted <- fitted(fit); d$std_resid <- rstandard(fit)
      p1 <- ggplot(d, aes(effort, log_cpue)) + geom_point(size = 2, alpha = .8) +
        geom_smooth(method = "lm", formula = y ~ x, se = TRUE, colour = "#3498DB") +
        labs(title = "ln(CPUE) vs effort", x = "Effort", y = "ln(CPUE)") + theme_dsi(10)
      p2 <- ggplot(d, aes(year, std_resid)) + geom_hline(yintercept = 0, linetype = "dashed") +
        geom_hline(yintercept = c(-2, 2), linetype = "dotted", colour = "#D55E00") + geom_point(size = 2) + geom_line(alpha = .4) +
        labs(title = "Std. residuals by year", x = NULL, y = NULL) + theme_dsi(10)
      gridExtra::grid.arrange(p1, p2, ncol = 2)
    })

    ## ---- null test ----
    null_res <- reactiveVal(NULL)
    observeEvent(app_state$current_group, null_res(app_state$null_tests[[app_state$current_group]]))
    observeEvent(input$run_null, {
      w <- sel_window(); req(w)
      n <- as.integer(input$null_n)
      res <- withProgress(message = "Random-catch null test", value = 0, {
        tryCatch(dsi_null_test(grp_data(), w[1], w[2], n_sim = n, mode = input$null_mode,
                               seed = input$null_seed %||% 1, score_args = score_args(),
                               progress = function(i, n) setProgress(i / n, detail = sprintf("%d / %d", i, n))),
                 error = function(e) { showNotification(conditionMessage(e), type = "error"); NULL })
      })
      req(res)
      null_res(res)
      nt <- app_state$null_tests; nt[[app_state$current_group]] <- res; app_state$null_tests <- nt
    })
    output$null_has_result <- reactive({
      g <- app_state$current_group
      !is.null(g) && !is.null(app_state$null_tests[[g]])
    })
    outputOptions(output, "null_has_result", suspendWhenHidden = FALSE)

    output$null_summary <- renderUI({
      r <- null_res()
      if (is.null(r)) return(p(class = "muted", "Not run yet for this group."))
      verdict <- if (!is.finite(r$p_value)) list("callout", "Observed window has no valid DSI_v2.")
        else if (r$p_value <= 0.05) list("callout ok", sprintf("Observed DSI_v2 %.1f is above %.0f%% of the null runs (p = %.3f). The score is unlikely to be just the catch/effort artefact.", r$observed_dsi_v2, r$percentile, r$p_value))
        else list("callout warn", sprintf("Observed DSI_v2 %.1f is not clearly above the null (p = %.3f, %.0fth percentile). Random catch often scores this high in this window.", r$observed_dsi_v2, r$p_value, r$percentile))
      tagList(
        div(class = "metric-row",
          metric_box(sprintf("%d\u2013%d", r$start_year, r$end_year), "Window"),
          metric_box(format_dsi_score(r$observed_dsi_v2, 1), "Observed"),
          metric_box(format_dsi_score(r$null_median, 1), "Null median"),
          metric_box(format_dsi_score(r$null_q95, 1), "Null 95%"),
          metric_box(format_p(r$p_value), "p (one-sided)"),
          metric_box(sprintf("%d/%d", r$n_valid_null, r$n_sim), "Valid runs")),
        div(class = verdict[[1]], id = ns("null_verdict"), verdict[[2]]),
        if (!isTRUE(r$cpue_is_catch_over_effort))
          p(class = "muted", style = "font-size:12.5px;", sprintf("Note: the mapped CPUE is not catch/effort here. With CPUE rebuilt as catch/effort the observed DSI_v2 would be %.1f. The null runs use catch/effort.", r$observed_ce_dsi_v2)))
    })
    output$null_chart <- renderEcharts4r({
      r <- null_res(); req(r)
      v <- r$null_dsi_v2[is.finite(r$null_dsi_v2)]
      req(length(v) > 0)
      br <- seq(0, 100, by = 2.5)
      h <- graphics::hist(pmin(pmax(v, 0), 100), breaks = br, plot = FALSE)
      lo <- utils::head(br, -1)
      df <- data.frame(bin = sprintf("%g", lo), count = h$counts)
      obs_bin <- sprintf("%g", lo[max(1, findInterval(min(max(r$observed_dsi_v2, 0), 99.99), br))])
      df |> e_charts(bin) |>
        e_bar(count, name = "Null runs", itemStyle = list(color = "#BDC3C7"), barCategoryGap = "5%") |>
        e_mark_line(data = list(xAxis = obs_bin), title = sprintf("observed %.1f", r$observed_dsi_v2),
                    lineStyle = list(color = "#D55E00", width = 3, type = "solid"), symbol = "none",
                    label = list(formatter = sprintf("observed %.1f", r$observed_dsi_v2), color = "#D55E00")) |>
        e_x_axis(name = "DSI_v2 with randomised catch", nameLocation = "middle", nameGap = 28,
                 axisLabel = list(interval = 7)) |>
        e_y_axis(name = "runs") |> e_legend(show = FALSE) |> e_tooltip(trigger = "axis") |>
        e_grid(left = 44, right = 20, top = 30, bottom = 50) |> e_animation(FALSE)
    })
  })
}

#' Time-series chart with a window selector that does not zoom the plot
#'
#' The slider is a dataZoom bound to a hidden copy of the x axis, so dragging
#' it moves a window band over the full series instead of zooming. The JS
#' sends the selected years to Shiny (debounced) and exposes
#' `el.__dsiSetWindow(start, end)` so the server can move it.
#' @keywords internal
ts_window_chart <- function(d, w0, input_id, group, min_span = 7) {
  years <- seq(min(d$year, na.rm = TRUE), max(d$year, na.rm = TRUE))
  val <- function(col) { v <- d[[col]][match(years, d$year)]; lapply(v, function(x) if (is.finite(x)) signif(x, 6) else NULL) }
  idx <- function(y) max(0, match(y, years) - 1)
  band <- function(s, e) list(list(list(xAxis = as.character(s)), list(xAxis = as.character(e))))
  ycat <- as.character(years)
  base <- list(
    animation = FALSE,
    tooltip = list(trigger = "axis"),
    legend = list(top = 0, data = list("Catch", "Effort", "CPUE")),
    grid = list(left = 64, right = 120, top = 44, bottom = 78),
    xAxis = list(
      list(type = "category", data = ycat, boundaryGap = FALSE, axisLabel = list(hideOverlap = TRUE)),
      list(type = "category", data = ycat, boundaryGap = FALSE, show = FALSE, gridIndex = 0)),
    yAxis = list(
      list(type = "value", name = "Catch", position = "left", splitLine = list(lineStyle = list(color = "#F0F0F0")),
           axisLine = list(show = TRUE, lineStyle = list(color = "#E69F00"))),
      list(type = "value", name = "Effort", position = "right", splitLine = list(show = FALSE),
           axisLine = list(show = TRUE, lineStyle = list(color = "#56B4E9"))),
      list(type = "value", name = "CPUE", position = "right", offset = 62, splitLine = list(show = FALSE),
           axisLine = list(show = TRUE, lineStyle = list(color = "#009E73")))),
    dataZoom = list(list(type = "slider", xAxisIndex = 1, startValue = idx(w0[1]), endValue = idx(w0[2]),
                         filterMode = "none", showDataShadow = FALSE, brushSelect = FALSE, minValueSpan = min_span,
                         bottom = 14, height = 26, handleSize = "120%",
                         fillerColor = "rgba(52,152,219,0.25)", borderColor = "#3498DB",
                         handleStyle = list(color = "#3498DB", borderColor = "#1F6FA8"),
                         moveHandleStyle = list(color = "#3498DB"),
                         textStyle = list(color = "#1F6FA8", fontWeight = "bold"))),
    series = list(
      list(name = "Catch", id = "catch", type = "line", yAxisIndex = 0, xAxisIndex = 0, data = val("catch"),
           itemStyle = list(color = "#E69F00"), symbolSize = 4, connectNulls = FALSE,
           markArea = list(silent = TRUE, itemStyle = list(color = "rgba(52,152,219,0.14)"), data = band(w0[1], w0[2]))),
      list(name = "Effort", id = "effort", type = "line", yAxisIndex = 1, xAxisIndex = 0, data = val("effort"),
           itemStyle = list(color = "#56B4E9"), symbolSize = 4),
      list(name = "CPUE", id = "cpue", type = "line", yAxisIndex = 2, xAxisIndex = 0, data = val("cpue"),
           itemStyle = list(color = "#009E73"), symbolSize = 4, lineStyle = list(width = 2.5)))
  )
  media <- list(list(query = list(maxWidth = 560),
    option = list(grid = list(left = 46, right = 84, top = 52, bottom = 74),
                  yAxis = list(list(name = "", axisLabel = list(fontSize = 9)), list(name = "", axisLabel = list(fontSize = 9)),
                               list(name = "", offset = 40, axisLabel = list(fontSize = 9))),
                  legend = list(top = 0, itemGap = 8))))
  e <- e_charts(width = "100%")
  e$x$opts <- list(baseOption = base, media = media)
  htmlwidgets::onRender(e, "
    function(el, x, data) {
      var chart = echarts.getInstanceByDom(el);
      if (!chart) return;
      var years = data.years, timer = null, last = null;
      function band(s, e) {
        chart.setOption({series: [{id: 'catch', markArea: {data: [[{xAxis: String(years[s])}, {xAxis: String(years[e])}]]}}]});
      }
      chart.off('datazoom');
      chart.on('datazoom', function() {
        var dz = chart.getOption().dataZoom[0];
        var s = Math.max(0, Math.round(dz.startValue)), e = Math.min(years.length - 1, Math.round(dz.endValue));
        band(s, e);
        var key = s + '-' + e;
        if (key === last) return;
        clearTimeout(timer);
        timer = setTimeout(function() {
          last = key;
          Shiny.setInputValue(data.inputId, {start: years[s], end: years[e], group: data.group}, {priority: 'event'});
        }, 350);
      });
      el.__dsiSetWindow = function(sy, ey) {
        var s = years.indexOf(sy), e = years.indexOf(ey);
        if (s < 0 || e < 0) return;
        last = s + '-' + e;
        chart.dispatchAction({type: 'dataZoom', dataZoomIndex: 0, startValue: s, endValue: e});
        band(s, e);
      };
      el.__dsiGetWindow = function() {
        var dz = chart.getOption().dataZoom[0];
        return [years[Math.round(dz.startValue)], years[Math.round(dz.endValue)]];
      };
    }", data = list(years = years, inputId = input_id, group = group))
}

#' Explain which DSI_v2 multipliers pull a window's score down
#' @keywords internal
dsi_v2_limiters <- function(m, threshold = 0.9) {
  # DSI_v2 = DSI_base x p_miss x p_out x p_inf x (0.85 + 0.15 s_stab) x (0.85 + 0.15 s_fit_e)
  lab <- c(p_inf = "Influential points (Cook's D / leverage)", p_out = "Outliers in log-CPUE residuals",
           p_miss = "Missing or unusable years")
  v <- vapply(names(lab), function(k) { x <- m[[k]]; if (is.null(x) || !is.finite(x)) NA_real_ else as.numeric(x) }, 0)
  v <- v[is.finite(v) & v < threshold]
  if (length(v) == 0) return(NULL)
  v <- sort(v)
  data.frame(id = names(v), label = unname(lab[names(v)]), value = unname(v), stringsAsFactors = FALSE)
}

#' @keywords internal
dsi_v2_limiters_ui <- function(m) {
  lim <- dsi_v2_limiters(m)
  if (is.null(lim)) return(NULL)
  div(class = "limiters", style = "margin-top:8px;font-size:12.5px;",
      span(class = "muted", "DSI_v2 multipliers below 1: "),
      lapply(seq_len(nrow(lim)), function(i)
        span(class = if (lim$value[i] < 0.05) "poor-text" else "moderate-text", style = "display:inline-block;margin-right:8px;",
             title = lim$id[i], sprintf("%s \u00d7%.2f", lim$label[i], lim$value[i]))))
}

## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Module: Legacy vs Corrected comparison      ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Comparison UI
#' @export
mod_compare_ui <- function(id) {
  ns <- NS(id)
  tagList(
    dsi_card(title = "Legacy vs Corrected on the same data",
      p(class = "help", "Runs your data through the original scripts' logic (Legacy) and the corrected method with the same windows settings, then reverts each correction on its own to show which fixes drive the differences."),
      actionButton(ns("run_compare"), "Run comparison", icon = icon("code-compare"), class = "btn-primary"),
      uiOutput(ns("compare_status"))),
    uiOutput(ns("compare_body"))
  )
}

#' Comparison server
#' @export
mod_compare_server <- function(id, app_state) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    observeEvent(input$run_compare, {
      req(app_state$dsi_results, app_state$screen_settings)
      st <- app_state$screen_settings
      res <- withProgress(message = "Legacy vs Corrected", value = 0, {
        tryCatch(dsi_compare_methods(
          app_state$data_raw, app_state$col_map, st$group_cols, min_n = st$min_n, max_n = st$max_n,
          anchor_mode = if (identical(st$method, "corrected")) st$anchor_mode else "last_usable_year",
          effort_semantics = st$effort_semantics, refs = st$refs,
          weights = if (identical(st$method, "corrected")) st$weights else NULL,
          selection_opts = st$selection_opts, min_usable = st$min_usable,
          progress = function(m, v) setProgress(v, detail = m)),
          error = function(e) { showNotification(paste("Comparison error:", conditionMessage(e)), type = "error"); NULL })
      })
      req(res)
      app_state$comparison <- res
    })

    output$compare_status <- renderUI({
      if (is.null(app_state$dsi_results)) return(div(class = "callout", "Run screening first."))
      if (is.null(app_state$comparison)) p(class = "muted", style = "margin-top:10px;font-size:13px;", "Not run yet. Takes a few seconds (about 30 s for 40+ groups).")
    })

    output$compare_body <- renderUI({
      cmp <- app_state$comparison; req(cmp)
      w <- cmp$windows; g <- cmp$groups; a <- cmp$attribution
      both <- w[w$in_both, ]
      a$impact <- a$windows_changed + a$windows_added_or_removed
      top <- a[order(-a$groups_ready_changed, -a$impact, -a$mean_abs_delta), ][1, ]
      n_both <- sum(w$in_both %in% TRUE & is.finite(w$dsi_v2_legacy) & is.finite(w$dsi_v2_corrected))
      lead <- sprintf("Largest driver: %s. Reverting it changes %d of %d windows%s%s%s.",
                      top$label, top$windows_changed, top$windows_compared,
                      if (top$windows_changed > 0) sprintf(" (mean |\u0394| %.1f DSI_v2 points across compared windows)", top$mean_abs_delta) else "",
                      if (top$windows_added_or_removed > 0) sprintf(", adds or removes %d windows", top$windows_added_or_removed) else "",
                      if (top$groups_ready_changed > 0) sprintf(" and changes the READY status of %d group(s)", top$groups_ready_changed)
                      else if (top$groups_best_window_changed > 0) sprintf(" and moves the best window of %d group(s)", top$groups_best_window_changed) else "")
      tagList(
        dsi_card(title = "Summary",
          div(class = "metric-row",
            metric_box(sum(!is.na(w$valid_legacy)), "Legacy windows"),
            metric_box(sum(!is.na(w$valid_corrected)), "Corrected windows"),
            metric_box(sum(cmp$legacy$dsi_best$ready %in% TRUE), "READY legacy"),
            metric_box(sum(cmp$corrected$dsi_best$ready %in% TRUE), "READY corrected", "ready"),
            metric_box(sum(g$window_changed), "Best window changed"),
            metric_box(format_dsi_score(mean(abs(both$d_dsi_v2), na.rm = TRUE), 1), "Mean |\u0394 DSI_v2|")),
          div(class = "callout", id = ns("compare_headline"), lead),
          if (n_both == 0) div(class = "callout warn", style = "margin-top:8px;",
            "No window has a valid DSI_v2 in both runs: Legacy windows end at the last calendar year, corrected windows end at each group's last usable year. Compare the per-group table below; the per-window \u0394 columns show the effect of each fix on the corrected windows.")),
        div(class = "dsi-grid-2",
          dsi_card(title = "Which fixes drive the difference",
            p(class = "help", "Bar = windows whose DSI_v2 changes, or that appear or disappear, when that one correction is reverted from the corrected run. Label: count (mean |\u0394 DSI_v2| across windows present in both runs). Fixes interact, so bars do not add up to the total."),
            echarts4rOutput(ns("attr_chart"), height = "260px")),
          dsi_card(title = "Per window: Legacy vs Corrected DSI_v2",
            p(class = "help", "Each point is one window present in both runs. Points off the diagonal changed."),
            if (n_both > 0) echarts4rOutput(ns("scatter_chart"), height = "260px")
            else p(class = "muted", style = "padding:30px 0;text-align:center;", "No window has a valid DSI_v2 in both runs."))),
        dsi_card(title = "The corrections",
          div(class = "table-wrap", tags$table(class = "dsi-table fix-table",
            tags$thead(tags$tr(tags$th("Fix"), tags$th("Legacy (original)"), tags$th("Corrected"),
                               tags$th("Windows changed"), tags$th("Mean |\u0394|"), tags$th("Best window changed"), tags$th("READY changed"))),
            tags$tbody(lapply(seq_len(nrow(a)), function(i) {
              cat_row <- cmp$catalog[cmp$catalog$id == a$id[i], ]
              tags$tr(tags$td(strong(a$label[i])), tags$td(cat_row$legacy), tags$td(cat_row$corrected),
                      tags$td(sprintf("%d/%d%s", a$windows_changed[i], a$windows_compared[i],
                                      if (a$windows_added_or_removed[i] > 0) sprintf(" (+%d added/removed)", a$windows_added_or_removed[i]) else "")),
                      tags$td(sprintf("%.2f", a$mean_abs_delta[i])), tags$td(a$groups_best_window_changed[i]), tags$td(a$groups_ready_changed[i]))
            }))))),
        dsi_card(title = "Per group: suggested window and score",
          div(class = "table-wrap", tags$table(class = "dsi-table", id = ns("group_table"),
            tags$thead(tags$tr(tags$th("Group"), tags$th("Legacy window"), tags$th("Legacy DSI_v2"), tags$th("Corrected window"),
                               tags$th("Corrected DSI_v2"), tags$th("\u0394"), tags$th("READY (L \u2192 C)"))),
            tags$tbody(lapply(order(-abs(g$d_best_dsi_v2)), function(i) {
              d <- g$d_best_dsi_v2[i]
              tags$tr(tags$td(g$group_key[i]),
                      tags$td(sprintf("%s\u2013%s", g$start_year_legacy[i], g$end_year_legacy[i])),
                      tags$td(format_dsi_score(g$dsi_v2_legacy[i], 1)),
                      tags$td(sprintf("%s\u2013%s", g$start_year_corrected[i], g$end_year_corrected[i]),
                              if (isTRUE(g$window_changed[i])) span(class = "badge-pill badge-mod", style = "margin-left:4px;", "changed")),
                      tags$td(format_dsi_score(g$dsi_v2_corrected[i], 1)),
                      tags$td(class = if (is.finite(d) && d > 0) "delta-up" else if (is.finite(d) && d < 0) "delta-down",
                              if (is.finite(d)) sprintf("%+.1f", d) else "\u2014"),
                      tags$td(sprintf("%s \u2192 %s", if (isTRUE(g$ready_legacy[i])) "yes" else "no", if (isTRUE(g$ready_corrected[i])) "yes" else "no")))
            }))))),
        dsi_card(title = "Per window, with the effect of each fix",
          p(class = "help", "\u0394 columns: DSI_v2 (corrected) \u2212 DSI_v2 with only that fix reverted. Blank = window not present when the fix is reverted."),
          DT::dataTableOutput(ns("window_table")))
      )
    })

    output$attr_chart <- renderEcharts4r({
      a <- app_state$comparison$attribution; req(a)
      a$affected <- a$windows_changed + a$windows_added_or_removed
      a$lab <- sprintf("%d (|\u0394| %.1f)", a$affected, a$mean_abs_delta)
      a <- a[order(a$affected, a$mean_abs_delta), ]
      a$label <- factor(a$label, levels = a$label)
      a |> e_charts(label) |> e_bar(affected, name = "Windows affected", bind = lab, itemStyle = list(color = "#3498DB"),
                                   label = list(show = TRUE, position = "right", formatter = "{b}")) |>
        e_flip_coords() |> e_grid(left = 170, right = 90, top = 10, bottom = 30) |>
        e_legend(show = FALSE) |> e_tooltip(trigger = "item", formatter = htmlwidgets::JS("function(p){return p.value[1] + '<br/>windows changed, added or removed: ' + p.value[0] + '<br/>' + p.name;}")) |>
        e_animation(FALSE)
    })

    output$scatter_chart <- renderEcharts4r({
      w <- app_state$comparison$windows; req(w)
      w <- w[w$in_both & is.finite(w$dsi_v2_legacy) & is.finite(w$dsi_v2_corrected), ]
      req(nrow(w) > 0)
      w$label <- sprintf("%s %d\u2013%d", w$group_key, w$start_year, w$end_year)
      w |> e_charts(dsi_v2_legacy) |>
        e_scatter(dsi_v2_corrected, name = "window", symbol_size = 6, bind = label, itemStyle = list(color = "rgba(52,152,219,0.6)")) |>
        e_line(dsi_v2_legacy, name = "y = x", symbol = "none", lineStyle = list(color = "#999", type = "dashed"), y_index = 0) |>
        e_x_axis(name = "Legacy", min = 0, max = 100, nameLocation = "middle", nameGap = 24) |>
        e_y_axis(name = "Corrected", min = 0, max = 100) |>
        e_tooltip(formatter = htmlwidgets::JS("function(p){ if(p.seriesName!=='window') return ''; return p.name + '<br/>legacy ' + Number(p.value[0]).toFixed(1) + ' \u2192 corrected ' + Number(p.value[1]).toFixed(1);}")) |>
        e_legend(show = FALSE) |> e_grid(left = 44, right = 16, top = 16, bottom = 40) |> e_animation(FALSE)
    })

    output$window_table <- DT::renderDataTable({
      cmp <- app_state$comparison; req(cmp)
      w <- cmp$windows
      pf <- cmp$per_fix_windows
      lab <- stats::setNames(cmp$catalog$label, cmp$catalog$id)
      wide <- tidyr::pivot_wider(pf[, c("group_key", "start_year", "end_year", "fix", "delta")],
                                 names_from = fix, values_from = delta)
      names(wide)[-(1:3)] <- paste("\u0394", lab[names(wide)[-(1:3)]])
      out <- dplyr::left_join(w[, c("group_key", "start_year", "end_year", "dsi_v2_legacy", "dsi_v2_corrected", "d_dsi_v2")],
                              wide, by = c("group_key", "start_year", "end_year"))
      names(out)[1:6] <- c("Group", "Start", "End", "Legacy DSI_v2", "Corrected DSI_v2", "\u0394 total")
      num <- vapply(out, is.numeric, TRUE); num[2:3] <- FALSE
      out[num] <- lapply(out[num], function(x) round(x, 2))
      DT::datatable(out, rownames = FALSE, filter = "none",
                    options = list(pageLength = 10, scrollX = TRUE, order = list(list(5, "desc")), dom = "ftip"))
    })
  })
}

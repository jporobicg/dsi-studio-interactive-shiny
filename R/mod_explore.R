## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Module: Explore (Redesigned) ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

library(echarts4r)

#' Explore UI
#' @param id Module ID
#' @export
mod_explore_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    div(class = "step-header",
      h2("Explore Results"),
      p(class = "step-purpose",
        "Review DSI scores across all groups. Click any cell to examine window details, ",
        "component breakdowns, and diagnostic plots."
      )
    ),
    
    uiOutput(ns("explore_content"))
  )
}

#' Explore server
#' @param id Module ID
#' @param app_state Application state
#' @export
mod_explore_server <- function(id, app_state) {
  moduleServer(id, function(input, output, session) {
    
    output$explore_content <- renderUI({
      req(app_state$dsi_results)
      
      ns <- session$ns
      
      tagList(
        div(class = "content-section",
          h3(style = "font-size: 18px; font-weight: 600; margin-bottom: 16px;",
             "Suitability Score Grid"),
          p(style = "color: #7F8C8D; margin-bottom: 24px;",
            "Each cell shows best DSI score for a group. Color indicates suitability band. ",
            "Click to explore details."),
          
          div(class = "score-grid",
            lapply(1:nrow(app_state$dsi_results$dsi_best), function(i) {
              row <- app_state$dsi_results$dsi_best[i, ]
              
              band <- get_dsi_band(row$dsi_v2)
              band_class <- tolower(band)
              color <- get_dsi_color(band)
              
              actionButton(ns(paste0("cell_", i)),
                div(class = paste("score-cell", band_class),
                  div(class = "score-cell-title", row$group_key),
                  div(class = "score-cell-value", style = sprintf("color: %s;", color),
                      format_dsi_score(row$dsi_v2, 1)),
                  div(class = "score-cell-band", style = sprintf("color: %s;", color),
                      band)
                ),
                class = "btn-link", 
                style = "all: unset; display: block; width: 100%;"
              )
            })
          )
        ),
        
        uiOutput(ns("detail_view"))
      )
    })
    
    # Handle cell clicks
    observe({
      req(app_state$dsi_results)
      
      best <- app_state$dsi_results$dsi_best
      
      lapply(1:nrow(best), function(i) {
        observeEvent(input[[paste0("cell_", i)]], {
          row <- best[i, ]
          app_state$current_group <- row$group_key
          app_state$current_window <- row
        }, ignoreInit = TRUE)
      })
    })
    
    output$detail_view <- renderUI({
      req(app_state$current_group)
      req(app_state$current_window)
      
      ns <- session$ns
      
      grp <- app_state$current_group
      win <- app_state$current_window
      
      tagList(
        div(class = "content-section", style = "margin-top: 48px;",
          h3(style = "font-size: 18px; font-weight: 600; margin-bottom: 24px;",
             sprintf("Detail View: %s", grp)),
          
          div(class = "dsi-card",
            layout_columns(
              col_widths = c(4, 4, 4),
              
              div(
                div(class = "metric-label", "WINDOW"),
                div(class = "metric-value", style = "font-size: 20px;",
                    sprintf("%d–%d", win$start_year, win$end_year))
              ),
              
              div(
                div(class = "metric-label", "DSI SCORE"),
                div(class = "metric-value", style = sprintf("color: %s;", get_dsi_color(get_dsi_band(win$dsi))),
                    format_dsi_score(win$dsi, 1))
              ),
              
              div(
                div(class = "metric-label", "DSI V2 SCORE"),
                div(class = "metric-value", style = sprintf("color: %s;", get_dsi_color(get_dsi_band(win$dsi_v2))),
                    format_dsi_score(win$dsi_v2, 1))
              )
            ),
            
            tags$hr(style = "margin: 24px 0; border-top: 1px solid #E8E8E8;"),
            
            layout_columns(
              col_widths = c(6, 6),
              
              div(
                h4(style = "font-size: 14px; font-weight: 600; margin-bottom: 12px;",
                   "Window Metrics"),
                tags$dl(style = "font-size: 13px;",
                  tags$dt(style = "color: #7F8C8D; margin-bottom: 4px;", "Usable years"),
                  tags$dd(style = "margin-bottom: 12px;", win$n_usable),
                  tags$dt(style = "color: #7F8C8D; margin-bottom: 4px;", "β (slope)"),
                  tags$dd(style = "margin-bottom: 12px;", sprintf("%.4f", win$beta)),
                  tags$dt(style = "color: #7F8C8D; margin-bottom: 4px;", "p-value"),
                  tags$dd(style = "margin-bottom: 12px;", format.pval(win$p_value, digits = 3)),
                  tags$dt(style = "color: #7F8C8D; margin-bottom: 4px;", "Effort contrast"),
                  tags$dd(style = "margin-bottom: 12px;", sprintf("%.2f", win$ec)),
                  tags$dt(style = "color: #7F8C8D; margin-bottom: 4px;", "CPUE contrast"),
                  tags$dd(sprintf("%.2f", win$ic))
                )
              ),
              
              div(
                h4(style = "font-size: 14px; font-weight: 600; margin-bottom: 16px;",
                   "Component Scores"),
                echarts4rOutput(ns("component_chart"), height = "220px")
              )
            )
          ),
          
          div(class = "dsi-card",
            h3("Interactive Time Series"),
            p(style = "color: #7F8C8D; margin-bottom: 20px;",
              "Drag the slider to adjust window range. Use mouse wheel to zoom, drag to pan."),
            echarts4rOutput(ns("timeseries_interactive"), height = "450px")
          ),
          
          div(class = "dsi-card",
            h3("Diagnostics"),
            plotOutput(ns("diagnostic_plot"), height = "350px")
          )
        )
      )
    })
    
    output$component_chart <- renderEcharts4r({
      req(app_state$current_window)
      
      win <- app_state$current_window
      
      data.frame(
        component = c("Slope", "Effort", "CPUE", "Sample", "C-E"),
        score = c(win$s_slope, win$s_e, win$s_i, win$s_n, win$s_ce)
      ) %>%
        e_charts(component) %>%
        e_bar(score, 
             itemStyle = list(color = "#3498DB"),
             label = list(show = TRUE, position = "right", 
                         formatter = JS("function(p) { return p.value.toFixed(2); }"))) %>%
        e_y_axis(max = 1, splitLine = list(lineStyle = list(color = "#F0F0F0"))) %>%
        e_x_axis(axisLabel = list(fontSize = 11)) %>%
        e_flip_coords() %>%
        e_grid(left = "25%", right = "15%", top = "5%", bottom = "5%") %>%
        e_tooltip(trigger = "axis")
    })
    
    output$timeseries_interactive <- renderEcharts4r({
      req(app_state$current_group)
      req(app_state$current_window)
      req(app_state$data_std)
      
      grp <- app_state$current_group
      win <- app_state$current_window
      
      df_std <- app_state$data_std
      df_std$group_key <- make_group_key(df_std, app_state$group_cols)
      
      grp_data <- df_std[df_std$group_key == grp, ]
      grp_data <- grp_data[order(grp_data$year), ]
      
      # Create chart
      grp_data %>%
        e_charts(year) %>%
        e_line(catch, name = "Catch", 
              smooth = FALSE,
              lineStyle = list(width = 2)) %>%
        e_line(effort, name = "Effort",
              smooth = FALSE,
              lineStyle = list(width = 2)) %>%
        e_line(cpue, name = "CPUE",
              smooth = FALSE, 
              lineStyle = list(width = 2)) %>%
        e_tooltip(trigger = "axis") %>%
        e_datazoom(
          type = "slider",
          start = (win$start_year - min(grp_data$year, na.rm = TRUE)) / 
                  (max(grp_data$year, na.rm = TRUE) - min(grp_data$year, na.rm = TRUE)) * 100,
          end = (win$end_year - min(grp_data$year, na.rm = TRUE)) / 
                (max(grp_data$year, na.rm = TRUE) - min(grp_data$year, na.rm = TRUE)) * 100,
          bottom = 20
        ) %>%
        e_datazoom(type = "inside") %>%
        e_toolbox_feature(feature = "dataZoom") %>%
        e_toolbox_feature(feature = "restore") %>%
        e_toolbox_feature(feature = "saveAsImage") %>%
        e_legend(top = "3%") %>%
        e_grid(top = "12%", bottom = "15%", left = "8%", right = "5%") %>%
        e_mark_area(
          data = list(list(
            list(xAxis = win$start_year),
            list(xAxis = win$end_year)
          )),
          itemStyle = list(color = "rgba(52, 152, 219, 0.15)")
        ) %>%
        e_x_axis(axisLabel = list(fontSize = 11)) %>%
        e_y_axis(axisLabel = list(fontSize = 11))
    })
    
    output$diagnostic_plot <- renderPlot({
      req(app_state$current_group)
      req(app_state$current_window)
      req(app_state$data_std)
      
      grp <- app_state$current_group
      win <- app_state$current_window
      
      df_std <- app_state$data_std
      df_std$group_key <- make_group_key(df_std, app_state$group_cols)
      
      grp_data <- df_std[df_std$group_key == grp, ]
      grp_data <- grp_data[grp_data$year >= win$start_year & 
                          grp_data$year <= win$end_year, ]
      grp_data <- grp_data[order(grp_data$year), ]
      
      log_result <- safe_log_cpue(grp_data$cpue)
      grp_data$log_cpue <- log_result$log_cpue
      
      usable_mask <- is.finite(grp_data$log_cpue) & is.finite(grp_data$effort)
      fit_data <- grp_data[usable_mask, ]
      
      if (nrow(fit_data) < 3) {
        plot.new()
        text(0.5, 0.5, "Insufficient data", cex = 1.2, col = "#7F8C8D")
        return()
      }
      
      fit <- lm(log_cpue ~ effort, data = fit_data)
      fit_data$fitted <- fitted(fit)
      fit_data$std_resid <- rstandard(fit)
      
      p1 <- ggplot(fit_data, aes(x = effort, y = log_cpue)) +
        geom_point(size = 2.5, alpha = 0.6, color = "#3498DB") +
        geom_smooth(method = "lm", se = TRUE, color = "#2C3E50", fill = "#3498DB", alpha = 0.2) +
        labs(title = "ln(CPUE) vs Effort", x = "Effort", y = "ln(CPUE)") +
        theme_dsi()
      
      p2 <- ggplot(fit_data, aes(x = fitted, y = std_resid)) +
        geom_point(size = 2.5, alpha = 0.6, color = "#3498DB") +
        geom_hline(yintercept = 0, linetype = "dashed", color = "#7F8C8D") +
        geom_hline(yintercept = c(-2, 2), linetype = "dotted", color = "#D55E00") +
        labs(title = "Standardized Residuals", x = "Fitted values", y = "Std. Residuals") +
        theme_dsi()
      
      gridExtra::grid.arrange(p1, p2, ncol = 2)
    })
  })
}

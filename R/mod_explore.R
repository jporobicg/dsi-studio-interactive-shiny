## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Module: Explore (with Interactive Features) ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

library(echarts4r)

#' Explore UI
#' 
#' @param id Module ID
#' @export
mod_explore_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    h3("Explore Results"),
    
    uiOutput(ns("explore_content"))
  )
}

#' Explore server
#' 
#' @param id Module ID
#' @param app_state Application state
#' @export
mod_explore_server <- function(id, app_state) {
  moduleServer(id, function(input, output, session) {
    
    output$explore_content <- renderUI({
      req(app_state$dsi_results)
      
      ns <- session$ns
      
      tagList(
        card(
          card_header("Suitability Score Grid"),
          card_body(
            p("Each cell shows a group with mini sparkline of DSI scores by start year. Color indicates best DSI band. Click to explore details."),
            uiOutput(ns("score_grid_ui"))
          )
        ),
        
        uiOutput(ns("detail_view"))
      )
    })
    
    output$score_grid_ui <- renderUI({
      req(app_state$dsi_results)
      
      ns <- session$ns
      
      all_windows <- app_state$dsi_results$dsi_all
      best_windows <- app_state$dsi_results$dsi_best
      
      groups <- unique(all_windows$group_key)
      
      # Create grid of cells
      cells <- lapply(groups, function(grp) {
        grp_windows <- all_windows[all_windows$group_key == grp & all_windows$valid, ]
        best <- best_windows[best_windows$group_key == grp, ]
        
        if (nrow(grp_windows) == 0 || nrow(best) == 0) {
          return(NULL)
        }
        
        # Order by start year
        grp_windows <- grp_windows[order(grp_windows$start_year), ]
        
        best_dsi <- best$dsi_v2[1]
        band <- get_dsi_band(best_dsi)
        bg_color <- switch(band$label,
          "Good" = "#009E73",
          "Moderate" = "#E69F00",
          "Poor" = "#D55E00",
          "#CCCCCC"
        )
        
        # Create sparkline data
        spark_data <- paste0("[", paste(round(grp_windows$dsi_v2, 1), collapse = ","), "]")
        
        div(
          class = "score-grid-cell",
          style = sprintf("background-color: %s; border: 2px solid %s;", 
                         paste0(bg_color, "20"), bg_color),
          onclick = sprintf("Shiny.setInputValue('%s', '%s', {priority: 'event'});", 
                          ns("cell_click"), grp),
          div(class = "cell-title", grp),
          div(class = "cell-score", sprintf("DSI: %.1f", best_dsi)),
          div(class = "cell-band", band$label),
          tags$canvas(
            class = "sparkline-canvas",
            `data-values` = spark_data,
            width = "150",
            height = "30"
          )
        )
      })
      
      tagList(
        tags$style(HTML("
          .score-grid-cell {
            display: inline-block;
            width: 200px;
            margin: 10px;
            padding: 15px;
            border-radius: 8px;
            cursor: pointer;
            transition: transform 0.2s;
            vertical-align: top;
          }
          .score-grid-cell:hover {
            transform: scale(1.05);
            box-shadow: 0 4px 8px rgba(0,0,0,0.2);
          }
          .cell-title {
            font-weight: bold;
            margin-bottom: 5px;
            font-size: 14px;
          }
          .cell-score {
            font-size: 18px;
            font-weight: bold;
            margin: 5px 0;
          }
          .cell-band {
            font-size: 12px;
            margin-bottom: 10px;
          }
          .sparkline-canvas {
            display: block;
            margin-top: 5px;
          }
        ")),
        tags$script(HTML("
          $(document).ready(function() {
            function drawSparkline(canvas) {
              var ctx = canvas.getContext('2d');
              var values = JSON.parse(canvas.getAttribute('data-values'));
              if (!values || values.length === 0) return;
              
              var width = canvas.width;
              var height = canvas.height;
              var max = Math.max(...values, 100);
              var min = Math.min(...values, 0);
              var range = max - min || 1;
              
              ctx.clearRect(0, 0, width, height);
              ctx.strokeStyle = 'rgba(0, 0, 0, 0.6)';
              ctx.lineWidth = 2;
              ctx.beginPath();
              
              values.forEach(function(val, i) {
                var x = (i / (values.length - 1)) * width;
                var y = height - ((val - min) / range) * height;
                if (i === 0) {
                  ctx.moveTo(x, y);
                } else {
                  ctx.lineTo(x, y);
                }
              });
              
              ctx.stroke();
            }
            
            // Draw all sparklines
            $('.sparkline-canvas').each(function() {
              drawSparkline(this);
            });
            
            // Redraw on any UI update
            setTimeout(function() {
              $('.sparkline-canvas').each(function() {
                drawSparkline(this);
              });
            }, 500);
          });
        ")),
        cells
      )
    })
    
    observeEvent(input$cell_click, {
      req(input$cell_click)
      app_state$current_group <- input$cell_click
      
      # Find the best window for this group
      best <- app_state$dsi_results$dsi_best
      grp_best <- best[best$group_key == input$cell_click, ]
      if (nrow(grp_best) > 0) {
        app_state$current_window <- grp_best[1, ]
      }
    })
    
    output$detail_view <- renderUI({
      req(app_state$current_group)
      req(app_state$current_window)
      
      ns <- session$ns
      
      grp <- app_state$current_group
      win <- app_state$current_window
      
      tagList(
        card(
          card_header(sprintf("Detail View: %s", grp)),
          card_body(
            layout_columns(
              col_widths = c(6, 6),
              
              card(
                card_header("Window Details"),
                card_body(
                  tags$dl(
                    tags$dt("DSI"), tags$dd(format_dsi_score(win$dsi, 1)),
                    tags$dt("DSI_v2"), tags$dd(format_dsi_score(win$dsi_v2, 1)),
                    tags$dt("Window"), tags$dd(sprintf("%d-%d", win$start_year, win$end_year)),
                    tags$dt("Usable years"), tags$dd(win$n_usable),
                    tags$dt("β (slope)"), tags$dd(sprintf("%.4f", win$beta)),
                    tags$dt("p-value"), tags$dd(format.pval(win$p_value, digits = 3))
                  )
                )
              ),
              
              card(
                card_header("Component Scores"),
                card_body(
                  echarts4rOutput(ns("component_chart"), height = "250px")
                )
              )
            )
          )
        ),
        
        card(
          card_header("Interactive Time Series Explorer"),
          card_body(
            p("Use the slider below to adjust the time window. Drag to zoom, scroll to pan."),
            echarts4rOutput(ns("timeseries_interactive"), height = "500px")
          )
        ),
        
        card(
          card_header("Diagnostics"),
          card_body(
            plotOutput(ns("diagnostic_plot"), height = "400px")
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
                         formatter = htmlwidgets::JS("function(p) { var v = Array.isArray(p.value) ? p.value[0] : p.value; return Number(v).toFixed(2); }"))) %>%
        e_y_axis(max = 1, splitLine = list(lineStyle = list(color = "#F0F0F0"))) %>%
        e_x_axis(axisLabel = list(fontSize = 11)) %>%
        e_flip_coords() %>%
        e_grid(left = "20%", right = "15%") %>%
        e_tooltip(trigger = "axis") %>%
        e_title("Component Scores", left = "center")
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
      
      # Create interactive chart with data zoom
      grp_data %>%
        e_charts(year) %>%
        e_line(catch, name = "Catch", 
              smooth = FALSE,
              lineStyle = list(width = 2),
              emphasis = list(focus = "series")) %>%
        e_line(effort, name = "Effort",
              smooth = FALSE,
              lineStyle = list(width = 2),
              emphasis = list(focus = "series")) %>%
        e_line(cpue, name = "CPUE",
              smooth = FALSE, 
              lineStyle = list(width = 2),
              emphasis = list(focus = "series")) %>%
        e_tooltip(trigger = "axis") %>%
        e_datazoom(
          type = "slider",
          start = (win$start_year - min(grp_data$year, na.rm = TRUE)) / 
                  (max(grp_data$year, na.rm = TRUE) - min(grp_data$year, na.rm = TRUE)) * 100,
          end = (win$end_year - min(grp_data$year, na.rm = TRUE)) / 
                (max(grp_data$year, na.rm = TRUE) - min(grp_data$year, na.rm = TRUE)) * 100
        ) %>%
        e_datazoom(type = "inside") %>%
        e_toolbox_feature(feature = "dataZoom") %>%
        e_toolbox_feature(feature = "restore") %>%
        e_toolbox_feature(feature = "saveAsImage") %>%
        e_legend(top = "3%") %>%
        e_grid(top = "12%", bottom = "15%", left = "8%", right = "5%") %>%
        e_mark_area(
          data = list(
            list(xAxis = win$start_year),
            list(xAxis = win$end_year)
          ),
          itemStyle = list(color = "rgba(52, 152, 219, 0.15)")
        ) %>%
        e_x_axis(axisLabel = list(fontSize = 11, formatter = htmlwidgets::JS("function(v) { return String(v); }")), min = "dataMin", max = "dataMax") %>%
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
        text(0.5, 0.5, "Insufficient data for diagnostics", cex = 1.5)
        return()
      }
      
      fit <- lm(log_cpue ~ effort, data = fit_data)
      
      fit_data$fitted <- fitted(fit)
      fit_data$resid <- residuals(fit)
      fit_data$std_resid <- rstandard(fit)
      
      p1 <- ggplot(fit_data, aes(x = effort, y = log_cpue)) +
        geom_point(size = 2, alpha = 0.7) +
        geom_smooth(method = "lm", se = TRUE, color = "#3498DB") +
        labs(
          title = "ln(CPUE) vs Effort",
          x = "Effort",
          y = "ln(CPUE)"
        ) +
        theme_dsi()
      
      p2 <- ggplot(fit_data, aes(x = fitted, y = std_resid)) +
        geom_point(size = 2, alpha = 0.7) +
        geom_hline(yintercept = 0, linetype = "dashed") +
        geom_hline(yintercept = c(-2, 2), linetype = "dotted", color = "#D55E00") +
        labs(
          title = "Standardized Residuals",
          x = "Fitted values",
          y = "Std. Residuals"
        ) +
        theme_dsi()
      
      gridExtra::grid.arrange(p1, p2, ncol = 2)
    })
  })
}

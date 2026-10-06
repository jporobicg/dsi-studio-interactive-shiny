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
      
      # Detect if we have both species and fleet dimensions for matrix layout
      # [LOCAL FIX 3] standardize_columns() always creates a `fleet` column (all NA
      # when unmapped), so testing names(data_std) forced the matrix layout for
      # single-dimension data. Use the mapped grouping columns instead.
      has_species <- "species" %in% app_state$group_cols
      has_fleet <- "fleet" %in% app_state$group_cols
      use_matrix <- has_species && has_fleet
      
      if (use_matrix) {
        # [LOCAL FIX 3] make_group_key() joins with " | ", not "___"
        key_sep <- " | "
        best_windows$species_name <- sapply(strsplit(as.character(best_windows$group_key), key_sep, fixed = TRUE), `[`, 1)
        best_windows$fleet_name <- sapply(strsplit(as.character(best_windows$group_key), key_sep, fixed = TRUE), `[`, 2)
        
        species_list <- unique(best_windows$species_name)
        fleet_list <- unique(best_windows$fleet_name)
        
        # Create matrix layout
        matrix_content <- tagList(
          tags$style(HTML("
            .dsi-matrix {
              display: table;
              border-collapse: separate;
              border-spacing: 4px;
              margin: 1rem 0;
            }
            .dsi-matrix-row {
              display: table-row;
            }
            .dsi-matrix-header {
              display: table-cell;
              padding: 0.5rem;
              font-weight: bold;
              text-align: center;
              background: #f5f5f5;
              border: 1px solid #ddd;
              font-size: 0.85rem;
            }
            .dsi-matrix-row-label {
              display: table-cell;
              padding: 0.5rem;
              font-weight: bold;
              text-align: right;
              background: #f5f5f5;
              border: 1px solid #ddd;
              font-size: 0.85rem;
              vertical-align: middle;
            }
            .dsi-matrix-cell {
              display: table-cell;
              width: 120px;
              padding: 8px;
              border-radius: 4px;
              cursor: pointer;
              transition: transform 0.15s;
              vertical-align: top;
              text-align: center;
              font-size: 0.75rem;
            }
            .dsi-matrix-cell:hover {
              transform: scale(1.08);
              box-shadow: 0 2px 8px rgba(0,0,0,0.25);
              z-index: 10;
            }
            .dsi-matrix-cell .cell-score {
              font-size: 1rem;
              font-weight: bold;
              margin: 3px 0;
            }
            .dsi-matrix-cell .cell-band {
              font-size: 0.7rem;
              margin-bottom: 6px;
            }
            .dsi-matrix-cell canvas {
              margin: 0 auto;
              display: block;
            }
          ")),
          div(class = "dsi-matrix",
            # Header row
            div(class = "dsi-matrix-row",
              div(class = "dsi-matrix-header", style = "width: 100px;", "Species \\ Fleet"),
              lapply(fleet_list, function(f) {
                div(class = "dsi-matrix-header", f)
              })
            ),
            # Data rows
            lapply(species_list, function(sp) {
              div(class = "dsi-matrix-row",
                div(class = "dsi-matrix-row-label", sp),
                lapply(fleet_list, function(fl) {
                  grp_key <- paste0(sp, key_sep, fl)  # [LOCAL FIX 3]
                  best <- best_windows[best_windows$group_key == grp_key, ]
                  
                  if (nrow(best) == 0) {
                    return(div(class = "dsi-matrix-cell", style = "background: #f0f0f0;", "—"))
                  }
                  
                  grp_windows <- all_windows[all_windows$group_key == grp_key & all_windows$valid, ]
                  grp_windows <- grp_windows[order(grp_windows$start_year), ]
                  
                  best_dsi <- best$dsi_v2[1]
                  band <- get_dsi_band(best_dsi)
                  bg_color <- switch(band$label,
                    "Good" = "#009E73",
                    "Moderate" = "#E69F00",
                    "Poor" = "#D55E00",
                    "#CCCCCC"
                  )
                  
                  spark_data <- paste0("[", paste(round(grp_windows$dsi_v2, 1), collapse = ","), "]")
                  
                  div(
                    class = "dsi-matrix-cell",
                    style = sprintf("background-color: %s; border: 2px solid %s;", 
                                   paste0(bg_color, "20"), bg_color),
                    onclick = sprintf("Shiny.setInputValue('%s', '%s', {priority: 'event'});", 
                                    ns("cell_click"), grp_key),
                    div(class = "cell-score", sprintf("%.0f", best_dsi)),
                    div(class = "cell-band", band$label),
                    tags$canvas(
                      class = "sparkline-canvas",
                      `data-values` = spark_data,
                      width = "100",
                      height = "20"
                    )
                  )
                })
              )
            })
          )
        )
      } else {
        # Simple flow layout for single dimension
        groups <- unique(all_windows$group_key)
        
        cells <- lapply(groups, function(grp) {
          grp_windows <- all_windows[all_windows$group_key == grp & all_windows$valid, ]
          best <- best_windows[best_windows$group_key == grp, ]
          
          if (nrow(grp_windows) == 0 || nrow(best) == 0) {
            return(NULL)
          }
          
          grp_windows <- grp_windows[order(grp_windows$start_year), ]
          
          best_dsi <- best$dsi_v2[1]
          band <- get_dsi_band(best_dsi)
          bg_color <- switch(band$label,
            "Good" = "#009E73",
            "Moderate" = "#E69F00",
            "Poor" = "#D55E00",
            "#CCCCCC"
          )
          
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
        
        matrix_content <- tagList(
          tags$style(HTML("
            .score-grid-cell {
              display: inline-block;
              width: 200px;
              min-width: 180px;
              max-width: 250px;
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
            .score-grid-container {
              display: flex;
              flex-wrap: wrap;
              gap: 10px;
              justify-content: flex-start;
              align-items: flex-start;
            }
          ")),
          div(class = "score-grid-container", cells)
        )
      }
      
      tagList(
        matrix_content,
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
        "))
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
                    tags$dt("β (slope)"), tags$dd(sprintf("%.3g", win$beta)),
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
      
      # Create interactive chart with data zoom and separate y-axes
      grp_data %>%
        e_charts(year) %>%
        # [LOCAL FIX 4] echarts4r ignores/overrides `yAxisIndex` passed via `...`;
        # all three series landed on one axis (0-150000) so CPUE was still flat.
        # Use echarts4r's own `y_index` and give axes 1/2 a right-hand position.
        e_line(catch, name = "Catch", 
              y_index = 0,
              smooth = FALSE,
              lineStyle = list(width = 2),
              itemStyle = list(color = "#E69F00"),
              emphasis = list(focus = "series")) %>%
        e_line(effort, name = "Effort",
              y_index = 1,
              smooth = FALSE,
              lineStyle = list(width = 2),
              itemStyle = list(color = "#56B4E9"),
              emphasis = list(focus = "series")) %>%
        e_line(cpue, name = "CPUE",
              y_index = 2,
              smooth = FALSE, 
              lineStyle = list(width = 2),
              itemStyle = list(color = "#009E73"),
              emphasis = list(focus = "series")) %>%
        e_tooltip(trigger = "axis") %>%
        e_y_axis(index = 0, name = "Catch", nameLocation = "middle", nameGap = 50,
                axisLabel = list(fontSize = 11),
                splitLine = list(show = FALSE)) %>%
        e_y_axis(index = 1, name = "Effort", nameLocation = "middle", nameGap = 50,
                position = "right",  # [LOCAL FIX 4]
                axisLabel = list(fontSize = 11),
                splitLine = list(show = FALSE)) %>%
        e_y_axis(index = 2, name = "CPUE", nameLocation = "middle", nameGap = 50,
                position = "right", offset = 80,  # [LOCAL FIX 4]
                axisLabel = list(fontSize = 11)) %>%
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
        e_grid(top = "12%", bottom = "15%", left = "8%", right = "15%") %>%
        e_mark_area(
          data = list(
            list(xAxis = win$start_year),
            list(xAxis = win$end_year)
          ),
          itemStyle = list(color = "rgba(52, 152, 219, 0.15)")
        ) %>%
        e_x_axis(axisLabel = list(fontSize = 11, formatter = htmlwidgets::JS("function(v) { return String(v); }")), min = "dataMin", max = "dataMax") %>%
        e_title("Time Series (drag slider to change window)", left = "center", top = "0%")
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

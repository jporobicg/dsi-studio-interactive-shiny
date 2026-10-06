## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Module: Explore ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

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
          card_header("Suitability Matrix"),
          card_body(
            p("Matrix showing DSI scores by group. Click a group to view details."),
            DT::dataTableOutput(ns("matrix_table"))
          )
        ),
        
        card(
          card_header("Window Explorer"),
          card_body(
            uiOutput(ns("window_explorer"))
          )
        )
      )
    })
    
    output$matrix_table <- DT::renderDataTable({
      req(app_state$dsi_results)
      
      best <- app_state$dsi_results$dsi_best
      
      display_data <- best %>%
        dplyr::select(
          group_key,
          start_year,
          end_year,
          n_usable,
          dsi,
          dsi_v2,
          beta,
          p_value,
          ready,
          selection_reason
        ) %>%
        dplyr::mutate(
          window = sprintf("%d-%d", start_year, end_year),
          dsi = round(dsi, 1),
          dsi_v2 = round(dsi_v2, 1),
          beta = round(beta, 4),
          p_value = format.pval(p_value, digits = 3),
          ready = ifelse(ready, "✓", "✗")
        ) %>%
        dplyr::select(
          Group = group_key,
          Window = window,
          `N usable` = n_usable,
          DSI = dsi,
          DSI_v2 = dsi_v2,
          β = beta,
          `p-value` = p_value,
          READY = ready,
          Reason = selection_reason
        )
      
      DT::datatable(
        display_data,
        selection = "single",
        options = list(
          pageLength = 20,
          scrollX = TRUE,
          dom = 'ftip'
        ),
        rownames = FALSE
      )
    })
    
    observeEvent(input$matrix_table_rows_selected, {
      req(app_state$dsi_results)
      
      selected_row <- input$matrix_table_rows_selected
      if (length(selected_row) == 0) return()
      
      best <- app_state$dsi_results$dsi_best
      selected_group <- best[selected_row, ]
      
      app_state$current_group <- selected_group$group_key
      app_state$current_window <- selected_group
    })
    
    output$window_explorer <- renderUI({
      req(app_state$current_group)
      req(app_state$current_window)
      
      ns <- session$ns
      
      grp <- app_state$current_group
      win <- app_state$current_window
      
      tagList(
        h4(sprintf("Group: %s", grp)),
        h5(sprintf("Selected window: %d-%d", win$start_year, win$end_year)),
        
        layout_columns(
          col_widths = c(6, 6),
          
          card(
            card_header("Window Details"),
            card_body(
              tags$dl(
                tags$dt("DSI"), tags$dd(format_dsi_score(win$dsi, 1)),
                tags$dt("DSI_v2"), tags$dd(format_dsi_score(win$dsi_v2, 1)),
                tags$dt("Usable years"), tags$dd(win$n_usable),
                tags$dt("β (slope)"), tags$dd(sprintf("%.4f", win$beta)),
                tags$dt("p-value"), tags$dd(format.pval(win$p_value, digits = 3)),
                tags$dt("Effort contrast"), tags$dd(sprintf("%.2f", win$ec)),
                tags$dt("CPUE contrast"), tags$dd(sprintf("%.2f", win$ic)),
                tags$dt("Coverage"), tags$dd(sprintf("%.1f%%", win$frac_usable * 100)),
                tags$dt("Outlier penalty"), tags$dd(sprintf("%.2f", win$p_out))
              )
            )
          ),
          
          card(
            card_header("Component Scores"),
            card_body(
              plotOutput(ns("component_plot"), height = "300px")
            )
          )
        ),
        
        card(
          card_header("Time Series"),
          card_body(
            plotOutput(ns("timeseries_plot"), height = "400px")
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
    
    output$component_plot <- renderPlot({
      req(app_state$current_window)
      
      win <- app_state$current_window
      
      components <- data.frame(
        component = c("Slope", "Effort", "CPUE", "Sample", "C-E"),
        score = c(win$s_slope, win$s_e, win$s_i, win$s_n, win$s_ce)
      )
      
      ggplot(components, aes(x = component, y = score)) +
        geom_col(fill = "#3498DB", alpha = 0.8) +
        geom_hline(yintercept = 1, linetype = "dashed", color = "gray50") +
        coord_flip() +
        labs(
          title = "Component Scores",
          x = NULL,
          y = "Score (0-1)"
        ) +
        theme_dsi() +
        ylim(0, 1)
    })
    
    output$timeseries_plot <- renderPlot({
      req(app_state$current_group)
      req(app_state$current_window)
      req(app_state$data_std)
      
      grp <- app_state$current_group
      win <- app_state$current_window
      
      df_std <- app_state$data_std
      df_std$group_key <- make_group_key(df_std, app_state$group_cols)
      
      grp_data <- df_std[df_std$group_key == grp, ]
      
      in_window <- grp_data$year >= win$start_year & grp_data$year <= win$end_year
      
      grp_data$in_window <- in_window
      
      p1 <- ggplot(grp_data, aes(x = year, y = catch)) +
        geom_line(aes(color = in_window, linewidth = in_window)) +
        geom_point(aes(color = in_window, size = in_window)) +
        scale_color_manual(values = c("TRUE" = "#3498DB", "FALSE" = "gray70")) +
        scale_linewidth_manual(values = c("TRUE" = 1, "FALSE" = 0.5)) +
        scale_size_manual(values = c("TRUE" = 2, "FALSE" = 1)) +
        labs(title = "Catch", y = "Catch") +
        theme_dsi() +
        theme(legend.position = "none", axis.title.x = element_blank())
      
      p2 <- ggplot(grp_data, aes(x = year, y = effort)) +
        geom_line(aes(color = in_window, linewidth = in_window)) +
        geom_point(aes(color = in_window, size = in_window)) +
        scale_color_manual(values = c("TRUE" = "#3498DB", "FALSE" = "gray70")) +
        scale_linewidth_manual(values = c("TRUE" = 1, "FALSE" = 0.5)) +
        scale_size_manual(values = c("TRUE" = 2, "FALSE" = 1)) +
        labs(title = "Effort", y = "Effort") +
        theme_dsi() +
        theme(legend.position = "none", axis.title.x = element_blank())
      
      p3 <- ggplot(grp_data, aes(x = year, y = cpue)) +
        geom_line(aes(color = in_window, linewidth = in_window)) +
        geom_point(aes(color = in_window, size = in_window)) +
        scale_color_manual(values = c("TRUE" = "#3498DB", "FALSE" = "gray70")) +
        scale_linewidth_manual(values = c("TRUE" = 1, "FALSE" = 0.5)) +
        scale_size_manual(values = c("TRUE" = 2, "FALSE" = 1)) +
        labs(title = "CPUE", x = "Year", y = "CPUE") +
        theme_dsi() +
        theme(legend.position = "none")
      
      gridExtra::grid.arrange(p1, p2, p3, ncol = 1)
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

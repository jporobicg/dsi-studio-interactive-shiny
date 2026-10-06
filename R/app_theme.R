## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ DSI Studio: Custom Theme ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' DSI Studio theme with distinctive scientific product styling
#' @export
dsi_theme <- function() {
  bslib::bs_theme(
    version = 5,
    bg = "#FAFAFA",
    fg = "#2C2C2C",
    primary = "#3498DB",
    secondary = "#7F8C8D",
    success = "#009E73",
    warning = "#E69F00", 
    danger = "#D55E00",
    base_font = bslib::font_google("IBM Plex Sans"),
    code_font = bslib::font_google("IBM Plex Mono"),
    heading_font = bslib::font_google("IBM Plex Sans", wght = 600),
    font_scale = 0.95
  )
}

#' Get DSI band color
#' @export
get_dsi_band <- function(score) {
  if (is.na(score)) return("Invalid")
  if (score >= 70) return("Good")
  if (score >= 50) return("Moderate")
  return("Poor")
}

#' Get DSI band color code
#' @export
get_dsi_color <- function(band) {
  switch(band,
    "Good" = "#009E73",
    "Moderate" = "#E69F00",
    "Poor" = "#D55E00",
    "#CCCCCC"
  )
}

#' Format DSI score with color
#' @export
format_dsi_score <- function(score, digits = 1) {
  if (is.na(score)) return("—")
  sprintf("%.1f", round(score, digits))
}

#' ggplot2 theme for DSI plots
#' @export
theme_dsi <- function() {
  ggplot2::theme_minimal(base_size = 11, base_family = "IBM Plex Sans") +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = "#FAFAFA", color = NA),
      panel.background = ggplot2::element_rect(fill = "white", color = NA),
      panel.grid.major = ggplot2::element_line(color = "#E8E8E8", linewidth = 0.3),
      panel.grid.minor = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(size = 13, face = "bold", margin = ggplot2::margin(b = 10)),
      axis.title = ggplot2::element_text(size = 10),
      axis.text = ggplot2::element_text(size = 9),
      legend.position = "top",
      legend.background = ggplot2::element_rect(fill = "white", color = "#E8E8E8"),
      legend.title = ggplot2::element_text(size = 10),
      plot.margin = ggplot2::margin(15, 15, 15, 15)
    )
}

#' Custom CSS for DSI Studio
#' @keywords internal
dsi_custom_css <- function() {
  tags$style(HTML("
    /* Global styling */
    body {
      font-family: 'IBM Plex Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      font-variant-numeric: tabular-nums;
      background-color: #FAFAFA;
    }
    
    /* Step rail styling */
    .step-rail {
      background: white;
      border-right: 1px solid #E0E0E0;
      padding: 0;
      overflow-y: auto;
    }
    
    .step-item {
      padding: 20px 24px;
      border-bottom: 1px solid #F0F0F0;
      cursor: pointer;
      transition: background 0.15s ease;
      position: relative;
    }
    
    .step-item:hover {
      background: #F8F9FA;
    }
    
    .step-item.active {
      background: #F0F7FC;
      border-left: 3px solid #3498DB;
      padding-left: 21px;
    }
    
    .step-item.completed {
      opacity: 0.8;
    }
    
    .step-item.locked {
      opacity: 0.5;
      cursor: not-allowed;
    }
    
    .step-number {
      display: inline-block;
      width: 28px;
      height: 28px;
      border-radius: 14px;
      background: #E8E8E8;
      color: #666;
      text-align: center;
      line-height: 28px;
      font-weight: 600;
      font-size: 13px;
      margin-right: 12px;
      vertical-align: middle;
    }
    
    .step-item.active .step-number {
      background: #3498DB;
      color: white;
    }
    
    .step-item.completed .step-number {
      background: #009E73;
      color: white;
    }
    
    .step-title {
      font-weight: 600;
      font-size: 14px;
      color: #2C2C2C;
      display: inline;
      vertical-align: middle;
    }
    
    .step-subtitle {
      font-size: 12px;
      color: #7F8C8D;
      margin-top: 4px;
      line-height: 1.4;
    }
    
    /* Context rail */
    .context-rail {
      background: white;
      padding: 24px;
      border-left: 1px solid #E0E0E0;
      font-size: 13px;
    }
    
    .context-section {
      margin-bottom: 24px;
    }
    
    .context-label {
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      color: #95A5A6;
      margin-bottom: 6px;
      font-weight: 600;
    }
    
    .context-value {
      font-size: 15px;
      font-weight: 600;
      color: #2C2C2C;
      font-variant-numeric: tabular-nums;
    }
    
    .context-value.empty {
      color: #BDC3C7;
      font-weight: 400;
    }
    
    /* Main content area */
    .main-content {
      padding: 40px;
      max-width: 1200px;
    }
    
    .step-header {
      margin-bottom: 32px;
    }
    
    .step-header h2 {
      font-size: 28px;
      font-weight: 600;
      color: #2C2C2C;
      margin: 0 0 8px 0;
    }
    
    .step-purpose {
      font-size: 15px;
      color: #7F8C8D;
      line-height: 1.6;
      max-width: 600px;
    }
    
    /* Cards without default chrome */
    .dsi-card {
      background: white;
      border: 1px solid #E8E8E8;
      border-radius: 8px;
      padding: 28px;
      margin-bottom: 24px;
    }
    
    .dsi-card h3 {
      font-size: 16px;
      font-weight: 600;
      margin: 0 0 16px 0;
      color: #2C2C2C;
    }
    
    /* Primary action buttons */
    .btn-primary-action {
      background: #3498DB;
      color: white;
      border: none;
      padding: 12px 28px;
      font-size: 14px;
      font-weight: 600;
      border-radius: 6px;
      cursor: pointer;
      transition: background 0.15s ease;
    }
    
    .btn-primary-action:hover {
      background: #2980B9;
    }
    
    /* Empty state styling */
    .empty-state {
      text-align: center;
      padding: 60px 40px;
      background: white;
      border: 2px dashed #D0D0D0;
      border-radius: 8px;
      margin-bottom: 24px;
    }
    
    .empty-state-icon {
      font-size: 48px;
      color: #BDC3C7;
      margin-bottom: 16px;
    }
    
    .empty-state h3 {
      font-size: 18px;
      font-weight: 600;
      color: #2C2C2C;
      margin-bottom: 8px;
    }
    
    .empty-state p {
      font-size: 14px;
      color: #7F8C8D;
      max-width: 500px;
      margin: 0 auto 24px;
    }
    
    /* Demo data tiles */
    .demo-tiles {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
      gap: 16px;
      margin-top: 32px;
    }
    
    .demo-tile {
      background: white;
      border: 1px solid #E8E8E8;
      border-radius: 8px;
      padding: 20px;
      cursor: pointer;
      transition: all 0.15s ease;
      position: relative;
    }
    
    .demo-tile:hover {
      border-color: #3498DB;
      box-shadow: 0 2px 8px rgba(52, 152, 219, 0.1);
      transform: translateY(-2px);
    }
    
    .demo-tile-badge {
      position: absolute;
      top: 12px;
      right: 12px;
      background: #FEF5E7;
      color: #E67E22;
      font-size: 10px;
      font-weight: 600;
      padding: 4px 8px;
      border-radius: 3px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    
    .demo-tile h4 {
      font-size: 15px;
      font-weight: 600;
      margin: 0 0 8px 0;
      color: #2C2C2C;
    }
    
    .demo-tile p {
      font-size: 13px;
      color: #7F8C8D;
      margin: 0 0 12px 0;
      line-height: 1.5;
    }
    
    .demo-tile-meta {
      font-size: 12px;
      color: #95A5A6;
      font-family: 'IBM Plex Mono', monospace;
    }
    
    /* DSI score badges */
    .dsi-score {
      display: inline-block;
      padding: 6px 14px;
      border-radius: 4px;
      font-weight: 600;
      font-size: 15px;
      font-variant-numeric: tabular-nums;
    }
    
    .dsi-score.good { background: rgba(0, 158, 115, 0.1); color: #009E73; }
    .dsi-score.moderate { background: rgba(230, 159, 0, 0.1); color: #E69F00; }
    .dsi-score.poor { background: rgba(213, 94, 0, 0.1); color: #D55E00; }
    
    /* Score grid cells */
    .score-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
      gap: 16px;
      margin-top: 24px;
    }
    
    .score-cell {
      background: white;
      border: 2px solid #E8E8E8;
      border-radius: 8px;
      padding: 18px;
      cursor: pointer;
      transition: all 0.2s ease;
    }
    
    .score-cell:hover {
      transform: translateY(-3px);
      box-shadow: 0 4px 12px rgba(0,0,0,0.08);
    }
    
    .score-cell.good { border-left: 4px solid #009E73; }
    .score-cell.moderate { border-left: 4px solid #E69F00; }
    .score-cell.poor { border-left: 4px solid #D55E00; }
    
    .score-cell-title {
      font-size: 13px;
      font-weight: 600;
      color: #2C2C2C;
      margin-bottom: 8px;
    }
    
    .score-cell-value {
      font-size: 24px;
      font-weight: 700;
      font-variant-numeric: tabular-nums;
      margin-bottom: 4px;
    }
    
    .score-cell-band {
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      font-weight: 600;
    }
    
    /* Generous whitespace */
    .content-section {
      margin-bottom: 48px;
    }
    
    .metric-row {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
      gap: 20px;
      margin: 24px 0;
    }
    
    .metric-box {
      text-align: center;
      padding: 20px;
      background: white;
      border: 1px solid #E8E8E8;
      border-radius: 6px;
    }
    
    .metric-value {
      font-size: 28px;
      font-weight: 700;
      color: #2C2C2C;
      font-variant-numeric: tabular-nums;
      margin-bottom: 4px;
    }
    
    .metric-label {
      font-size: 12px;
      color: #7F8C8D;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      font-weight: 600;
    }
  "))
}

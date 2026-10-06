## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ DSI Studio: Theme and styling ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Create DSI Studio bslib theme
#' 
#' Custom theme with Okabe-Ito inspired colors for DSI bands.
#' 
#' @return bslib theme object
#' @export
dsi_theme <- function() {
  bs_theme(
    version = 5,
    preset = "bootstrap",
    
    bg = "#FAFAFA",
    fg = "#2C3E50",
    primary = "#3498DB",
    secondary = "#95A5A6",
    success = "#009E73",
    warning = "#E69F00",
    danger = "#D55E00",
    
    base_font = font_google("IBM Plex Sans"),
    code_font = font_google("IBM Plex Mono"),
    heading_font = font_google("IBM Plex Sans", wght = 600),
    
    "font-size-base" = "0.95rem",
    "headings-font-weight" = "600"
  ) %>%
    bs_add_rules(
      '
      :root {
        --dsi-poor: #D55E00;
        --dsi-moderate: #E69F00;
        --dsi-good: #009E73;
        --dsi-invalid: #CCCCCC;
        --rail-width: 260px;
      }
      
      body {
        font-feature-settings: "tnum" 1;
      }
      
      .dsi-number {
        font-family: var(--bs-font-monospace);
        font-feature-settings: "tnum" 1;
      }
      
      .dsi-band-poor {
        color: var(--dsi-poor);
        font-weight: 600;
      }
      
      .dsi-band-moderate {
        color: var(--dsi-moderate);
        font-weight: 600;
      }
      
      .dsi-band-good {
        color: var(--dsi-good);
        font-weight: 600;
      }
      
      .dsi-band-invalid {
        color: var(--dsi-invalid);
      }
      
      .context-rail {
        background: white;
        padding: 1rem;
        border-right: 1px solid #E0E0E0;
      }
      
      .context-item {
        margin-bottom: 1rem;
        padding-bottom: 0.75rem;
        border-bottom: 1px solid #F0F0F0;
      }
      
      .context-item:last-child {
        border-bottom: none;
      }
      
      .context-label {
        font-size: 0.75rem;
        text-transform: uppercase;
        letter-spacing: 0.05em;
        color: #7F8C8D;
        margin-bottom: 0.25rem;
      }
      
      .context-value {
        font-size: 0.9rem;
        font-weight: 500;
      }
      
      .step-indicator {
        display: inline-block;
        width: 1.5rem;
        height: 1.5rem;
        border-radius: 50%;
        background: #95A5A6;
        color: white;
        text-align: center;
        line-height: 1.5rem;
        font-size: 0.8rem;
        font-weight: 600;
        margin-right: 0.5rem;
      }
      
      .step-indicator.active {
        background: var(--bs-primary);
      }
      
      .step-indicator.complete {
        background: var(--bs-success);
      }
      
      .metric-card {
        background: white;
        border: 1px solid #E0E0E0;
        border-radius: 0.375rem;
        padding: 1rem;
        margin-bottom: 1rem;
      }
      
      .metric-card .metric-value {
        font-size: 1.5rem;
        font-weight: 600;
        font-family: var(--bs-font-monospace);
      }
      
      .metric-card .metric-label {
        font-size: 0.875rem;
        color: #7F8C8D;
        text-transform: uppercase;
        letter-spacing: 0.05em;
      }
      
      .sparkline-cell {
        display: inline-block;
        width: 80px;
        height: 30px;
      }
      
      .audit-finding {
        background: #FFF9E6;
        border-left: 3px solid #E69F00;
        padding: 0.75rem;
        margin-bottom: 0.5rem;
        border-radius: 0.25rem;
      }
      
      .audit-finding.warning {
        background: #FFEBE6;
        border-left-color: #D55E00;
      }
      
      .audit-finding.info {
        background: #E6F7FF;
        border-left-color: #3498DB;
      }
      '
    )
}

#' DSI band colors (Okabe-Ito inspired, color-blind safe)
#' 
#' @return Named vector of hex colors
#' @export
dsi_band_colors <- function() {
  c(
    poor = "#D55E00",
    moderate = "#E69F00",
    good = "#009E73",
    invalid = "#CCCCCC"
  )
}

#' Create ggplot2 theme for DSI
#' 
#' @param base_size Base font size
#' @return ggplot2 theme
#' @export
theme_dsi <- function(base_size = 11) {
  theme_minimal(base_size = base_size) +
    theme(
      text = element_text(family = "IBM Plex Sans"),
      plot.title = element_text(face = "bold", size = base_size * 1.2),
      plot.subtitle = element_text(color = "#7F8C8D", size = base_size * 0.9),
      axis.title = element_text(size = base_size * 0.9),
      axis.text = element_text(color = "#2C3E50"),
      legend.title = element_text(face = "bold", size = base_size * 0.9),
      legend.text = element_text(size = base_size * 0.85),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "#E0E0E0", linewidth = 0.3),
      plot.background = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA),
      strip.text = element_text(face = "bold", size = base_size)
    )
}

#' Format DSI score for display
#' 
#' @param score Numeric score
#' @param digits Number of decimal places
#' @return Formatted string
#' @export
format_dsi_score <- function(score, digits = 0) {
  if (is.na(score) || !is.finite(score)) {
    return("—")
  }
  sprintf(paste0("%.", digits, "f"), score)
}

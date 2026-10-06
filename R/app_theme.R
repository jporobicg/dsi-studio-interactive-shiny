## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ DSI Studio: theme, CSS and small UI helpers ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## Visual system from the step-rail redesign (dd9d88a): IBM Plex, tabular
## numerals, restrained palette, white cards without default chrome,
## Okabe-Ito band colours. Extended with a responsive shell (no overlay
## sidebars on phones) and the components used by later steps.

#' Create DSI Studio bslib theme
#' @export
dsi_theme <- function() {
  bs_theme(
    version = 5,
    bg = "#FAFAFA", fg = "#2C2C2C",
    primary = "#3498DB", secondary = "#7F8C8D",
    success = "#009E73", warning = "#E69F00", danger = "#D55E00",
    base_font = font_google("IBM Plex Sans", local = TRUE),
    code_font = font_google("IBM Plex Mono", local = TRUE),
    heading_font = font_google("IBM Plex Sans", wght = 600, local = TRUE),
    font_scale = 0.95
  )
}

#' DSI band colors (Okabe-Ito, colour-blind safe)
#' @export
dsi_band_colors <- function() {
  c(poor = "#D55E00", moderate = "#E69F00", good = "#009E73", invalid = "#CCCCCC")
}

#' ggplot2 theme for DSI plots
#' @export
theme_dsi <- function(base_size = 11) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title = element_text(face = "bold", size = base_size * 1.15),
      plot.subtitle = element_text(color = "#7F8C8D", size = base_size * 0.9),
      axis.text = element_text(color = "#2C3E50"),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "#E8E8E8", linewidth = 0.3),
      plot.background = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA),
      strip.text = element_text(face = "bold", size = base_size)
    )
}

#' Format DSI score for display
#' @export
format_dsi_score <- function(score, digits = 0) {
  if (is.null(score) || length(score) == 0 || is.na(score) || !is.finite(score)) return("\u2014")
  sprintf(paste0("%.", digits, "f"), score)
}

#' Format a regression slope for people
#'
#' Slopes of log(CPUE) on effort are often ~1e-5. "%.4f" printed them as
#' -0.0000, so they use "-2.17 x 10^-5" with superscripts instead.
#' @param x Numeric
#' @param digits Significant digits
#' @export
format_beta <- function(x, digits = 3) {
  if (is.null(x) || length(x) == 0 || is.na(x) || !is.finite(x)) return("\u2014")
  if (x == 0) return("0")
  e <- floor(log10(abs(x)))
  if (e >= -2 && e < 4) return(sub("^-", "\u2212", formatC(signif(x, digits), format = "fg", digits = digits)))
  m <- signif(x / 10^e, digits)
  if (abs(m) >= 10) { m <- m / 10; e <- e + 1 }
  sup <- c("0" = "\u2070", "1" = "\u00b9", "2" = "\u00b2", "3" = "\u00b3", "4" = "\u2074",
           "5" = "\u2075", "6" = "\u2076", "7" = "\u2077", "8" = "\u2078", "9" = "\u2079", "-" = "\u207b")
  ex <- paste(sup[strsplit(as.character(e), "")[[1]]], collapse = "")
  paste0(sub("^-", "\u2212", formatC(m, format = "f", digits = digits - 1)), " \u00d7 10", ex)
}

#' Format a p-value
#' @export
format_p <- function(p) {
  if (is.null(p) || length(p) == 0 || is.na(p)) return("\u2014")
  if (p < 0.001) "< 0.001" else sprintf("%.3f", p)
}

## ---- small UI components ----

#' Step header (title + purpose line)
#' @keywords internal
step_header <- function(title, purpose = NULL, number = NULL) {
  div(class = "step-header",
    if (!is.null(number)) div(class = "step-kicker", sprintf("Step %s of 6", number)),
    h2(title),
    if (!is.null(purpose)) p(class = "step-purpose", purpose))
}

#' Card without default chrome
#' @keywords internal
dsi_card <- function(..., title = NULL, class = NULL, actions = NULL, id = NULL) {
  div(class = paste("dsi-card", class), id = id,
    if (!is.null(title) || !is.null(actions))
      div(class = "dsi-card-head", if (!is.null(title)) h3(title), if (!is.null(actions)) div(class = "dsi-card-actions", actions)),
    ...)
}

#' Metric box
#' @keywords internal
metric_box <- function(value, label, class = NULL) {
  div(class = paste("metric-box", class), div(class = "metric-value", value), div(class = "metric-label", label))
}

#' "Continue" button that navigates to the next step
#' @keywords internal
next_step_button <- function(step, label) {
  tags$button(type = "button", class = "btn btn-primary btn-next",
    onclick = sprintf("Shiny.setInputValue('step_nav', '%s', {priority: 'event'});", step),
    label, HTML(" &rarr;"))
}

#' Band label/colour helper for UI
#' @keywords internal
band_class <- function(score) tolower(get_dsi_band(score)$label)

#' Custom CSS for DSI Studio
#' @keywords internal
dsi_custom_css <- function() {
  tags$style(HTML("
    body { font-variant-numeric: tabular-nums; background: #FAFAFA; }
    .bslib-page-fill, .container-fluid { padding: 0 !important; }

    /* ---------- shell: step rail | main | context rail ---------- */
    .dsi-shell { display: grid; grid-template-columns: 260px minmax(0, 1fr) 250px; min-height: 100vh; }
    .step-rail { background: #fff; border-right: 1px solid #E0E0E0; position: sticky; top: 0;
                 height: 100vh; overflow-y: auto; z-index: 10; }
    .rail-brand { padding: 24px; border-bottom: 1px solid #E0E0E0; }
    .rail-brand h1 { margin: 0; font-size: 18px; font-weight: 600; }
    .rail-brand p { margin: 4px 0 0; font-size: 12px; color: #7F8C8D; }
    .dsi-main { padding: 36px 40px 64px; min-width: 0; }
    .dsi-main-inner { max-width: 1200px; }
    .context-rail { background: #fff; border-left: 1px solid #E0E0E0; padding: 24px; position: sticky;
                    top: 0; height: 100vh; overflow-y: auto; font-size: 13px; }

    /* ---------- step items ---------- */
    .step-item { display: flex; align-items: flex-start; gap: 12px; padding: 18px 24px; border-bottom: 1px solid #F0F0F0;
                 border-left: 3px solid transparent; color: inherit; text-decoration: none; cursor: pointer;
                 transition: background .15s ease; position: relative; }
    .step-item:hover { background: #F8F9FA; color: inherit; }
    .step-item.active { background: #F0F7FC; border-left-color: #3498DB; }
    .step-item.locked { opacity: .45; cursor: not-allowed; }
    .step-item.locked:hover { background: transparent; }
    .step-number { flex: 0 0 28px; width: 28px; height: 28px; border-radius: 14px; background: #E8E8E8; color: #666;
                   text-align: center; line-height: 28px; font-weight: 600; font-size: 13px; }
    .step-item.active .step-number { background: #3498DB; color: #fff; }
    .step-item.done .step-number { background: #009E73; color: #fff; }
    .step-item.done.active .step-number { box-shadow: 0 0 0 3px #CDE8F7; }
    .step-title { font-weight: 600; font-size: 14px; color: #2C2C2C; line-height: 28px; }
    .step-subtitle { font-size: 12px; color: #7F8C8D; line-height: 1.4; }
    .step-meta { font-size: 11.5px; color: #2C7BB6; margin-top: 4px; font-family: 'IBM Plex Mono', monospace; line-height: 1.35; word-break: break-word; }
    .step-item.done .step-meta { color: #00785A; }
    .step-lock { font-size: 11px; margin-left: 4px; color: #95A5A6; }

    /* ---------- context rail ---------- */
    .context-item { margin-bottom: 18px; }
    .context-label { font-size: 11px; text-transform: uppercase; letter-spacing: .5px; color: #95A5A6; margin-bottom: 4px; font-weight: 600; }
    .context-value { font-size: 14px; font-weight: 600; color: #2C2C2C; word-break: break-word; }
    .context-value.empty { color: #BDC3C7; font-weight: 400; }
    .context-sub { font-size: 12px; color: #7F8C8D; font-weight: 400; }
    .context-strip { display: none; flex-wrap: wrap; gap: 6px; margin: -8px 0 20px; }
    .chip { display: inline-flex; gap: 4px; align-items: center; padding: 3px 9px; border-radius: 999px; background: #fff;
            border: 1px solid #E3E3E3; font-size: 12px; color: #555; max-width: 100%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .chip b { color: #2C2C2C; font-weight: 600; }

    /* ---------- headers, cards, buttons ---------- */
    .step-header { margin-bottom: 28px; }
    .step-kicker { font-size: 11px; text-transform: uppercase; letter-spacing: .8px; color: #3498DB; font-weight: 600; margin-bottom: 6px; }
    .step-header h2 { font-size: 28px; font-weight: 600; margin: 0 0 8px; }
    .step-purpose { font-size: 15px; color: #7F8C8D; line-height: 1.6; max-width: 680px; margin: 0; }
    .dsi-card { background: #fff; border: 1px solid #E8E8E8; border-radius: 8px; padding: 24px 28px; margin-bottom: 24px; min-width: 0; }
    .dsi-card-head { display: flex; justify-content: space-between; align-items: center; gap: 12px; flex-wrap: wrap; margin-bottom: 16px; }
    .dsi-card-head h3 { font-size: 16px; font-weight: 600; margin: 0; }
    .dsi-card .help { font-size: 13px; color: #7F8C8D; margin: -8px 0 14px; line-height: 1.5; }
    .btn-next { margin-top: 8px; padding: 10px 24px; font-weight: 600; }
    .step-footer { display: flex; justify-content: flex-end; margin-top: 8px; }
    .dsi-grid-2 { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 24px; }
    .dsi-grid-3 { display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 20px; }
    .dsi-grid-2 > .dsi-card, .dsi-grid-3 > .dsi-card { margin-bottom: 0; }
    .callout { border-left: 3px solid #3498DB; background: #F0F7FC; padding: 12px 16px; border-radius: 4px; font-size: 13.5px; margin: 12px 0; }
    .callout.ok { border-color: #009E73; background: #E8F6F1; }
    .callout.warn { border-color: #E69F00; background: #FFF6E5; }
    .callout.bad { border-color: #D55E00; background: #FDEEE6; }
    .muted { color: #7F8C8D; }
    .badge-pill { display: inline-block; padding: 2px 9px; border-radius: 999px; font-size: 11px; font-weight: 600; letter-spacing: .3px; text-transform: uppercase; }
    .badge-ready { background: #E0F3EC; color: #00785A; }
    .badge-notready { background: #F2F2F2; color: #777; }
    .badge-user { background: #EAF3FB; color: #1F6FA8; }
    .badge-mod { background: #FFF1D6; color: #9A6500; }

    /* ---------- data step ---------- */
    .empty-state { text-align: center; padding: 44px 32px; background: #fff; border: 2px dashed #D0D0D0; border-radius: 8px; margin-bottom: 24px; }
    .empty-state h3 { font-size: 18px; font-weight: 600; margin-bottom: 6px; }
    .empty-state p { font-size: 14px; color: #7F8C8D; max-width: 520px; margin: 0 auto 18px; }
    .empty-state .shiny-input-container { margin: 0 auto; max-width: 420px; }
    .demo-tiles { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 16px; margin-top: 8px; }
    .demo-tile { display: block; text-align: left; width: 100%; background: #fff; border: 1px solid #E8E8E8; border-radius: 8px; padding: 20px;
                 cursor: pointer; transition: all .15s ease; position: relative; color: inherit; }
    .demo-tile:hover { border-color: #3498DB; box-shadow: 0 2px 8px rgba(52,152,219,.12); transform: translateY(-2px); }
    .demo-tile-badge { position: absolute; top: 12px; right: 12px; background: #FEF5E7; color: #E67E22; font-size: 10px; font-weight: 600;
                       padding: 4px 8px; border-radius: 3px; text-transform: uppercase; letter-spacing: .5px; }
    .demo-tile h4 { font-size: 15px; font-weight: 600; margin: 0 0 8px; padding-right: 90px; }
    .demo-tile p { font-size: 13px; color: #7F8C8D; margin: 0 0 10px; line-height: 1.5; }
    .demo-tile-meta { font-size: 12px; color: #95A5A6; font-family: 'IBM Plex Mono', monospace; }
    .dataset-banner { display: flex; flex-wrap: wrap; align-items: center; gap: 12px 20px; justify-content: space-between; }
    .dataset-banner .name { font-size: 17px; font-weight: 600; }
    .map-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(210px, 1fr)); gap: 4px 20px; }
    .req { color: #D55E00; font-weight: 600; }
    .sem-option { border: 1px solid #E8E8E8; border-radius: 6px; padding: 10px 14px; margin-bottom: 8px; }

    /* ---------- audit ---------- */
    .audit-finding { background: #E6F2FB; border-left: 3px solid #3498DB; padding: 12px 16px; margin-bottom: 10px; border-radius: 4px; }
    .audit-finding.warning { background: #FDEEE6; border-left-color: #D55E00; }
    .audit-finding h5 { font-size: 13px; font-weight: 600; margin: 0 0 4px; text-transform: uppercase; letter-spacing: .4px; }
    .audit-finding p { margin: 0 0 6px; font-size: 14px; }

    /* ---------- metrics ---------- */
    .metric-row { display: grid; grid-template-columns: repeat(auto-fit, minmax(120px, 1fr)); gap: 14px; margin: 8px 0 4px; }
    .metric-box { text-align: center; padding: 16px 10px; background: #fff; border: 1px solid #E8E8E8; border-radius: 6px; }
    .metric-value { font-size: 26px; font-weight: 700; font-variant-numeric: tabular-nums; margin-bottom: 2px; }
    .metric-label { font-size: 11px; color: #7F8C8D; text-transform: uppercase; letter-spacing: .5px; font-weight: 600; }
    .kv { display: grid; grid-template-columns: max-content 1fr; gap: 6px 16px; font-size: 14px; margin: 0; }
    .kv dt { color: #7F8C8D; font-weight: 500; } .kv dd { margin: 0; font-weight: 600; font-variant-numeric: tabular-nums; }
    .delta-up { color: #00785A; } .delta-down { color: #C0392B; }

    /* ---------- segmented control (not bslib tabs) ---------- */
    .dsi-seg .shiny-options-group { display: inline-flex; flex-wrap: wrap; border: 1px solid #D6DCE1; border-radius: 8px; overflow: hidden; background: #fff; }
    .dsi-seg .form-check, .dsi-seg .radio-inline { margin: 0 !important; padding: 0 !important; min-height: 0; }
    .dsi-seg input[type=radio] { position: absolute; opacity: 0; pointer-events: none; }
    .dsi-seg label { margin: 0; }
    .dsi-seg .form-check-label, .dsi-seg .radio-inline span { display: inline-block; padding: 7px 16px; font-size: 13px; font-weight: 600; color: #555; cursor: pointer; border-right: 1px solid #E3E7EA; }
    .dsi-seg .form-check:last-child .form-check-label { border-right: 0; }
    .dsi-seg input[type=radio]:checked + span, .dsi-seg input[type=radio]:checked + .form-check-label { background: #3498DB; color: #fff; }
    .dsi-seg .control-label { display: block; font-size: 13px; font-weight: 600; margin-bottom: 6px; }

    /* ---------- score grid ---------- */
    .score-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(210px, 1fr)); gap: 16px; margin-top: 8px; }
    .score-cell { background: #fff; border: 2px solid #E8E8E8; border-radius: 8px; padding: 16px 18px; cursor: pointer; transition: all .2s ease; min-width: 0; }
    .score-cell:hover { transform: translateY(-3px); box-shadow: 0 4px 12px rgba(0,0,0,.08); }
    .score-cell.good { border-left: 5px solid #009E73; } .score-cell.moderate { border-left: 5px solid #E69F00; }
    .score-cell.poor { border-left: 5px solid #D55E00; } .score-cell.invalid { border-left: 5px solid #CCC; background: #FAFAFA; }
    .score-cell.selected { border-color: #3498DB; box-shadow: 0 0 0 3px #CDE8F7; }
    .score-cell-title { font-size: 13px; font-weight: 600; margin-bottom: 6px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .score-cell-value { font-size: 26px; font-weight: 700; line-height: 1.1; }
    .score-cell-band { font-size: 11px; text-transform: uppercase; letter-spacing: .5px; font-weight: 600; margin-bottom: 6px; }
    .score-cell-meta { font-size: 11.5px; color: #7F8C8D; font-family: 'IBM Plex Mono', monospace; }
    .good-text { color: #009E73; } .moderate-text { color: #C98A00; } .poor-text { color: #D55E00; } .invalid-text { color: #999; }
    .spark { display: block; margin-top: 6px; width: 100%; height: 28px; }
    .matrix-wrap { overflow-x: auto; max-width: 100%; }
    .dsi-matrix { display: grid; gap: 6px; min-width: 0; }
    .mx-head, .mx-row-label { font-size: 12px; font-weight: 600; color: #555; display: flex; align-items: center; justify-content: center; text-align: center;
                               background: #F5F7F9; border-radius: 4px; padding: 6px 4px; min-width: 0; overflow: hidden; text-overflow: ellipsis; }
    .mx-row-label { justify-content: flex-end; padding-right: 8px; }
    .mx-cell { border-radius: 6px; padding: 8px 6px; text-align: center; cursor: pointer; border: 2px solid transparent; min-width: 0; transition: transform .15s; }
    .mx-cell:hover { transform: scale(1.05); box-shadow: 0 2px 8px rgba(0,0,0,.18); }
    .mx-cell.good { background: rgba(0,158,115,.14); border-color: #009E73; } .mx-cell.moderate { background: rgba(230,159,0,.16); border-color: #E69F00; }
    .mx-cell.poor { background: rgba(213,94,0,.10); border-color: #E7A27A; } .mx-cell.invalid { background: #F3F3F3; color: #999; cursor: default; }
    .mx-cell.empty { background: #FAFAFA; border: 1px dashed #E0E0E0; cursor: default; color: #BBB; }
    .mx-cell.ready { box-shadow: inset 0 0 0 2px #009E73; }
    .mx-cell.selected { border-color: #3498DB !important; box-shadow: 0 0 0 3px #CDE8F7; }
    .mx-score { font-size: 17px; font-weight: 700; line-height: 1.1; } .mx-band { font-size: 10px; text-transform: uppercase; letter-spacing: .4px; }
    .grid-legend { display: flex; flex-wrap: wrap; gap: 14px; font-size: 12px; color: #666; margin-top: 12px; }
    .grid-legend i { display: inline-block; width: 12px; height: 12px; border-radius: 3px; margin-right: 5px; vertical-align: -1px; }

    /* ---------- explore detail ---------- */
    .detail-head { display: flex; flex-wrap: wrap; align-items: baseline; gap: 10px 16px; margin: 8px 0 18px; }
    .detail-head h3 { font-size: 22px; margin: 0; }
    .win-toolbar { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; margin-top: 8px; }
    .win-range .irs { margin-top: -6px; }
    .compare-scores { display: flex; gap: 22px; align-items: baseline; flex-wrap: wrap; }
    .compare-scores .big { font-size: 30px; font-weight: 700; }
    .dsi-advanced { border: 1px solid #E8E8E8; border-radius: 8px; padding: 0; margin: 16px 0 6px; background: #FCFCFD; }
    .dsi-advanced > summary { cursor: pointer; padding: 12px 16px; font-weight: 600; font-size: 14px; list-style: none; display: flex; justify-content: space-between; gap: 8px; }
    .dsi-advanced > summary::-webkit-details-marker { display: none; }
    .dsi-advanced > summary::before { content: '\\25B8'; margin-right: 8px; color: #3498DB; transition: transform .15s; display: inline-block; }
    .dsi-advanced[open] > summary::before { transform: rotate(90deg); }
    .dsi-advanced .adv-body { padding: 4px 16px 16px; }
    .adv-group h6 { font-size: 12px; text-transform: uppercase; letter-spacing: .5px; color: #7F8C8D; margin: 14px 0 6px; font-weight: 600; }
    .adv-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 0 14px; }
    .adv-grid .form-group, .adv-grid .shiny-input-container { margin-bottom: 8px; width: 100% !important; }
    .adv-grid label { font-size: 12px; font-weight: 500; }
    .fix-table td, .fix-table th { font-size: 13px; vertical-align: top; }
    .decide-row { display: grid; grid-template-columns: minmax(0, 1.2fr) minmax(0, 1fr); gap: 16px; align-items: start; }
    .decide-card { padding: 18px 22px; }
    .decide-card .dsi-card-head { margin-bottom: 8px; }
    .decide-toolbar { display: flex; flex-wrap: wrap; gap: 10px; align-items: center; margin-bottom: 16px; }
    .table-wrap { overflow-x: auto; }
    table.dsi-table { width: 100%; border-collapse: collapse; font-size: 13px; }
    .dsi-table th { background: #F5F7F9; font-weight: 600; text-align: left; padding: 7px 9px; border-bottom: 1px solid #E3E3E3; }
    .dsi-table td { padding: 6px 9px; border-bottom: 1px solid #F0F0F0; }
    .echarts4r, .html-widget { max-width: 100%; }
    .dataTables_wrapper { max-width: 100%; }
    .dataTables_wrapper .pagination { flex-wrap: wrap; }

    /* ---------- responsive ---------- */
    @media (max-width: 1199.98px) {
      .dsi-shell { grid-template-columns: 236px minmax(0, 1fr); }
      .context-rail { display: none; }
      .context-strip { display: flex; }
    }
    @media (max-width: 767.98px) {
      .dsi-shell { display: block; }
      .step-rail { position: sticky; top: 0; height: auto; display: flex; overflow-x: auto; border-right: 0;
                   border-bottom: 1px solid #E0E0E0; box-shadow: 0 1px 4px rgba(0,0,0,.06); scrollbar-width: none; }
      .step-rail::-webkit-scrollbar { display: none; }
      .rail-brand { display: none; }
      #step_rail { display: flex; }
      .step-item { flex: 0 0 auto; padding: 10px 12px 9px; gap: 6px; border-bottom: 3px solid transparent; border-left: 0; align-items: center; }
      .step-item.active { border-left: 0; border-bottom-color: #3498DB; }
      .step-number { flex-basis: 24px; width: 24px; height: 24px; line-height: 24px; font-size: 12px; }
      .step-title { font-size: 13px; line-height: 24px; }
      .step-subtitle, .step-meta, .step-lock { display: none; }
      .dsi-main { padding: 18px 12px 48px; }
      .step-header { margin-bottom: 18px; }
      .step-header h2 { font-size: 22px; }
      .step-purpose { font-size: 14px; }
      .dsi-card { padding: 16px 14px; margin-bottom: 16px; }
      .score-grid { grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 10px; }
      .score-cell { padding: 12px; } .score-cell-value { font-size: 22px; }
      .matrix-wrap { overflow-x: visible; }
      .dsi-matrix { gap: 3px; }
      .mx-head, .mx-row-label { font-size: 10px; padding: 4px 1px; }
      .mx-cell { padding: 6px 1px; border-width: 1.5px; }
      .mx-cell .mx-band, .mx-cell .spark { display: none; }
      .mx-score { font-size: 13px; }
      .dsi-grid-2, .dsi-grid-3 { grid-template-columns: minmax(0, 1fr); gap: 16px; }
      .decide-row { grid-template-columns: minmax(0, 1fr); }
      .demo-tile h4 { padding-right: 0; margin-top: 18px; }
      .metric-row { grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 8px; }
      .metric-value { font-size: 20px; }
      .compare-scores .big { font-size: 24px; }
      .dataTables_wrapper .dataTables_info, .dataTables_wrapper .dataTables_paginate { float: none; text-align: left; font-size: 12px; }
      .dataTables_wrapper .dataTables_paginate .page-link { padding: 4px 8px; }
      .dataTables_wrapper .dataTables_filter { float: none; text-align: left; }
      #shiny-notification-panel { max-width: calc(100vw - 16px); right: 8px; left: auto; }
    }
  "))
}

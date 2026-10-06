## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ DSI Studio: self-contained HTML report      ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

.png_data_uri <- function(plot, width = 9, height = 5, dpi = 110) {
  f <- tempfile(fileext = ".png")
  on.exit(unlink(f))
  ggplot2::ggsave(f, plot, width = width, height = height, dpi = dpi, bg = "white")
  paste0("data:image/png;base64,", base64enc::base64encode(f))
}

.html_table <- function(df, digits = 1, class = "tbl") {
  if (is.null(df) || nrow(df) == 0) return(htmltools::tags$p(class = "muted", "None."))
  fmt_col <- function(x) {
    if (is.numeric(x)) {
      whole <- all(is.na(x) | abs(x - round(x)) < 1e-9)
      ifelse(is.na(x), "\u2014", formatC(x, format = "f", digits = if (whole) 0 else digits, big.mark = ","))
    } else ifelse(is.na(x) | x == "", "\u2014", as.character(x))
  }
  cells <- as.data.frame(lapply(df, fmt_col), stringsAsFactors = FALSE, check.names = FALSE)
  htmltools::tags$table(class = class,
    htmltools::tags$thead(htmltools::tags$tr(lapply(names(df), htmltools::tags$th))),
    htmltools::tags$tbody(lapply(seq_len(nrow(cells)), function(i)
      htmltools::tags$tr(lapply(cells[i, , drop = TRUE], function(v) htmltools::tags$td(v))))))
}

#' Per-group summary used by Decide, the HTML report and the export
#'
#' Combines the screened best window, any user-selected window (from the
#' Explore window slider) and the decisions.
#' @param results Workflow results
#' @param overrides Named list group_key -> scored window (from score_window)
#' @param decisions Named list group_key -> list(action, rationale, ...)
#' @return Data frame, one row per group
#' @export
dsi_group_summary <- function(results, overrides = list(), decisions = list()) {
  best <- results$dsi_best
  if (is.null(best) || nrow(best) == 0) return(data.frame())
  rows <- lapply(seq_len(nrow(best)), function(i) {
    b <- best[i, ]
    g <- as.character(b$group_key)
    o <- overrides[[g]]
    sel <- if (!is.null(o)) o else b
    dec <- decisions[[g]]
    data.frame(
      group_key = g,
      best_window = sprintf("%d\u2013%d", b$start_year, b$end_year),
      best_dsi_v2 = b$dsi_v2,
      ready = isTRUE(b$ready),
      selection_reason = b$selection_reason %||% NA_character_,
      selected_window = sprintf("%d\u2013%d", sel$start_year, sel$end_year),
      selected_start = sel$start_year, selected_end = sel$end_year,
      window_source = if (is.null(o)) "screened best" else "user-selected",
      selected_dsi = sel$dsi %||% NA_real_,
      selected_dsi_v2 = sel$dsi_v2 %||% NA_real_,
      beta = sel$beta %||% NA_real_, p_value = sel$p_value %||% NA_real_,
      decision = if (is.null(dec)) NA_character_ else dec$action,
      rationale = if (is.null(dec)) NA_character_ else (dec$rationale %||% ""),
      stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

#' Build a self-contained HTML summary report
#'
#' Everything (CSS, charts as base64 PNG) is inlined so the file can be
#' emailed or archived without the app.
#'
#' @param results Workflow results (run_dsi_workflow)
#' @param file Output path
#' @param dataset_name,settings Labels
#' @param overrides,decisions See [dsi_group_summary()]
#' @param audit Audit findings list
#' @param null_tests Named list group_key -> dsi_null_test() result
#' @param comparison dsi_compare_methods() result or NULL
#' @return `file`, invisibly
#' @export
dsi_build_html_report <- function(results, file, dataset_name = "dataset", settings = list(),
                                  overrides = list(), decisions = list(), audit = NULL,
                                  null_tests = list(), comparison = NULL) {
  h <- htmltools::tags
  summ <- dsi_group_summary(results, overrides, decisions)
  all_w <- results$dsi_all
  band_col <- c(Good = "#009E73", Moderate = "#E69F00", Poor = "#D55E00", Invalid = "#BBBBBB")
  band_of <- function(x) ifelse(is.na(x), "Invalid", ifelse(x >= 70, "Good", ifelse(x >= 50, "Moderate", "Poor")))
  th <- ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(), plot.title = ggplot2::element_text(face = "bold"))

  imgs <- list()
  # 1. Selected-window score per group
  s1 <- summ
  s1$band <- band_of(s1$selected_dsi_v2)
  s1$group_key <- factor(s1$group_key, levels = s1$group_key[order(s1$selected_dsi_v2, na.last = FALSE)])
  p1 <- ggplot2::ggplot(s1, ggplot2::aes(x = selected_dsi_v2, y = group_key, colour = band)) +
    ggplot2::geom_vline(xintercept = c(50, 70), linetype = "dotted", colour = "grey60") +
    ggplot2::geom_segment(ggplot2::aes(x = 0, xend = selected_dsi_v2, yend = group_key), colour = "grey80") +
    ggplot2::geom_point(size = 3) +
    ggplot2::scale_colour_manual(values = band_col, drop = FALSE) +
    ggplot2::scale_x_continuous(limits = c(0, 100)) +
    ggplot2::labs(x = "DSI_v2 of selected window", y = NULL, colour = "Band",
                  title = "Selected window score by group") + th
  imgs$scores <- .png_data_uri(p1, 9, max(3, 0.22 * nrow(s1) + 1.2))

  # 2. DSI_v2 by window start year
  w <- all_w[all_w$valid %in% TRUE & is.finite(all_w$dsi_v2), ]
  if (nrow(w) > 0) {
    n_g <- length(unique(w$group_key))
    p2 <- ggplot2::ggplot(w, ggplot2::aes(start_year, dsi_v2)) +
      ggplot2::geom_hline(yintercept = 70, linetype = "dotted", colour = "grey60") +
      ggplot2::geom_line(colour = "#3498DB") + ggplot2::geom_point(size = 0.8, colour = "#3498DB") +
      ggplot2::facet_wrap(~group_key, ncol = min(4, n_g)) +
      ggplot2::labs(x = "Window start year", y = "DSI_v2", title = "DSI_v2 across candidate windows") + th
    imgs$windows <- .png_data_uri(p2, 9, max(3, 1.8 * ceiling(n_g / min(4, n_g)) + 0.8))
  }

  # 3. Time series for selected windows (first 12 groups by decision priority)
  ds <- results$data_std
  if (!is.null(ds) && nrow(summ) > 0) {
    ord <- order(match(summ$decision, c("accept", "flag", "reject"), nomatch = 4), -summ$selected_dsi_v2)
    pick <- head(summ[ord, ], 12)
    tsd <- ds[ds$group_key %in% pick$group_key, c("group_key", "year", "cpue", "effort")]
    tsd <- tsd[order(tsd$group_key, tsd$year), ]
    sc <- do.call(rbind, lapply(split(tsd, tsd$group_key), function(d) {
      d$cpue_s <- d$cpue / max(d$cpue, na.rm = TRUE); d$effort_s <- d$effort / max(d$effort, na.rm = TRUE); d }))
    rect <- pick[, c("group_key", "selected_start", "selected_end")]
    p3 <- ggplot2::ggplot(sc, ggplot2::aes(year)) +
      ggplot2::geom_rect(data = rect, inherit.aes = FALSE,
                         ggplot2::aes(xmin = selected_start - 0.5, xmax = selected_end + 0.5, ymin = -Inf, ymax = Inf),
                         fill = "#3498DB", alpha = 0.12) +
      ggplot2::geom_line(ggplot2::aes(y = cpue_s, colour = "CPUE")) +
      ggplot2::geom_line(ggplot2::aes(y = effort_s, colour = "Effort")) +
      ggplot2::scale_colour_manual(values = c(CPUE = "#009E73", Effort = "#56B4E9")) +
      ggplot2::facet_wrap(~group_key, ncol = 3, scales = "free_x") +
      ggplot2::labs(x = NULL, y = "Scaled to max = 1", colour = NULL,
                    title = "CPUE and effort with the selected window shaded") + th +
      ggplot2::theme(legend.position = "top")
    imgs$ts <- .png_data_uri(p3, 9, max(3, 2 * ceiling(nrow(pick) / 3) + 1))
  }

  # 4. Null tests
  null_tbl <- NULL
  if (length(null_tests) > 0) {
    nd <- do.call(rbind, lapply(names(null_tests), function(g) {
      x <- null_tests[[g]]; data.frame(group_key = g, dsi_v2 = x$null_dsi_v2) }))
    od <- do.call(rbind, lapply(names(null_tests), function(g) {
      x <- null_tests[[g]]
      data.frame(group_key = g, window = sprintf("%d\u2013%d", x$start_year, x$end_year),
                 observed = x$observed_dsi_v2, null_median = x$null_median, null_q95 = x$null_q95,
                 p_value = x$p_value, n_sim = x$n_sim, mode = x$mode) }))
    null_tbl <- od
    p4 <- ggplot2::ggplot(nd[is.finite(nd$dsi_v2), ], ggplot2::aes(dsi_v2)) +
      ggplot2::geom_histogram(bins = 30, fill = "#BDC3C7") +
      ggplot2::geom_vline(data = od, ggplot2::aes(xintercept = observed), colour = "#D55E00", linewidth = 1) +
      ggplot2::facet_wrap(~group_key, scales = "free_y", ncol = min(3, nrow(od))) +
      ggplot2::labs(x = "DSI_v2 with randomised catch", y = "Count",
                    title = "Random-catch null distribution (red = observed)") + th
    imgs$null <- .png_data_uri(p4, 9, max(2.8, 2.2 * ceiling(nrow(od) / 3) + 0.8))
  }

  # 5. Comparison
  if (!is.null(comparison)) {
    a <- comparison$attribution
    a$label <- factor(a$label, levels = a$label[order(a$mean_abs_delta)])
    p5 <- ggplot2::ggplot(a, ggplot2::aes(mean_abs_delta, label)) +
      ggplot2::geom_col(fill = "#3498DB") +
      ggplot2::labs(x = "Mean |change in DSI_v2| when this fix is reverted", y = NULL,
                    title = "Which corrections drive the Legacy vs Corrected differences") + th
    imgs$cmp <- .png_data_uri(p5, 9, 3.2)
  }

  img <- function(k, alt) if (!is.null(imgs[[k]])) h$img(src = imgs[[k]], alt = alt, class = "chart")
  n_dec <- sum(!is.na(summ$decision))
  dec_counts <- table(factor(summ$decision, levels = c("accept", "flag", "reject")))
  tbl <- summ[, c("group_key", "selected_window", "window_source", "selected_dsi", "selected_dsi_v2",
                  "best_window", "best_dsi_v2", "ready", "decision", "rationale")]
  tbl$ready <- ifelse(tbl$ready, "READY", "not ready")
  names(tbl) <- c("Group", "Selected window", "Source", "DSI", "DSI_v2", "Screened best", "Best DSI_v2",
                  "Status", "Decision", "Rationale")
  set_tbl <- data.frame(Setting = names(settings),
                        Value = vapply(settings, function(v) paste(format(unlist(v)), collapse = ", "), ""),
                        stringsAsFactors = FALSE)
  audit_list <- if (length(audit)) h$ul(lapply(names(audit), function(n)
    h$li(h$strong(paste0("[", audit[[n]]$severity, "] ")), audit[[n]]$message))) else h$p("No findings.")

  css <- "
  body{font-family:-apple-system,'IBM Plex Sans','Segoe UI',Roboto,sans-serif;color:#2C2C2C;max-width:1000px;margin:32px auto;padding:0 20px;font-variant-numeric:tabular-nums;background:#FAFAFA}
  h1{font-size:26px;margin-bottom:4px} h2{font-size:18px;margin-top:36px;border-bottom:1px solid #E0E0E0;padding-bottom:6px}
  .muted{color:#7F8C8D} .kpis{display:flex;flex-wrap:wrap;gap:12px;margin:20px 0}
  .kpi{background:#fff;border:1px solid #E8E8E8;border-radius:8px;padding:12px 18px;min-width:110px}
  .kpi b{display:block;font-size:24px} .kpi span{font-size:11px;text-transform:uppercase;color:#7F8C8D;letter-spacing:.5px}
  table.tbl{border-collapse:collapse;width:100%;font-size:13px;background:#fff} .tbl th,.tbl td{border-bottom:1px solid #EEE;padding:6px 8px;text-align:left;vertical-align:top}
  .tbl th{background:#F5F7F9;font-weight:600} img.chart{max-width:100%;border:1px solid #EEE;border-radius:6px;background:#fff;margin:8px 0}
  .wrap{overflow-x:auto} footer{margin:40px 0 20px;font-size:12px;color:#95A5A6}"
  page <- h$html(lang = "en",
    h$head(h$meta(charset = "utf-8"), h$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
           h$title(paste("DSI report \u2014", dataset_name)), h$style(htmltools::HTML(css))),
    h$body(
      h$h1("Data Suitability Index \u2014 summary report"),
      h$p(class = "muted", sprintf("%s \u00b7 generated %s by DSI Studio", dataset_name, format(Sys.time(), "%Y-%m-%d %H:%M %Z"))),
      h$div(class = "kpis",
        h$div(class = "kpi", h$b(length(unique(all_w$group_key))), h$span("Groups")),
        h$div(class = "kpi", h$b(nrow(all_w)), h$span("Windows")),
        h$div(class = "kpi", h$b(sum(all_w$valid, na.rm = TRUE)), h$span("Valid")),
        h$div(class = "kpi", h$b(sum(summ$ready)), h$span("READY")),
        h$div(class = "kpi", h$b(sprintf("%d / %d", n_dec, nrow(summ))), h$span("Decided")),
        h$div(class = "kpi", h$b(sprintf("%d \u00b7 %d \u00b7 %d", dec_counts[["accept"]], dec_counts[["flag"]], dec_counts[["reject"]])),
              h$span("Accept \u00b7 flag \u00b7 reject"))),
      h$h2("Selected windows, scores and decisions"),
      h$div(class = "wrap", .html_table(tbl, 1)),
      img("scores", "Selected window score by group"),
      h$h2("Scores across candidate windows"), img("windows", "DSI_v2 by window start year"),
      h$h2("Time series"), img("ts", "CPUE and effort with selected window"),
      if (!is.null(null_tbl)) htmltools::tagList(
        h$h2("Random-catch null test"),
        h$p(class = "muted", "Catch was randomised within the window and CPUE rebuilt as catch/effort. A small p-value means the observed score is unlikely to come from the catch/effort ratio artefact alone."),
        h$div(class = "wrap", .html_table(null_tbl, 2)), img("null", "Null distributions")),
      if (!is.null(comparison)) htmltools::tagList(
        h$h2("Legacy vs Corrected"),
        h$div(class = "wrap", .html_table(data.frame(
          Group = comparison$groups$group_key,
          `Legacy window` = sprintf("%s\u2013%s", comparison$groups$start_year_legacy, comparison$groups$end_year_legacy),
          `Legacy DSI_v2` = comparison$groups$dsi_v2_legacy,
          `Corrected window` = sprintf("%s\u2013%s", comparison$groups$start_year_corrected, comparison$groups$end_year_corrected),
          `Corrected DSI_v2` = comparison$groups$dsi_v2_corrected,
          Change = comparison$groups$d_best_dsi_v2, check.names = FALSE), 1)),
        img("cmp", "Fix attribution")),
      h$h2("Data audit"), audit_list,
      h$h2("Settings"), .html_table(set_tbl),
      h$footer("Self-contained file: all charts are embedded. Scores reproducible with the standalone R script in the export ZIP.")
    ))
  writeLines(c("<!DOCTYPE html>", as.character(page)), file, useBytes = TRUE)
  invisible(file)
}

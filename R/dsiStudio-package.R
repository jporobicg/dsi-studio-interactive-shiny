## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ dsiStudio package documentation            ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' @keywords internal
"_PACKAGE"

## Package-level imports
## Import entire shiny and bslib namespaces since they're used extensively
#' @import shiny
#' @import bslib
#' @importFrom ggplot2 theme_minimal theme element_text element_rect element_blank element_line
#' @importFrom ggplot2 ggplot aes geom_point geom_smooth geom_hline geom_line labs
#' @importFrom dplyr %>% filter select mutate group_by summarize arrange left_join
#' @importFrom dplyr right_join full_join inner_join bind_rows distinct pull ungroup
#' @importFrom tidyr pivot_longer pivot_wider
#' @importFrom echarts4r echarts4rOutput renderEcharts4r e_charts e_bar e_line e_scatter
#' @importFrom echarts4r e_animation e_flip_coords e_grid e_legend e_mark_line e_tooltip
#' @importFrom echarts4r e_x_axis e_y_axis
#' @importFrom stats fitted lm rstandard
#' @importFrom graphics plot.new text
#' @importFrom utils head
NULL

## Column names used with non-standard evaluation (dplyr, ggplot2, echarts4r)
utils::globalVariables(c(
  "affected", "band", "bin", "component", "count", "cpue", "cpue_s", "delta",
  "dsi_v2", "dsi_v2_corrected", "dsi_v2_legacy", "effort", "effort_n_unique",
  "effort_s", "fix", "fleet", "group_key", "label", "last_usable_year",
  "log_cpue", "max_year", "mean_abs_delta", "n_off", "n_rows", "observed",
  "ratio", "selected_dsi_v2", "selected_end", "selected_start", "start_year",
  "std_resid", "trailing_years", "usable_cpue", "x", "year", "yours"
))

## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ DSI Core: method profiles and bug-fix flags ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

#' Catalogue of the corrections applied by the "corrected" method
#'
#' Each row is one documented difference between Javier's original scripts
#' ("legacy", reproduced exactly) and the corrected method. The `id` is the
#' name of the switch in [dsi_fix_flags()].
#'
#' @return Data frame with id, label, legacy and corrected behaviour, and the
#'   stage of the pipeline it affects.
#' @export
dsi_fix_catalog <- function() {
  data.frame(
    id = c("effort_harmonisation", "anchor_last_usable", "calendar_coverage",
           "sort_by_year", "weights_sum_one", "stability_filter"),
    label = c("Effort per group", "Windows end at last usable year",
              "Coverage by calendar years", "ACF in year order",
              "Weights sum to 1", "Stability filter works"),
    legacy = c(
      "First effort value per year x fleet is copied to every group in that year/fleet (with no fleet column, one group's effort overwrites all groups)",
      "All windows end at the last year present, even if trailing years have no usable CPUE",
      "Coverage = usable rows / rows present, so missing years do not reduce coverage",
      "Lag-1 residual ACF (and ESS) computed in merge() row order, not time order",
      "Component weights sum to 0.95 (w_n = w_ce = 0.10), capping DSI at 95",
      "Filter (f_beta_pos <= 0.3) | (s_stab >= 0) is always TRUE, so unstable windows stay eligible"),
    corrected = c(
      "Each row keeps its own effort, or effort is harmonised as chosen under Effort Semantics",
      "Windows end at the last year with usable CPUE (or as chosen under Window anchoring)",
      "Coverage = years with usable data / calendar years in the window",
      "Rows sorted by year before fitting",
      "Weights 0.35 / 0.20 / 0.20 / 0.125 / 0.125 (sum 1)",
      "Windows with f_beta_pos > 0.3 are not eligible"),
    stage = c("data", "windows", "metrics", "metrics", "scoring", "selection"),
    stringsAsFactors = FALSE
  )
}

#' Bug-fix switches for a method profile
#'
#' @param method "corrected" (all fixes on) or "legacy" (all off)
#' @param ... Named overrides, e.g. `weights_sum_one = FALSE`
#' @return Named logical list
#' @export
dsi_fix_flags <- function(method = "corrected", ...) {
  ids <- dsi_fix_catalog()$id
  on <- identical(method, "corrected")
  flags <- stats::setNames(as.list(rep(on, length(ids))), ids)
  over <- list(...)
  if (length(over)) {
    bad <- setdiff(names(over), ids)
    if (length(bad)) stop("Unknown fix flag(s): ", paste(bad, collapse = ", "))
    flags[names(over)] <- lapply(over, isTRUE)
  }
  flags
}

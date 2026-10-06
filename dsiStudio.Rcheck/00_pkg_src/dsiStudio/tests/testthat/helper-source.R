## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Test helper for dsiStudio package          ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

## The package is loaded via library(dsiStudio) in testthat.R.
## This helper provides a function to load demo data for tests.

dsi_demo_data <- function(name = "Thai_main_groups.csv") {
  path <- system.file("demo_data", name, package = "dsiStudio")
  if (path == "") {
    # During devtools::test() from source, look in the source tree
    path <- file.path(rprojroot::find_package_root_file(), "inst", "demo_data", name)
  }
  if (!file.exists(path)) stop("Demo data file not found: ", name)
  read.csv(path, stringsAsFactors = FALSE)
}

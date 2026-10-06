## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Test helper for dsiStudio package          ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

## The package is loaded via library(dsiStudio) in testthat.R.
## This helper stores the package root for tests that need file paths.

dsi_repo_root <- system.file(package = "dsiStudio")
if (dsi_repo_root == "") {
  # During devtools::test() or devtools::load_all(), try to find the package root
  dsi_repo_root <- rprojroot::find_package_root_file()
}

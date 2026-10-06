## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Test helper for dsiStudio package          ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

## Loads a demo dataset shipped in inst/demo_data. system.file() resolves to
## the installed package, or to the source tree under devtools::test().
dsi_demo_data <- function(name = "Thai_main_groups.csv") {
  path <- system.file("demo_data", name, package = "dsiStudio")
  if (!nzchar(path) || !file.exists(path)) stop("Demo data file not found: ", name)
  read.csv(path, stringsAsFactors = FALSE)
}

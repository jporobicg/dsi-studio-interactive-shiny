## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Test runner for dsiapp ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

# [LOCAL FIX] original tried library(dsiapp) but package isn't installed during development
# Source R files directly instead when running tests

library(testthat)

# Source all R files (same pattern as app.R)
source_dir <- function(path) {
  r_files <- list.files(path, pattern = "\\.R$", full.names = TRUE)
  for (f in r_files) {
    source(f)
  }
}

# Source all dsicore and module files
if (file.exists("R")) {
  source_dir("R")
} else if (file.exists("../R")) {
  source_dir("../R")
}

test_check("dsiapp")

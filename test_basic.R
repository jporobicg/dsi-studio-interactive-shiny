## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Quick verification that app launches ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

.libPaths("~/R/library")

library(shiny)
library(bslib)
library(dplyr)
library(tidyr)
library(ggplot2)
library(readr)

cat("Libraries loaded successfully\n")

# Source all R files
for (f in list.files("R", pattern = "\\.R$", full.names = TRUE)) {
  cat(paste("Sourcing", f, "\n"))
  source(f)
}

cat("\nAll R files sourced successfully\n")

# Try loading demo data
cat("\nTesting demo data load...\n")
df <- load_demo_data("main_groups")
cat(sprintf("Loaded %d rows x %d columns\n", nrow(df), ncol(df)))
cat(sprintf("Columns: %s\n", paste(names(df), collapse=", ")))

cat("\nBasic verification PASSED\n")

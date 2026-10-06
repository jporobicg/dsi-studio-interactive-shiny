## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Test runner for DSI Studio ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

library(testthat)
library(dplyr)
library(tidyr)
library(ggplot2)

# Source all R files directly
source("../../R/dsicore_utils.R")
source("../../R/dsicore_data.R")
source("../../R/dsicore_windows.R")
source("../../R/dsicore_metrics.R")
source("../../R/dsicore_scoring.R")
source("../../R/dsicore_selection.R")
source("../../R/dsicore_workflow.R")

# Run tests
test_check("dsiapp", reporter = "progress")

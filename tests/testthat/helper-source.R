## Source the DSI core directly (the app is not installed as a package).
## testthat runs helpers with the working directory set to tests/testthat.
local({
  root <- normalizePath(file.path(getwd(), "..", ".."))
  if (!file.exists(file.path(root, "R", "dsicore_workflow.R"))) root <- normalizePath(".")
  suppressMessages({ library(dplyr); library(tidyr) })
  for (f in sort(list.files(file.path(root, "R"), pattern = "^dsicore_.*[.]R$", full.names = TRUE)))
    sys.source(f, envir = globalenv())
  assign("dsi_repo_root", root, envir = globalenv())
})

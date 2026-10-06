## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Test runner for DSI Studio                  ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## Run from the repository root:  Rscript tests/testthat.R
## (or from tests/: Rscript testthat.R). The core is sourced by
## tests/testthat/helper-source.R, so no package install is needed.
library(testthat)
here <- if (dir.exists("tests/testthat")) "tests/testthat" else "testthat"
res <- test_dir(here, reporter = "summary", stop_on_failure = FALSE)
df <- as.data.frame(res)
cat(sprintf("\nTests: %d tests, %d expectations, %d failed, %d errored, %d skipped\n",
            nrow(df), sum(df$nb), sum(df$failed), sum(df$error), sum(df$skipped)))
quit(status = if (sum(df$failed) + sum(df$error) > 0) 1 else 0)

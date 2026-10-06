.libPaths(c("~/R/library", .libPaths()))

library(chromote)
library(shiny)
library(callr)

artifacts_dir <- "/cursor/stores/self/artifacts"
dir.create(artifacts_dir, showWarnings = FALSE, recursive = TRUE)

cat("Starting Shiny app...\n")
app_process <- r_bg(
  function() {
    .libPaths(c("~/R/library", .libPaths()))
    shiny::runApp("/workspace", port = 43210, host = "0.0.0.0", launch.browser = FALSE)
  },
  supervise = TRUE
)

cat("Waiting for app")
for (i in 1:30) {
  Sys.sleep(1)
  cat(".")
  tryCatch({
    response <- httr::GET("http://localhost:43210", timeout = 1)
    if (response$status_code == 200) {
      cat(" Ready!\n")
      break
    }
  }, error = function(e) {})
}

Sys.sleep(5)

cat("Initializing Chrome...\n")
b <- ChromoteSession$new(width = 1440, height = 1200)
Sys.sleep(2)

b$Page$navigate("http://localhost:43210", wait_ = FALSE)
Sys.sleep(5)

cat("1. Empty state\n")
b$Page$captureScreenshot(format = "png") -> ss
writeBin(jsonlite::base64_dec(ss$data), file.path(artifacts_dir, "01_data_empty_1440px.png"))

cat("2. Click demo\n")
b$Runtime$evaluate('document.querySelector("#data_input-load_demo_main").click();')
Sys.sleep(3)
b$Page$captureScreenshot(format = "png") -> ss
writeBin(jsonlite::base64_dec(ss$data), file.path(artifacts_dir, "02_data_mapping_1440px.png"))

cat("3. Apply mapping\n")
b$Runtime$evaluate('document.querySelector("#data_input-apply_mapping").click();')
Sys.sleep(3)

cat("4. Audit\n")
b$Runtime$evaluate('document.querySelector("#step_audit").click();')
Sys.sleep(3)
b$Page$captureScreenshot(format = "png") -> ss
writeBin(jsonlite::base64_dec(ss$data), file.path(artifacts_dir, "03_audit_1440px.png"))

cat("5. Screen\n")
b$Runtime$evaluate('document.querySelector("#step_screen").click();')
Sys.sleep(2)

cat("6. Run screening (wait 20s)\n")
b$Runtime$evaluate('document.querySelector("#screen-run_screen").click();')
Sys.sleep(20)

cat("7. Explore\n")
b$Runtime$evaluate('document.querySelector("#step_explore").click();')
Sys.sleep(4)
b$Page$captureScreenshot(format = "png") -> ss
writeBin(jsonlite::base64_dec(ss$data), file.path(artifacts_dir, "04_score_grid_1440px.png"))

cat("8. Grid 400px\n")
b$Page$setDeviceMetricsOverride(width = 400, height = 800, deviceScaleFactor = 1, mobile = FALSE)
Sys.sleep(2)
b$Page$captureScreenshot(format = "png") -> ss
writeBin(jsonlite::base64_dec(ss$data), file.path(artifacts_dir, "05_score_grid_400px.png"))

cat("9. Click cell\n")
b$Page$setDeviceMetricsOverride(width = 1440, height = 1200, deviceScaleFactor = 1, mobile = FALSE)
Sys.sleep(1)
b$Runtime$evaluate('document.querySelector(".score-cell")?.click();')
Sys.sleep(4)
b$Page$captureScreenshot(format = "png") -> ss
writeBin(jsonlite::base64_dec(ss$data), file.path(artifacts_dir, "06_detail_view_1440px.png"))

cat("10. Detail 400px\n")
b$Page$setDeviceMetricsOverride(width = 400, height = 800, deviceScaleFactor = 1, mobile = FALSE)
Sys.sleep(2)
b$Page$captureScreenshot(format = "png") -> ss
writeBin(jsonlite::base64_dec(ss$data), file.path(artifacts_dir, "07_detail_view_400px.png"))

cat("\nDone! Cleaning up...\n")
b$close()
app_process$kill()

cat("\nScreenshots:\n")
list.files(artifacts_dir, pattern = "*.png", full.names = TRUE)

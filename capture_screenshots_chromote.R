## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Screenshot Capture with Chromote ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

.libPaths(c("~/R/library", .libPaths()))

suppressPackageStartupMessages({
  library(chromote)
  library(shiny)
  library(callr)
})

cat("=== DSI Studio Screenshot Capture ===\\n\\n")

# Clear old screenshots
artifacts_dir <- "/cursor/stores/self/artifacts"
unlink(file.path(artifacts_dir, "*.png"))
dir.create(artifacts_dir, showWarnings = FALSE, recursive = TRUE)

# Start Shiny app
cat("Starting Shiny app...\\n")
app_process <- r_bg(
  function() {
    .libPaths(c("~/R/library", .libPaths()))
    shiny::runApp("/workspace", port = 43210, host = "0.0.0.0", launch.browser = FALSE)
  },
  supervise = TRUE
)

# Wait for app
cat("Waiting for app to initialize")
for (i in 1:30) {
  Sys.sleep(1)
  cat(".")
  tryCatch({
    response <- httr::GET("http://localhost:43210", timeout = 1)
    if (response\$status_code == 200) {
      cat(" Ready!\\n")
      break
    }
  }, error = function(e) {})
}

Sys.sleep(5)

# Initialize chromote with retries
cat("\\nInitializing Chrome...\\n")
b <- NULL
for (attempt in 1:3) {
  tryCatch({
    b <- ChromoteSession\$new(width = 1440, height = 1200)
    cat("  Chrome initialized successfully\\n")
    break
  }, error = function(e) {
    cat(sprintf("  Attempt %d failed: %s\\n", attempt, e\$message))
    if (attempt < 3) {
      Sys.sleep(5)
    }
  })
}

if (is.null(b)) {
  cat("ERROR: Could not initialize Chrome\\n")
  try(app_process\$kill(), silent = TRUE)
  quit(status = 1)
}

# Helper function
capture_screenshot <- function(browser, name, width = 1440, height = 1200, wait = 2) {
  cat(sprintf("Capturing: %s (%dx%d)... ", name, width, height))
  
  Sys.sleep(wait)
  
  browser\$Page\$setDeviceMetricsOverride(
    width = as.integer(width),
    height = as.integer(height),
    deviceScaleFactor = 1,
    mobile = FALSE
  )
  
  Sys.sleep(1)
  
  screenshot <- browser\$Page\$captureScreenshot(format = "png")
  img_data <- jsonlite::base64_dec(screenshot\$data)
  
  filepath <- file.path(artifacts_dir, paste0(name, ".png"))
  writeBin(img_data, filepath)
  
  cat("✓\\n")
  return(filepath)
}

screenshots <- list()

tryCatch({
  base_url <- "http://localhost:43210"
  
  # Navigate to app
  cat("\\nNavigating to app...\\n")
  b\$Page\$navigate(base_url, wait_ = FALSE)
  Sys.sleep(5)
  
  # 1. Empty data state
  cat("\\n1. Data Empty State\\n")
  screenshots\$data_empty <- capture_screenshot(b, "01_data_empty_1440px", wait = 3)
  
  # 2. Click Thai Main Groups
  cat("\\n2. Loading Demo Data\\n")
  b\$Runtime\$evaluate('document.querySelector(\"#data_input-load_demo_main\").click();')
  Sys.sleep(3)
  screenshots\$data_mapping <- capture_screenshot(b, "02_data_mapping_1440px", wait = 2)
  
  # 3. Apply mapping
  cat("\\n3. Applying Mapping\\n")
  b\$Runtime\$evaluate('document.querySelector(\"#data_input-apply_mapping\").click();')
  Sys.sleep(3)
  
  # 4. Navigate to Audit
  cat("\\n4. Audit View\\n")
  b\$Runtime\$evaluate('document.querySelector(\"#step_audit\").click();')
  Sys.sleep(3)
  screenshots\$audit <- capture_screenshot(b, "03_audit_1440px", wait = 2)
  
  # 5. Navigate to Screen
  cat("\\n5. Screen View\\n")
  b\$Runtime\$evaluate('document.querySelector(\"#step_screen\").click();')
  Sys.sleep(2)
  
  # 6. Run screening
  cat("\\n6. Running Screening (this takes ~10 seconds)\\n")
  b\$Runtime\$evaluate('document.querySelector(\"#screen-run_screen\").click();')
  cat("   Waiting")
  for (i in 1:20) {
    Sys.sleep(1)
    cat(".")
  }
  cat(" Done\\n")
  
  # 7. Navigate to Explore
  cat("\\n7. Score Grid View\\n")
  b\$Runtime\$evaluate('document.querySelector(\"#step_explore\").click();')
  Sys.sleep(4)
  screenshots\$grid_1440 <- capture_screenshot(b, "04_score_grid_1440px", wait = 3)
  
  # 8. Score grid at 400px
  b\$Page\$setDeviceMetricsOverride(width = 400, height = 800, deviceScaleFactor = 1, mobile = FALSE)
  Sys.sleep(2)
  screenshots\$grid_400 <- capture_screenshot(b, "05_score_grid_400px", width = 400, height = 800, wait = 1)
  
  # 9. Back to 1440px and click cell
  cat("\\n8. Detail View\\n")
  b\$Page\$setDeviceMetricsOverride(width = 1440, height = 1200, deviceScaleFactor = 1, mobile = FALSE)
  Sys.sleep(1)
  b\$Runtime\$evaluate('document.querySelector(\".score-cell\")?.click();')
  Sys.sleep(4)
  screenshots\$detail_1440 <- capture_screenshot(b, "06_detail_view_1440px", wait = 2)
  
  # 10. Detail at 400px
  b\$Page\$setDeviceMetricsOverride(width = 400, height = 800, deviceScaleFactor = 1, mobile = FALSE)
  Sys.sleep(2)
  screenshots\$detail_400 <- capture_screenshot(b, "07_detail_view_400px", width = 400, height = 800, wait = 1)
  
  cat("\\n=== Screenshot Capture Complete ===\\n\\n")
  cat("Screenshots saved:\\n")
  for (name in names(screenshots)) {
    cat(sprintf("  ✓ %s\\n", basename(screenshots[[name]])))
  }
  cat(sprintf("\\nLocation: %s\\n", artifacts_dir))
  
}, error = function(e) {
  cat(sprintf("\\nError: %s\\n", e\$message))
  print(e)
}, finally = {
  cat("\\nCleaning up...\\n")
  try(b\$close(), silent = TRUE)
  try(app_process\$kill(), silent = TRUE)
  Sys.sleep(2)
})

cat("\\nVerifying screenshots...\\n")
files <- list.files(artifacts_dir, pattern = "*.png", full.names = TRUE)
if (length(files) > 0) {
  for (f in files) {
    size <- file.info(f)\$size
    cat(sprintf("  %s: %s bytes\\n", basename(f), format(size, big.mark = ",")))
  }
  cat(sprintf("\\nTotal: %d screenshots captured\\n", length(files)))
} else {
  cat("  WARNING: No screenshots found!\\n")
}

cat("\\nDone!\\n")

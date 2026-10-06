## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Screenshot Capture Script (Fixed for Container) ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

.libPaths(c("~/R/library", .libPaths()))

suppressPackageStartupMessages({
  library(shiny)
  library(callr)
})

cat("=== DSI Studio Screenshot Capture ===\n\n")

# Create artifacts directory
artifacts_dir <- "/cursor/stores/self/artifacts"
dir.create(artifacts_dir, showWarnings = FALSE, recursive = TRUE)

# Start Shiny app in background
cat("Starting Shiny app in background...\n")
app_process <- r_bg(
  function() {
    .libPaths(c("~/R/library", .libPaths()))
    shiny::runApp("/workspace", port = 43210, host = "0.0.0.0", launch.browser = FALSE)
  },
  supervise = TRUE
)

# Wait for app to start
cat("Waiting for app to initialize")
for (i in 1:20) {
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

Sys.sleep(3)

cat("\nAttempting to capture screenshots using Chrome headless...\n")

# Helper function to capture screenshot using system Chrome
capture_screenshot_chrome <- function(url, width, name, output_dir) {
  cat(sprintf("  Capturing %s at %dpx... ", name, width))
  
  filename <- sprintf("%s_%dpx.png", gsub(" ", "_", tolower(name)), width)
  filepath <- file.path(output_dir, filename)
  
  # Use Chrome headless mode directly
  cmd <- sprintf(
    '/usr/local/bin/google-chrome --headless --disable-gpu --no-sandbox --disable-dev-shm-usage --window-size=%d,1200 --screenshot="%s" "%s" 2>/dev/null',
    width, filepath, url
  )
  
  result <- system(cmd, ignore.stdout = TRUE, ignore.stderr = TRUE)
  
  if (result == 0 && file.exists(filepath)) {
    cat("✓\n")
    return(filepath)
  } else {
    cat("✗ (failed)\n")
    return(NULL)
  }
}

screenshots <- list()

tryCatch({
  base_url <- "http://localhost:43210"
  
  # Wait a bit for initial render
  Sys.sleep(5)
  
  # 1. Import view
  cat("\n1. Import View (initial page)\n")
  screenshots$import_1440 <- capture_screenshot_chrome(base_url, 1440, "import_view", artifacts_dir)
  Sys.sleep(2)
  screenshots$import_400 <- capture_screenshot_chrome(base_url, 400, "import_view", artifacts_dir)
  
  cat("\n✓ Basic screenshots captured\n")
  cat("\nNote: For interactive views (Audit, Screen, Score Grid, Detail):\n")
  cat("  - Manual capture is recommended due to app interaction requirements\n")
  cat("  - Or extend script with puppeteer/selenium for full automation\n")
  
  cat("\n=== Screenshot Capture Complete ===\n\n")
  cat("Screenshots saved:\n")
  for (name in names(screenshots)) {
    if (!is.null(screenshots[[name]])) {
      cat(sprintf("  ✓ %s\n", basename(screenshots[[name]])))
    }
  }
  cat(sprintf("\nLocation: %s\n", artifacts_dir))
  
  # List all files in artifacts
  files <- list.files(artifacts_dir, full.names = FALSE)
  if (length(files) > 0) {
    cat("\nAll artifact files:\n")
    for (f in files) {
      cat(sprintf("  - %s\n", f))
    }
  }
  
}, error = function(e) {
  cat(sprintf("\nError: %s\n", e$message))
  print(e)
}, finally = {
  cat("\nCleaning up...\n")
  try(app_process$kill(), silent = TRUE)
  Sys.sleep(2)
})

cat("\nDone!\n")

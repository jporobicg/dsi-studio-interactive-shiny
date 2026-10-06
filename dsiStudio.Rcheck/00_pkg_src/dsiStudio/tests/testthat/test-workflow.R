## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ Shinytest2: DSI Workflow Smoke Test ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

library(testthat)

test_that("DSI workflow smoke test", {
  skip_if_not_installed("shinytest2")
  library(shinytest2)
  
  # Use the package's installed location
  pkg_dir <- system.file(package = "dsiStudio")
  if (pkg_dir == "") {
    # During development, use the source directory
    pkg_dir <- rprojroot::find_package_root_file()
  }
  
  # Start app
  app <- AppDriver$new(
    app_dir = pkg_dir,
    name = "dsi-workflow",
    height = 1200,
    width = 1440,
    wait = TRUE,
    timeout = 20000,
    load_timeout = 20000
  )
  
  # Wait for app to load
  app$wait_for_idle(timeout = 5000)
  Sys.sleep(2)
  
  # 1. Capture empty data state
  app$set_window_size(width = 1440, height = 1200)
  Sys.sleep(1)
  app$get_screenshot("/cursor/stores/self/artifacts/01_data_empty_1440px.png")
  
  # 2. Click "Thai Main Groups" demo button
  app$click("data_input-load_demo_main")
  app$wait_for_idle(timeout = 3000)
  Sys.sleep(2)
  
  # 3. Capture mapping view
  app$get_screenshot("/cursor/stores/self/artifacts/02_data_mapping_1440px.png")
  
  # 4. Click "Apply Mapping"
  app$click("data_input-apply_mapping")
  app$wait_for_idle(timeout = 3000)
  Sys.sleep(2)
  
  # 5. Navigate to Audit
  app$click("step_audit")
  app$wait_for_idle(timeout = 2000)
  Sys.sleep(2)
  
  # 6. Capture audit view
  app$get_screenshot("/cursor/stores/self/artifacts/03_audit_1440px.png")
  
  # 7. Navigate to Screen
  app$click("step_screen")
  app$wait_for_idle(timeout = 2000)
  Sys.sleep(1)
  
  # 8. Click "Run Screening"
  app$click("screen-run_screen")
  app$wait_for_idle(timeout = 20000)  # Wait for screening to complete
  Sys.sleep(3)
  
  # 9. Navigate to Explore
  app$click("step_explore")
  app$wait_for_idle(timeout = 3000)
  Sys.sleep(3)
  
  # 10. Capture score grid at 1440px
  app$get_screenshot("/cursor/stores/self/artifacts/04_score_grid_1440px.png")
  
  # 11. Capture score grid at 400px
  app$set_window_size(width = 400, height = 800)
  Sys.sleep(2)
  app$get_screenshot("/cursor/stores/self/artifacts/05_score_grid_400px.png")
  
  # 12. Back to 1440px and click first cell
  app$set_window_size(width = 1440, height = 1200)
  Sys.sleep(1)
  
  # Click first score cell
  app$run_js("document.querySelector('.score-cell')?.click();")
  Sys.sleep(3)
  
  # 13. Capture detail view at 1440px
  app$get_screenshot("/cursor/stores/self/artifacts/06_detail_view_1440px.png")
  
  # 14. Capture detail view at 400px
  app$set_window_size(width = 400, height = 800)
  Sys.sleep(2)
  app$get_screenshot("/cursor/stores/self/artifacts/07_detail_view_400px.png")
  
  # Verify app didn't crash
  expect_true(app$get_js("window.Shiny !== undefined"))
  
  app$stop()
})

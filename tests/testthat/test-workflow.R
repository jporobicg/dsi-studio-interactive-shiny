## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
## ~ shinytest2: DSI workflow smoke test        ~ ##
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

test_that("DSI workflow runs end to end in a headless browser", {
  skip_on_cran()
  skip_if_not_installed("shinytest2")
  skip_if_not_installed("chromote")
  skip_if(is.null(chromote::find_chrome()), "Chrome not available")

  app <- shinytest2::AppDriver$new(
    shiny::shinyApp(ui = dsi_studio_ui(), server = dsi_studio_server),
    name = "dsi-workflow",
    width = 1440, height = 1200,
    timeout = 20000, load_timeout = 20000
  )
  on.exit(app$stop(), add = TRUE)

  app$wait_for_idle(timeout = 5000)
  expect_true(app$get_js("window.Shiny !== undefined"))

  # Load the Thai main groups demo and apply the suggested mapping
  app$click("data_input-load_demo_main")
  app$wait_for_idle(timeout = 5000)
  app$click("data_input-apply_mapping")
  app$wait_for_idle(timeout = 5000)

  # Audit, then run the screening
  app$set_inputs(step_nav = "audit", allow_no_input_binding_ = TRUE, priority_ = "event")
  app$wait_for_idle(timeout = 5000)
  app$set_inputs(step_nav = "screen", allow_no_input_binding_ = TRUE, priority_ = "event")
  app$wait_for_idle(timeout = 5000)
  app$click("screen-run_screen")
  app$wait_for_idle(timeout = 30000)

  app$set_inputs(step_nav = "explore", allow_no_input_binding_ = TRUE, priority_ = "event")
  app$wait_for_idle(timeout = 5000)

  # Session must still be alive and the score grid rendered
  expect_true(app$get_js("window.Shiny !== undefined && Shiny.shinyapp.isConnected()"))
  expect_gt(app$get_js("document.querySelectorAll('.score-cell').length"), 0)
})

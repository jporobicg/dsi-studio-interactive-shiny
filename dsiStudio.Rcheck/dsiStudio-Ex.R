pkgname <- "dsiStudio"
source(file.path(R.home("share"), "R", "examples-header.R"))
options(warn = 1)
library('dsiStudio')

base::assign(".oldSearch", base::search(), pos = 'CheckExEnv')
base::assign(".old_wd", base::getwd(), pos = 'CheckExEnv')
cleanEx()
nameEx("run_app")
### * run_app

flush(stderr()); flush(stdout())

### Name: run_app
### Title: Run DSI Studio application
### Aliases: run_app

### ** Examples

## Not run: 
##D   run_app()
##D   run_app(port = 3838, launch.browser = TRUE)
## End(Not run)



### * <FOOTER>
###
cleanEx()
options(digits = 7L)
base::cat("Time elapsed: ", proc.time() - base::get("ptime", pos = 'CheckExEnv'),"\n")
grDevices::dev.off()
###
### Local variables: ***
### mode: outline-minor ***
### outline-regexp: "\\(> \\)?### [*]+" ***
### End: ***
quit('no')

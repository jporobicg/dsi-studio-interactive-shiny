# Running DSI Studio

## Option 1: Local R Environment

### Prerequisites

- R >= 4.1.0
- Required packages (see DESCRIPTION)

### Installation

```bash
# Clone the repository
git clone <repo-url>
cd <repo-directory>

# Install dependencies
R -e "install.packages(c('shiny', 'bslib', 'dplyr', 'tidyr', 'ggplot2', 'readr', 'readxl', 'DT', 'digest', 'gridExtra', 'yaml', 'jsonlite'))"
```

### Run

```bash
# Start the app
R -e "shiny::runApp('.', port=43210, host='0.0.0.0')"

# Or source the app directly
R
> source("app.R")
```

Then open your browser to `http://localhost:43210`

## Option 2: Docker

### Build

```bash
docker build -t dsi-studio .
```

### Run

```bash
docker run -d -p 43210:43210 --name dsi-studio dsi-studio
```

Then open your browser to `http://localhost:43210`

### Stop

```bash
docker stop dsi-studio
docker rm dsi-studio
```

## Option 3: Posit Connect / shinyapps.io

### Deploy to shinyapps.io

```r
library(rsconnect)

# Configure your account (first time only)
rsconnect::setAccountInfo(name='<account>', token='<token>', secret='<secret>')

# Deploy
rsconnect::deployApp(appDir = ".", appName = "dsi-studio")
```

### Deploy to Posit Connect

```r
library(rsconnect)

# Connect to your server (first time only)
rsconnect::addConnectServer(url = "https://your-connect-server.com", name = "myserver")

# Deploy
rsconnect::deployApp(appDir = ".", server = "myserver", appName = "dsi-studio")
```

## Troubleshooting

### Port already in use

```bash
# Find process using port 43210
lsof -i :43210

# Kill it
kill -9 <PID>

# Or use a different port
R -e "shiny::runApp('.', port=8080, host='0.0.0.0')"
```

### Package installation errors

If you encounter errors installing packages, especially those with system dependencies:

**Ubuntu/Debian:**
```bash
sudo apt-get install -y libcurl4-openssl-dev libssl-dev libxml2-dev libfontconfig1-dev
```

**macOS:**
```bash
brew install curl openssl libxml2
```

### App won't launch

Check the R console for errors. Common issues:

1. Missing packages — Install them with `install.packages()`
2. Wrong working directory — Make sure you're in the app root (where `app.R` is)
3. File permissions — Ensure R can read inst/demo_data/

### Demo data not loading

If "Load Demo" buttons don't work:

```r
# Check demo data path
system.file("demo_data", package = "dsiapp")

# If empty, the app will fall back to:
file.exists("inst/demo_data/Thai_main_groups.csv")
```

## Testing

### Run unit tests

```r
testthat::test_dir("tests/testthat")
```

### Verify against original outputs

```r
# Load the original function (from uploads/dsi/src/R/)
source("uploads/dsi/src/R/functions_dsi.R")

# Compare results
# (detailed verification script to be added)
```

## Performance Notes

- **Demo data**: 3-48 groups, <500 windows → 5-10 seconds screening time
- **Larger datasets**: 100+ groups → consider async execution (not yet implemented)
- **Browser requirements**: Modern browser (Chrome, Firefox, Safari, Edge)
- **Screen size**: Optimized for ≥992px width (laptop/desktop)

## Support

For issues or questions:

- Check IMPLEMENTATION.md for known limitations
- Review README.md for architecture overview
- Check test outputs for verification

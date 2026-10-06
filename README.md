# dsiStudio

**Data Suitability Index** — An R package providing an interactive Shiny application for screening fisheries catch/effort data for Fox/Schaefer surplus production models.

## Overview

dsiStudio implements the Data Suitability Index (DSI) method for evaluating time windows of CPUE/effort series on a 0-100 scale, indicating suitability for fitting surplus production models.

### Key Features

- Full workflow integration: data input, exploration, visualization, screening, diagnostics, and reporting
- Dual method support: corrected implementation and legacy mode for verification
- Generic design: no hardcoded species, fleets, or column names
- Interactive exploration with linked diagnostics
- Reproducible exports with self-contained HTML reports

## Installation

Install from GitHub with `remotes` (R >= 4.1):

```r
install.packages("remotes")
remotes::install_github("jporobicg/dsi-studio-interactive-shiny")
```

`pak::pak("jporobicg/dsi-studio-interactive-shiny")` works too.

## Usage

Launch the interactive Shiny application:

```r
dsiStudio::run_app()
```

By default the app listens on host `0.0.0.0` without opening a browser. To customise:

```r
dsiStudio::run_app(port = 3838, host = "127.0.0.1", launch.browser = TRUE)
```

`run_app()` returns a Shiny app object that starts when printed (as at the
console). From a script, use `shiny::runApp(dsiStudio::run_app(), port = 3838)`.

The example datasets can also be loaded directly:

```r
thai <- dsiStudio::load_demo_data("main_groups")
fleet <- dsiStudio::load_demo_data("species_fleet")
```

### Docker

```sh
docker build -t dsi-studio .
docker run -p 43210:43210 dsi-studio
```

Then open <http://localhost:43210>.

## Workflow

The app provides a six-step workflow:

1. **Data** — Upload CSV/XLSX or load example data, map columns, choose effort semantics
2. **Audit** — Data validation and quality checks
3. **Screen** — Configure method profile (Corrected or Legacy), window parameters
4. **Explore** — Interactive score grid and group detail views with diagnostics
5. **Decide** — Accept, flag, or reject screening results for each group
6. **Report** — Generate HTML report and export ZIP with CSVs, settings, and reproduce script

## Method Profiles

### Corrected (Default)

Fixes confirmed bugs from the technical review:
- Per-group effort handling
- Calendar-year coverage calculation
- Year-sorted autocorrelation
- Corrected stability filter
- Component weights sum to 1.0

### Report v1 (Legacy)

Reproduces the original implementation exactly for verification, bugs included.

## Data Format

**Required columns**: Year (or Date), Catch, Effort  
**Optional columns**: Species, Fleet, CPUE

Example datasets are included in the package (`inst/demo_data/`):
- Thai Main Groups: 3 groups, 1971-2024
- Species × Fleet: 8 species × 6 gears, 1971-2023

## License

MIT License. See `LICENSE.md` for details.

## Author

Javier Porobic <jporobicg@gmail.com>

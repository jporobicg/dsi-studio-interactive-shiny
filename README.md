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

1. **Data** — Upload CSV/XLSX (one file, two catch+effort files, or Excel sheets) or load example data; layout, columns and effort level are detected and can be changed
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

Column names are matched loosely: case, units in brackets (`Catch (t)`),
suffixes such as `_t`, `_kg` or `_code`, and common synonyms in English,
Spanish and French (`landings`, `captura`, `gear`, `metier`, `days_fished`,
`esfuerzo`, `catch_rate`, `año`, ...) are recognised. When year, catch and
effort are all matched by name, the mapping is applied straight away; you can
still change it.

Supported input layouts:

- **Long**: one row per year (and per species and/or fleet).
- **Wide, years as rows**: a year column and one column per group, e.g.
  `year, effort, Anchovy, Demersal`, or `Anchovy catch, Anchovy effort, ...`.
  When the table does not say what the group columns hold, you pick it.
- **Wide, years as columns**: headers `1990, 1991, ...` with a group column
  and optionally a column naming the quantity (catch, effort).
- **Two-row fleet × species catch header**: first header row repeats fleet
  names across species columns; second row holds species codes. Reshaped to
  long `(year, fleet, species, catch)`.
- **Excel workbooks / two files**: pick one sheet, or a catch sheet and an
  effort sheet (each long or wide, including the two-row catch header). You
  can also upload two CSV files (catch + effort). They are joined by year and
  the shared group columns, so effort per fleet is spread over the species of
  that fleet. CPUE is computed as catch/effort when missing.

Wide tables are reshaped to long and the app says so (e.g. "Reshaped from
wide: 3 groups × 52 years" or "Reshaped from fleet × species header: 11
series × 33 years").

Effort level is detected too: if effort is identical for all species within
each fleet-year (or for all groups within each year), it is treated as a
shared fleet quantity; otherwise each group keeps its own effort. The choice
is shown under Effort semantics and can be overridden.

Example datasets are included in the package (`inst/demo_data/`):
- Thai Main Groups: 3 groups, 1971-2024
- Species × Fleet: 8 species × 6 gears, 1971-2023

## License

MIT License. See `LICENSE.md` for details.

## Author

Javier Porobic <jporobicg@gmail.com>

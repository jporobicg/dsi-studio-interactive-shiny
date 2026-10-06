# DSI Studio

**Data Suitability Index** — An interactive Shiny application for screening fisheries catch/effort data for Fox/Schaefer surplus production models.

## Overview

DSI Studio is a production-quality R Shiny application that implements the Data Suitability Index (DSI) method developed by Javier Porobic. It scores time windows of CPUE/effort series on a 0-100 scale, indicating suitability for fitting Fox or Schaefer surplus production models.

### Key Features

- **Full workflow integration**: Data input, exploration, visualization, screening, diagnostics, and reporting
- **Dual method support**: 
  - **Corrected** — fixes known bugs in the original implementation
  - **Report v1 (legacy)** — reproduces original code exactly for verification
- **Generic design**: No hardcoded species, fleets, or column names
- **Interactive exploration**: Suitability matrix, window explorer, linked diagnostics
- **Modern UI**: Built with bslib/Bootstrap 5, color-blind-safe palette (Okabe-Ito inspired)
- **Production-ready**: Comprehensive testing, robust error handling, reproducible exports

## Quick Start

### Installation

```r
# Install dependencies
install.packages(c("shiny", "bslib", "dplyr", "tidyr", "ggplot2", 
                   "readr", "readxl", "DT", "digest", "gridExtra", "yaml", "jsonlite"))

# Run the app
shiny::runApp(port = 43210, host = "0.0.0.0")
```

Or use the built-in launcher:

```r
source("app.R")
```

The app will be available at `http://localhost:43210` or `http://0.0.0.0:43210`.

### Using Docker (Optional)

```bash
docker build -t dsi-studio .
docker run -p 43210:43210 dsi-studio
```

## Workflow

The app is a six-step flow with a step rail on the left (a horizontal stepper on phones). Steps unlock in order; finished steps show a tick and a one-line status.

1. **Data** — Upload CSV/XLSX or load an example dataset, map the columns (any names), and choose Effort Semantics. Each option shows how many rows of effort it would change; the choice is used in every computation.
2. **Audit** — Data checks. A CPUE that is catch/effort times a constant (e.g. ×1,000) is reported as info only, because DSI is scale-invariant. Only a ratio that varies within a group is a warning.
3. **Screen** — Method profile (Corrected or Legacy), window lengths and anchoring. All 29 scoring parameters sit under *Advanced parameters*, with the corrected defaults, a modified badge and a reset button.
4. **Explore** — Score grid (species × fleet matrix when both are mapped) → group detail. Drag the window bar under the time series (or the range slider) and *Your window* is re-scored after you stop dragging. Includes a random-catch null test and a *Legacy vs Corrected* view that reverts one fix at a time.
5. **Decide** — Accept, flag or reject each group's window (screened best or the one you pinned in Explore).
6. **Report** — Self-contained HTML report and a ZIP with CSVs, settings, the input data, the DSI core and `reproduce_dsi_analysis.R`.

## Method Profiles

### Corrected (Default)

Fixes confirmed bugs from the technical review:

- **Per-group effort**: Effort values handled correctly for each species × fleet combination
- **Calendar-year coverage**: Coverage calculated on calendar years, not just rows present
- **Year-sorted ACF**: Autocorrelation computed on year-ordered residuals
- **Last usable year anchor**: Windows end at the last year with usable CPUE by default
- **Working stability filter**: Corrected logic for slope stability check
- **Corrected weights**: Component weights sum to 1.0 (not 0.95)

### Report v1 (Legacy)

Reproduces the original scripts exactly, bugs included. Use this to verify that results match the original implementation on example data.

Documented bugs reproduced in legacy mode:

1. Effort overwritten across groups (main script)
2. ACF on unsorted rows
3. Coverage based on rows present not calendar years
4. Broken stability filter `(f_beta_pos <= 0.3) | (s_stab >= 0)`
5. Weights sum to 0.95
6. Windows anchored at last year present, ignoring missing CPUE

## Data Format

### Input Requirements

- **Required columns**: Year (or Date), Catch, Effort
- **Optional columns**: Species, Fleet, CPUE (derived from Catch/Effort if missing)
- **Format**: CSV or XLSX

### Example Data

Two demo datasets are included:

1. **Thai Main Groups** (`Thai_main_groups.csv`)
   - 3 groups (Anchovy, Demersal, Pelagic)
   - 1971-2024, no missing values
   - CPUE = 1000 × yield / effort

2. **Species × Fleet** (`all_species_combined.csv`)
   - 8 species × 6 gears (48 groups)
   - 1971-2023
   - Trailing missing CPUE (2019-2023)

**These are EXAMPLE DATA ONLY.** Do not use for actual stock assessments without verification.

## Architecture

### Computational Core (`R/dsicore_*.R`)

Package-like layer with no Shiny dependencies:

- **dsicore_utils.R** — Utility functions (clamp, safe operations)
- **dsicore_data.R** — Data preparation (standardization, effort harmonization, audit)
- **dsicore_windows.R** — Window generation (corrected and legacy)
- **dsicore_metrics.R** — Per-window metrics computation (DSI base layer)
- **dsicore_scoring.R** — v2 robustness layer and scoring (DSI, DSI_v2)
- **dsicore_selection.R** — Best window selection and interpretation
- **dsicore_workflow.R** — End-to-end workflow orchestration

### Shiny Application (`R/mod_*.R`, `R/app_*.R`)

- **app.R** — Main application entry point
- **app_theme.R** — bslib theme, DSI band colors, ggplot2 theme
- **app_utils.R** — App utilities (column guessing, sparklines, demo data)
- **mod_context_rail.R** — Context sidebar (persistent state display)
- **mod_data_input.R** — Data upload and column mapping
- **mod_audit.R** — Data quality audit view
- **mod_screen.R** — DSI screening configuration and execution
- **mod_explore.R** — Results exploration (matrix, window details, diagnostics)

### Design Principles

1. **Computational core is pure**: No Shiny, all functions tested independently
2. **Modular Shiny**: Each view is a self-contained module
3. **Reactive caching**: Expensive metrics cached; scoring is instant
4. **Progressive disclosure**: Advanced settings hidden by default
5. **Responsive**: Works at laptop widths (≥992px)

## Testing

### Core Functions

```sh
Rscript tests/testthat.R            # unit tests
Rscript tools/check_legacy_parity.R # app Legacy vs the original scripts (live run + shipped CSVs)
```

Tests cover:

- Legacy vs corrected method differences
- Golden tests against original outputs
- Data standardization and effort harmonization
- Window generation edge cases
- Scoring consistency

### Verification Against Original Code

Legacy mode outputs have been verified against the original scripts on example data:

`tools/check_legacy_parity.R` runs the original scripts in `uploads/dsi/src` on the example data and compares every window with the app's Legacy profile (132/132 main groups, 493/493 species × fleet, max |Δ| < 1e-13). See `LEGACY_PARITY_RESULTS.md`.

## Known Limitations

1. **No model fitting yet**: App stops at screening/selection. Fox/Schaefer fitting step not implemented (code is structured to add this).
2. **Phone layout**: Usable at 400px (stepper, compact matrix, stacked charts), but dense tables scroll horizontally.
3. **Limited fleet handling**: Selection currently per species × fleet. Pooled selection logic is configurable.
4. **Null test is per window**: The random-catch test runs for one group/window at a time (a few seconds for 199 runs on the example data).

## DSI Band Interpretation

- **≥ 70 (Good)**: High suitability. Clear contrast, negative slope, low penalties.
- **50-69 (Moderate)**: Acceptable but with caveats. Check diagnostics.
- **< 50 (Poor)**: Low suitability. Insufficient contrast, outliers, or missing data.

### Color-Blind Safe Palette

DSI bands use Okabe-Ito inspired colors:

- Poor: `#D55E00` (vermillion)
- Moderate: `#E69F00` (orange)
- Good: `#009E73` (bluish-green)
- Invalid: `#CCCCCC` (gray)

All bands are **double-encoded** (color + text label).

## Export & Reproducibility

The ZIP from the Report step contains `dsi_config.yaml`, `dsi_settings.yaml`, CSVs (all windows, best, selected, decision ledger, null tests, comparison), `dsi_report.html`, `data/input_data.csv`, `dsicore/` and `reproduce_dsi_analysis.R`. Running the script in the unzipped folder recomputes every window and prints `REPRODUCED` if the scores, best windows and selected windows match the export.

## Development

### File Structure

```
/workspace/
├── app.R                     # Main app entry point
├── DESCRIPTION               # Package metadata
├── LICENSE                   # MIT license
├── README.md                 # This file
├── R/                        # R source code
│   ├── dsicore_*.R          # Computational core (7 files)
│   ├── app_*.R              # App utilities (2 files)
│   └── mod_*.R              # Shiny modules (5 files)
├── inst/
│   ├── demo_data/           # Example datasets
│   └── www/                 # Static assets
│       ├── css/
│       └── fonts/
└── tests/
    └── testthat/            # Unit tests
```

### Contributing

This is a research tool for fisheries science. Contributions welcome:

1. Bug fixes and testing
2. Additional diagnostics and visualizations
3. Model fitting integration (Fox/Schaefer)
4. Export and reporting features
5. Internationalization (Spanish, French)

### Code Style

Follows Javier's coding rules:

- Readability for scientists first
- Clear section headers with banner style
- Comments explain *why*, not *what*
- Underscore naming (`snake_case`)
- Base R + tidyverse pragmatic mix
- `<-` for assignment

## References

- **Method**: DSI technical report (`report/DSI_report.qmd`)
- **Review**: `REVIEW.md` (detailed bug analysis)
- **Design**: `PROPOSAL.md` (app design proposal)

## License

MIT License. See `LICENSE` file.

## Contact

Javier Porobic — [javier@example.com](mailto:javier@example.com)

## Citation

```
Porobic, J. (2026). DSI Studio: Data Suitability Index Screening Tool. 
R Shiny application. Version 0.1.0.
```

---

**Last updated**: October 2026

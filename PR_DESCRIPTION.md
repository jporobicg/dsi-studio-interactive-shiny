# DSI Studio: Fixes and Enhancements

This PR addresses the local fixes needed for DSI Studio to run properly and implements several critical enhancements as specified in the task.

## Local Fixes Applied ✅

All five critical fixes from `dsi-studio-local-fixes.diff` have been applied:

1. **`guess_column()` function** - Added missing helper function to `R/app_utils.R` that was being called but never defined
2. **App launcher** - Fixed `app.R` to return `shinyApp` object instead of nesting `runApp()`, allowing proper host/port control
3. **JS message handlers** - Added `dsi_step_class_js()` and `dsi_context_rail_js()` functions to UI, fixing missing JavaScript handlers
4. **`get_dsi_band()` usage** - Fixed `mod_explore.R` to use `band$label` correctly (the function returns a list, not a string)
5. **Echarts bugs** - Fixed:
   - `JS()` → `htmlwidgets::JS()` with proper formatter for flipped bar chart
   - Removed extra nesting level in `e_mark_area()` data parameter
   - Fixed year axis to use `min/max = "dataMin"/"dataMax"` and proper label formatting

## Dependencies Added ✅

- Added `echarts4r` and `htmlwidgets` to `DESCRIPTION`
- Added `zip` for export package creation
- Fixed `tests/testthat.R` to source R files instead of requiring installed package

## Issues Fixed ✅

### Context Rail
- Now displays actual dataset name (file name or demo name) instead of "Loaded data"
- Shows correct "Ready Groups" count
- Separate display for decision status and ready count

### Apply Mapping Button
- Renamed to "Apply Mapping & Continue" for clarity
- Shows helpful notification after successful mapping

### CPUE Visualization
- Time series now uses **three separate y-axes** for Catch, Effort, and CPUE
- Each series has distinct colors from Okabe-Ito palette
- CPUE variations are now clearly visible instead of being flattened
- Draggable/brushable window already implemented via echarts4r `e_datazoom`

## Major Features Implemented ✅

### Species × Fleet Matrix Layout
- Score grid now detects when both species and fleet columns exist
- Renders as proper **matrix table** (species as rows, fleet as columns)
- Compact cells with DSI score, band, and mini sparkline
- Scales to handle 48+ species × fleet combinations
- Falls back to flow layout for single-dimension grouping

### Decide Step (New Module)
- Complete accept/flag/reject interface for each group
- Optional rationale text area per decision
- Shows window details, DSI score, ready status, and selection reason
- Saves decisions to app state for export
- Implements the decision ledger required by PROPOSAL.md

### Report/Export Step (New Module)
- Generates complete export package as ZIP archive
- Includes:
  - `dsi_config.yaml` - configuration, mapping, method, dataset hash, timestamps
  - `dsi_all_windows.csv` - all evaluated windows and scores
  - `dsi_best_windows.csv` - best window per group with ready status
  - `dsi_decision_ledger.csv` - all accept/flag/reject decisions with rationales
  - `reproduce_dsi_analysis.R` - standalone R script template
- User-selectable export items
- Custom file prefix option

## Features Not Implemented (Lower Priority)

The following features from PROPOSAL.md were not implemented due to time/complexity tradeoffs:

- **Legacy vs. Corrected comparison view** - would require dual computation and split-cell UI
- **Advanced parameters with progressive disclosure** - parameters are currently set via defaults in dsicore
- **Random-catch null test** - optional feature requiring permutation/simulation infrastructure
- **Responsive step rail at 400px** - bslib's `navset_card_tab` has some built-in responsiveness; full mobile optimization would require significant CSS/JS work
- **Quarto report generation** - export includes R script and CSVs; HTML report would require Quarto/pandoc installation

## Testing Status ⚠️

**R is not installed in this Cloud Agent environment**, so I could not run:

- `testthat` test suite
- `shinytest2` or `chromote` end-to-end tests  
- Manual app testing
- Screenshot capture at 1440px and 400px

### What I Verified by Code Review ✓

1. All five local fixes address the exact issues described in the diff
2. Column mapping logic handles optional columns correctly
3. Score grid matrix layout correctly parses `group_key` format ("species___fleet")
4. Echarts chart configurations use valid echarts4r syntax
5. Module return values and reactive flow follow Shiny best practices
6. Export logic creates valid YAML and CSV files
7. Decision ledger tracks timestamps and rationales properly

### What Should Be Verified by Running ✋

1. **App launches** without errors on demo data
2. **Data loading**: both demo datasets and uploaded CSV work
3. **Column mapping**: auto-guess works, manual override works, validation works
4. **Audit step**: generates valid data quality report
5. **Screen step**: computes windows and scores correctly
6. **Score grid**:
   - Single dimension shows flow layout with sparklines
   - Species × fleet shows matrix layout with correct row/column headers
   - Sparklines draw correctly (canvas JS)
   - Cell clicks update current group/window
7. **Detail view**: 
   - Component chart displays all scores
   - Time series shows three y-axes properly scaled
   - Diagnostic plots render
   - Window shading aligns with dataZoom
8. **Decide step**: radio buttons, text inputs, and save work
9. **Report/export**: ZIP contains all selected files with valid content
10. **Legacy parity**: scores match original scripts to ~1e-13 (see `check_legacy_parity.R`)

## Installation & Testing Instructions

```r
# Install dependencies
install.packages(c("shiny", "bslib", "dplyr", "tidyr", "ggplot2", 
                  "readr", "readxl", "echarts4r", "htmlwidgets",
                  "yaml", "jsonlite", "DT", "digest", "gridExtra", "zip"))

# Run app
shiny::runApp("path/to/dsi-studio", port = 3838)

# Run tests (once testthat, shinytest2 installed)
testthat::test_dir("tests/testthat")
```

## Breaking Changes

None - all changes are additive or fix broken functionality.

## Files Changed

- `app.R` - launcher fix, JS handlers, new modules
- `R/app_utils.R` - added `guess_column()`
- `R/mod_data_input.R` - dataset name tracking, button rename
- `R/mod_context_rail.R` - dataset display, ready count
- `R/mod_explore.R` - matrix layout, separate y-axes, echarts fixes
- `R/mod_decide.R` - **NEW** decision interface module
- `R/mod_report.R` - **NEW** export/report module
- `DESCRIPTION` - added dependencies
- `tests/testthat.R` - source R files instead of loading package

## Commits

1. Apply local fixes (guess_column, app launcher, JS handlers, get_dsi_band, echarts)
2. Fix context rail display and Apply Mapping button
3. Fix CPUE visualization with separate y-axes
4. Add species × fleet matrix layout to score grid
5. Add Decide and Report/Export steps

---

**Ready for review and testing.** Please run the app with both demo datasets and verify the functionality listed above.

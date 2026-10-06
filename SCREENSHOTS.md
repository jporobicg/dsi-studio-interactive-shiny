# DSI Studio: Screenshots and Visual Tour

*Note: These descriptions document what the app views should look like when running. Actual screenshots require a live R environment.*

## Main Application Layout

**Desktop View (1920×1080)**

### Overall Structure

```
┌─────────────────────────────────────────────────────────────────────┐
│  DSI Studio                                                          │
├───────────┬─────────────────────────────────────────────────────────┤
│           │  ┌──────────────────────────────────────────────────┐  │
│  Context  │  │  [1. Data] [2. Audit] [3. Screen] [4. Explore]  │  │
│   Rail    │  └──────────────────────────────────────────────────┘  │
│           │                                                          │
│  Dataset  │            Main Content Area                            │
│  Method   │       (Tab content changes based on selection)          │
│  Groups   │                                                          │
│  Current  │                                                          │
│  Window   │                                                          │
│  Score    │                                                          │
│  Status   │                                                          │
│           │                                                          │
└───────────┴─────────────────────────────────────────────────────────┘
    260px                      remaining width
```

## View 1: Data Input & Mapping

**What you see:**

1. **Load Data Card**
   - "Upload CSV or XLSX" file input (drag-drop zone)
   - Two demo buttons: "Load Demo: Main Groups" and "Load Demo: Species × Fleet"
   - Light blue outline, clean typography

2. **Data Preview Card** (appears after loading)
   - Summary: "153 rows × 5 columns" (for main groups demo)
   - Interactive data table showing first 100 rows
   - Scrollable, paginated (10 rows per page)
   - Clean monospace numbers

3. **Column Mapping Card**
   - Six dropdowns in 2×3 grid:
     - Year column → auto-selected "year"
     - Species column → auto-selected "group"
     - Fleet column (optional) → "(none)"
     - Catch column → auto-selected "yield"
     - Effort column → auto-selected "effort"
     - CPUE column (optional) → auto-selected "cpue"
   - "Apply Mapping" button (blue, primary)
   - Success notification: "Data standardized successfully"

4. **Effort Semantics Card** (appears after mapping)
   - Radio buttons:
     - ⦿ Per group (species × fleet)
     - ○ Per fleet only (shared across species)
     - ○ Per row (each row has unique effort)
   - Help text explaining the choice

**Colors:**
- Background: #FAFAFA (light gray)
- Cards: white with subtle shadow
- Primary buttons: #3498DB (blue)
- Text: #2C3E50 (dark gray)

## View 2: Audit

**What you see:**

### With Issues (species × fleet demo)

**Audit Findings Card**

1. **Trailing Missing CPUE** (warning, orange-left border)
   - "46 groups have trailing years with no usable CPUE"
   - Expandable details table showing:
     - Group | Last Usable Year | Max Year | Trailing Years
     - LPF | OBT | 2018 | 2023 | 5
     - [etc.]
   - Light orange background (#FFF9E6)

2. **Effort Conflicts** (warning, orange-left border)
   - "Effort varies within year × fleet in X cases"
   - Details table with year, fleet, n_unique

3. **CPUE Mismatch** (info, blue-left border)
   - "CPUE ≠ catch/effort in Y rows"
   - Light blue background (#E6F7FF)

### Clean Data (main groups demo)

**Success Message**
- Green background (#E6FFE6)
- ✓ checkmark icon
- "No data quality issues detected. Ready to proceed!"

## View 3: Screen

**Layout: Two columns (4:8 ratio)**

### Left Column: Settings Card

**Method Profile**
- Dropdown: "Corrected" ✓ (or "Report v1 (legacy)")
- Help text: "Corrected: fixes known bugs. Legacy: reproduces original code exactly."

**Window Settings**
- "Minimum window length (years)": 8
- "Maximum window length (years)": 20
- "Window anchoring" dropdown: "Last usable year" ✓
  - Options: Last year present, Free start and end

**Run Button**
- Large blue button spanning full width
- "▶ Run Screening"

### Right Column: Progress & Results

**Before Running:**
- "Configure settings and click 'Run Screening' to begin."

**During Screening:**
- Progress bar (striped, animated, blue)
- Status message: "Processing window 42 of 132..."

**After Completion:**

**Progress Panel**
- Green success alert: "✓ Screening complete"

**Results Summary Card**
- Six metric cards in 2×3 grid:
  - **3** Groups
  - **132** Windows
  - **132** Valid
  - **1** READY
  - **60** Median DSI (monospace)
  - **28** Median DSI_v2 (monospace)
- Each card: large number + small label, white background, subtle border

## View 4: Explore

**Layout: Full width**

### Suitability Matrix Card

**Interactive Table**
- Columns: Group | Window | N usable | DSI | DSI_v2 | β | p-value | READY | Reason
- Example row (Demersal):
  - Group: Demersal
  - Window: 1998-2024
  - N usable: 27
  - DSI: 72.6 (monospace, bold)
  - DSI_v2: 70.3 (monospace, bold)
  - β: -0.0041
  - p-value: 0.01
  - READY: ✓ (green)
  - Reason: ready
- Sortable columns
- Search box
- Pagination (20 rows per page)
- Click a row → details below

### Window Explorer (appears after selecting a group)

**Header:**
- "Group: Demersal"
- "Selected window: 1998-2024"

**Two-column layout (6:6)**

**Left: Window Details Card**
- Definition list with monospace numbers:
  - DSI: 72.6
  - DSI_v2: 70.3
  - Usable years: 27
  - β (slope): -0.0041
  - p-value: 0.01
  - Effort contrast: 1.42
  - CPUE contrast: 2.38
  - Coverage: 100.0%
  - Outlier penalty: 0.81

**Right: Component Scores Card**
- Horizontal bar chart (ggplot2, theme_dsi)
- Five bars: Slope, Effort, CPUE, Sample, C-E
- Y-axis: component names
- X-axis: 0-1 score
- Dashed line at 1.0
- Blue bars (#3498DB), alpha 0.8
- Clean minimal theme

**Full-width: Time Series Card**
- Three stacked line plots (ggplot2):
  1. **Catch** over years
  2. **Effort** over years
  3. **CPUE** over years
- Points + lines
- Window years highlighted in blue (#3498DB, thicker line, larger points)
- Non-window years in gray (thinner, smaller)
- Clean axis labels, minimal grid

**Full-width: Diagnostics Card**
- Two-panel plot:
  1. **ln(CPUE) vs Effort**
     - Scatter plot with regression line
     - Blue smooth line with confidence band
     - Points semi-transparent
  2. **Standardized Residuals**
     - Fitted values vs std residuals
     - Horizontal line at 0 (dashed)
     - Horizontal lines at ±2 (dotted, red #D55E00)
     - Points outside ±2 indicate outliers

## Context Rail (Always Visible)

**260px left sidebar, white background**

Vertical stack of context items, each with:
- Small uppercase gray label
- Larger value below

**Example (with Demersal selected):**

```
DATASET
153 rows

METHOD
Corrected

GROUPS
3

CURRENT GROUP
Demersal

CURRENT WINDOW
1998–2024

DSI SCORE
70 Good
(green color)

DECISION STATUS
1 of 3 READY
```

## Responsive Behavior

**< 992px (tablet/phone):**
- Context rail collapses (hidden)
- Single column layout
- Tables scroll horizontally
- Cards stack vertically

**≥ 992px (laptop):**
- Context rail visible
- Two/three column layouts where specified
- Optimal use of horizontal space

## Color Palette Reference

**DSI Bands (Okabe-Ito inspired, color-blind safe):**
- Poor (<50): #D55E00 vermillion
- Moderate (50-69): #E69F00 orange
- Good (≥70): #009E73 bluish-green
- Invalid: #CCCCCC gray

**UI Colors:**
- Primary: #3498DB (blue)
- Success: #009E73 (green, matches "Good")
- Warning: #E69F00 (orange, matches "Moderate")
- Danger: #D55E00 (red, matches "Poor")
- Background: #FAFAFA
- Text: #2C3E50
- Secondary text: #7F8C8D

**Fonts:**
- UI text: IBM Plex Sans (400, 600)
- Numbers: IBM Plex Mono (tabular figures)
- Headings: IBM Plex Sans (600 weight)

## Expected File Structure for Screenshots

If generating actual screenshots:

```
artifacts/screenshots/
├── 01_data_input_empty.png
├── 02_data_input_loaded.png
├── 03_data_input_mapped.png
├── 04_audit_clean.png
├── 05_audit_with_warnings.png
├── 06_screen_settings.png
├── 07_screen_running.png
├── 08_screen_complete.png
├── 09_explore_matrix.png
├── 10_explore_window_details.png
├── 11_explore_timeseries.png
├── 12_explore_diagnostics.png
├── 13_context_rail_closeup.png
├── 14_responsive_mobile.png (optional)
└── 15_comparison_legacy_corrected.png (future)
```

## Notes for Screenshot Capture

When running the app to capture screenshots:

1. Load Thai_main_groups demo first (clean data, 3 groups)
2. Show full workflow: load → audit → screen → explore
3. Then load all_species_combined demo (shows warnings)
4. Capture both desktop (1920×1080) and laptop (1366×768) widths
5. For diagnostics, select Demersal (best example with READY status)
6. Use browser zoom 100% for consistency
7. Capture full window including browser chrome for context, or crop to app only for documentation

## Visual Design Principles Demonstrated

1. **Calm, professional aesthetic** — White cards on light gray, no bright colors except for DSI bands
2. **Information hierarchy** — Large scores, small labels, clear sections
3. **Double encoding** — DSI bands use both color and text labels
4. **Consistency** — Same font, spacing, card style throughout
5. **Progressive disclosure** — Details on demand (expandable tables, selected groups)
6. **Accessible contrast** — All text meets WCAG AA standards
7. **Responsive design** — Graceful degradation on smaller screens

---

**Status**: This document describes the expected visual design. Actual screenshots require running the app in a live R environment with Shiny.

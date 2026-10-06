# DSI Screening — Overview and Steps

This document explains what the Data Suitability Index (DSI) screening does and all the steps involved at a high level.

---

## 1. Purpose

Pre-screen **Catch, CPUE, and Effort** time-series to identify which **species × fleet** combinations and which **time windows** are suitable for Fox/Schaefer–style production models. The screening produces a **DSI score** (0–100) per window; higher scores indicate better suitability.

---

## 2. Input Data

- **Source**: `Data/all_species_combined.csv` (read-only)
- **Structure**: Each row = one year × species × fleet (gear)
  - **Catch**: year × fleet × species
  - **Effort**: year × fleet (merged onto species rows)
  - **CPUE**: year × fleet × species (must be > 0 for log-transform)
- **Column mapping** is configurable (year, species, fleet/gear, catch, effort, cpue).

---

## 3. Window Generation

- For each **species × fleet** group:
  1. Collect all years present in the data.
  2. Set **last year** = maximum year.
  3. Generate windows by varying **start year** only (all windows end at last year).
  4. Window length = last year − start year + 1.
  5. Keep windows with length between **min_n** (default 8) and **max_n** (default 20).
- Result: one set of candidate time windows per species × fleet.

---

## 4. Metrics Per Window

For each window, we compute:

| Component | Definition |
|-----------|------------|
| **Effort contrast (EC)** | (max(E) − min(E)) / mean(E) → score S_E |
| **CPUE contrast (IC)** | max(CPUE) / min(CPUE) → score S_I |
| **Sample size** | n valid rows → score S_n |
| **Catch–effort realism** | Spearman ρ(C, E) → score S_CE |
| **Slope (β)** | From lm(log(CPUE) ~ effort) → score S_slope |
| **Outlier penalty** | Fraction of |rstandard| > 2 → penalty P_out |

Combined: **DSI = 100 × (0.35×S_slope + 0.20×S_E + 0.20×S_I + 0.10×S_n + 0.10×S_CE) × P_out**

---

## 5. Optional DSI v2 (Extra Diagnostics)

When enabled, additional checks are applied:

- **Influence / leverage** (Cook’s distance, hatvalues) → penalty P_inf
- **Residual autocorrelation** (lag-1 ACF) → score S_acf
- **Regime shift** (simple changepoint) → score S_shift
- **Identifiability** (correlation of fitted vs effort) → score S_fitE
- **Robust slope stability** (leave-one-out beta sign) → score S_stab

**DSI_v2 = DSI × P_inf × (0.85 + 0.15×S_acf) × …** (clamped to 0–100).

---

## 6. Validation and Invalid Windows

A window is **invalid** (DSI = NA) when:

- No rows in the window
- Too few valid rows (< min_n, or < 3)
- Zero variance in effort
- Min(CPUE) ≤ 0
- ρ(C,E) cannot be computed (e.g. zero variance)
- Errors in fitting or metrics

Invalid reasons are stored in the `reasons_invalid` column.

---

## 7. Outputs

| Output | Description |
|--------|-------------|
| `dsi_all_windows.csv` | All windows and metrics (DSI, DSI_v2, component scores, validity) |
| `dsi_top_windows.csv` | Top 3 windows per species × fleet (by DSI or DSI_v2 when enabled) |
| `dsi_by_species__<species>.png` | One plot per species; panels = fleets; two lines (DSI, DSI_v2) vs start year; empty panels show "Not enough data" |
| `heatmap_dsi__<group>.png` | DSI heatmap (start_year × end_year) per species × fleet |
| `heatmap_dsi_v2__<group>.png` | DSI_v2 heatmap (only when use_dsi_v2 is enabled) |
| `best_timeseries__<group>.png` | Catch / CPUE / Effort time-series with best window highlighted |
| `best_cooks__<group>.png` | Cook’s distance for best window (only when use_dsi_v2 is enabled) |

---

## 8. Interpretation

- **DSI ≥ 70**: good
- **50–70**: moderate
- **< 50**: poor

---

## 9. How to Run

```bash
cd 01_DSI_screening
Rscript R/run_dsi_screening.R
```

Main parameters (set at top of `R/run_dsi_screening.R`): `min_n`, `max_n`, `beta_ref_base`, `p_ref`, `use_dsi_v2`, `col_map`, `group_cols`.

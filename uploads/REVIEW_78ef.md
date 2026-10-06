# DSI: technical review

*Javier Porobic's DSI code base, reviewed 6 Oct 2026 (AEDT). Scope: the six R scripts, the method report (`report/DSI_report.qmd`, its rendered `.html`) and `report/DSI_guide.md`, plus a test run on the two example CSVs and on synthetic cases labelled as such.*

The report and guide describe the method. Where they disagree with the code, this review describes what the code actually does and lists the disagreement in §7.

---

## 0. Files

| Path (in `/workspace/dsi/`) | What it is |
|---|---|
| `src/R/functions_dsi.R` | Core functions: windows, per-window metrics, DSI, DSI_v2, best-window selection |
| `src/run_dsi_main.R` | Main screening run. Set up here for `Thai_main_groups.csv` (species = `group`, no fleet). Writes the CSVs and PNGs. The report calls it `R/run_dsi_screening.R` |
| `src/run_dsi_species_fleet.R` | Cut-down run for species × fleet (`all_species_combined.csv`, fleet = `gear`). Adds drift metrics. Writes CSV only |
| `src/plot_dsi_fleet_species.R` | Plots DSI and DSIr (= DSI_v2) by start year, one facet per species, lines coloured by fleet |
| `src/plot_drift_fleet_species.R` | Plots drift stability, plus DSIr against a "drift-adjusted DSIr" |
| `src/plot_dsi_dsir_timeseries.R` | `theme_report()` plus DSI vs DSIr for the main groups (Anchovy, Demersal, Pelagic) |
| `report/DSI_report.qmd`, `.html` | Method slides (revealjs) titled "Data Suitability Index (DSI): Pre-screening for Fox/Schaefer production models" |
| `report/DSI_guide.md` | Step-by-step overview of the method |
| `data/*.csv` | The user's **example** data (see §8) |
| `src/FILE_MAP.md` | Original attachment hash → new name |
| `run/` | Test harness, outputs, `checks.R` / `checks_output.txt`, `summarise.R` / `summary_output.txt` |

---

## 1. What DSI is

**DSI = Data Suitability Index** (named in the report). It is a 0–100 heuristic score for a **time window** of one stock unit (species, or species × fleet). It says how suitable the window's Catch, CPUE and Effort series are for fitting a **Fox/Schaefer surplus-production model**. Higher means more suitable. The report says it "complements expert judgment; does not replace it."

The idea behind it: a production model can only be estimated if the data show **contrast**, meaning effort varies, the index varies, and CPUE falls as effort rises. That last one is the Fox equilibrium relation, ln(U) = a + bE with b < 0. DSI rewards those features and penalises small samples, outliers, influential points, missing data and unstable slopes.

There are two scores:
- **DSI**: weighted sum of five component scores, multiplied by an outlier penalty.
- **DSI_v2**, called **DSIr** in the plot scripts: DSI_base multiplied by missingness, outlier, influence, stability and identifiability penalties.

---

## 2. Method, step by step (as the code runs it)

### 2.1 Input and column mapping
`col_map` maps your column names to the internal ones: `year` (or `date`, from which the year is taken), `species`, `fleet`, `catch`, `effort`, `cpue`. `standardize_columns()` builds `year` (integer), `species`, `fleet` and numeric `catch/effort/cpue`. Values that won't parse become NA without a warning.
- `run_dsi_main.R`: if no species column, species = `"ALL"`. If no fleet column, fleet = `"ALL_FLEET"`.
- `run_dsi_species_fleet.R`: species and fleet are required, but nothing checks that they exist.
- CPUE is **taken as supplied**. It is never derived from catch/effort or checked against them.

### 2.2 Effort harmonisation
`effort_by_fleet_year()` reduces effort to **one value per year × fleet**: the first finite value, taken in row order. That value is merged back onto every species row and replaces `effort`. It assumes effort belongs to the fleet and is repeated across species. Conflicts are counted (`effort_n_unique`, main script only) but never reported.

### 2.3 Grouping
`group_key` is species, or "species | fleet", depending on `group_cols`. Each group is screened on its own.

### 2.4 Window generation: `generate_windows(years, min_n, max_n)`
- Every window **ends at the group's last year present in the data**. Only the start year varies.
- A window is kept if its calendar length (last − start + 1) is within [min_n, max_n].
- Start years are limited to years that actually appear in the data.
- Defaults: 8–20. The main script uses 8–55.

### 2.5 Per-window metrics: `compute_window_metrics()` (DSI layer)
Within the window:
1. A row is **usable** if CPUE is finite and > 0 and effort is finite (`safe_log_cpue`).
2. Validity gates, each with a reason code:
   - `no_rows_in_window`
   - `too_few_valid_rows` (< 3)
   - `n_usable_lt_min_usable` (< 6)
   - `n_valid_lt_min_n` (< 8)
   - `effort_zero_variance`
   - `cpue_min_leq_0`
   - `rho_ce_na`
   - `error:<msg>`
3. **Model:** OLS `lm(log(CPUE) ~ E)` on usable rows. This is a Fox-type equilibrium regression. Outputs β, two-sided p and R².
4. Component scores (Π = clamp to [0,1]):

| Score | Formula | Fixed constants |
|---|---|---|
| S_slope | 0 if β ≥ 0; otherwise Π(−β/β_ref) · Π(1 − p/p_ref), with β_ref = `beta_ref_base`/mean(E) | beta_ref_base = 0.02, p_ref = 0.20 |
| S_E | Π(EC/1), EC = (max E − min E)/mean E | 1.0 |
| S_I | Π(ln IC / ln 2), IC = max CPUE / min CPUE | 2-fold contrast |
| S_n | Π((n − 8)/12) | 8, 12 (n = 20 gives full score) |
| S_CE | Π((ρ_S(C,E) + 1)/2), Spearman, on *all* window rows | – |
| P_out | 1 − Π(f_out/0.20), f_out = share of \|rstandard\| > 2 | 2, 0.20 |
| S_cov | Π((frac_usable − 0.5)/0.5), frac_usable = n_usable / rows in window | 0.5 |
| ESS | n·(1 − \|acf1\|) of OLS residuals (lag 1); S_ESS = Π((ESS − 6)/14) | 6, 14 |
| P_miss | (0.7 + 0.3·S_cov)·(0.85 + 0.15·S_ESS), range 0.595–1 | refs `p_miss_*` |

5. **DSI_base** = 100·(0.35 S_slope + 0.20 S_E + 0.20 S_I + 0.10 S_n + 0.10 S_CE) (`compute_dsi_base`).
   **DSI** = DSI_base · P_out (`compute_dsi`).

### 2.6 Robustness layer: `compute_window_v2_metrics()`
Runs only for valid windows with finite DSI. Rows are sorted by year here.
- **Influence:** f_cook = share of Cook's D > 4/n; f_lev = share of hat > 4/n. P_inf = (1 − Π(f_cook/0.2))·(1 − Π(f_lev/0.2)).
- **Autocorrelation:** s_acf = 1 − Π(\|acf1\|/0.6).
- **Regime shift:** z_shift = max over split points k of \|mean(y₁..k) − mean(y_{k+1}..n)\| / sd(y). s_shift = 1 − Π(z/2.5).
- **Identifiability:** s_fit_e = Π(\|cor(fitted, E)\|/0.7).
- **Leave-one-out slope stability:** f_beta_pos = share of jackknife β ≥ 0. s_stab = 1 − Π(f/0.3).
- **Drift** (species × fleet run only): years are split at the median. Early and late halves of catch, effort and log CPUE are compared with PSI (quantile bins from the early half, ≤ 10 bins, eps 0.005) and a KS test. Per series: s = (1 − Π(PSI/4))·Π(p_KS/0.05). s_drift = minimum over series.

### 2.7 DSI_v2: `compute_dsi_v2_robust()`
DSI_v2 = DSI_base × P_miss × P_out × P_inf × (0.85 + 0.15 S_stab) × (0.85 + 0.15 S_fitE).
- If a component is NA it is replaced: P_miss → 0.7, P_out → 1, P_inf → 1, S_stab → 0.7, S_fitE → 0.7.
- If DSI_base ≤ 0 the result is NA.
- `compute_dsi_v2()` is an alternative formula using s_acf and s_shift. It matches the guide's text but is **never called**.
- In `plot_drift_fleet_species.R` only: "DSIr (drift-adjusted)" = DSI_v2 × (0.85 + 0.15 s_drift), with NA → 0.7.

### 2.8 Best-window selection: `select_best_window_per_species(dsi_all, opts)` (main script)
Runs **per species, pooling all fleets**.
- **Eligible:** n_usable ≥ 6, β < 0, frac_usable ≥ 0.6, EC ≥ 0.4, IC ≥ 1.2, the stability test, and finite DSI_v2.
- **Ranking:** DSI_v2 descending, then n_usable desc, β asc, EC desc.
- **READY** if all three hold: ≥ 3 eligible windows; top DSI_v2 ≥ 70; top minus 3rd ≤ 20 (a plateau, not a lone spike).
- Otherwise the top window is returned with READY = FALSE and reasons `few_eligible`, `low_DSI_v2`, `unstable_spread` (or `no_eligible_windows`).
- `get_best_window_for_species()` is a lookup helper; it is never called.

### 2.9 Interpretation
- Report and guide: **≥ 70 Good, 50–70 Moderate, < 50 Poor**.
- Plots: four background zones (0–25 red `#e74c3c`, 25–50 orange `#e67e22`, 50–75 yellow `#f1c40f`, 75–100 green `#27ae60`).
- Heatmap: a different diverging RdBu scale.

### 2.10 Outputs
`run_dsi_main.R` writes to `outputs/`:
- `dsi_all_windows.csv`: every window with all metrics and `reasons_invalid`.
- `dsi_best_window_selected.csv`
- `dsi_top_windows.csv`: top 10 per species, by DSI, or by DSI_v2 if `use_dsi_v2 = TRUE`.
- `selected_window_data/<sp>_selected_window.csv`: READY species only.
- PNGs: `dsi_by_species__*`, `heatmap_dsi__*`, `best_timeseries__*`, and with v2 `heatmap_dsi_v2__*` and `best_cooks__*`.
- `run_warnings.txt` and `run_messages.txt`, written via `.with_log`, which silences warnings and messages and saves them to these files.

`run_dsi_species_fleet.R` writes `dsi_all_windows_fleet_species.csv` with a smaller column set: no `reasons_invalid`, P_miss, p_out or s_stab.

---

## 3. Function inventory

**Core (`functions_dsi.R`)**

| Signature | Role |
|---|---|
| `clamp01(x)` | Π projection |
| `safe_log_cpue(cpue)` → list(log_cpue, n_invalid, invalid_idx) | Log CPUE; non-positive or non-finite → NA |
| `generate_windows(years, min_n=8, max_n=20)` | Windows anchored at the last year |
| `.safe_spearman(x,y)` | Spearman; NA if n < 3 or sd = 0 |
| `.year_in_window(year, s, e)` | Window mask |
| `.append_reason(reasons, reason)` | Concatenates reason codes |
| `.safe_ks_pvalue(x_ref,x_new)` | KS p-value; NA if n < 5; 1 or 0 if a variance is zero |
| `.psi_numeric(x_ref,x_new,n_bins=10,eps=0.005)` | Population Stability Index |
| `.score_drift(psi, ks_p, psi_ref=4, p_ref=0.05)` | Drift score per series |
| `compute_window_metrics(df, start_year, end_year, min_n=8, min_usable=6, refs=list(...), cols=list(...))` | DSI-layer metrics and validity (§2.5) |
| `compute_dsi_base(metrics)`, `compute_dsi(metrics)` | DSI_base, DSI |
| `compute_window_v2_metrics(df, start_year, end_year, cols)` | Robustness and drift metrics (§2.6) |
| `compute_dsi_v2(dsi, v2)` | Alternative v2 formula (unused) |
| `compute_dsi_v2_robust(dsi_base, P_miss, p_out, v2)` | DSI_v2 as used |
| `default_selection_opts()` | Selection thresholds |
| `select_best_window_per_species(dsi_all, opts)` | READY logic |
| `get_best_window_for_species(dsi_table, species, require_ready=TRUE)` | Lookup (unused) |

**Script-local**
- **Main:** `standardize_columns(df,map)`, `effort_by_fleet_year(df)`, `make_group_key(df,cols)`, `.with_log(expr)`, `.theme_base()`, `.scale_fill_dsi()`, `.scale_colour_group()` (unused), `.safe_filename(x)`, `plot_heatmap(dd,score_col,title,out_path)`, `plot_dsi_by_species(dsi_all,species_id,all_fleets,out_path)`, `plot_best_timeseries(d_g,best_row,out_path)`, `plot_best_cooks(d_g,best_row,out_path)`.
- **Plot scripts:** `theme_report(base_size=11)` (defined three times, identically), `species_cols()`, `make_plot(...)` (two different versions).
- **Hard-coded lookups:** `sp_labels` (8 species codes), `fleet_labels` and `fleet_cols` (6 gears), `zones`, and `vlines` (1996, 1971, 2001: defined but never drawn).

---

## 4. Parameters you would want to tune

- **Windowing:** `min_n`, `max_n`; anchor (last year present vs last *usable* year); free end year.
- **Validity:** `min_usable`; minimum rows (3, hard-coded).
- **Slope:** `beta_ref_base`, `p_ref`; one- vs two-sided p.
- **Hard-coded scaling constants** (should all be exposed): EC full-score 1.0; IC full-score 2×; S_n 8/12; outlier \|r\| > 2 and cap 0.20; S_cov 0.5; ESS 6/14; Cook and leverage thresholds 4/n and cap 0.20; s_acf 0.6; z_shift 2.5; s_fit_e 0.7; s_stab 0.3; PSI ref 4, KS p ref 0.05, bins 10.
- **Weights:** 0.35, 0.20, 0.20, 0.10, 0.10. The (0.85 + 0.15·x) blend for the v2 multipliers. NA defaults (0.7, 1, 1, 0.7, 0.7).
- **Penalties:** `p_miss_cov_lo/hi`, `p_miss_ess_lo/hi`.
- **Selection:** `min_frac_usable`, `min_EC`, `min_IC`, `max_f_beta_pos`, `min_eligible_windows`, `min_DSI_v2_top1`, `max_DSI_v2_spread`. Which score drives selection (DSI or DSI_v2).
- **Interpretation:** band cut-points.
- **Data handling:** effort aggregation rule (first value, mean, sum, or refuse on conflict); grouping.

---

## 5. Test run (R 4.x installed on the box via apt)

All runs reproduce the user's folder layout under `run/`. The hard-coded `setwd()` was commented out in the test copy of `plot_drift_fleet_species.R` only. Runtime is about 10 s (main) and 5 s (species × fleet).

**Example data, main script** (`run/01_DSI_screening/outputs_main/`):
- 132 windows (lengths 8–54), all valid.
- Median DSI: 60 / 54 / 42 (Anchovy / Demersal / Pelagic). Median DSI_v2: 28 / 26 / 20.
- READY: Demersal only (1998–2024, DSI_v2 = 70.3). Anchovy and Pelagic: `low_DSI_v2`.

**Example data, species × fleet** (`outputs_species_fleet/`):
- 47 of 48 groups produce windows (DMF | APS spans only 7 years).
- 493 windows, 241 valid. Invalid: 142 `n_usable_lt_min_usable`, 74 `n_valid_lt_min_n`, 36 `too_few_valid_rows`.
- Median DSI 43, median DSI_v2 10. **No group reaches DSI_v2 ≥ 50.** Best: LPF | OBT 2004–2023, DSI_v2 = 41.9.

**Synthetic checks** (`run/checks.R`, `run/checks_output.txt`). These use SYNTHETIC data: log CPUE = 2 − 0.004E + N(0, 0.15²), effort 50→250, n = 15, 500 replicates. The data follow the model exactly and are about as good as a window can get:
- DSI_base ≈ 90, but median DSI = 60 and median **DSI_v2 = 37.6**.
- P_out < 1 in 57 % of replicates. P_inf ≤ 0.5 in 24 %.
- s_fit_e = 1 in every replicate.
- s_drift = 0 in nearly all replicates.

---

## 6. Problems found, ranked by impact (all confirmed by running the code)

1. **The main script overwrites each group's effort with another group's.** Without a fleet column, every row gets fleet `ALL_FLEET`, so `effort_by_fleet_year` assigns *the first group's effort in each year* to all groups.
   - In `Thai_main_groups.csv`, effort differs by group in 52 of 52 years, and cpue = 1000 × yield / effort using each group's own effort. So effort is group-specific.
   - Merged effort ≠ own effort in 94 % of Demersal years and 100 % of Pelagic years.
   - Using each group's own effort changes DSI by up to 56 (Demersal) and 71 (Pelagic) points, and **changes the outcome**: Pelagic becomes READY (2009–2024, 76.8), Demersal drops to 61.3.
   - Test copy: `run_dsi_main_fixed_effort.R`.
2. **The penalties are steps and they pile up.** With n ≈ 8–20, one standardised residual > 2 removes 25–50 % of the score through P_out. One point above the Cook or leverage threshold removes as much again through P_inf. Under correct Gaussian errors about 5 % of points exceed \|r\| > 2, so "clean" windows are routinely marked Poor (median DSI_v2 37.6 above). The 3-band labels, which are on the DSI scale, are then applied to DSI_v2, which is much lower.
3. **Spurious slope when CPUE = C/E.** ln(C/E) regressed on E has a negative slope even when catch is pure noise. In SYNTHETIC tests with catch independent of effort: β < 0 in 100 % of runs, median p = 2×10⁻⁶, median DSI = 58.6, and 96 % score ≥ 50. S_CE (weight 0.10) only partly protects against this. It applies directly to `Thai_main_groups.csv`, where cpue is exactly yield/effort.
4. **Lag-1 ACF / ESS uses rows in merge order, not year order.** `merge(sort = FALSE)` leaves rows unsorted in 29 of 48 species × fleet groups, and in Demersal and Pelagic. In a SYNTHETIC test, shuffling rows changed acf1 from 0.68 to 0.28 and ESS from 4.9 to 10.8. The v2 layer sorts first; the v1 layer does not.
5. **Missing years don't count against coverage.** frac_usable = usable / rows *present*, but the report defines it per year. A SYNTHETIC 20-year window with 5 years absent gets frac_usable = 1 and P_miss = 0.92. The same 5 years present with NA CPUE get 0.75 and 0.79.
6. **Trailing missing CPUE.** In the example data CPUE is NA for 2019–2023 in about 46 of 48 groups, while catch runs to 2023. Every window ends at 2023 anyway, so ≥ 5 years of each window are unusable. The best possible n_usable is 15, which caps S_n at 0.58 and S_cov at 0.5. This explains why the species × fleet results are structurally low. Windows should be anchored on the last *usable* year.
7. **The selection's stability filter does nothing.** `(f_beta_pos ≤ 0.3) | (s_stab ≥ 0)` is always TRUE. A SYNTHETIC case with f_beta_pos = 0.9 passes as READY.
8. **S_fitE is always 1.** In simple OLS, fitted values are linear in E, so \|cor\| = 1. That term is effectively a constant ×1 (or ×0.955 when NA).
9. **The drift diagnostic contradicts the index.** It penalises early vs late differences in effort and log CPUE, which is exactly the contrast DSI rewards. In the synthetic depletion case s_drift = 0 almost always. It needs reframing, e.g. drift in the *residuals* or in the catch–effort relationship, not in the raw series.
10. **The weights sum to 0.95**, so DSI ≤ 95. This is undocumented. Either intended or a typo (S_n or S_CE meant to be 0.15?).
11. **Several different "best" windows.**
    - `dsi_top_windows.csv` and `best_timeseries__*.png` rank by DSI, because `use_dsi_v2 = FALSE`.
    - Selection ranks by DSI_v2.
    - In the example these disagree for all three groups (e.g. Demersal: 2008 by DSI vs 1998 by DSI_v2).
    - The guide says top 3 per species × fleet; the code writes top 10 per species.
12. **The heatmap is degenerate.** All windows share one end year, so `heatmap_dsi__*` is a single strip.
13. **Smaller issues:**
    - `min_usable` (6) is always overridden by `min_n` (8).
    - ESS = n(1 − \|ρ\|) is not the AR(1) formula n(1 − ρ)/(1 + ρ), and negative ρ is penalised too.
    - The p-value is two-sided, although only β < 0 is rewarded.
    - S_slope saturates: −β·mean(E) ≥ 0.02 is almost always met, so it is really a p-value score.
    - EC and IC come from raw max/min, so one extreme year can drive them.
    - DSI_v2 is NA, not 0, when DSI_base = 0.
    - The effort aggregation picks the first value silently.
    - Unparseable numbers become NA without a warning.
    - `group_key` is split on " | ", which breaks if a name contains it.
    - Plot scripts drop codes missing from `sp_labels`/`fleet_labels` (they become NA).
    - `plot_dsi_fleet_species.R` reads `dsi_all_windows__all_species.csv`, which no supplied script writes.
    - `plot_drift_fleet_species.R` has an absolute `setwd('/home/por07g/...')`.
    - `geom_line` joins lines across invalid windows.
    - The zone colours (red/orange/yellow/green) and the tab10 fleet colours clash: a red fleet line sits on a red band. Red vs green is not colour-blind safe.
    - `.with_log` silences every warning.

## 7. Report and guide vs code

| Topic | Report / guide | Code |
|---|---|---|
| DSI_v2 formula | Guide: DSI × P_inf × (0.85 + 0.15 S_acf) × … ; Report: robust formula | Robust formula (no S_acf or S_shift); the guide's formula is never called |
| "Optional DSI_v2" | Enabled by `use_dsi_v2` | Always computed; the flag only changes ranking and plots |
| n_total | Years in window | Rows in window |
| Top windows | Top 3 per species × fleet | Top 10 per species |
| Bands | 3 bands (50/70) | Plots use 4 zones (25/50/75) |
| Drift / DSIr | Not mentioned | Species × fleet run and plots |
| S_slope | Formula only partly given | §2.5 |
| Weights | Sum shown as given | Sum to 0.95, not stated |

The rendered `.html` also shows the mermaid chunk options as plain text, so the workflow diagram did not render.

## 8. Example data (schema only; the app must stay generic)

- **`all_species_combined.csv`**: 1 874 rows × `species, gear, year, catch, effort, cpue`.
  - 8 species codes × 6 gears; 48 groups, 4–53 years each; 1971–2023.
  - Effort is unique per gear × year.
  - 29 effort NAs (AFN 1999–2015); 323 CPUE NAs (mostly 2019–2023).
  - CPUE is not catch/effort; it is an independent index.
- **`Thai_main_groups.csv`**: 153 rows × `year, group, yield, effort, cpue`.
  - 3 groups; 1971–2024; no NAs.
  - Effort is group-specific. cpue = 1000 · yield / effort.

## 9. Ambiguities and missing pieces

**Ambiguous:**
- Whether the 0.95 weight sum is intended.
- Whether 3 or 4 interpretation bands are canonical.
- Whether DSI or DSI_v2 should drive selection.
- Whether drift should feed into the score.
- The meaning of the `vlines` years (1996, 1971, 2001).
- The rationale for each constant (0.02, 0.20, 2.5, …).
- Whether selection should pool fleets per species, as it does now.

**Not supplied:**
- `R/run_dsi_screening.R` (the name the report uses; probably a version of `run_dsi_main.R` set up for species × fleet, since the report shows `dsi_by_species__ANC.png`).
- `plot_style.R` / `check_plot_style()` (optional, sourced if present).
- `DSI_presentation_style.css`.
- The `outputs/*.png` figures the report embeds.
- The script that writes `dsi_all_windows__all_species.csv`.
- The `Report/DSI/figures` folder.
- The downstream Fox/Schaefer fitting step.

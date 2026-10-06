# Source file map (original attachment hash -> content-based name)
| New name | Original | Content |
|---|---|---|
| R/functions_dsi.R | d407b614...c78.r | Core DSI functions (windows, metrics, DSI/DSI_v2, selection) |
| run_dsi_main.R | 3600a5e7...195d2.r | Main screening on Thai_main_groups.csv (species=group, no fleet), outputs + plots |
| run_dsi_species_fleet.R | f9672aa2...7f7c.r | Screening species x fleet (gear) on all_species_combined.csv, adds drift metrics |
| plot_drift_fleet_species.R | dd990bab...1d05.r | Drift stability + drift-adjusted DSIr plots, species x fleet |
| plot_dsi_fleet_species.R | 2ad6c290...e5ac.r | DSI and DSIr faceted by species, coloured by fleet (defines species_cols, theme_report) |
| plot_dsi_dsir_timeseries.R | 0edd28d6...a242.r | theme_report + DSI vs DSIr by start year for main groups (Anchovy/Demersal/Pelagic) |
| ../report/DSI_report.qmd | 00c1d944...cda44.qmd | Method slides (revealjs), "Data Suitability Index (DSI)" |
| ../report/DSI_report.html | ba9c7330...45d.html | Rendered version of the qmd (same content; figures not embedded) |
| ../report/DSI_guide.md | d6d0fa47...fe61.md | "DSI Screening: Overview and Steps" guide |
| ../data/all_species_combined.csv | 1fd802a0...5023.csv | EXAMPLE species x gear data |
| ../data/Thai_main_groups.csv | d294f3a1...3251.csv | EXAMPLE main groups data |

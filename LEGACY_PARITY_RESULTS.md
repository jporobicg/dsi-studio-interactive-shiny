# Legacy Parity Verification

Run from the repository root:

```bash
Rscript tools/check_legacy_parity.R
```

The script runs Javier's **original scripts live** (`uploads/dsi/src/run_dsi_main.R` and
`run_dsi_species_fleet.R`, copied into a temp dir together with `R/functions_dsi.R` and the
example data), also loads the reference CSVs shipped in `uploads/dsi/run/01_DSI_screening/`,
and compares both against `run_dsi_workflow(method = "legacy")`. It exits non-zero on failure.

## Result (2026-10-06)

| Case | Original windows | App windows | Matched (all of valid, beta, p, DSI, DSI_v2 within 1e-8) | max abs diff DSI_v2 |
|---|---|---|---|---|
| Main groups, live original run | 132 | 132 | 132 / 132 | 5.33e-14 |
| Main groups, shipped reference CSV | 132 | 132 | 132 / 132 | 5.33e-14 |
| Species x fleet, live original run | 493 | 493 | 493 / 493 | 5.15e-14 |
| Species x fleet, shipped reference CSV | 493 | 493 | 493 / 493 | 5.15e-14 |

Summary table: `parity/parity_summary.csv`.

## About the "0 vs 132" result reported in VERIFICATION_REPORT.md

That number did not come from the legacy implementation. It was not a regression either. It came from a broken ad-hoc check:

1. The one-liner in VERIFICATION_REPORT.md ran `method = "corrected"`, not `"legacy"`, so it
   was never comparable to the legacy reference output.
2. It printed `nrow(result$summary)`, but `run_dsi_workflow()` returns no `summary` element
   (it returns `data_std, audit, windows, dsi_all, dsi_best, config`). `nrow(NULL)` is `NULL`,
   `sprintf("%d", NULL)` is `character(0)`, so nothing was printed and that was read as "0".
   The same call actually produces 132 windows (132 valid) in `result$dsi_all`.
3. The old `check_legacy_parity.R` could never run. It `setwd()`'d into `uploads/dsi/src`,
   called `standardize_columns()`, which does not exist in the original `functions_dsi.R`, and
   `setwd(".")` would not have returned to the repo root anyway. The committed
   `parity_check_output.txt` was a truncated log of that ad-hoc corrected-method run.

The old `check_legacy_parity_v2.R`, which compares against the shipped CSV, gave 132/132 at every commit
from 3350d0e to b992ee0. Both old scripts are replaced by `tools/check_legacy_parity.R`.

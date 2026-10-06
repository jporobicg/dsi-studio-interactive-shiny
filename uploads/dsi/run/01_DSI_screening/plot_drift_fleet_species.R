## Plot drift diagnostics (species × fleet) in DSI style
##
## Run from: DSI_test/01_DSI_screening/

suppressPackageStartupMessages(library(ggplot2))

zones <- data.frame(
  ymin = c(0, 25, 50, 75),
  ymax = c(25, 50, 75, 100),
  fill = c("#e74c3c", "#e67e22", "#f1c40f", "#27ae60"),
  stringsAsFactors = FALSE
)

theme_report <- function(base_size = 11) {
  theme_minimal(base_size = base_size) +
    theme(
      text = element_text(color = "black"),
      plot.title = element_text(size = base_size + 2, face = "bold", hjust = 0),
      axis.title = element_text(size = base_size * 1.1, face = "bold" ),
      axis.text = element_text(size = base_size, face = "bold"),
      legend.title = element_text(size = base_size, face = "bold"),
      legend.text = element_text(size = base_size,face="bold"),
      panel.grid.major = element_line(color = "gray90", linewidth = 0.5),
      panel.grid.minor = element_blank(),
      panel.background = element_rect(fill = "white", color = NA),
      plot.background = element_rect(fill = "white", color = NA),
      axis.line = element_line(color = "black", linewidth = 0.5),
      axis.ticks = element_line(color = "black", linewidth = 0.5),
      legend.position = "bottom",
      legend.background = element_rect(fill = "white", color = "gray80"),
      legend.key = element_rect(fill = "white", color = NA),
      plot.margin = margin(10, 10, 10, 10, "pt"),
      strip.text = element_text(face = "bold", size = base_size + 1)
    )
}

sp_labels <- c(
  "DMF" = "Demersal Fish",
  "NTU" = "Neritic Tunas",
  "CMA" = "Coastal Mackerel",
  "MPF" = "Medium Pelagic Fish",
  "SCP" = "Small Coastal Pelagics",
  "LPF" = "Large Pelagic",
  "ANC" = "Anchovies",
  "SAR" = "Sardine"
)

fleet_labels <- c(
  "OBT" = "Otter board trawl",
  "PT"  = "Pair trawl",
  "PS"  = "Purse seine",
  "APS" = "Anchovy purse seine",
  "GN"  = "Gill net",
  "AFN" = "Anchovy falling net"
)

fleet_cols <- c(
  "Otter board trawl"    = "#1f77b4",
  "Pair trawl"           = "#ff7f0e",
  "Purse seine"          = "#2ca02c",
  "Anchovy purse seine"  = "#d62728",
  "Gill net"             = "#9467bd",
  "Anchovy falling net"  = "#8c564b"
)
## setwd removed for test (was hard-coded absolute path)
in_path <- file.path("outputs", "dsi_all_windows_fleet_species.csv")
stopifnot(file.exists(in_path))
d <- read.csv(in_path, stringsAsFactors = FALSE)
d <- d[d$valid %in% TRUE, , drop = FALSE]

d$species <- factor(sp_labels[d$species], levels = sp_labels)
d$fleet <- factor(fleet_labels[d$fleet], levels = fleet_labels)

make_plot <- function(dat, score, score_label, title) {
  dat$score <- score
  dat <- dat[is.finite(dat$score), , drop = FALSE]

  ggplot(dat, aes(x = start_year, y = score, colour = fleet)) +
    geom_rect(data = zones, inherit.aes = FALSE,
              aes(xmin = -Inf, xmax = Inf, ymin = ymin, ymax = ymax, fill = fill),
              alpha = 0.18) +
    scale_fill_identity() +
    geom_line(linewidth = 0.8, na.rm = TRUE) +
    facet_wrap(~species, ncol = 4) +
    scale_colour_manual(values = fleet_cols, name = "Fleet") +
    coord_cartesian(ylim = c(0, 100)) +
    labs(title = title, x = "Start year of window", y = score_label) +
    guides(colour = guide_legend(nrow = 1)) +
    theme_report()
}

## Drift stability score (0–100 for plotting)
d$drift100 <- 100 * d$s_drift
p_drift <- make_plot(d, d$drift100, "Drift stability (0–100)", "Dataset shift (drift) stability by species and fleet")

## Drift-penalised DSIr variant for influence display
sd_def <- ifelse(is.finite(d$s_drift), d$s_drift, 0.7)
d$dsir_drift <- pmin(100, pmax(0, d$dsi_v2 * (0.85 + 0.15 * sd_def)))

long <- rbind(
  data.frame(start_year = d$start_year, species = d$species, fleet = d$fleet, metric = "DSIr", value = d$dsi_v2),
  data.frame(start_year = d$start_year, species = d$species, fleet = d$fleet, metric = "DSIr (drift-adjusted)", value = d$dsir_drift)
)
long <- long[is.finite(long$value), , drop = FALSE]

p_dsir_drift <- ggplot(long, aes(x = start_year, y = value, colour = fleet, linetype = metric)) +
  geom_rect(data = zones, inherit.aes = FALSE,
            aes(xmin = -Inf, xmax = Inf, ymin = ymin, ymax = ymax, fill = fill),
            alpha = 0.18) +
  scale_fill_identity() +
  geom_line(linewidth = 0.75, na.rm = TRUE) +
  facet_wrap(~species, ncol = 4) +
  scale_colour_manual(values = fleet_cols, name = "Fleet") +
  scale_linetype_manual(values = c("DSIr" = "solid", "DSIr (drift-adjusted)" = "dashed"), name = NULL) +
  coord_cartesian(ylim = c(0, 100)) +
  labs(title = "Influence of drift diagnostic on DSIr",
       x = "Start year of window", y = "Score") +
  guides(colour = guide_legend(nrow = 1), linetype = guide_legend(nrow = 1)) +
  theme_report()

## Save to DSI_test outputs
ggsave(file.path("outputs", "drift_fleet_species.png"), p_drift, width = 12, height = 9, dpi = 300)
cat("Saved: outputs/drift_fleet_species.png\n")

ggsave(file.path("outputs", "dsir_drift_fleet_species.png"), p_dsir_drift, width = 12, height = 9, dpi = 300)
cat("Saved: outputs/dsir_drift_fleet_species.png\n")

## Copy into the report figures folder (best-effort; works when run from repo root too)
out1 <- file.path("outputs", "drift_fleet_species.png")
out2 <- file.path("outputs", "dsir_drift_fleet_species.png")
rep_dir <- file.path("..", "..", "Report", "DSI", "figures")
if (dir.exists(rep_dir)) {
  file.copy(out1, file.path(rep_dir, "drift_fleet_species.png"), overwrite = TRUE)
  file.copy(out2, file.path(rep_dir, "dsir_drift_fleet_species.png"), overwrite = TRUE)
  cat("Copied figures to: ", rep_dir, "\n", sep = "")
}

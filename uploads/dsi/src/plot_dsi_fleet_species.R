suppressPackageStartupMessages(library(ggplot2))

source(file.path("R", "functions_dsi.R"))

species_cols <- function() {
  c(
    "DMF" = "#1f77b4",
    "NTU" = "#ff7f0e",
    "CMA" = "#2ca02c",
    "MPF" = "#d62728",
    "SCP" = "#9467bd",
    "LPF" = "#8c564b",
    "ANC" = "#e377c2",
    "SAR" = "#7f7f7f"
  )
}

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

zones <- data.frame(
  ymin = c(0,  25, 50, 75),
  ymax = c(25, 50, 75, 100),
  fill = c("#e74c3c", "#e67e22", "#f1c40f", "#27ae60"),
  stringsAsFactors = FALSE
)

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

dsi_all <- read.csv(file.path("outputs", "dsi_all_windows__all_species.csv"),
                    stringsAsFactors = FALSE)
dsi_all <- dsi_all[dsi_all$valid == TRUE, , drop = FALSE]
dsi_all$fleet   <- factor(fleet_labels[dsi_all$fleet],   levels = fleet_labels)
dsi_all$species <- factor(sp_labels[dsi_all$species],    levels = sp_labels)

make_plot <- function(dat, score_col, score_label) {
  dat$score <- dat[[score_col]]
  dat <- dat[is.finite(dat$score), , drop = FALSE]

  ggplot(dat, aes(x = start_year, y = score, colour = fleet)) +
    geom_rect(data = zones, inherit.aes = FALSE,
              aes(xmin = -Inf, xmax = Inf, ymin = ymin, ymax = ymax, fill = fill),
              alpha = 0.18) +
    scale_fill_identity() +
    geom_line(linewidth = 0.8) +
    facet_wrap(~species, ncol = 4) +
    scale_colour_manual(values = fleet_cols, name = "Fleet") +
    coord_cartesian(ylim = c(0, 100)) +
    labs(title = paste0(score_label, " by species and fleet"),
         x = "Start year of window",
         y = score_label) +
    guides(colour = guide_legend(nrow = 1)) +
    theme_report()
}

p_dsi  <- make_plot(dsi_all, "dsi",    "DSI")
p_dsir <- make_plot(dsi_all, "dsi_v2", "DSIr")

ggsave(file.path("outputs", "dsi_fleet_species.png"),
       p_dsi,  width = 16, height = 9, dpi = 400)
cat("Saved: outputs/dsi_fleet_species.png\n")

ggsave(file.path("outputs", "dsir_fleet_species.png"),
       p_dsir, width = 16, height = 9, dpi = 400)
cat("Saved: outputs/dsir_fleet_species.png\n")

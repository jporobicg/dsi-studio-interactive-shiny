suppressPackageStartupMessages(library(ggplot2))
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


dsi_all <- read.csv(file.path("outputs", "dsi_all_windows.csv"),
                    stringsAsFactors = FALSE)

dsi_all <- dsi_all[dsi_all$valid == TRUE, , drop = FALSE]

long <- rbind(
  data.frame(start_year = dsi_all$start_year,
             species    = dsi_all$species,
             metric     = "DSI",
             value      = dsi_all$dsi,
             stringsAsFactors = FALSE),
  data.frame(start_year = dsi_all$start_year,
             species    = dsi_all$species,
             metric     = "DSIr",
             value      = dsi_all$dsi_v2,
             stringsAsFactors = FALSE)
)
long <- long[is.finite(long$value), , drop = FALSE]

vlines <- data.frame(
  species = c("Anchovy", "Demersal", "Pelagic"),
  xint    = c(1996,       1971,       2001),
  stringsAsFactors = FALSE
)

zones <- data.frame(
  ymin   = c(0,   25,  50,  75),
  ymax   = c(25,  50,  75,  100),
  fill   = c("#e74c3c", "#e67e22", "#f1c40f", "#27ae60"),
  stringsAsFactors = FALSE
)

p <- ggplot(long, aes(x = start_year, y = value)) +
  geom_rect(data = zones, inherit.aes = FALSE,
            aes(xmin = -Inf, xmax = Inf, ymin = ymin, ymax = ymax, fill = fill),
            alpha = 0.18) +
  scale_fill_identity() +
  geom_line(aes(colour = metric, linetype = metric), linewidth = 0.9) +
  geom_point(aes(colour = metric), size = 2) +
  facet_wrap(~species, ncol = 1, scales = "free_y") +
  scale_colour_manual(values = c("DSI" = "#2166ac", "DSIr" = "#b2182b")) +
  scale_linetype_manual(values = c("DSI" = "solid", "DSIr" = "dashed")) +
  scale_x_continuous(limits = c(1971, NA), breaks = seq(1975, 2020, by = 5)) +
  coord_cartesian(ylim = c(0, 100)) +
  labs(x = "Start year of window",
       y = "Score",
       colour = NULL, linetype = NULL) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    legend.position  = "bottom",
    strip.text       = element_text(face = "bold", size = 12)
  ) + theme_report()

ggsave(file.path("outputs", "dsi_dsir_timeseries.png"),
       p, width = 10, height = 9, dpi = 300)

cat("Plot saved to outputs/dsi_dsir_timeseries.png\n")
